# yacc -m -o template.b template.y

%{
include "sys.m";
	sys: Sys;
include "template.m";
include "bufio.m";
	bufio: Bufio;
	Iobuf: import bufio;
include "env.m";
	env: Env;
include "cgi.m";
	cgi: Cgi;
include "string.m";
	str: String;
include "regex.m";
	regex: Regex;

sprint: import sys;

YYSTYPE: adt {
	c: int;
	v, s: string;
};
YYLEX: adt {
	lval:	YYSTYPE;
	lex:	fn(l: self ref YYLEX): int;
	error:	fn(l: self ref YYLEX, msg: string);
};
%}

%module Template {
}

%left	'+' '-'
%left	'*' '/'
%left	AND
%left	OR

%type   <c> top cond andcond ucond expr uexpr term
%type	<s> sexpr string

%token  <c> INT
%token  <s> LITERAL
%token  <v> VAR
%token	AND OR NOT
%token	LE GE EQ NE
%token	SET LENGTH
%token	TRUE FALSE

%%
top :
	cond 			{ return $1; }
	;

cond :	andcond
	| andcond OR cond	{ $$ = $1 || $3; }
	;

andcond : ucond
	| ucond AND andcond 	{ $$ = $1 && $3; }
	;

ucond :
	NOT ucond		{ $$ = ! $2; }
	| SET VAR
	{
		(have, nil, nil, nil) := findvar($2, parsepairs, parselpairs, parseforeach);
		$$ = have;
	}
	| TRUE			{ $$ = 1; }
	| FALSE			{ $$ = 0; }
	| sexpr '<' sexpr	{ $$ = $1 < $3; }
	| sexpr '>' sexpr	{ $$ = $1 > $3; }
	| sexpr LE sexpr	{ $$ = $1 <= $3; }
	| sexpr GE sexpr	{ $$ = $1 >= $3; }
	| sexpr EQ sexpr	{ $$ = $1 == $3; }
	| sexpr NE sexpr	{ $$ = $1 != $3; }
	;

sexpr :
	string			{ $$ = $1; }
	| expr			{ $$ = string $1; }
	;

expr :	uexpr
	| expr '*' expr		{ $$ = $1 * $3; }
	| expr '/' expr		{ $$ = $1 / $3; }
	| expr '+' expr		{ $$ = $1 + $3; }
	| expr '-' expr		{ $$ = $1 - $3; }
	;

uexpr : term
	| '+' uexpr		{ $$ = $2; }
	| '-' uexpr		{ $$ = - $2; }
	;

term : INT
	| '(' cond ')'		{ $$ = $2; }
	| LENGTH LITERAL	{ $$ = len $2; }
	| LENGTH VAR
	{
		(have, t) := find($2, parselists);
		if(have) {
			$$ = len t;
		} else {
			(nil, nil, nil, value) := findvar($2, parsepairs, parselpairs, parseforeach);
			# xxx print warning if variable is missing
			$$ = len value;
		}
	}
	;

string:
	LITERAL			{ $$ = $1; }
	| VAR
	{
		(have, nil, nil, value) := findvar($1, parsepairs, parselpairs, parseforeach);
		# xxx print warning if variable is missing
if(!have)
	sys->fprint(sys->fildes(2), "missing var %q\n", $1);
		$$ = value;
	}
	;

%%

in: ref Iobuf;
parsepairs: list of (string, string);
parselpairs: list of list of (string, string);
parseforeach: int;
parseerror: string;
parselists: list of (string, list of list of (string, string));

parse(line: string, pairs: list of (string, string), lpairs: list of list of (string, string), foreach: int, lists: list of (string, list of list of (string, string))): (int, string)
{
	bufio = load Bufio Bufio->PATH;
	in = bufio->sopen(line);
	lex := ref YYLEX;
	parseerror = nil;
	parsepairs = pairs;
	parselpairs = lpairs;
	parseforeach = foreach;
	parselists = lists;
	return (yyparse(lex), parseerror);
}

YYLEX.error(nil: self ref YYLEX, err: string)
{
	parseerror = err;
}

YYLEX.lex(lex: self ref YYLEX): int
{
	strtab := list of {
		("not", NOT),
		("and", AND),
		("or", OR),
		("set", SET),
		("length", LENGTH),
		("true", TRUE),
		("false", FALSE),
	};
	optab := list of {
		("<=", LE),
		(">=", GE),
		("==", EQ),
		("!=", NE),
		("<", '<'),
		(">", '>'),
	};

	for(;;){
		c := in.getc();
		case c{
		' ' or '\t' =>
			;
		'(' or ')' or '*' or '/' or '+' or '-' =>
			return c;
		'"' =>
			s := "";
			i := 0;
			while((c = in.getc()) != '"')
				s[i++] = c;
			lex.lval.s = s;
			return LITERAL;

		'0' to '9' or 'a' to 'z' or 'A' to 'Z' =>
			s := "";
			i := 0;
			s[i++] = c;
			isint := c >= '0' && c <= '9';
			for(;;) {
				c = in.getc();
				if(c >= '0' && c <= '9' || c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z') {
					s[i++] = c;
					isint = isint && c >= '0' && c <= '9';
					continue;
				}
				break;
			}
			in.ungetc();
			if(isint) {
				lex.lval.c = int s;
				return INT;
			}
			for(l := strtab; l != nil; l = tl l) {
				(k, v) := hd l;
				if(k == s)
					return v;
			}
			lex.lval.v = s;
			return VAR;
			
		* =>
			if(c == bufio->EOF || c == bufio->ERROR)
				return -1;
			s := "";
			s[0] = c;
			c2 := in.getc();
			if(c2 != '=')
				in.ungetc();
			else
				s[1] = c2;
			for(l := optab; l != nil; l = tl l) {
				(k, v) := hd l;
				if(k == s)
					return v;
			}
				
			return -1;
		}
	}
}



