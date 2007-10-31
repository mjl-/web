implement Testtemplate2;

include "sys.m";
include "draw.m";
include "template.m";

sys: Sys;
template: Template;
print: import sys;
Form, Vars, vars: import template;


Testtemplate2: module
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
		v := vars();
		v.add("a", "&<test>!var\"");
		v.add("b", "2");
		v.add("c", "3");
		v.add("d", "abcd");
		v.add("key1", "a en b-en-c-&<>'\"");
		v.add("key2", "test\b\noink");
		v.add("path", "/lala?yay=yahoo");
		v.listadd("elems", ("var1", "val1")::nil);
		v.listadd("elems", ("var2", "val2")::nil);
	 	v.addlist("noelems", list of {("var1", "blah1")::nil, ("var2", "blah2")::nil});

		form := ref Form("testform");
		last := 15;
		for(i := 1; i <= last; i++) {
			formname := "test"+string i;
			print("=== %s\n%s\n", formname, form.spitv(formname, v));
		}
		print("### finally, some more tests, for the various spit([vl])/print([vl]) functions\n");
		form.print("test8", v.pairs);
		print("\n");
		print("%s\n", form.spit("test8", v.pairs));
		form.printv("test8", v);
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
