// Example shows
// - When config doesn't match flags (here, a flag wants to operate over multiple config fields
// - Handling a default case with overrides
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
	NO_BATCH_OPS = {"", "no-batch-ops"},
	NO_ZERO_LOOP = {"", "no-zero-loop"},
	NO_REMOVE_DEAD = {"", "no-remove-dead"},
	NO_REDUCE_LOOPS = {"", "no-reduce-loops"},
	LEVEL = {"O", ""},
}

fn void! parse_cli(String[] args, Config* config) {
	// Opter does not make any assumptions about order of flags
	//
	// For handling -O, we want to be able to override a default
	// Optimization flags should be parsed first;
	// then apply them in order to Config as
	// - level
	// - others
	// so that level is the default regardless of flag parse order
	//
	// For handling --x and --no-x flags, --no-x flag wins. We
	// set this priority, it's possible to decide the other way.
	// We don't do last flag wins because overriding the default
	// optimization requires that all flags be parsed before
	// applying, and preserving order requires too much work.

	ushort level;
	bool batch_ops;
	bool zero_loop;
	bool remove_dead;
	bool reduce_loops;
	bool no_batch_ops;
	bool no_zero_loop;
	bool no_remove_dead;
	bool no_reduce_loops;

	opter::@parse_opts(args, Flags; Flags opt_type, Opter* opter, Arg arg) {
		switch (opt_type) {
			case BATCH_OPS: batch_ops = true;
			case ZERO_LOOP: zero_loop = true;
			case REMOVE_DEAD: remove_dead = true;
			case REDUCE_LOOPS: reduce_loops = true;
			case NO_BATCH_OPS: no_batch_ops = true;
			case NO_ZERO_LOOP: no_zero_loop = true;
			case NO_REMOVE_DEAD: no_remove_dead = true;
			case NO_REDUCE_LOOPS: no_reduce_loops = true;
			case LEVEL:
				level = opter.value()!.as_int(ushort)!;
		}
	}!;

	if (level > 0) {
		config.optimisation.batch_ops = true;
		config.optimisation.zero_loop = true;
	}
	if (batch_ops) config.optimisation.batch_ops = true;
	if (zero_loop) config.optimisation.zero_loop = true;
	if (remove_dead) config.optimisation.remove_dead = true;
	if (reduce_loops) config.optimisation.reduce_loops = true;
	// --no-x comes last, has priority
	if (no_batch_ops) config.optimisation.batch_ops = false;
	if (no_zero_loop) config.optimisation.zero_loop = false;
	if (no_remove_dead) config.optimisation.remove_dead = false;
	if (no_reduce_loops) config.optimisation.reduce_loops = false;

}

fn int main(String[] args) {
	Config config;
	if (catch parse_cli(args, &config)) {
		return 1;
	}

	io::printfn("%s", string::new_struct_to_str(config));

	return 0;
}