ESCnone, ESChtml, ESCuri, ESCuripath: con iota;

parseform(p: string): list of string
{
	instring := 1;
	s := "";
	l: list of string;
	i := 0;
	while(i < len p) {
		if(instring) {
			if(p[i] == '%') {
				if(i+1 < len p && p[i+1] == '%') {
					s += "%";
					i += 2;
					continue;
				}
				instring = 0;
				l = s :: l;
				s = "";
			} else
				s += p[i:i+1];
		} else {
			if(p[i] == '%' || p[i] == '\n') {
				instring = 1;
				l = s :: l;
				s = "";
			} else
				s += p[i:i+1];
		}
		i++;
	}
	if(instring)
		l = s :: l;
	return rev(l);
}


warn(s: string)
{
	sys->fprint(sys->fildes(2), "%s\n", s);
}


finditem[T](s: string, l: list of (string, T)): T
{
	(nil, r) := find(s, l);
	return r;
}


find[T](var: string, l: list of (string, T)): (int, T)
{
	for(; l != nil; l = tl l) {
		(name, t) := hd l;
		if(var == name)
			return (1, t);
	}
	return (0, nil);
}

findvar(rawvar: string, pairs: list of (string, string), lpairs: list of list of (string, string), foreach: int): (int, int, string, string)
{
	escape := ESChtml;
	fromenv := 0;
	var := rawvar;
changevar:
	while(var != nil ) {
		case(int var[0]) {
		'!' =>	escape = ESCnone;
		'#' =>	escape = ESCuri;
		'&' =>	escape = ESCuripath;
		'$' =>	fromenv = 1;
		* =>	break changevar;
		}
		var = var[1:];
	}

	value: string;
	have := 0;
	
	if(fromenv) {
		(have, value) = find(var, env->getall());
	} else {
		if(foreach)
			(have, value) = find(var, hd lpairs);
		if(!have)
			(have, value) = find(var, pairs);
	}
	return (have, escape, var, value);
}


tokenize(s: string): list of string
{
	l: list of string;
	s = s[len str->take(s, " \t"):];
	while(s != "") {
		word := str->take(s, "^ \t");
		s = s[len word:];
		s = s[len str->take(s, " \t"):];
		l = word::l;
	}
	return rev(l);
}


applyform(form: ref Form, templ: list of string, pairs: list of (string, string), lists: list of (string, list of list of (string, string))): string
{
	literal := 1;
	r := "";
	foreachifstack, ifstack: list of (int, int);
	foreach := 0;
	foreachtempl: list of string;
	foreachlist: list of list of (string, string);

	while(templ != nil) {
		if(literal) {
			lit := hd templ;
			literal = 0;
			templ = tl templ;
			if(ifstack != nil) {
				(inif, cond):= hd ifstack;
				if(inif && !cond || !inif && cond)
					continue;
			}
			r += lit;
			continue;
		}

		word := hd templ;
		tokens := tokenize(word);
		templ = tl templ;
		literal = 1;
		if(tokens == nil) {
			warn("empty command");
			continue;
		}

		token := hd tokens;
		tokens = tl tokens;
		if(!foreach && token == "foreach" && len tokens == 1) {
			foreachlist = finditem(hd tokens, lists);
			if(foreachlist == nil) {
				for(;;) {
					if(templ == nil || tl templ == nil) {
						sys->fprint(sys->fildes(2), "missing end for foreach\n");
						return r;
					}
					elem := hd templ;
					templ = tl templ;
					if(elem == "done")
						break;
				}
			} else {
				foreach = 1;
				foreachtempl = templ;
				foreachifstack = ifstack;
				ifstack = nil;
			}
		} else if(foreach && token == "done" && len tokens == 0) {
			if(ifstack != nil) {
				warn("missing end while in foreach");
				return r;
			}
			if(tl foreachlist == nil) {
				foreach = 0;
				ifstack = foreachifstack;
			} else {
				foreachlist = tl foreachlist;
				templ = foreachtempl;
			}
		} else if(token == "if") {
		        word = word[len str->take(word, " \t"):];
			word = word[2:];
		        word = word[len str->take(word, " \t"):];
			(cond, err) := parse(word, pairs, foreachlist, foreach, lists);
			if(err != nil) {
				warn("invalid command: "+word);
				return r;
			}
			inif := 1;
			ifstack = (inif, cond)::ifstack;
		} else if(token == "else" && len tokens == 0) {
			if(ifstack == nil) {
				warn("else without if");
				return r;
			}
			(nil, cond) := hd ifstack;
			inif := 0;
			ifstack = (inif, cond)::tl ifstack;
		} else if(token == "end" && len tokens == 0) {
			if(ifstack == nil) {
				warn("end without if");
				return r;
			}
			ifstack = tl ifstack;
			continue;
		} else {
			if(len tokens == 1) {
				if(token != "include" && token != "length")
					warn("invalid command: "+joinstr(token::tokens, ", "));
			}

			if(ifstack != nil) {
				(inif, cond):= hd ifstack;
				if(inif && !cond || !inif && cond)
					continue;
			}

			if(token == "include" && len tokens == 1) {
				r += form.spitl(hd tokens, pairs, lists);
			} else if(token == "length" && len tokens == 1) {
				(have, l) := find(hd tokens, lists);
				if(!have)
					warn(sprint("missing variable %q, for length", hd tokens));
				else
					r += sprint("%d", len l);
			} else {
				rawvar := token;
				(have, escape, var, value) := findvar(rawvar, pairs, foreachlist, foreach);

				if(!have) {
					r += sprint("<!-- %s -->", rawvar);
					warn(sprint("missing variable %q", var));
				} else {
					case escape {
					ESCnone		=> ;
					ESChtml		=> value = cgi->htmlescape(value);
					ESCuri		=> value = cgi->encode(value);
					ESCuripath	=> value = cgi->encodepath(value);
					}
					r += value;
				}
			}
		}
	}
	return r;
}


