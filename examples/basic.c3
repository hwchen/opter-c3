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

	while (try arg = opter.next()) {
		switch {
			case arg.is(SHORT, 'n'):
			case arg.is(LONG, "number"):
				// There's two possible error messages that can be set here:
				// - value()
				// - err_custom_message()
				// Opter will keep the first one set, which will then be reported
				// when the loop is broken out of.
				// Note that you could handle the error from to_integer separately,
				// but passing it into Opter allows for more context to be reported.
				uint! number_parsed = opter.value().to_integer(uint);
				if (catch err = number_parsed) {
					opter.err_custom_message("Error parsing: %s", err);
				}
				number = number_parsed;

			case arg.is(LONG, "shout"):
				shout = true;

			case arg.is(VALUE):
				if (!thing.has_value) {
					thing = { .value = arg.value, .has_value = true };
				}

			case arg.is(LONG, "help"):
				io::printn("Usage: hello [-n|--number=NUM] [--shout] THING");
				return 0;

			default:
				opter.err_unexpected_arg());
		}
	}

	// Note that if you don't handle the error here, it's possible to continue with junk values,
	// as Opter is not designed to early-return using `!` on methods.
	if (opter.error_type != NONE) {
		io::eprintfn("CLI Error: %s", opter.error_message);
		return 1;
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
