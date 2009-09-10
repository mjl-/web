implement Cgiparse;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "draw.m";
include "arg.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "env.m";
	env: Env;
include "cgi.m";
	cgi: Cgi;
	Fields: import cgi;

Cgiparse: module {
	init:	fn(nil: ref Draw->Context, nil: list of string);
};

modinit()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	env = load Env Env->PATH;
	str = load String String->PATH;
	cgi = load Cgi Cgi->PATH;
	if(cgi == nil)
		fail("loading cgi: %r");
	cgi->init();
}

init(nil: ref Draw->Context, args: list of string)
{
	if(sys == nil)
		modinit();

	arg := load Arg Arg->PATH;
	arg->init(args);
	arg->setusage(arg->progname());
	while((c := arg->opt()) != 0)
		case c {
		* =>	arg->usage();
		}
	args = arg->argv();
	if(args != nil)
		arg->usage();

	case env->getenv("REQUEST_METHOD") {
	"GET" or
	"HEAD" =>
		b := bufio->fopen(sys->fildes(1), Bufio->OWRITE);
		qsl := str->unquoted(env->getenv("QUERY_STRING"));
		if(len qsl >= 1)
			qs := hd qsl;
		f := cgi->unpack(qs);
		for(l := f.l; l != nil; l = tl l) {
			(k, v, nil) := hd l;
			if(hasnul(k) || hasnul(v))
				fail("nul character in parameters, refusing to process");
			if(b.puts(k)    == Bufio->ERROR
			|| b.putc('\0') == Bufio->ERROR
			|| b.puts(v)    == Bufio->ERROR
			|| b.putc('\0') == Bufio->ERROR
			|| b.flush()    == Bufio->ERROR)
				fail(sprint("write: %r"));
		}
	* =>
		fail("only GET & HEAD supported for now");
	}
}

hasnul(s: string): int
{
	n := len s;
	for(i := 0; i < n; i++)
		if(s[i] == '\0')
			return 1;
	return 0;
}

fail(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
	raise "fail:"+s;
}
