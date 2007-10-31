# xxx
# - look at appl/svc/webget
# - this code and interface are quite ugly, redo most of it

# see
# - http://www.ietf.org/rfc/rfc2616.txt (http/1.1)
# - http://www.ietf.org/rfc/rfc2617.txt (http authentication)
# - http://www.ietf.org/rfc/rfc1945.txt (http/1.0)
# - http://www.cs.tut.fi/~jkorpela/http.html (headers)
# - http://www.jmarshall.com/easy/http/ (nice introduction to http)

# future
# - http auth
# - proxy auth
# - cookies?  mostly on redirection
# - allow conversion to utf-8?
# - ssl support
# - support for conditional retrieving, needs functions for testing whether a previously requested url and headers represent "same" object, and for calculating dates and times.  user of library can set the right headers and handle response.

# notes
# - does not support "expect" header or 100-continue status.  the mechanism is broken in the rfc.  does skip over a 100-continue response.
# - no support for: OPTIONS.
# - no keep-alive for http/1.0.
# - no downgrading of http version (from 1.1 to 1.0), clients of this library should send new request themselves.
# - although interface allows otherwise, pipelining should only be done for http/1.1.  also, do not pipeline non-idempotent requests.
# - caller should add content-type header, and accept, and such.
# - when caller has a valid response, it must either read through eof or close() it.  since it may spawn a process that cannot be garbage collected.

implement Http;

include "sys.m";
include "bufio.m";
include "string.m";
include "filter.m";
include "encoding.m";
include "keyring.m";
include "security.m";
include "pkcs.m";
include "asn1.m";
include "sslsession.m";
include "ssl3.m";
include "http.m";

sys: Sys;
bufio: Bufio;
str: String;
base64: Encoding;
inflate: Filter;
ssl3: SSL3;

Iobuf: import bufio;
Rq: import Filter;
Context: import ssl3;
sprint, fprint, print, FileIO: import sys;

verbose = 0;
debug = 0;
quiet = 1;

methods := array[] of {"GET", "POST", "HEAD", "TRACE", "PUT", "DELETE", "PROPFIND", "MKCOL", "MOVE", "PROPPATCH"};
httpversions := array[] of {"", "HTTP/1.0", "HTTP/1.1"};
bodymethods := array[] of {POST, PUT, DELETE, PROPFIND, MKCOL};
unsafemethods := array[] of {POST, PUT, DELETE, MKCOL, MOVE, PROPPATCH};

ssl_suites := array [] of {
        byte 0, byte 16r03,     # RSA_EXPORT_WITH_RC4_40_MD5
        byte 0, byte 16r04,     # RSA_WITH_RC4_128_MD5
        byte 0, byte 16r05,     # RSA_WITH_RC4_128_SHA
        byte 0, byte 16r06,     # RSA_EXPORT_WITH_RC2_CBC_40_MD5
        byte 0, byte 16r07,     # RSA_WITH_IDEA_CBC_SHA
        byte 0, byte 16r08,     # RSA_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r09,     # RSA_WITH_DES_CBC_SHA
        byte 0, byte 16r0A,     # RSA_WITH_3DES_EDE_CBC_SHA

        byte 0, byte 16r0B,     # DH_DSS_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r0C,     # DH_DSS_WITH_DES_CBC_SHA
        byte 0, byte 16r0D,     # DH_DSS_WITH_3DES_EDE_CBC_SHA
        byte 0, byte 16r0E,     # DH_RSA_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r0F,     # DH_RSA_WITH_DES_CBC_SHA
        byte 0, byte 16r10,     # DH_RSA_WITH_3DES_EDE_CBC_SHA
        byte 0, byte 16r11,     # DHE_DSS_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r12,     # DHE_DSS_WITH_DES_CBC_SHA
        byte 0, byte 16r13,     # DHE_DSS_WITH_3DES_EDE_CBC_SHA
        byte 0, byte 16r14,     # DHE_RSA_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r15,     # DHE_RSA_WITH_DES_CBC_SHA
        byte 0, byte 16r16,     # DHE_RSA_WITH_3DES_EDE_CBC_SHA

        byte 0, byte 16r17,     # DH_anon_EXPORT_WITH_RC4_40_MD5
        byte 0, byte 16r18,     # DH_anon_WITH_RC4_128_MD5
        byte 0, byte 16r19,     # DH_anon_EXPORT_WITH_DES40_CBC_SHA
        byte 0, byte 16r1A,     # DH_anon_WITH_DES_CBC_SHA
        byte 0, byte 16r1B,     # DH_anon_WITH_3DES_EDE_CBC_SHA

        byte 0, byte 16r1C,     # FORTEZZA_KEA_WITH_NULL_SHA
        byte 0, byte 16r1D,     # FORTEZZA_KEA_WITH_FORTEZZA_CBC_SHA
        byte 0, byte 16r1E,     # FORTEZZA_KEA_WITH_RC4_128_SHA
};
ssl_comprs := array [] of {byte 0};




