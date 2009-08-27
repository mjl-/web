implement Testrssgen;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "lists.m";
	lists: Lists;
include "rssgen.m";
	rssgen: Rssgen;
	Item: import rssgen;

Testrssgen: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

init(nil: ref Draw->Context, args: list of string)
{
	sys = load Sys Sys->PATH;
	arg := load Arg Arg->PATH;
	lists = load Lists Lists->PATH;
	rssgen = load Rssgen Rssgen->PATH;
	if(rssgen == nil)
		nomod(rssgen->PATH);

	arg->init(args);
	arg->setusage(arg->progname()+" title url descr [ititle ilink idescr itime iguid icategories ...]");
	while((c := arg->opt()) != 0)
		case c {
		* =>	arg->usage();
		}
	args = arg->argv();
	if((len args-3) % 6 != 0)
		arg->usage();

	a := l2a(args);
	i := 0;
	title := a[i++];
	link := a[i++];
	descr := a[i++];
	items: list of ref Item;
	while(i < len a) {
		it := a[i++];
		il := a[i++];
		id := a[i++];
		itime := a[i++];
		ig := a[i++];
		ic := a[i++];
		items = ref Item(it, il, id, int itime, 0, ig, sys->tokenize(ic, "/").t1)::items;
	}
	items = lists->reverse(items);

	xml := rssgen->rssgen(title, link, descr, items);
	sys->print("%s\n", xml);
}

l2a[T](l: list of T): array of T
{
	a := array[len l] of T;
	i := 0;
	for(; l != nil; l = tl l)
		a[i++] = hd l;
	return a;
}

nomod(m: string)
{
	warn(sprint("loading %s: %r", m));
	raise "fail:load";
}

warn(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
}

fail(s: string)
{
	warn(s);
	raise "fail:"+s;
}
