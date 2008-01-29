Netstr: module
{
	PATH:		con "/dis/lib/netstr.dis";
	readstr:	fn(fd: ref Sys->FD): (string, string);
	readbytes:	fn(fd: ref Sys->FD): (string, array of byte);
	writestr:	fn(fd: ref Sys->FD, s: string): string;
	writebytes:	fn(fd: ref Sys->FD, a: array of byte): string;
	packstr:	fn(s: string): string;
	packbytes:	fn(a: array of byte): array of byte;
	unpackstr:	fn(s: string): (string, string);
	unpackbytes:	fn(a: array of byte): (string, array of byte);
};
