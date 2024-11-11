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
				// TODO the error returned by value doesn't fit nicely with the error
				// system I want to use, which will check opter.diagnostics. It's not
				// great to have two paths for errors. lexopt uses
				// `if let Some(arg) = parser.next()? {` so all errors are bubbled up.
				// but here, the natural thing is to have value() bubble up and have
				// next errors not bubble up. Check advanced err handling, maybe there's
				// a try-catch kind of situation.
				//
				// Also I want to have the diagnostics system, because I can't return error
				// messages through `!`. maybe that means it's ok to throw from value, becuase
				// the error should also be handled on the spot.
				//
				// But what if I want to parse cli in a fn? How are the errors returned?
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
