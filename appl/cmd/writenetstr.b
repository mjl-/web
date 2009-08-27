implement Writenetstr;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "netstr.m";
	netstr: Netstr;

Writenetstr: module {
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

	if(len(args) != 0)
		fail("usage: writenetstr");

	a := array[0] of byte;
	buf := array[1024] of byte;
	for(;;) {
		n := sys->read(sys->fildes(0), buf, len buf);
		if(n == 0)
			break;
		if(n < 0)
			fail(sprint("reading string: %r"));
		anew := array [len a+n] of byte;
		for(i := 0; i < len a; i++)
			anew[i] = a[i];
		for(i = 0; i < n; i++)
			anew[len a+i] = buf[i];
		a = anew;
	}

	err := netstr->writestr(sys->fildes(1), string a);
	if(err != nil)
		fail("writing netstring: "+err);
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
