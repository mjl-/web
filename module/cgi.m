Cgi: module
{
	PATH:	con "/dis/lib/cgi.dis";

	init:	fn();

	pack:	fn(l: list of (string, string)): string;
	unpack:	fn(s: string): ref Fields;
	unpackenv:	fn(): ref Fields;
	decode:	fn(s: string): string;
	decodebytes:	fn(s: string): array of byte;
	encode:	fn(s: string): string;
	encodepath:	fn(s: string): string;
	htmlescape:	fn(s: string): string;
	
	Fields: adt {
		l:	list of (string, string, array of byte);  # key, value, value

		get:		fn(f: self ref Fields, name: string): string;
		getbytes:	fn(f: self ref Fields, name: string): array of byte;
		getdefault:	fn(f: self ref Fields, name, default: string): string;
		getlist:	fn(f: self ref Fields, name: string): list of string;
		all:		fn(f: self ref Fields): list of (string, string, array of byte);
		has:		fn(f: self ref Fields, name: string): int;
	};
};
