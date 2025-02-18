// Example shows:
// - When config doesn't match flags (here, a flag wants to operate over multiple config fields
// - Handling a default case with overrides
// - Handling order of flags
// - subcommand
//
// Opter does not make any assumptions about order of flags during parsing, order must
// be handled by the user.
//
// For handling -O, we want to be able to override a default. Optimization flags
// should be parsed first; then apply them in order to Config as
// - level
// - others
// so that level is the default regardless of flag parse order.
//
// For handling --x and --no-x flags, --no-x flag wins. The dev sets this priority,
// it's possible to decide the other way. We don't do last flag wins because if we also
// want to override the default optimization (requires that all flags be parsed before
// applying), we need to preserve order separately, and that requires too much work.
//
// For handling repeated flags (that don't need to be repeated) and conflicting flags,
// we could also report an error. These choices are all up to the implementer.

import std::io;
import opter;

struct Config {
	struct optimization {
		bool batch_ops;
		bool zero_loop;
		bool remove_dead;
		bool reduce_loops;
	}
	struct compile {
		Path path;
	}
}

fn void Config.update_optimizations(&config, ParsedOptimizations parsed) {
	if (parsed.level > 0) {
		config.optimization.batch_ops = true;
		config.optimization.zero_loop = true;
	}
	if (parsed.batch_ops) config.optimization.batch_ops = true;
	if (parsed.zero_loop) config.optimization.zero_loop = true;
	if (parsed.remove_dead) config.optimization.remove_dead = true;
	if (parsed.reduce_loops) config.optimization.reduce_loops = true;
	// --no-x comes last, has priority
	if (parsed.no_batch_ops) config.optimization.batch_ops = false;
	if (parsed.no_zero_loop) config.optimization.zero_loop = false;
	if (parsed.no_remove_dead) config.optimization.remove_dead = false;
	if (parsed.no_reduce_loops) config.optimization.reduce_loops = false;

}

struct ParsedOptimizations {
	ushort level;
	bool batch_ops;
	bool zero_loop;
	bool remove_dead;
	bool reduce_loops;
	bool no_batch_ops;
	bool no_zero_loop;
	bool no_remove_dead;
	bool no_reduce_loops;
}

enum GlobalFlags: (String short_opt, String long_opt) {
	BATCH_OPS = {"", "batch-ops"},
	ZERO_LOOP = {"", "zero-loop"},
	REMOVE_DEAD = {"", "remove-dead"},
	REDUCE_LOOPS = {"", "reduce-loops"},
	NO_BATCH_OPS = {"", "no-batch-ops"},
	NO_ZERO_LOOP = {"", "no-zero-loop"},
	NO_REMOVE_DEAD = {"", "no-remove-dead"},
	NO_REDUCE_LOOPS = {"", "no-reduce-loops"},
	LEVEL = {"O", ""},
	SUBCOMMAND = {"", ""},
}

fn void! parse_cli(Opter* opter, Config* config) {
	ParsedOptimizations parsed;

	opter::@parse_opts(opter, GlobalFlags; GlobalFlags opt_type, Arg arg) {
		switch (opt_type) {
			case BATCH_OPS: parsed.batch_ops = true;
			case ZERO_LOOP: parsed.zero_loop = true;
			case REMOVE_DEAD: parsed.remove_dead = true;
			case REDUCE_LOOPS: parsed.reduce_loops = true;
			case NO_BATCH_OPS: parsed.no_batch_ops = true;
			case NO_ZERO_LOOP: parsed.no_zero_loop = true;
			case NO_REMOVE_DEAD: parsed.no_remove_dead = true;
			case NO_REDUCE_LOOPS: parsed.no_reduce_loops = true;
			case LEVEL:
				parsed.level = opter.value()!.as_int(ushort)!;
			case SUBCOMMAND:
				config.update_optimizations(parsed);
				switch (arg.value.as_str()) {
					case "compile": return parse_compile(opter, config);
				}
		}
	}!;
	// No subcommand, could write help here.
}

enum CompileFlags: (String short_opt, String long_opt) {
	FILEPATH = {"", ""},
}

fn void! parse_compile(Opter* opter, Config* config) {
	opter::@parse_opts(opter, CompileFlags; CompileFlags opt_type, Arg arg) {
		switch (opt_type) {
			case FILEPATH:
				config.compile.path = arg.value.as_path()!;
		}
	}!;
}

// usage example: `optimization-cli -O1 --no-zero-loop compile mypath.c3`
fn int main(String[] args) {
	Opter opter;
	opter.init(args);
	Config config;
	if (catch parse_cli(&opter, &config)) {
		io::eprintfn("%s", opter.err_msg);
		return 1;
	}

	io::printfn("%s", string::new_struct_to_str(config));

	return 0;
}
