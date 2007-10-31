# for use with scgid.  print environment variables, parse query string using cgi->unpackenv (which uses get or post).

implement Cgienv;

include "sys.m";
	sys: Sys;
include "draw.m";
include "env.m";
	env: Env;
include "cgi.m";
	cgi: Cgi;

print: import sys;
Fields: import cgi;

Cgienv: module {
	modinit:	fn(): string;
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

modinit(): string
{
	sys = load Sys Sys->PATH;
	env = load Env Env->PATH;
	cgi = load Cgi Cgi->PATH;
	if(cgi == nil)
		return sys->sprint("loading cgi: %r");
	cgi->init();
	return nil;
}

init(nil: ref Draw->Context, nil: list of string)
{
	if(sys == nil)
		modinit();

	print("Status: 200 OK\r\n");
	print("content-type: text/plain; charset=utf-8\r\n\r\n");
	for(l := env->getall(); l != nil; l = tl l) {
		(key, value) := hd l;
		print("%s=%q\n", key, value);
	}

	print("===\n");
	fields := cgi->unpackenv();
	for(l = fields.all(); l != nil; l = tl l) {
		(key, value) := hd l;
		print("%s=%q\n", key, value);
	}
	print("===\n");
}
