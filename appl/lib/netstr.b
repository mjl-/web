implement Netstr;

include "sys.m";
	sys: Sys;
include "netstr.m";


init()
{
	if(sys != nil)
		return;
	sys = load Sys Sys->PATH;
}

readstr(fd: ref Sys->FD): (string, string)
{
	(r, s) := readbytes(fd);
	if(r != nil)
		return (r, nil);
	return (nil, string s);
}

readbytes(fd: ref Sys->FD): (string, array of byte)
{
	init();

	n := 0;
	first := -1;
	for(;;) {
		a := array[1] of byte;
		count := sys->read(fd, a, 1);
		if(count == 0)
			return ("eof reading length", nil);
		if(count < 0)
			return ("error reading length", nil);
		c := int a[0];
		if(c >= '0' && c <= '9') {
			if(first == '0')
				return ("invalid leading zero", nil);
			n = 10*n + (c - '0');
			if(first == -1)
				first = c;
			continue;
		}
		if(c != ':')
			return ("missing semicolon", nil);
		break;
	}

	a := array[n+1] of byte;
	off := 0;
	while(off < len a) {
		have := sys->read(fd, a[off:], len a - off);
		if(have == 0)
			return ("eof while reading data", nil);
		if(have < 0)
			return (sys->sprint("error while reading data: %r"), nil);
		off += have;
	}
	if(a[n] != byte ',')
		return ("missing closing comma", nil);
	return (nil, a[:n]);
}

writestr(fd: ref Sys->FD, s: string): string
{
	return writebytes(fd, array of byte s);
}

writebytes(fd: ref Sys->FD, a: array of byte): string
{
	init();

	start := array of byte (string len(a) + ":");
	end := array of byte string ",";
	n := sys->write(fd, start, len start);
	if(n == 0)
		return sys->sprint("eof while writing length");
	if(n != len start)
		return sys->sprint("error writing length: %r");

	n = sys->write(fd, a, len a);
	if(n == 0)
		return sys->sprint("eof while writing data");
	if(n != len a)
		return sys->sprint("error writing data: %r");

	n = sys->write(fd, end, len end);
	if(n == 0)
		return sys->sprint("eof while writing ending comma");
	if(n != len end)
		return sys->sprint("error writing ending comma: %r");

	return nil;
}

packstr(s: string): string
{
	return string len s + ":" + s + ",";
}

packbytes(a: array of byte): array of byte
{
	length := array of byte string len a;
	r := array[len length+1+len a+1] of byte;
	for(i := 0; i < len length; i++)
		r[i] = length[i];
	r[len length] = byte ':';
	for(i = 0; i < len a; i++)
		r[len length+1+i] = a[i];
	r[len length+1+len a] = byte ',';
	return r;
}

unpackstr(s: string): (string, string)
{
	(err, a) := unpackbytes(array of byte s);
	if(err != nil)
		return (err, nil);
	return (nil, string a);
}

unpackbytes(a: array of byte): (string, array of byte)
{
	n := 0;
	first := -1;
	for(;;) {
		if(len a == 0)
			return ("data too short", nil);
		c := int a[0];
		a = a[1:];
		if(c >= '0' && c <= '9') {
			if(first == '0')
				return ("invalid leading zero", nil);
			n = 10*n + (c - '0');
			if(first == -1)
				first = c;
			continue;
		}
		if(c != ':')
			return ("missing semicolon", nil);
		break;
	}

	if(len a < n+1)
		return ("data too short", nil);
	if(a[n] != byte ',')
		return ("terminating character not comma", nil);
	return (nil, a[:n]);
}
