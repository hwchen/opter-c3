// Basic lexer for cli options.
// Supports:
// - short opts
// - long opts
// - -- marks the end of options
// - positional args
// - ' ' or = or unseparated for opt-value separator
// - short -abc
// - options with optional arguments
// - options with multiple arguments
//
//	```
//	import std::collections::maybe;
//	import std::io;
//	import opter;
//
//	fn void! main(String args_str) {
//		Opter opter;
//		opter.init(args_str);
//
//		Maybe(<String>) thing;
//		uint number;
//		bool shout;
//
//		while (try arg = opter.next()) {
//			switch {
//				case arg.is(SHORT, 'n'):
//				case arg.is(LONG, "number"):
//					number = opter.value()!.to_integer(uint);
//
//				case arg.is(LONG, "shout"):
//					shout = true;
//
//				case arg.is(VALUE):
//					if (!thing.has_value) {
//						thing = maybe::value(arg.value());
//					}
//
//				case arg.is(LONG, "help") {
//					io::printn("Usage: hello [-n|--number=NUM] [--shout] THING");
//					return;
//				}
//				default: return OpterError.UNEXPECTED_ARG?;
//			}
//		}
//
//		String out;
//		if (thing.has_value) {
//			out = thing.value;
//		} else {
//			out = "missing argument THING";
//		}
//		if (shout) string.convert_ascii_to_upper();
//		for (int i = 0; i < number; i += 1) {
//			io::printn(out);
//		}
//		return;
//	}
//	```

module opter;

struct Parser {
	String[] args;
	int curr;
}

fn Arg! Parser.next(&p) {
	Arg arg;
	return arg;
}

struct Arg {
	ArgType type;
	union {
		char arg_short;
		String arg_long;
		String arg_value;
	}
}

enum ArgType {
	SHORT,
	LONG,
	VALUE,
}

macro bool Arg.is(&arg, varargs) { return true; };
