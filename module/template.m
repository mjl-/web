Template: module
{
	PATH:	con "/dis/lib/template.dis";

	Vars: adt {
		pairs:		list of (string, string);
		lpairs:		list of (string, list of list of (string, string));
		add:		fn(v: self ref Vars, key, value: string);
		addlist:	fn(v: self ref Vars, key: string, value: list of list of (string, string));
		listadd:	fn(v: self ref Vars, key: string, value: list of (string, string));
	};

	Form: adt {
		formpath: string;
		spit:	fn(f: self ref Form, name: string, pairs: list of (string, string)): string;
		print:	fn(f: self ref Form, name: string, pairs: list of (string, string));
		spitl:	fn(f: self ref Form, name: string, pairs: list of (string, string), lists: list of (string, list of list of (string, string))): string;
		printl:	fn(f: self ref Form, name: string, pairs: list of (string, string), lists: list of (string, list of list of (string, string)));
		spitv:	fn(f: self ref Form, name: string, vars: ref Vars): string;
		printv:	fn(f: self ref Form, name: string, vars: ref Vars);
	};

	init:	fn();
	vars:	fn(): ref Vars;
};
