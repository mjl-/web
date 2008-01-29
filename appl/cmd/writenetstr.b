implement Writenetstr;

include "sys.m";
include "draw.m";
include "netstr.m";

sys: Sys;
netstr: Netstr;

Writenetstr: module {
	init:	fn(nil: ref Draw->Context, args: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	netstr = load Netstr Netstr->PATH;
	if(netstr == nil)
		nomod(Netstr->PATH);

	if(args != nil)
		args = tl args;
	if(args != nil && hd args == "--")
		args = tl args;

	if(len(args) != 0) {
		sys->fprint(sys->fildes(2), "usage: writenetstr\n");
		raise "fail:usage";
	}

	a := array[0] of byte;
	buf := array[1024] of byte;
	for(;;) {
		n := sys->read(sys->fildes(0), buf, len buf);
		if(n == 0)
			break;
		if(n < 0) {
			sys->fprint(sys->fildes(2), "reading string: %r");
			raise "fail:error reading string";
		}
		anew := array [len a+n] of byte;
		for(i := 0; i < len a; i++)
			anew[i] = a[i];
		for(i = 0; i < n; i++)
			anew[len a+i] = buf[i];
		a = anew;
	}

	err := netstr->writestr(sys->fildes(1), string a);
	if(err != nil) {
		sys->fprint(sys->fildes(2), "writing netstring: %s", err);
		raise "fail:error writing netstring";
	}
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
