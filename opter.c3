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

module opter;

struct Opter {
	String[] args;
	int curr;
}

fn void Opter.init(&opter, String[] args) {
	opter.args = args;
}

fn Arg! Opter.next(&opter) {
	Arg arg;
	return arg;
}

fn String! Opter.value(&opter) {
	return "";
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

fn bool Arg.is(&arg, ArgType type, varargs...) { return true; }
fn String Arg.value(&arg) { return ""; }

fault OpterError {
	UNEXPECTED_ARG,
}
