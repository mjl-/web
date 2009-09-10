implement Cgi;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "string.m";
	str: String;
include "env.m";	
	env: Env;
include "dict.m";
	dict: Dictionary;
	Dict: import dict;
include "cgi.m";


init()
{
	sys = load Sys Sys->PATH;
	bufio = load Bufio Bufio->PATH;
	str = load String String->PATH;
	env = load Env Env->PATH;
	dict = load Dictionary Dictionary->PATH;
}


Fields.get(f: self ref Fields, name: string): string
{
	for(l := f.l; l != nil; l = tl l) {
		(k, v, nil) := hd l;
		if(k == name)
			return v;
	}
	return nil;
}

Fields.getbytes(f: self ref Fields, name: string): array of byte
{
	for(l := f.l; l != nil; l = tl l) {
		(k, nil, v) := hd l;
		if(k == name)
			return v;
	}
	return nil;
}

Fields.getdefault(f: self ref Fields, name, default: string): string
{
	for(l := f.l; l != nil; l = tl l) {
		(k, v, nil) := hd l;
		if(k == name)
			return v;
	}
	return default;
}

Fields.getlist(f: self ref Fields, name: string): list of string
{
	r: list of string;
	for(l := f.l; l != nil; l = tl l) {
		(k, v, nil) := hd l;
		if(k == name)
			r = v :: r;
	}
	return r;
}

Fields.all(f: self ref Fields): list of (string, string, array of byte)
{
	return f.l;
}

Fields.has(f: self ref Fields, name: string): int
{
	for(l := f.l; l != nil; l = tl l)
		if((hd l).t0 == name)
			return 1;
	return 0;
}

hex(c: int): int
{
	if(c >= '0' && c <= '9')
		return c - '0';
	if(c >= 'A' && c <= 'F')
		c += 'a' - 'A';
	if(c >= 'a' && c <= 'f')
		return 10 + c - 'a';
	return -1;
}

decodebytes(s: string): array of byte
{
	sa := array of byte s;
	ra := array[len sa] of byte;
	si := 0;
	ri := 0;
	while(si < len sa) {
		c: byte;
		if(sa[si] == byte '%') {
			if(si+2 < len sa) {
				h1 := hex(int sa[si+1]);
				h2 := hex(int sa[si+2]);
				if(h1 < 0 || h2 < 0)
					return nil;
				c = byte ((h1 << 4) | h2);
				si += 3;
			} else
				return nil;
		} else if(sa[si] == byte '+') {
			c = byte ' ';
			si += 1;
		} else {
			c = sa[si];
			si += 1;
		}
		ra[ri++] = c;
	}
	return ra[:ri];
}

decode(s: string): string
{
	return string decodebytes(s);
}

encodepath(s: string): string
{
	return _encode(s, "/");
}

encode(s: string): string
{
	return _encode(s, "");
}

_encode(s: string, okayspecial: string): string
{
	a := array of byte s;
	r := "";
	okay := "a-zA-Z0-9*_.-";
	for(i := 0; i < len a; i++) {
		c := int a[i];
		if(str->in(c, okay) || str->in(c, okayspecial))
			r += sprint("%c", c);
		else if(c == ' ')
			r += "+";
		else
			r += sprint("%%%02X", c);
	}
	return r;
}

pack(l: list of (string, string)): string
{
	r := "";
	first := 1;
	while(l != nil) {
		(k, v) := hd l;
		if(!first)
			r += sprint("&");
		r += sprint("%s=%s", encode(k), encode(v));
		l = tl l;
		first = 0;
	}
	return r;
}

htmlescape(s: string): string
{
	r := "";
	for(i := 0; i < len s; i++)
		case s[i] {
		'<' =>	r += "&lt;";
		'>' =>	r += "&gt;";
		'&' =>	r += "&amp;";
		'"' =>	r += "&quot;";
		* =>	r += s[i:i+1];
		}
	return r;
}

tokenize(s, delims: string): list of string
{
	if(s == "")
		return nil;
	(token, remain) := str->splitstrl(s, delims);
	if(remain != "")
		remain = remain[1:];
	return token :: tokenize(remain, delims);
}

readstr(fd: ref Sys->FD, n: int): string
{
        a := array[0] of byte;
        buf := array[1024] of byte;
        while(n > 0) {
		want := len buf;
		if(want > n)
			want = n;
                have := sys->read(fd, buf, want);
                if(have == 0)
			# premature eof
                        return nil;
                if(have < 0)
			# xxx warn
                        return nil;
		anew := array[len a+have] of byte;
		anew[:] = a;
		anew[len a:] = buf[:have];
		a = anew;
                n -= have;
        }
        return string a;
}

# xxx
readall(fd: ref Sys->FD): string
{
        a := array[0] of byte;
        buf := array[1024] of byte;
        for(;;) {
                have := sys->read(fd, buf, len buf);
                if(have == 0)
                        break;
                if(have < 0)
			# xxx error
                        return nil;
		anew := array[len a+have] of byte;
		anew[:] = a;
		anew[len a:] = buf[:have];
		a = anew;
        }
        return string a;
}

unpackenv(): ref Fields
{
	qs := "";
	method := env->getenv("REQUEST_METHOD");
	if(method == nil || method == "GET" || method == "HEAD") {
		qs = env->getenv("QUERY_STRING");
	} else if(method == "POST") {
		content := env->getenv("CONTENT_TYPE");
		if(content != nil && content != "application/x-www-form-urlencoded")
			# xxx it is probably multipart/form-data (used for files)
			return nil;
		length := env->getenv("CONTENT_LENGTH");
		if(length != nil)
			qs = readstr(sys->fildes(0), int length);
		else
			qs = readall(sys->fildes(0));
	}
	return unpack(qs);
}

unpack(s: string): ref Fields
{
	l: list of (string, string, array of byte);
	pairs := tokenize(s, "&");
	while(pairs != nil) {
		pair := hd pairs;
		pairs = tl pairs;
		(k, v) := str->splitstrl(pair, "=");
		if(v == nil)
			continue;
		v = v[1:];
		k = decode(k);
		vd := decodebytes(v);
		l = (k, string vd, vd)::l;
	}
	return ref Fields(l);
}
