// Basic lexer for cli options.
// Supports:
// - short opts
// - long opts
// - positional args
// - options with optional arguments
// - options with multiple arguments

// - -- marks the end of options
// - ' ' or = or (unseparated short) for opt-value separator
// - short -abc
// - errors using Opter.diagnostic
// - TODO test all errors

module opter;
import std::collections::list;
import std::core::string;
import std::io;

def ValueList = List(<String>);

struct Opter {
	String[] args;
	ulong idx_args;
	ulong idx_arg; // for multiple chars
}

fn void Opter.init(&opter, String[] args) {
	opter.args = args;
	opter.idx_args = 1;
}

fn Arg! Opter.next(&o) {
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
					}

				// SHORT at beginning of arg
				case curr_arg[0] == '-':
					// TODO report. Dash followed by space not allowed.
					if (curr_arg.len == 1) return OpterStop.END?;
					arg.type = SHORT;
					arg.short_name = curr_arg[1];
					if (curr_arg.len == 2) {
						o.idx_args += 1;
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
			// This state should be unreachable; if was at end of an arg, should have moved to the next
			assert(o.idx_arg == curr_arg.len);
			// TODO report. Cannot call 'next()' in the middle of a word which starts with
			// a long; only 'value()' is allowed.
			if (curr_arg[0:2] == "--") return OpterStop.END?;
			arg.type = SHORT;
			arg.short_name = curr_arg[1];
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
	if (o.idx_args >= o.args.len) return OpterError.NO_MORE_ARGS?;

	// If in the middle of an arg, reads the rest of it.
	// If at the beginning reads the entire thing.
	String curr_arg = o.args[o.idx_args];
	String res = curr_arg[o.idx_arg..];
	o.idx_args += 1;
	o.idx_arg = 0;
	return res;
}

fn ValueList! Opter.values(&o, Allocator alloc = allocator::heap()) {
	// Cannot start in the middle of an arg (opt value without leading space)
	// returns all args until the end, or the next arg starts with '-'
	if (o.idx_arg != 0) return OpterStop.END?;
	String curr_arg = o.args[o.idx_args];

	ValueList values;
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

fn String Arg.unexpected(&arg, Allocator alloc = allocator::heap()) {
	switch (arg.type) {
		case SHORT: return string::format("Unexpected argument: -%c", arg.short_name, allocator: alloc);
		case LONG: return string::format("Unexpected argument: --%s", arg.long_name, allocator: alloc);
		case VALUE: return string::format("Unexpected argument: %s", arg.value, allocator: alloc);
	}
}

// Used only for stopping iteration next();
fault OpterStop {
	END,
}

fault OpterError {
	NO_MORE_ARGS,
}

// Tests

fn void assert_arg(Arg found, Arg expected) @private {
	assert(found.type == expected.type, "Found %s, expected %s", found.type, expected.type);
	switch (found.type) {
		case SHORT:
			assert(found.short_name == expected.short_name, "Found %s, expected %s", found.short_name, expected.short_name);
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
	assert(opter.value()!!, "one");
	assert(!@ok(opter.next()));
}

fn void test_short_with_value_no_separator() @test {
	String[] input = { "test", "-none"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'n' });
	assert(opter.value()!!, "one");
	assert(!@ok(opter.next()));
}

fn void test_long_no_value() @test {
	String[] input = { "test", "--number" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "number" });
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

// values should not start in the middle of a word
fn void test_values_starting_condition() @test {
	String[] input = { "test", "-fbar", "baz", "one" };
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = SHORT, .short_name = 'f' });
	assert(!@ok(opter.values()));
}
