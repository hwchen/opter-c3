// Basic lexer for cli options.
// Supports:
// - short opts
// - long opts
// - positional args
// - options with multiple arguments
// - -- marks the end of options
// - ' ' or = or (unseparated short) for opt-value separator
// - short -abc

// - errors using Opter.diagnostic
// - TODO test all errors
// - test unexpected args in example
// - test no more value(s)
// - what if `value` is called in a loop? it won't be able to escape, as there's no
//     external indication there's an error.

// === Error Handling ===
//
// It's a bit more manual than something like Rust's lexopt, which creates errors in the
// parser and just bubbles them up on each function call `next()` or `value()`, etc.
//
// Instead, Opter methods will just issue an END Fault if there's any reason to stop, whether
// it's the happy path or the error path. And then it's up to the user to check diagnostics
// for the error code or error message.
//
// Sending out errors through a separate check on diagnostics is the only way to have better
// error messages (otherwise it would only be error codes). So all methods on Opter do this,
// even if it might seem easier to return a more descriptive error directly. For example,
// Opter.value() could directly return a NO_MORE_ARGS instead of a STOP. But it would split
// error handling paths (as the user would be tempted to just bubble it up with `!`), and
// it's not a good enough error to provide needed context for end-users anyways.
//
// The most important point for returning good error messages is to avoid bubbling up CLI errors
// to `fn void! main(String[] args)`. Instead, use `fn int main(String[] args)` and handle printing
// error messages in the body.
//
// Note: after errors are set on Opter, any method will return END/STOP, that way the loop for checking
// `next()` will break.
// 
// TODO:
// - patterns for handling errors when encapsulating CLI parsing in a function.
// - patterns for turning all errors during parsing into an OpterError, and handling those in one place.
//     (uses Opter.make_err()?)

module opter;
import std::collections::list;
import std::core::string;
import std::io;

def ValueList = List(<String>);

struct Opter {
	String[] args;
	ulong idx_args;
	ulong idx_arg; // for multiple chars and non-space separator
	OpterError error_type;
	String error_message;
}

fn void Opter.init(&opter, String[] args) {
	opter.args = args;
	opter.idx_args = 1;
	opter.idx_arg = 0;
	opter.error_type = NONE;
}

fn Arg! Opter.next(&o) {
	if (o.error_type != OpterError.NONE) return OpterStop.END?;
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
			// o.idx_arg == curr_arg.len should be unreachable; if was at end of an arg,
			// should have moved to the next
			assert(o.idx_arg < curr_arg.len);
			// TODO report. Cannot call 'next()' in the middle of a word which starts with
			// a long; only 'value()' is allowed.
			if (curr_arg[0:2] == "--") return OpterStop.END?;
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
	if (o.idx_args >= o.args.len) {
		o.make_err(INTERNAL, "No more values after arg");
		return OpterStop.END?;
	}

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

// Used only for stopping iteration next();
fault OpterStop {
	END,
}

fault OpterError {
	NONE,
	INTERNAL,
	CUSTOM,
}

fn void Opter.err_unexpected_arg(&o) {
	// TODO is heap allocator always ok? Assume cli will exit immediately after anyways
	// refers to the arg that was just parsed
	o.make_err(INTERNAL, string::format("found unexpected argument: %s", o.args[o.idx_args - 1], allocator: allocator::heap()));
}

fn void Opter.err_custom_message(&o, String msg) {
	o.make_err(CUSTOM, msg);
}

fn void Opter.make_err(&o, OpterError error_type, String error_message) {
	o.error_type = error_type;
	o.error_message = string::format("Error at arg %s: %s", o.args[o.idx_args - 1], error_message");
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

fn void test_short_with_value_eq_separator() @test {
	String[] input = { "test", "-n=one"};
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
	assert(opter.value()!!, "one");
	assert(!@ok(opter.next()));
}

fn void test_long_with_value_eq_separator() @test {
	String[] input = { "test", "--foo=one"};
	Opter opter;
	opter.init(input);
	assert_arg(opter.next()!!, Arg { .type = LONG, .long_name = "foo" });
	assert(opter.value()!!, "one");
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
