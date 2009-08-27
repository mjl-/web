implement Testnetstr;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "netstr.m";
	netstr: Netstr;

Testnetstr: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	netstr = load Netstr Netstr->PATH;

	orig := "test 1 2 3\n";
	packed := netstr->packstr(orig);
	(unpacked, err) := netstr->unpackstr(packed);
	if(err != nil)
		fail("unpackstr: "+err);
	else if(orig != unpacked)
		sys->print("orig != unpacked\n");
	sys->print("orig: %q\npacked: %q\nunpacked: %q\n", orig, packed, unpacked);
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