init()
{
	sys = load Sys Sys->PATH;
	env = load Env Env->PATH;
	str = load String String->PATH;
	cgi = load Cgi Cgi->PATH;
	if(cgi == nil)
		nomod(Cgi->PATH);
	cgi->init();
}

joinstr(l: list of string, e: string): string
{
	if(l == nil)
		return "";
	s := hd l;
	l = tl l;
	for(; l != nil; l = tl l)
		s += e+hd l;
	return s;
}


Form.spitl(form: self ref Form, name: string, pairs: list of (string, string), lists: list of (string, list of list of (string, string))): string
{
	filename := form.formpath+"/"+name;
	if(filename[0] != '/')
		filename = "/lib/template/"+filename;
	fd := sys->open(filename, sys->OREAD);
	if(fd == nil)
		raise sprint("spit:opening %s: %r", filename);
	data := readfile(fd);
	if(data == nil)
		raise sprint("spit:reading %s: %r", filename);

	templ := parseform(string data);
	s := applyform(form, templ, pairs, lists);
	return s;
}


Form.printl(form: self ref Form, name: string, pairs: list of (string, string), lists: list of (string, list of list of (string, string)))
{
	sys->print("%s", form.spitl(name, pairs, lists));
}


Form.print(form: self ref Form, name: string, pairs: list of (string, string))
{
	form.printl(name, pairs, nil);
}


Form.spit(form: self ref Form, name: string, pairs: list of (string, string)): string
{
	return form.spitl(name, pairs, nil);
}

Form.printv(f: self ref Form, name: string, vars: ref Vars)
{
	f.printl(name, vars.pairs, vars.lpairs);
}

Form.spitv(f: self ref Form, name: string, vars: ref Vars): string
{
	return f.spitl(name, vars.pairs, vars.lpairs);
}

Vars.add(v: self ref Vars, key, value: string)
{
	v.pairs = (key, value)::v.pairs;
}

Vars.addlist(v: self ref Vars, key: string, value: list of list of (string, string))
{
	v.lpairs = (key, value)::v.lpairs;
}

Vars.listadd(v: self ref Vars, key: string, value: list of (string, string))
{
	r: list of (string, list of list of (string, string));
	have := 0;
	for(l := v.lpairs; l != nil; l = tl l) {
		(k, lv) := hd l;
		if(k == key) {
			lv = rev(value::rev(lv));
			have = 1;
		}
		r = (k, lv)::r;
	}
	v.lpairs = r;
	if(!have)
		v.lpairs = (key, value::nil)::v.lpairs;
}

vars(): ref Vars
{
	return ref Vars(nil, nil);
}

rev[t](l: list of t): list of t
{
	r: list of t;
	for(; l != nil; l = tl l)
		r = hd l :: r;
	return r;
}

readfile(fd: ref Sys->FD): array of byte
{
	(ok, d) := sys->fstat(fd);
	if(ok != 0)
		raise sys->sprint("fstat-ing file (%d)", ok);
	a := array[int d.length] of byte;
	buf := array[8*1024] of byte;
	n := 0;
	for(;;) {
		have := sys->read(fd, buf, 8*1024);
		if(have == 0)
			break;
		if(have < 0)
			raise "reading from file";
		if(n+have > len a) {
			anew := array[n+have] of byte;
			anew[:] = a[:n];
			a = anew;
		}
		a[n:] = buf[:have];
		n += have;
	}
	return a;
}

nomod(m: string)
{
	sys->fprint(sys->fildes(2), "loading %s: %r\n", m);
	raise "fail:load";
}
