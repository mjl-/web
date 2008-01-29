implement Testnetstr;

include "sys.m";
include "draw.m";
include "netstr.m";

sys: Sys;
netstr: Netstr;


Testnetstr: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};


init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	netstr = load Netstr Netstr->PATH;
	if(netstr == nil)
		nomod(Netstr->PATH);

	orig := "test 1 2 3\n";
	packed := netstr->packstr(orig);
	(err, unpacked) := netstr->unpackstr(packed);
	if(err != nil)
		sys->print("error in unpackstr: %s\n", err);
	else if(orig != unpacked)
		sys->print("orig != unpacked\n");
	sys->print("orig: %q\npacked: %q\nunpacked: %q\n", orig, packed, unpacked);
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
