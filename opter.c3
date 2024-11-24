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
// TODO trying to simplify interface, so this section may not apply.
//
// It's a bit more manual than something like Rust's lexopt, which creates errors in the
// parser and just bubbles them up on each function call `next()` or `value()`, etc.
//
// Instead, Opter methods will just issue an END Fault if there's any reason to stop, whether
// it's the happy path or the error path. And then it's up to the user to call a function to write
// the error to file. This way, the control flow (happy path and error path) are separated from
// writing error messages. If you try to streamline error message writing, control flow must be
// controlled by Opter, which is confusing as the user can no longer easily see when errors occur.
// (In Rust the error message is explicitly carried in the result, but with runtime costs. This allows
// both explicit control flow and convenient automatic err message generation by Opter, but comes at
// a runtime cost)
//
// For example, trying to consolidate all the Opter errors to be checked in one place (i.e. having a `diagnostic`
// be checked only after running the parser loop) makes it simpler to write the error but requires not returning
// errors from `value` and `values`, hiding what can return an error and making Opter control the error flow
// instead of the user. 
//
// For now, it's up to the user to handle errors on-the-spot however they like. The only helpers are a
// last_processed_arg which provides enough context for custom errors, and canned messages for `missing value`
// and `unexpected arg`.
//
// To prevent bubbling up when unwanted, don't allow `!` in the fn signature (for `main`, return `int`)
//
// It's a bit unwieldy and can have unexpected errors (because user has to make sure to return, break, etc. in right place)
// but it's very straightforward and not-magic.
//
// Also, it allows user to control messages better; you can use the preset messages or your own. If Opter prints the messages
// internally, it's hard to modify.

module opter;
import std::collections::list;
import std::core::string;
import std::io;

def ValueList = List(<String>);

struct Opter {
	String[] args;
	ulong idx_args;
	ulong idx_arg; // for multiple chars and non-space separator
	bool has_next_error; // error while calling `next`
	String err_msg;
}

fn void Opter.init(&opter, String[] args) {
	opter.args = args;
	opter.idx_args = 1;
	opter.idx_arg = 0;
	opter.has_next_error = false;
}

