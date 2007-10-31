Cgi: module
{
	PATH:	con "/dis/lib/cgi.dis";
	init:	fn();
	pack:	fn(l: list of (string, string)): string;
	unpack:	fn(s: string): ref Fields;
	unpackenv: fn(): ref Fields;
	decode:	fn(s: string): string;
	encode:	fn(s: string): string;
	encodepath:	fn(s: string): string;
	htmlescape:	fn(s: string): string;
	
	Fields: adt
	{
		l:	list of (string, string);

		get:		fn(f: self ref Fields, name: string): string;
		getdefault:	fn(f: self ref Fields, name, default: string): string;
		getlist:	fn(f: self ref Fields, name: string): list of string;
		all:		fn(f: self ref Fields): list of (string, string);
	};
};
