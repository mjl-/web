implement Readnetstr;

include "sys.m";
include "draw.m";
include "netstr.m";

sys: Sys;
netstr: Netstr;

Readnetstr: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	netstr = load Netstr Netstr->PATH;

	if(args != nil)
		args = tl args;
	if(args != nil && hd args == "--")
		args = tl args;

	if(len(args) != 0) {
		sys->fprint(sys->fildes(2), "usage: readnetstr\n");
		raise "fail:usage";
	}

	(err, s) := netstr->readstr(sys->fildes(0));
	if(err != nil) {
		sys->fprint(sys->fildes(2), "reading netstring: %s", err);
		raise "fail:error";
	}
	sys->print("%s", s);
}
