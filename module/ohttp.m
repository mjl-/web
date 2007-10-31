Http: module {
	PATH:	con "/dis/lib/http.dis";

	init:	fn(bufio: Bufio);

	debug, verbose, quiet:	int;

	get:	fn(url: ref Url, hdrs: list of (string, string)): (ref Rbuf, string);
	post:	fn(url: ref Url, hdrs: list of (string, string), data: array of byte): (ref Rbuf, string);
	retrieve:	fn(req: ref Request): (ref Response, string);
	request:	fn(req: ref Request): (ref Response, string);

	writereq:	fn(fd: ref Sys->FD, req: ref Request): string;
	readresp:	fn(fd: ref Sys->FD, req: ref Request, prevresp: ref Response): (ref Response, string);
	readresp2:	fn(b: ref Iobuf): (ref Response, string);

	readreq:	fn(b: ref Iobuf): (ref Request, string);
	writeresp:	fn(fd: ref Sys->FD, resp: ref Response): string;

	status:	fn(req: ref Request, resp: ref Response): string;

	GET, POST, HEAD, TRACE, PUT, DELETE, PROPFIND, MKCOL, MOVE, PROPPATCH: con iota;
	HTTP_09, HTTP_10, HTTP_11: con iota;

	basicauth:	fn(user, pass: string): (string, string);

	Url: adt {
		ssl:	int;
		host, port, path, searchpart: string;

		parse:	fn(s: string):	(ref Url, string);
		str:	fn(u: self ref Url):	string;
		pathstr:	fn(u: self ref Url):	string;
		addr:	fn(u: self ref Url): string;
		dial:	fn(u: self ref Url): (ref Sys->FD, string);
	};

	encode:	fn(s: string): string;
	encodepath:	fn(s: string): string;
	decode:	fn(s: string): string;

	Request: adt {
		method:		int;
		hdrs:		list of (string, string);
		version:	int;
		url:		ref Url;

		data:		array of byte;
		redir, nredir:	int;
		referer:	int;

		proxyaddr:	string;

		mk:	fn(method: int, hdrs: list of (string, string), version: int, url: ref Url): ref Request;
		copy:	fn(req: self ref Request): ref Request;
	};

	
	Rbuf: adt {
		bio:	ref Iobuf;
		length, have, done, chunklen, blength:	int;
		hdrs:	list of (string, string);
		gzip, dfpid:	int;
		df:	chan of ref Filter->Rq;
		dfbuf:	array of byte;

		read:		fn(rbuf: self ref Rbuf, a: array of byte, n: int): int;
		readall:	fn(rbuf: self ref Rbuf): (array of byte, string);
		headers:	fn(rbuf: self ref Rbuf): list of (string, string);
		close:		fn(rbuf: self ref Rbuf);
	};

	Iresponse: adt {
		status:		string;
		statusmsg:	string;
		hdrs:		list of (string, string);
		data:		array of byte;
	};

	Response: adt {
		version:	int;
		status:		string;
		statusmsg:	string;
		iresps:		list of ref Iresponse;
		hdrs:		list of (string, string);
		rbuf:		ref Rbuf;

		copy:	fn(r: self ref Response): ref Response;
	};
};
