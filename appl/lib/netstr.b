implement Netstr;

include "sys.m";
	sys: Sys;
	sprint: import sys;
include "netstr.m";


init()
{
	if(sys != nil)
		return;
	sys = load Sys Sys->PATH;
}

readstr(fd: ref Sys->FD): (string, string)
{
	(a, err) := readbytes(fd);
	if(err == nil)
		s := string a;
	return (s, err);
}

readbytes(fd: ref Sys->FD): (array of byte, string)
{
	init();

	n := 0;
	first := -1;
	for(;;) {
		a := array[1] of byte;
		count := sys->read(fd, a, 1);
		if(count == 0)
			return (nil, "eof reading length");
		if(count < 0)
			return (nil, "error reading length");
		c := int a[0];
		if(c >= '0' && c <= '9') {
			if(first == '0')
				return (nil, "invalid leading zero");
			n = 10*n + (c - '0');
			if(first == -1)
				first = c;
			continue;
		}
		if(c != ':')
			return (nil, "missing semicolon");
		break;
	}

	a := array[n+1] of byte;
	off := 0;
	while(off < len a) {
		have := sys->read(fd, a[off:], len a - off);
		if(have == 0)
			return (nil, "eof while reading data");
		if(have < 0)
			return (nil, sprint("error while reading data: %r"));
		off += have;
	}
	if(a[n] != byte ',')
		return (nil, "missing closing comma");
	return (a[:n], nil);
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
		return sprint("eof while writing length");
	if(n != len start)
		return sprint("error writing length: %r");

	n = sys->write(fd, a, len a);
	if(n == 0)
		return sprint("eof while writing data");
	if(n != len a)
		return sprint("error writing data: %r");

	n = sys->write(fd, end, len end);
	if(n == 0)
		return sprint("eof while writing ending comma");
	if(n != len end)
		return sprint("error writing ending comma: %r");

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
	(a, err) := unpackbytes(array of byte s);
	if(err == nil)
		r := string a;
	return (r, err);
}

unpackbytes(a: array of byte): (array of byte, string)
{
	n := 0;
	first := -1;
	for(;;) {
		if(len a == 0)
			return (nil, "data too short");
		c := int a[0];
		a = a[1:];
		if(c >= '0' && c <= '9') {
			if(first == '0')
				return (nil, "invalid leading zero");
			n = 10*n + (c - '0');
			if(first == -1)
				first = c;
			continue;
		}
		if(c != ':')
			return (nil, "missing semicolon");
		break;
	}

	if(len a < n+1)
		return (nil, "data too short");
	if(a[n] != byte ',')
		return (nil, "terminating character not comma");
	return (a[:n], nil);
}
