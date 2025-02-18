module basic;
import std::collections::maybe;
import std::io;
import opter;

struct Opts {
	Maybe(<String>) thing;
	uint number;
	bool shout;
}

fn void! parse_cli(Opter* opter, Opts* opts) {
	while (true) {
		Arg arg = opter.next()!;
		if (arg.type == EOF) break;
		switch {
			case arg.is(SHORT, 'n'):
			case arg.is(LONG, "number"):
				opts.number = opter.value()!.as_int(uint)!;

			case arg.is(LONG, "shout"):
				opts.shout = true;

			case arg.is(VALUE):
				if (!opts.thing.has_value) {
					opts.thing = { .value = arg.value.as_str(), .has_value = true };
				}

			case arg.is(LONG, "help"):
				io::printn("Usage: hello [-n|--number=NUM] [--shout] THING");

			default:
				// always returns err; makes more sense when throwing using `!`
				return opter.err_unexpected_arg();
		}
	}
}

fn int main(String[] args) {
	Opter opter;
	opter.init(args);
	Opts opts;
	if (catch parse_cli(&opter, &opts)) {
		io::eprintfn("%s", opter.err_msg);
		return 1;
	}

	io::eprintfn("number: %d", opts.number);
	io::eprintfn("shout: %s", opts.shout);
	io::eprintfn("thing: %s", opts.thing.get() ?? "nil");

	String out;
	if (opts.thing.has_value) {
		out = opts.thing.value;
	} else {
		// copy needed because convert_ascii_to_upper is in-place
		out = "missing argument THING".copy();
	}
	if (opts.shout) out.convert_ascii_to_upper();
	for (int i = 0; i < opts.number; i += 1) {
		io::printn(out);
	}
	return 0;
}
