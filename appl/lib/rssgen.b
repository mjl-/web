implement Rssgen;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "daytime.m";
	daytime: Daytime;
include "cgi.m";
	cgi: Cgi;
include "rssgen.m";

init()
{
	sys = load Sys Sys->PATH;
	daytime = load Daytime Daytime->PATH;
	cgi = load Cgi Cgi->PATH;
	cgi->init();
}

tag(name, s: string): string
{
	return sprint("<%s>%s</%s>", name, cgi->htmlescape(s), name);
}

weekdays := array[] of {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};
months := array[] of {"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"};

datestr(n, ntz: int): string
{
	# xxx timezone
	tm := daytime->gmt(n);
	return sprint("%s, %d %s %d %02d:%02d:%02d +0000", weekdays[tm.wday], tm.mday, months[tm.mon], 1900+tm.year, tm.hour, tm.min, tm.sec);
}

Item.text(it: self ref Item): string
{
	catstr := "";
	for(l := it.cats; l != nil; l = tl l)
		catstr += "/"+hd l;
	if(catstr != nil)
		catstr = tag("category", catstr[1:]);
	return "<item>"+
		tag("title", it.title)+
		tag("link", it.link)+
		tag("description", it.descr)+
		tag("pubDate", datestr(it.time, it.timetzoff))+
		tag("guid", it.guid)+
		catstr+
		"</item>";
}

rssgen(title, link, descr: string, items: list of ref Item): string
{
	if(sys == nil)
		init();
	s := "";
	for(; items != nil; items = tl items)
		s += (hd items).text();
	return "<?xml version=\"1.0\" ?><channel>"+
		tag("title", title)+
		tag("link", link)+
		tag("description", descr)+
		"<items>"+s+"</items></channel></xml>";
}
