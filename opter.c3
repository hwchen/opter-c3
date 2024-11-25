// Basic lexer for cli options.
// Supports:
// - short opts
// - long opts
// - positional args
// - options with multiple arguments
// - -- marks the end of options
// - ' ' or = or (unseparated short) for opt-value separator
// - short -abc

// - TODO test all errors
// - test unexpected args in example
// - test no more value(s)

// === Error Handling ===
//
// Opter is fairly simple, but will write a nice-ish error message before returning an error.
//
// Currently does not handle parsing values, so user needs to either write those messages themselves,
// or pass the parse error into `Opter.write_err_parse_value(err)` for Opter to write the message.

module opter;
import std::collections::list;
import std::core::string;
import std::io;

def ValueList = List(<Value>);
distinct Value = String;

struct Opter {
	String[] args;
	ulong idx_args;
	ulong idx_arg; // for multiple chars and non-space separator
	OutStream out;
}

fn void Opter.init(&opter, String[] args, OutStream out = io::stdout()) {
	opter.args = args;
	opter.idx_args = 1;
	opter.idx_arg = 0;
	opter.out = out;
}

fn Arg! Opter.next(&o) {
	// Valid end of args
	if (o.idx_args == o.args.len) return { .type = EOF };

	String curr_arg = o.args[o.idx_args];
	Arg arg;
	switch (o.idx_arg) {
		// At beginning of curr_arg
		case 0:
			switch {
				// LONG at beginning of arg
				case curr_arg[0:2] == "--":
					// Valid end of args --
					if (curr_arg.len == 2) return { .type = EOF };
					arg.type = LONG;
					o.idx_arg = curr_arg.index_of_char('=') ?? curr_arg.len;
					// TODO disallow = directly after --?
					arg.long_name = curr_arg[2..o.idx_arg - 1];
					if (o.idx_arg == curr_arg.len) {
						o.idx_args += 1;
						o.idx_arg = 0;
					} else {
						o.idx_arg += 1;
					}

				// SHORT at beginning of arg
				case curr_arg[0] == '-':
					if (curr_arg.len == 1) {
						o.write_err("dash followed by space not allowed");
						return OpterError.ERROR?;
					}
					arg.type = SHORT;
					arg.short_name = curr_arg[1];
					if (curr_arg.len == 2) {
						o.idx_args += 1;
					} else if (curr_arg[2] == '=') {
						o.idx_arg += 3;
					} else {
						o.idx_arg += 2;
					}

				// VALUE at beginning of arg
				default:
					arg.type = VALUE;
					arg.value = (Value)curr_arg;
					o.idx_args += 1;
			}

		// collected shorts in the middle of the arg
		// If user wants a value following a short, they should call 'value()'
		default:
			// o.idx_arg == curr_arg.len should be unreachable; if was at end of an arg,
			// should have moved to the next
			assert(o.idx_arg < curr_arg.len);
			if (curr_arg[0:2] == "--") {
				o.write_err("attempted to parse a flag or positional argument, only values allowed afer '='");
				return OpterError.ERROR?;
			}
			arg.type = SHORT;
			arg.short_name = curr_arg[o.idx_arg];
			if (o.idx_arg == curr_arg.len - 1) {
				o.idx_args += 1;
				o.idx_arg = 0;
			} else {
				o.idx_arg += 1;
			}
	}
	return arg;
}

// Always reads to the end of the word. So things like
// -aone-btwo are read as "-a" "one-btwo" and not "-a" "one" "-b" "two"
fn Value! Opter.value(&o) {
	// Error if there's no more words to read.
	if (o.idx_args >= o.args.len) {
		o.write_err_missing_value();
		return OpterError.ERROR?;
	}

	// If in the middle of an arg, reads the rest of it.
	// If at the beginning reads the entire thing.
	String curr_arg = o.args[o.idx_args];
	String res = curr_arg[o.idx_arg..];
	o.idx_args += 1;
	o.idx_arg = 0;
	return (Value)res;
}

fn ValueList! Opter.values(&o, Allocator alloc = allocator::heap()) {
	ValueList values;
	// if called in middle of word, then return until the end of that word only.
	if (o.idx_arg != 0) {
		Value val = o.value()!!;
		values.push((Value)val);
		return values;
	}

	// returns all args until the end, or the next arg starts with '-'
	String curr_arg = o.args[o.idx_args];

	values.push((Value)curr_arg[o.idx_arg..]);
	o.idx_args += 1;
	o.idx_arg = 0;
	while (o.idx_args < o.args.len) {
		String curr_value = o.args[o.idx_args];
		// breaks on short or long flag
		if (curr_value[0] == '-') break;
		values.push((Value)curr_value);
		o.idx_args += 1;
	}
	return values;
}

fault OpterError {
	ERROR,
}

// For use in error messages.
fn String Opter.last_processed_arg(&o) @private {
	return o.args[o.idx_args - 1];
}

fn void Opter.write_err(&o, String msg) @private {
	String arg = o.last_processed_arg();
	io::fprintfn(o.out, "Error at \"%s\": %s", arg, msg);
}

