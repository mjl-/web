implement Testhtmlent;

include "sys.m";
	sys: Sys;
include "draw.m";
include "htmlent.m";

Testhtmlent: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	htmlent := load Htmlent Htmlent->PATH;
	if(htmlent == nil)
		nomod(Htmlent->PATH);
	htmlent->init();

	sys->print("%s\n", htmlent->conv("this is a test, &amp;&nbsp;another one&copy;&nonsense;"));
	sys->print("%s\n", htmlent->conv("&#20; &#33;"));
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
