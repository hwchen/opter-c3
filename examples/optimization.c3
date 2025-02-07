// Example shows
// - When config doesn't match flags (here, a flag wants to operate over multiple config fields
// - Handling a default case = overrides
//
// Perhaps a bit verbose, but straightforward.

import std::io;
import opter;

struct Config {
	struct optimisation {
		bool batch_ops;
		bool zero_loop;
		bool remove_dead;
		bool reduce_loops;
	}
}

enum Flags: (String short_opt, String long_opt) {
	BATCH_OPS = {"", "batch-ops"},
	ZERO_LOOP = {"", "zero-loop"},
	REMOVE_DEAD = {"", "remove-dead"},
	REDUCE_LOOPS = {"", "reduce-loops"},
	LEVEL = {"O", ""},
}

fn void! parse_cli(String[] args, Config* config) {
	// Optimization flags should be parsed first;
	// then apply them in order to Config as
	// - level
	// - others
	// so that level is the default regardless of flag parse order
	ushort level;
	bool batch_ops;
	bool zero_loop;
	bool remove_dead;
	bool reduce_loops;

	opter::@parse_opts(args, Flags; Flags opt_type, Opter* opter, Arg arg) {
		switch (opt_type) {
			case BATCH_OPS: batch_ops = true;
			case ZERO_LOOP: zero_loop = true;
			case REMOVE_DEAD: remove_dead = true;
			case REDUCE_LOOPS: reduce_loops = true;
			case LEVEL:
				level = opter.value()!.as_int(ushort)!;
		}
	}!;

	if (level > 0) {
		config.optimisation.batch_ops = true;
		config.optimisation.zero_loop = true;
	}
	if (zero_loop) config.optimisation.zero_loop = zero_loop;
	if (remove_dead) config.optimisation.remove_dead = remove_dead;
	if (reduce_loops) config.optimisation.reduce_loops = reduce_loops;

}

fn int main(String[] args) {
	Config config;
	if (catch parse_cli(args, &config)) {
		return 1;
	}

	io::printfn("%s", string::new_struct_to_str(config));

	return 0;
}
