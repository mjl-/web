implement Testtemplate;

include "sys.m";
include "draw.m";
include "template.m";

sys: Sys;
template: Template;
Form: import template;
print: import sys;


Testtemplate: module
{
	init:	fn(nil: ref Draw->Context, nil: list of string);
};


init(nil: ref Draw->Context, nil: list of string)
{
	sys = load Sys Sys->PATH;
	template = load Template Template->PATH;
	if(template == nil)
		nomod(Template->PATH);
	template->init();

	{
		args := list of {
			("a", "&<test>!var\""),
			("b", "2"),
			("c", "3"),
			("d", "abcd"),
			("key1", "a en b-en-c-&<>'\""),
			("key2", "test\b\noink"),
			("path", "/lala?yay=yahoo")
		};
		listargs := ("elems", list of { ("var1", "val1")::nil, ("var2", "val2")::nil})
			::("noelems", list of { ("var1", "blah1")::nil, ("var2", "blah2")::nil})
			::nil;
		form := ref Form("testform");
		last := 15;
		for(i := 1; i <= last; i++) {
			formname := "test"+string i;
			print("=== %s\n%s\n", formname, form.spitl(formname, args, listargs));
		}
		print("### finally, some more tests, for the various spit(l)/print(l) functions\n");
		form.print("test8", args);
		print("\n");
		print("%s\n", form.spit("test8", args));
		form.printl("test8", args, listargs);
		print("\n");
	} exception e {
	"spit:*" =>
		sys->fprint(sys->fildes(2), "error: %s\n", e);
		raise "fail:"+e;
	}
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
