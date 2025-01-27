module basic;
import std::collections::maybe;
import std::io;
import opter;

fn int main(String[] args) {
	Opter opter;
	opter.init(args);

	Maybe(<String>) thing;
	uint number;
	bool shout;

	while (true) {
		Arg! arg = opter.next();
		if (catch arg) return 1;
		if (arg.type == EOF) break;
		switch {
			case arg.is(SHORT, 'n'):
			case arg.is(LONG, "number"):
				// This works more smoothly when bubbling up error
				// inside fn which returns an optional.
				Value! v = opter.value();
				if (catch v) return 1;
				int! n = v.as_int(uint);
				if (catch n) return 1;
				number = n;

			case arg.is(LONG, "shout"):
				shout = true;

			case arg.is(VALUE):
				if (!thing.has_value) {
					thing = { .value = arg.value.as_str(), .has_value = true };
				}

			case arg.is(LONG, "help"):
				io::printn("Usage: hello [-n|--number=NUM] [--shout] THING");
				return 0;

			default:
				// always returns err; makes more sense when throwing using `!`
				if (catch opter.err_unexpected_arg()) {
					return 1;
				}
		}
	}

	io::eprintfn("number: %d", number);
	io::eprintfn("shout: %s", shout);
	io::eprintfn("thing: %s", thing.get() ?? "nil");

	String out;
	if (thing.has_value) {
		out = thing.value;
	} else {
		// copy needed because convert_ascii_to_upper is in-place
		out = "missing argument THING".copy();
	}
	if (shout) out.convert_ascii_to_upper();
	for (int i = 0; i < number; i += 1) {
		io::printn(out);
	}
	return 0;
}