init(b: Bufio)
{
	sys = load Sys Sys->PATH;
	bufio = b;
	str = load String String->PATH;
	base64 = load Encoding Encoding->BASE64PATH;
	inflate = load Filter Filter->INFLATEPATH;
	inflate->init();
	ssl3 = load SSL3 SSL3->PATH;
	ssl3->init();
}

bodymethod(m: int): int
{
	for(i := 0; i < len bodymethods; i++)
		if(bodymethods[i] == m)
			return 1;
	return 0;
}

unsafemethod(m: int): int
{
	for(i := 0; i < len unsafemethods; i++)
		if(unsafemethods[i] == m)
			return 1;
	return 0;
}

rev[t](l: list of t): list of t
{
	r: list of t;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

revtup(l: list of (string, string)): list of (string, string)
{
	r: list of (string, string);
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

prefix(pre, s: string): int
{
	while(pre != nil && s != nil) {
		if(pre[0] != s[0])
			return 0;
		pre = pre[1:];
		s = s[1:];
	}
	return pre == nil;
}

basicauth(user, pass: string): (string, string)
{
	return ("Authorization", "Basic "+string base64->enc(array of byte (user+":"+pass)));
}

Url.parse(s: string): (ref Url, string)
{
	ssl := 0;
	if(prefix("http://", s))
		s = s[len "http://":];
	else if(prefix("https://", s)) {
		s = s[len "https://":];
		ssl = 1;
	} else if(prefix("//", s))
		s = s[len "//":];
	(addr, path) := str->splitl(s, "/");
	(host, port) := str->splitl(addr, ":");
	if(port == "" || port == ":") {
		port = "80";
		if(ssl)
			port = "443";
	} else
		port = port[1:];
	searchpart: string;
	(path, searchpart) = str->splitl(path, "?");
	if(path == "")
		path = "/";
	if(searchpart != nil)
		searchpart = decode(searchpart);
	return (ref Url(ssl, host, port, decode(path), searchpart), nil);
}

Url.str(u: self ref Url): string
{
	port := "";
	if(u.port != "80")
		port = ":"+u.port;
	searchpart := u.searchpart;
	if(searchpart != nil)
		searchpart = searchpart[:1]+encodequery(searchpart[1:]);
	return "http://"+u.host+port+encodepath(u.path)+searchpart;
}

Url.pathstr(u: self ref Url): string
{
	searchpart := u.searchpart;
	if(searchpart != nil)
		searchpart = searchpart[:1]+encodequery(searchpart[1:]);
	return encodepath(u.path)+searchpart;
}

Url.addr(u: self ref Url): string
{
	if(u.host == nil)
		return nil;
	return sprint("net!%s!%s", u.host, u.port);
}

Url.dial(u: self ref Url): (ref Sys->FD, string)
{
	addr := u.addr();
	if(addr == nil)
		return (nil, "no host in url");
	return dial(u.addr(), u.ssl);
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

decode(s: string): string
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
	return string ra[:ri];
}

reserved:	con ";/?:@&=+$,";
unreserved:	con "a-zA-Z0-9_.!~*'()-";
escaped:	con  "%0-9a-fA-F";
pchar:		con "/"+escaped+":@&=_$,"+unreserved;
uric:		con reserved+escaped+unreserved;

encodepath(s: string): string
{
	return _encode(s, pchar);
}

encodequery(s: string): string
{
	return _encode(s, uric);
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
		#else if(c == ' ') r += "+";	not now, lighttpd webdav doesn't know it.  perhaps we it's illegal
		else
			r += sprint("%%%02X", c);
	}
	return r;
}


Request.mk(method: int, hdrs: list of (string, string), version: int, url: ref Url): ref Request
{
	return ref Request(method, hdrs, version, url, nil, 1, 10, 0, nil);
}

Request.copy(req: self ref Request): ref Request
{
	r: Request;
	r = *req;
	return ref r;
}

Response.copy(r: self ref Response): ref Response
{
	# note: does not copy intermediate responses or rbuf
	return ref Response(r.version, r.status, r.statusmsg, nil, r.hdrs, nil);
}


get(url: ref Url, hdrs: list of (string, string)): (ref Rbuf, string)
{
	req := Request.mk(GET, hdrs, HTTP_11, url);
	(resp, err) := retrieve(req);
	if(err != nil)
		return (nil, err);
	if(resp.status[0] != '2')
		return (nil, "failure, "+status(req, resp));
	return (resp.rbuf, nil);
}

post(url: ref Url, hdrs: list of (string, string), data: array of byte): (ref Rbuf, string)
{
	req := Request.mk(POST, hdrs, HTTP_11, url);
	req.data = data;
	(resp, err) := retrieve(req);
	if(err != nil)
		return (nil, err);
	if(resp.status[0] != '2')
		return (nil, "failure, "+status(req, resp));
	return (resp.rbuf, nil);
}

getline(bio: ref Iobuf): (string, int)
{
	line := bio.gets('\n');
	if(line == "")
		return (nil, 1);
	if(line != "" && line[len line - 1] == '\n') {
		line = line[:len line - 1];
		if(line != "" && line[len line - 1] == '\r')
			line = line[:len line - 1];
	}
	return (line, 0);
}

readheaders(bio: ref Iobuf): (list of (string, string), string)
{
	hdrs: list of (string, string);
	for(;;) {
		(line, eof) := httpgetline(bio);
		if(eof)
			return (nil, "eof from server while reading headers");
		if(line == "")
			break;
		if(line[0] == ' ' || line[0] == '\t') {
			if(hdrs == nil)
				return (nil, "first header claims to be continuation header, not possible");
			line = str->drop(line, " \t");
			while(line != nil && str->in(line[len line-1], " \t"))
				line = line[:len line-1];
			(k, v) := hd hdrs;
			hdrs = (k, v+" "+line)::tl hdrs;
			continue;
		}
		(key, value) := str->splitl(line, ":");
		if(value == nil)
			return (nil, "invalid header from server: "+line);
		value = str->drop(value[1:], " \t");
		while(value != nil && str->in(value[len value-1], " \t"))
			value = value[:len value-1];
		hdrs = (key, value)::hdrs;
	}
	return (revtup(hdrs), nil);
}

# returns effective value for header.  concatenates multiple occurrences with comma in between.
hfind(hdrs: list of (string, string), key: string): (int, string)
{
	key = str->tolower(key);
	have := 0;
	val := "";
	for(; hdrs != nil; hdrs = tl hdrs) {
		(k, v) := hd hdrs;
		k = str->tolower(k);
		if(k == key) {
			if(have)
				val += ",";
			val += v;
			have = 1;
		}
	}
	return (have, val);
}

# removes multiple occurrences of header
hset(req: ref Request, h: (string, string))
{
	(key, nil) := h;
	key = str->tolower(key);
	hdrs: list of (string, string);
	set := 0;
	for(l := req.hdrs; l != nil; l = tl l) {
		(k, nil) := hd l;
		k = str->tolower(k);
		if(!set && k == key) {
			hdrs = h::hdrs;
			set = 1;
		} else
			hdrs = (hd l)::hdrs;
	}
	if(!set)
		hdrs = revtup(h::revtup(hdrs));
	req.hdrs = revtup(hdrs);
}

hadd(req: ref Request, h: (string, string))
{
	(key, nil) := h;
	(have, nil) := hfind(req.hdrs, key);
	if(have)
		return;
	req.hdrs = revtup(h::revtup(req.hdrs));
}

retrieve(req: ref Request): (ref Response, string)
{
	iresps: list of ref Iresponse;

	if(req.data != nil && !bodymethod(req.method))
		return (nil, "cannot send message body for "+methods[req.method]);
	if(bodymethod(req.method))
		hset(req, ("Content-Length", string len req.data));
	if(req.version == HTTP_10)
		hadd(req, ("Accept-Encoding", "x-deflate, x-gzip"));
	else
		hadd(req, ("Accept-Encoding", "deflate, gzip"));

	addr := mkaddr(req);
	fd: ref Sys->FD;
	reused := 0;

	while(req.nredir >= 0) {
		if(fd == nil) {
			(nfd, err) := dial(addr, req.url.ssl);
			if(err != nil) {
				say(err);
				return (nil, err);
			}
			fd = nfd;
			say("dialed "+addr);
			reused = 0;
		} else {
			say("reusing connection to "+addr);
			reused = 1;
		}

		(resp, err) := _request(fd, req);
		if(err != nil && str->prefix("writing request:", err) && reused) {
			say("reused connection broke, redialing to "+addr);
			(fd, err) = dial(addr, req.url.ssl);
			if(err != nil) {
				say(err);
				return (nil, err);
			}
			say("dialed "+addr);
			(resp, err) = _request(fd, req);
		}
		if(err != nil)
			return (nil, err);
		resp.iresps = rev(iresps);

		case status := int resp.status {
		301 or 302 or 303 or 307 =>
			if(!req.redir)
				return (resp, nil);

			# note: following a 302 POST with a GET seems to be common practice, even according to rfc2616
			if(!unsafemethod(req.method) || (status == 303 || status == 302)) {
				(have, value) := hfind(resp.hdrs, "Location");
				if(!have) {
					resp.rbuf.close();
					return (resp, "redirect: missing \"Location\" header for redirect");
				}

				# ignore error, data is not that important ....
				(data, nil) := resp.rbuf.readall();
				hdrs := resp.hdrs;
				for(tail := resp.rbuf.headers(); tail != nil; tail = tl tail)
					hdrs = hd tail::hdrs;
				iresp := ref Iresponse(resp.status, resp.statusmsg, hdrs, data);
				iresps = iresp::iresps;

				if(prefix("/", value) && !prefix("//", value)) {
					host := "http://"+req.url.host;
					if(req.url.port != "80")
						host += ":"+req.url.port;
					value = host+value;
				}
				(newurl, urlerr) := Url.parse(value);
				if(urlerr != nil) {
					resp.rbuf.close();
					return (resp, "redirect: redirected to invalid url: "+value);
				}

				newhdrs: list of (string, string);
				for(orighdrs := req.hdrs; orighdrs != nil; orighdrs = tl orighdrs) {
					(k, nil) := hd orighdrs;
					k = str->tolower(k);
					if(k == "content-type" || k == "content-length" || k == "host")
						continue;
					newhdrs = hd orighdrs::newhdrs;
				}
				req.hdrs = revtup(newhdrs);

				newreq := req.copy();
				if(req.method == PROPFIND)
					newreq.method = PROPFIND;
				else
					newreq.method = GET;
				newreq.url = newurl;
				newreq.nredir--;
				if(newreq.referer)
					hset(newreq, ("Referer", req.url.str()));

				(nil, v) := hfind(resp.hdrs, "Connection");
				newaddr := mkaddr(newreq);
				if(newaddr != addr || req.version != HTTP_11 || str->tolower(v) == "close")
					fd = nil;
				addr = newaddr;

				req = newreq;
				if(!quiet)
					sys->fprint(sys->fildes(2), "redirecting to %q (%s %s)\n", newurl.str(), resp.status, resp.statusmsg);
				else
					say(sprint("redirecting to url=%q status=%q", newurl.str(), resp.status));
				continue;

			} else {
				resp.rbuf.close();
				return (resp, "redirect: not following redirect because method is not GET");
			}
		* =>
			return (resp, nil);
		}
	}
	return (ref Response(0, nil, nil, rev(iresps), nil, nil), "redirect: too many redirects");
}

mkaddr(req: ref Request): string
{
	if(req.proxyaddr != nil)
		return req.proxyaddr;
	return sprint("tcp!%s!%s", req.url.host, req.url.port);
}

_request(fd: ref Sys->FD, req: ref Request): (ref Response, string)
{
	err := writereq(fd, req);
	if(err != nil) {
		say("writing request: "+err);
		return (nil, err);
	}
	(resp, resperr) := readresp(fd, req, nil);
	if(resperr != nil)
		say("reading response: "+err);
	if(resp != nil && resp.rbuf != nil)
		resp.rbuf.close();
	return (resp, resperr);
}

request(req: ref Request): (ref Response, string)
{
	addr := mkaddr(req);
	(fd, err) := dial(addr, req.url.ssl);
	if(err != nil) {
		say(err);
		return (nil, err);
	}
	return _request(fd, req);
}

writereq(fd: ref Sys->FD, req: ref Request): string
{
	httpversion := httpversions[req.version];
	if(httpversion != "")
		httpversion = " "+httpversion;
	method := methods[req.method];
	path := req.url.pathstr();
	if(req.proxyaddr != nil)
		path = req.url.str();

	s := httpout(sprint("%s %s%s\r\n", method, path, httpversion));
	if(req.version >= HTTP_10) {
		(havehost, nil) := hfind(req.hdrs, "Host");
		if(!havehost)
			s += httpout(sprint("Host: %s\r\n", req.url.host));
		for(h := req.hdrs; h != nil; h = tl h)
			s += httpout(sprint("%s: %s\r\n", (hd h).t0, (hd h).t1));
		s += httpout("\r\n");
		if(sys->write(fd, d := array of byte s, len d) != len d)
			return sprint("writing request: %r");
		if(bodymethod(req.method) && len req.data != 0) {
			if(verbose || debug)
				sys->write(sys->fildes(2), req.data, len req.data);
			n := sys->write(fd, req.data, len req.data);
			if(n != len req.data)
				return sprint("writing post data: %r");
		}
	} else {
		if(sys->write(fd, d := array of byte s, len d) != len d)
			return sprint("writing request: %r");
	}
	return nil;
}

hval(hdrs: list of (string, string), key: string): string
{
	key = str->tolower(key);
	for(l := hdrs; l != nil; l = tl l) {
		(k, v) := hd l;
		if(str->tolower(k) == key)
			return v;
	}
	return sprint("(missing header \"%s\")", key);
}

status(nil: ref Request, resp: ref Response): string
{
	msg := "";
	case int resp.status {
	101 =>	msg = "upgrade to: "+hval(resp.hdrs, "Upgrade");
	301 to 303 =>
		msg = "redirection to: "+hval(resp.hdrs, "Location");
	305 =>	msg = "use proxy: "+hval(resp.hdrs, "Location");
	401 =>	msg = "unauthorized for: "+hval(resp.hdrs, "WWW-Authenticate");
	405 =>	msg = "bad method, allowed are: "+hval(resp.hdrs, "Allow");
	407 =>	msg = "unauthorized for proxy: "+hval(resp.hdrs, "Proxy-Authenticate");
	416 =>	msg = "bad range requested, contents range: "+hval(resp.hdrs, "Content-Range");
	}
	if(msg != "")
		msg = ": "+msg;
	return sprint("%s (%s)%s", resp.status, resp.statusmsg, msg);
}

httpgetline(bio: ref Iobuf): (string, int)
{
	(s, eof) := getline(bio);
	if(!eof && (verbose || debug))
		fprint(sys->fildes(2), "<- %s\n", s);
	return (s, eof);
}

readresp(fd: ref Sys->FD, req: ref Request, prevresp: ref Response): (ref Response, string)
{
	if(req.version >= HTTP_10) {
		bio: ref Iobuf;
		if(prevresp == nil || prevresp.rbuf == nil || prevresp.rbuf.bio == nil) {
			bio = bufio->fopen(fd, bufio->OREAD);
			if(bio == nil)
				return (nil, sprint("bufio opening: %r"));
		} else {
			if(!prevresp.rbuf.done)
				return (nil, sprint("cannot read response without reading previous response"));
			bio = prevresp.rbuf.bio;
		}

		hdrs: list of (string, string);
		httpversion: int;
		status, statusmsg: string;
		havecont := 0;
		for(;;) {
			(line, eof) := httpgetline(bio);
			if(eof)
				return (nil, "eof while reading http response line");
			(resphttpversion, rem) := str->splitl(line, " ");
			case resphttpversion {
			"HTTP/1.0" =>	httpversion = HTTP_10;
			"HTTP/1.1" =>	httpversion = HTTP_11;
			* =>		return (nil, "unrecognized http version: "+line);
			}
			if(rem == nil)
				return (nil, "missing response code: "+line);
			(status, statusmsg) = str->splitl(rem[1:], " ");
			if(len status != 3 || str->take(status, "0-9") != status)
				return (nil, "invalid response status: "+line);
			if(statusmsg != nil)
				statusmsg = statusmsg[1:];

			err: string;
			(hdrs, err) = readheaders(bio);
			if(err != nil)
				return (nil, err);
			if(status == "100") {
				if(havecont)
					return (nil, "two consecutive 100-continue responses");
				havecont = 1;
				continue;
			}
			break;
		}

		chunked := 0;
		length := -1;
		(nil, v) := hfind(hdrs, "Transfer-Encoding");
		if(str->tolower(v) == "chunked")
			chunked = 1;
		(nil, v) = hfind(hdrs, "Content-Length");
		if(!chunked && v != nil)
			length = int v;

		gzip := 0;
		(have, ce) := hfind(hdrs, "Content-Encoding");
		if(have)
			case str->tolower(ce) {
			"gzip" =>	gzip = 1;
			"deflate" =>	gzip = 2;
			* =>		return (nil, "unknown content-encoding: "+ce);
			}

		blength := length;
		if(gzip)
			blength = -1;

		done := 0;
		case int status {
		100 or 101 or 204 or 205 or 304 => done = 1;
		}
		if(req.method == HEAD)
			done = 1;
		if(length == 0)
			done = 1;

		rbuf := rbufopen(bio, done, length, chunked, gzip, blength);
		return (ref Response(httpversion, status, statusmsg, nil, hdrs, rbuf), nil);
	} else {
		bio := bufio->fopen(fd, bufio->OREAD);
		if(bio == nil)
			return (nil, sprint("bufio opening: %r"));
		gzip := 0;
		rbuf := rbufopen(bio, 0, -1, 0, gzip, -1);
		return (ref Response(HTTP_09, "200", "OK", nil, nil, rbuf), nil);
	}
}

# xxx need to do 100 continue
readresp2(b: ref Iobuf): (ref Response, string)
{
	hdrs: list of (string, string);
	(line, eof) := httpgetline(b);
	if(eof)
		return (nil, "eof while reading http response line");
	(resphttpversion, rem) := str->splitl(line, " ");
	httpversion: int;
	case resphttpversion {
	"HTTP/1.0" =>	httpversion = HTTP_10;
	"HTTP/1.1" =>	httpversion = HTTP_11;
	* =>		return (nil, "unrecognized http version: "+line);
	}
	if(rem == nil)
		return (nil, "missing response code: "+line);
	(status, statusmsg) := str->splitl(rem[1:], " ");
	if(len status != 3 || str->take(status, "0-9") != status)
		return (nil, "invalid response status: "+line);
	if(statusmsg != nil)
		statusmsg = statusmsg[1:];

	err: string;
	(hdrs, err) = readheaders(b);
	if(err != nil)
		return (nil, err);

	return (ref Response(httpversion, status, statusmsg, nil, hdrs, nil), nil);
}

rbufopen(bio: ref Iobuf, done, length, chunked, gzip, blength: int): ref Rbuf
{
	chunklen := -1;
	if(chunked)
		chunklen = 0;
	return ref Rbuf(bio, length, 0, done, chunklen, blength, nil, gzip, -1, nil, nil);
}


Rbuf.read(r: self ref Rbuf, a: array of byte, n: int): int
{
	if(r.done)
		return 0;
	if(!r.gzip)
		return rbufread(r, a, n);

	if(r.df == nil) {
		flags := "";
		if(r.gzip == 1)
			flags += "h";
		r.df = inflate->start(flags);
		pick m := <- r.df {
		Start =>
			r.dfpid = m.pid;
		* =>
			sys->werrstr("invalid start message from inflate filter");
			return -1;
		}
	}

	while(r.dfbuf == nil || len r.dfbuf == 0) {
		pick m := <- r.df {
		Fill =>
			say(sprint("read,inflate: fill len=%d", len m.buf));
			have := rbufread(r, m.buf, len m.buf);
			m.reply <-= have;
			if(have < 0) {
				r.dfpid = -1;
				return have;
			}
		Result =>
			say(sprint("read,inflate: result len=%d", len m.buf));
			buf := array[len m.buf] of byte;
			r.dfbuf = buf;
			r.dfbuf[:] = m.buf;
			m.reply <-= 0;
		Finished =>
			say(sprint("read,inflate: finished leftover-len=%d", len m.buf));
			r.done = 1;
			r.dfpid = -1;
			return 0;
		Info =>
			say("inflate: "+m.msg);
		Error =>
			sys->werrstr(sprint("inflate: %s", m.e));
			r.dfpid = -1;
			return -1;
		* =>
			sys->werrstr(sprint("inflate: unexpected response from filter"));
			return -1;
		}
	}

	m := len r.dfbuf;
	if(n < m)
		m = n;
	a[:] = r.dfbuf[:m];
	r.dfbuf = r.dfbuf[m:];
	return m;
}

rbufread(r: ref Rbuf, a: array of byte, n: int): int
{
	if(r.done)
		return 0;

	if(r.chunklen == 0) {
		(line, eof) := getline(r.bio);
		if(eof) {
			sys->werrstr("eof while reading chunk length");
			return -1;
		}
		(line, nil) = str->splitl(line, ";");
		line = str->drop(line, " \t");
		while(line != nil && (line[len line - 1] == ' ' || line[len line - 1] == '\t'))
			line = line[:len line - 1];
		say("new chunk: "+line);
		if(line == "0") {
			r.done = 1;
			err: string;
			(r.hdrs, err) = readheaders(r.bio);
			if(err != nil) {
				sys->werrstr("error reading trailing headers: "+err);
				return -1;
			}
			return 0;
		}
		rem: string;
		(r.chunklen, rem) = str->toint(line, 16);
		if(line == "" || rem != nil) {
			sys->werrstr("invalid chunk length: "+line);
			return -1;
		}
	}

	if(r.chunklen > 0) {
		want := r.chunklen;
		if(n < want)
			want = n;
		have := r.bio.read(a, want);
		if(have > 0)
			r.chunklen -= have;
		if(r.chunklen == 0) {
			(line, eof) := getline(r.bio);
			if(line != "" || eof) {
				sys->werrstr("missing newline after chunk");
				return -1;
			}
		}
		return have;
	} else {
		want := n;
		if(r.length >= 0 && want > r.length - r.have)
			want = r.length - r.have;
		have := r.bio.read(a, want);
		if(have > 0)
			r.have += have;
		if(have == 0)
			r.done = 1;
		return have;
	}
}

Rbuf.headers(r: self ref Rbuf): list of (string, string)
{
	return r.hdrs;
}

Rbuf.readall(r: self ref Rbuf): (array of byte, string)
{
	a: array of byte;
	buf := array[8*1024] of byte;

	for(;;) {
		have := r.read(buf, len buf);
		if(have == 0)
			return (a, nil);
		if(have < 0)
			return (nil, sprint("%r"));
		anew := array[len a + have] of byte;
		anew[:] = a;
		anew[len a:] = buf[:have];
		a = anew;
	}
}

Rbuf.close(r: self ref Rbuf)
{
	if(r.done)
		return;
	if(r.dfpid >= 0)
		killpid(r.dfpid);
	r.dfpid = -1;
}

readreq(b: ref Iobuf): (ref Request, string)
{
	(l, eof) := httpgetline(b);
	if(eof)
		return (nil, "eof reading request");

	s: string;
	(s, l) = str->splitstrl(l, " ");
	method := -1;
	s = str->toupper(s);
	for(i := 0; method == -1 && i < len methods; i++)
		if(methods[i] == s)
			method = i;
	if(method == -1)
		return (nil, "unknown method: "+s);
	while(l != nil && l[0] == ' ')
		l = l[1:];

	ver := "http/1.?";
	if(len l < len ver)
		return (nil, "bad request, no version");
	version: int;
	case str->tolower(l[len l-len ver:]) {
	"http/1.0" =>	version = HTTP_10;
	"http/1.1" =>	version = HTTP_11;
	* =>		return (nil, "bad version: "+l[len l-len ver:]);
	}
	l = l[:len l-len ver];
	while(l != nil && l[len l-1] == ' ')
		l = l[:len l-1];

	(u, uerr) := Url.parse(l);
	if(uerr != nil)
		return (nil, uerr);

	(hdrs, herr) := readheaders(b);
	if(herr != nil)
		return (nil, herr);

	return (ref Request(method, hdrs, version, u, nil, 0, 0, 0, nil), nil);
}


httpout(s: string): string
{
	if(verbose || debug)
		fprint(sys->fildes(2), "-> %s", s);
	return s;
}

writeresp(fd: ref Sys->FD, resp: ref Response): string
{
	version: string;
	case resp.version {
	HTTP_10 =>	version = "HTTP/1.0";
	HTTP_11 =>	version = "HTTP/1.1";
	* =>	return "request version not supported";
	}

	s := httpout(version+" "+resp.status+" "+resp.statusmsg+"\r\n");
	for(l := resp.hdrs; l != nil; l = tl l) {
		(k, v) := hd l;
		s += httpout(k+": "+v+"\r\n");
	}
	s += httpout("\r\n");
	d := array of byte s;
	n := sys->write(fd, d, len d);
	if(n != len d)
		return sprint("writing response: %r");
	return nil;
}

nsslfc := 0;
dial(addr: string, usessl: int): (ref Sys->FD, string)
{
	(ok, conn) := sys->dial(addr, nil);
	if(ok < 0)
		return (nil, sprint("dial %s: %r", addr));
	say("dial: dialed "+addr);
	if(!usessl)
		return (conn.dfd, nil);

	sslx := Context.new();
	info := ref SSL3->Authinfo(ssl_suites, ssl_comprs, nil, 0, nil, nil, nil);
	(err, vers) :=  sslx.client(conn.dfd, addr, 3, info);
	if(err != nil)
		return (nil, err);
	say(sprint("ssl connected version=%d", vers));

	f := sprint("fcn%d.%d", sys->pctl(0, nil), nsslfc++);
	fio := sys->file2chan("#sssl", f);
	spawn sslfc(fio, sslx);
	fd := sys->open(sprint("#sssl/%s", f), Sys->ORDWR);
	if(fd == nil)
		return (nil, sprint("opening ssl file: %r"));
	return (fd, nil);
}

sslfc(fio: ref FileIO, sslx: ref Context)
{
	say("sslfc: new");
	eof := 0;
	for(;;) alt {
	(nil, count, nil, rc) := <-fio.read =>
		if(rc == nil) {
			say("sslfc: rc == nil");
			return;
		}
		if(eof) {
			rc <-= (array[0] of byte, nil);
			continue;
		}
		n := sslx.read(d := array[count] of byte, len d);
		if(n < 0) {
			rc <-= (nil, sprint("%r"));
			return;
		}else
			rc <-= (d[:n], nil);
		if(n == 0)
			eof = 1;

	(nil, d, nil, wc) := <-fio.write =>
		if(wc == nil) {
			say("sslfc: wc == nil");
			return;
		}
		if(sslx.write(d, len d) != len d) {
			wc <-= (-1, sprint("%r"));
			say("sslfc: error writing");
			return;
		} else
			wc <-= (len d, nil);
	}
}

killpid(pid: int)
{
	ctl := "/prog/"+string pid+"/ctl";
	cfd := sys->open(ctl, sys->OWRITE);
	if(cfd != nil)
		sys->fprint(cfd, "kill\n");
}

say(s: string)
{
	if(debug)
		sys->fprint(sys->fildes(2), "%s\n", s);
}
