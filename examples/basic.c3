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
				number = opter.value()!!.to_integer(uint)!!;

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
				io::eprintfn("%s", arg.unexpected());
				return 42;
		}
	}

	String out;
	if (thing.has_value) {
		out = thing.value;
	} else {
		out = "missing argument THING";
	}
	if (shout) out.convert_ascii_to_upper();
	for (int i = 0; i < number; i += 1) {
		io::printn(out);
	}
	return 0;
}
