// Could have two separate macros for handling first arg as String[] or
// Opter*, but currently just initializing outside macro.
//
// Having first arg as Opter* is better for implementing subcommands

module opter;

macro @parse_opts(Opter* opter, $OptType; @body(opt_type, Arg arg)) {
	while (true) {
		Arg arg = opter.next()!!;
		if (arg.type == EOF) break;

		$OptType opt_type;
		bool matched;
		foreach LOOP: (variant : $OptType.values) {
			switch {
				case variant.short_opt.len > 0 && arg.is(SHORT, variant.short_opt[0]):
				case arg.is(LONG, variant.long_opt):
				case arg.is(VALUE) && variant.short_opt == "" && variant.long_opt == "":
					matched = true;
					opt_type = variant;
					break LOOP;
				default:
			}
		}
		if (!matched) {
			return opter.err_unexpected_arg();
		}
		@body(opt_type, arg);
	}
}
