module opter;

macro @parse_opts(String[] args, $OptType; @body(opt_type, Opter* opter, Arg arg)) {
	Opter opter;
	opter.init(args);

	while (true) {
		Arg arg = opter.next()!!;
		if (arg.type == EOF) break;

		$OptType opt_type;
		bool matched;
		foreach LOOP: (variant : $OptType.values) {
			switch {
				case variant.short_opt.len > 0 && arg.is(SHORT, variant.short_opt[0]):
				case arg.is(LONG, variant.long_opt):
				case arg.is(VALUE):
					matched = true;
					opt_type = variant;
					break LOOP;
				default:
			}
		}
		if (!matched) {
			return opter.err_unexpected_arg();
		}
		@body(opt_type, &opter, arg);
	}
}
