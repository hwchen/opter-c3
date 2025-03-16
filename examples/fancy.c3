module fancy;
import std::collections::maybe;
import std::io;
import opter;

struct Opts {
	Maybe{String} thing;
	uint number;
	bool shout;
}

enum Flags: (String short_opt, String long_opt) {
	THING = {"", ""},
	NUMBER = {"n", "number"},
	SHOUT = {"", "shout"},
}

fn void? parse_cli(Opter* opter, Opts* opts) {
	opter::@parse_opts(opter, Flags; Flags opt_type, Arg arg) {
		switch (opt_type) {
			case NUMBER:
				opts.number = opter.value()!.as_int(uint)!;
			case SHOUT:
				opts.shout = true;
			case THING:
				if (!opts.thing.has_value) {
					opts.thing = { .value = arg.value.as_str(), .has_value = true };
				}
		}
	}!;
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
		out = "missing argument THING";
	}
	if (opts.shout) {
		out = out.to_upper_tcopy();
	}
	for (int i = 0; i < opts.number; i += 1) {
		io::printn(out);
	}
	return 0;
}