fn Arg!! Opter.next(&o) {
	if (o.has_next_error) return OpterStop.END?;
	// Valid end of args
	if (o.idx_args == o.args.len) return OpterStop.END?;

	String curr_arg = o.args[o.idx_args];
	Arg arg;
	switch (o.idx_arg) {
		// At beginning of curr_arg
		case 0:
			switch {
				// LONG at beginning of arg
				case curr_arg[0:2] == "--":
					// Valid end of args --
					if (curr_arg.len == 2) return OpterStop.END?;
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
						o.has_next_error = true;
						o.err_msg = "dash followed by space not allowed";
						return OpterStop.ERROR?;
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
					arg.value = curr_arg;
					o.idx_args += 1;
			}

		// collected shorts in the middle of the arg
		// If user wants a value following a short, they should call 'value()'
		default:
			// o.idx_arg == curr_arg.len should be unreachable; if was at end of an arg,
			// should have moved to the next
			assert(o.idx_arg < curr_arg.len);
			if (curr_arg[0:2] == "--") {
				o.has_next_error = true;
				o.err_msg = "attempted to parse a flag or positional argument, only values allowed afer '='";
				return OpterStop.ERROR?;
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
fn String! Opter.value(&o) {
	// Error if there's no more words to read.
	if (o.idx_args >= o.args.len) return OpterStop.ERROR?;

	// If in the middle of an arg, reads the rest of it.
	// If at the beginning reads the entire thing.
	String curr_arg = o.args[o.idx_args];
	String res = curr_arg[o.idx_arg..];
	o.idx_args += 1;
	o.idx_arg = 0;
	return res;
}

fn ValueList! Opter.values(&o, Allocator alloc = allocator::heap()) {
	ValueList values;
	// if called in middle of word, then return until the end of that word only.
	if (o.idx_arg != 0) {
		String val = o.value()!!;
		values.push(val);
		return values;
	}

	// returns all args until the end, or the next arg starts with '-'
	String curr_arg = o.args[o.idx_args];

	values.push(curr_arg[o.idx_arg..]);
	o.idx_args += 1;
	o.idx_arg = 0;
	while (o.idx_args < o.args.len) {
		String curr_value = o.args[o.idx_args];
		// breaks on short or long flag
		if (curr_value[0] == '-') break;
		values.push(curr_value);
		o.idx_args += 1;
	}
	return values;
}

// Used only for stopping iteration next();
fault OpterStop {
	END,
	ERROR, // not generally switched on, but makes it easier to see errors.
}

// For use in error messages. Intended to be used both for canned messages, and for users to create
// custom messages
fn String Opter.last_processed_arg(&o) {
	return o.args[o.idx_args - 1];
}

fn void Opter.write_err_unexpected_arg(&o, OutStream out = io::stdout()) {
	String arg = o.last_processed_arg();
	io::fprintfn(out, "Found unexpected argument \"%s\"", arg);
}

fn void Opter.write_err_missing_value(&o, OutStream out = io::stdout()) {
	String arg = o.last_processed_arg();
	io::fprintfn(out, "Missing value after argument \"%s\"", arg);
}

fn void Opter.write_err_parse_value(&o, anyfault err, OutStream out = io::stdout()) {
	String arg = o.last_processed_arg();
	io::fprintfn(out, "Error parsing argument \"%s\": %s", arg, err);
}

fn void Opter.write_err_next(&o, OutStream out = io::stdout()) {
	String arg = o.args[o.idx_args];
	io::fprintfn(out, "Error at argument \"%s\": %s", arg, o.err_msg);
}

struct Arg {
	ArgType type;
	union {
		char short_name;
		String long_name;
		String value;
	}
}

enum ArgType {
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
	}
}

fn void test_short_no_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(!@ok(opter.next()));
}

fn void test_short_no_value_calls_value() @test {
	String[] input = { "test", "-n" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(!@ok(opter.value()));
}

fn void test_short_with_value() @test {
	String[] input = { "test", "-n" "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert(!@ok(opter.next()));
}

fn void test_short_with_value_no_separator() @test {
	String[] input = { "test", "-none"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert(!@ok(opter.next()));
}

fn void test_short_with_value_eq_separator() @test {
	String[] input = { "test", "-n=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!! == "one");
	assert(!@ok(opter.next()));
}

fn void test_long_no_value() @test {
	String[] input = { "test", "--number" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "number" });
	assert(!@ok(opter.next()));
}

fn void test_long_no_value_calls_value() @test {
	String[] input = { "test", "--foo" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(!@ok(opter.value()));
}

fn void test_long_with_value() @test {
	String[] input = { "test", "--foo", "one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.value()!! == "one");
	assert(!@ok(opter.next()));
}

fn void test_long_with_value_eq_separator() @test {
	String[] input = { "test", "--foo=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.value()!! == "one");
	assert(!@ok(opter.next()));
}

fn void test_positional() @test {
	String[] input = { "test", "thing" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = VALUE, .long_name = "thing" });
	assert(!@ok(opter.next()));
}

fn void test_short_then_another() @test {
	String[] input = { "test", "-n", "-o"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'o' });
	assert(!@ok(opter.next()));
}

fn void test_long_then_another() @test {
	String[] input = { "test", "--foo", "--bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "bar" });
	assert(!@ok(opter.next()));
}

fn void test_positional_then_another() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = VALUE, .value = "foo" });
	assert_arg(opter.next()!!, Arg { .type = VALUE, .value = "bar" });
	assert(!@ok(opter.next()));
}

fn void test_values_basic() @test {
	String[] input = { "test", "foo", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert(!@ok(opter.next()));
}

fn void test_values_then_short() @test {
	String[] input = { "test", "foo", "bar", "-a" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'a' });
	assert(!@ok(opter.next()));
}

fn void test_values_then_long() @test {
	String[] input = { "test", "foo", "bar", "--baz" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo", "bar" });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "baz" });
	assert(!@ok(opter.next()));
}

fn void test_short_values() @test {
	String[] input = { "test", "-f", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert(opter.values()!!.array_view() == { "bar", "baz" });
	assert(!@ok(opter.next()));
}

fn void test_long_values() @test {
	String[] input = { "test", "--foo", "bar", "baz" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.values()!!.array_view() == { "bar", "baz" });
	assert(!@ok(opter.next()));
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
	assert(!@ok(opter.next()));
}

fn void test_short_end_mark() @test {
	String[] input = { "test", "-f", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert(!@ok(opter.next()));
}

fn void test_long_end_mark() @test {
	String[] input = { "test", "--foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(!@ok(opter.next()));
}

fn void test_value_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.value()!! == "foo");
	assert(!@ok(opter.next()));
}

fn void test_values_end_mark() @test {
	String[] input = { "test", "foo", "--", "bar" };
	Opter opter;
	opter.init(input);
	assert(opter.values()!!.array_view() == { "foo" });
	assert(!@ok(opter.next()));
}

fn void test_short_cluster() @test {
	String[] input = { "test", "-abc", "--foo" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'a' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'b' });
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'c' });
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(!@ok(opter.next()));
}