fn void Opter.write_err_missing_value(&o) @private {
	String arg = o.last_processed_arg();
	io::fprintfn(o.out, "Missing value after argument \"%s\"", arg);
}

// User should call this in default case when switching on `Arg arg = parser.next()!`
fn void Opter.write_err_unexpected_arg(&o) {
	String arg = o.last_processed_arg();
	io::fprintfn(o.out, "Found unexpected argument \"%s\"", arg);
}

// Currently used by users. But in future, Opter may handle parsing internally.
fn void Opter.write_err_parse_value(&o, anyfault err) {
	String arg = o.last_processed_arg();
	io::fprintfn(o.out, "Error parsing argument \"%s\": %s", arg, err);
}

struct Arg {
	ArgType type;
	union {
		char short_name;
		String long_name;
		Value value;
	}
}

enum ArgType {
	EOF,
	SHORT,
	LONG,
	VALUE,
}

macro bool Arg.is(&arg, ArgType $type, ...) {
	$switch ($type)
		$case SHORT:
			$assert($vacount == 1);
			return arg.type == SHORT && $vaexpr[0] == arg.short_name;
		$case LONG:
			$assert($vacount == 1);
			return arg.type == LONG && $vaexpr[0] == arg.long_name;
		$case VALUE:
			$assert($vacount == 0);
			return arg.type == VALUE;
	$endswitch
}

fn String Value.as_str(value) {
	return (String)value;
}

fn Path! Value.as_path(value) {
	Path! path = path::new((String)value);
	if (catch err = path) {
		io::fprintfn(io::stdout(), "Error parsing argument \"%s\": %s", value, err);
	}
	return path;
}

macro Value.as_int(value, $Type, int base = 10) {
	String s = (String)value;
	// calling to_integer twice is weird, working around some weirdness
	// where $Type! n = s.to_integer($Type, base); gives
	// `Error: It is not possible to cast from 'uint!' to 'uint'.` when called with uint
	if (catch err = s.to_integer($Type, base)) {
		io::fprintfn(io::stdout(), "Error parsing argument \"%s\": %s", value, err);
		return OpterError.ERROR?;
	}
	return s.to_integer($Type, base)!!;
}


// Tests

fn void assert_arg(Arg found, Arg expected) @private {
	assert(found.type == expected.type, "Found %s, expected %s", found.type, expected.type);
	switch (found.type) {
		case SHORT:
			assert(found.short_name == expected.short_name, "Found %c, expected %c", found.short_name, expected.short_name);
		case LONG:
			assert(found.long_name == expected.long_name, "Found %s, expected %s", found.long_name, expected.value);
		case VALUE:
			assert(found.value == expected.value, "Found %s, expected %s", found.value, expected.value);
		case EOF: // covered by assert on .type
	}
}

fn void test_short_no_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_no_value_calls_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	DString out; // write here instead of stdout for err
	opter.init(input, &out);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(!@ok(opter.value()));
}

fn void test_short_with_value() @test {
	String[] input = { "test", "-n" "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_with_value_no_separator() @test {
	String[] input = { "test", "-none"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_with_value_eq_separator() @test {
	String[] input = { "test", "-n=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_no_value() @test {
	String[] input = { "test", "--number" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "number" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_no_value_calls_value() @test {
	String[] input = { "test", "--foo" };
	Opter opter;
	DString out; // write here instead of stdout for err
	opter.init(input, &out);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(!@ok(opter.value()));
}

fn void test_long_with_value() @test {
	String[] input = { "test", "--foo", "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.value()!! == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_with_value_eq_separator() @test {
	String[] input = { "test", "--foo=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.value()!! == "one");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_positional() @test {
	String[] input = { "test", "thing" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = VALUE, .long_name = "thing" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_then_another() @test {
	String[] input = { "test", "-n", "-o"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'o' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_then_another() @test {
	String[] input = { "test", "--foo", "--bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "bar" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_positional_then_another() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = VALUE, .value = "foo" });
	assert_arg(opter.next()!!, Arg { .type = VALUE, .value = "bar" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_basic() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_then_short() @test {
	String[] input = { "test", "foo", "bar", "-a" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'a' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_then_long() @test {
	String[] input = { "test", "foo", "bar", "--baz" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_values() @test {
	String[] input = { "test", "-f", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert(opter.values()!!.array_view() == { "bar", "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_values() @test {
	String[] input = { "test", "--foo", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.values()!!.array_view() == { "bar", "baz" });
	assert_arg(opter.next()!!, { .type = EOF });
}

// values can start in the middle of a word, but will only go to end of that word
fn void test_values_starting_condition() @test {
	String[] input = { "test", "-fbar", "baz", "one" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert(opter.values()!!.array_view() == { "bar" });
}

fn void test_positional_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = VALUE, .value = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_end_mark() @test {
	String[] input = { "test", "-f", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_long_end_mark() @test {
	String[] input = { "test", "--foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_value_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.value()!! == "foo");
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_values_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}

fn void test_short_cluster() @test {
	String[] input = { "test", "-abc", "--foo" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'a' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'b' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'c' });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, { .type = EOF });
}
