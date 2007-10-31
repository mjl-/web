implement Template;

#line	4	"template.y"
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
include "misc.m";

sprint: import sys;
misc: Misc;

YYSTYPE: adt {
	c: int;
	v, s: string;
};
YYLEX: adt {
	lval:	YYSTYPE;
	lex:	fn(l: self ref YYLEX): int;
	error:	fn(l: self ref YYLEX, msg: string);
};

AND: con	57346;
OR: con	57347;
INT: con	57348;
LITERAL: con	57349;
VAR: con	57350;
NOT: con	57351;
LE: con	57352;
GE: con	57353;
EQ: con	57354;
NE: con	57355;
SET: con	57356;
LENGTH: con	57357;
TRUE: con	57358;
FALSE: con	57359;
YYEOFCODE: con 1;
YYERRCODE: con 2;
YYMAXDEPTH: con 200;

#line	128	"template.y"


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
					warn("invalid command: "+misc->join(token::tokens, ", "));
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
	misc = load Misc Misc->PATH;
	if(cgi == nil)
		nomod(Cgi->PATH);
	if(misc == nil)
		nomod(Misc->PATH);
	cgi->init();
	misc->init();
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
yyexca := array[] of {-1, 1,
	1, -1,
	-2, 0,
};
YYNPROD: con 32;
YYPRIVATE: con 57344;
yytoknames: array of string;
yystates: array of string;
yydebug: con 0;
YYLAST:	con 77;
yyact := array[] of {
  11,  52,  24,  16,  17,  16,  17,   3,  22,  18,
   9,  18,  12,  13,   5,  38,  39,  21,  20,   6,
  20,   7,   8,  19,  10,  19,  33,  34,  31,  32,
  41,  15,  48,  49,  50,  51,  42,  43,  44,  45,
  46,  47,  16,  17,  27,  28,  29,  30,  18,  12,
  13,   2,  25,  26,  31,  32,   1,  20,  14,   4,
   0,   0,  19,   0,   0,  23,   0,   0,   0,   0,
   0,  37,   0,  40,   0,  35,  36,
};
yypact := array[] of {
   1,-1000,-1000,   8,   0,   1, -10,-1000,-1000,  30,
-1000,  22,-1000,-1000,-1000,-1000,  -1,  -1,-1000,   1,
   4,   1,   1,-1000,-1000,  38,  38,  38,  38,  38,
  38,  -1,  -1,  -1,  -1,-1000,-1000, -24,-1000,-1000,
-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,-1000,
  48,  48,-1000,
};
yypgo := array[] of {
   0,  56,  51,   7,  59,   0,  58,  31,  10,  24,
};
yyr1 := array[] of {
   0,   1,   2,   2,   3,   3,   4,   4,   4,   4,
   4,   4,   4,   4,   4,   4,   8,   8,   5,   5,
   5,   5,   5,   6,   6,   6,   7,   7,   7,   7,
   9,   9,
};
yyr2 := array[] of {
   0,   1,   1,   3,   1,   3,   2,   2,   1,   1,
   3,   3,   3,   3,   3,   3,   1,   1,   1,   3,
   3,   3,   3,   1,   2,   2,   1,   3,   2,   2,
   1,   1,
};
yychk := array[] of {
-1000,  -1,  -2,  -3,  -4,  13,  18,  20,  21,  -8,
  -9,  -5,  11,  12,  -6,  -7,   4,   5,  10,  24,
  19,   9,   8,  -4,  12,  22,  23,  14,  15,  16,
  17,   6,   7,   4,   5,  -6,  -6,  -2,  11,  12,
  -2,  -3,  -8,  -8,  -8,  -8,  -8,  -8,  -5,  -5,
  -5,  -5,  25,
};
yydef := array[] of {
   0,  -2,   1,   2,   4,   0,   0,   8,   9,   0,
  16,  17,  30,  31,  18,  23,   0,   0,  26,   0,
   0,   0,   0,   6,   7,   0,   0,   0,   0,   0,
   0,   0,   0,   0,   0,  24,  25,   0,  28,  29,
   3,   5,  10,  11,  12,  13,  14,  15,  19,  20,
  21,  22,  27,
};
yytok1 := array[] of {
   1,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
  24,  25,   6,   4,   3,   5,   3,   7,   3,   3,
   3,   3,   3,   3,   3,   3,   3,   3,   3,   3,
  22,   3,  23,
};
yytok2 := array[] of {
   2,   3,   8,   9,  10,  11,  12,  13,  14,  15,
  16,  17,  18,  19,  20,  21,
};
yytok3 := array[] of {
   0
};

YYSys: module
{
	FD: adt
	{
		fd:	int;
	};
	fildes:		fn(fd: int): ref FD;
	fprint:		fn(fd: ref FD, s: string, *): int;
};

yysys: YYSys;
yystderr: ref YYSys->FD;

YYFLAG: con -1000;

# parser for yacc output

yytokname(yyc: int): string
{
	if(yyc > 0 && yyc <= len yytoknames && yytoknames[yyc-1] != nil)
		return yytoknames[yyc-1];
	return "<"+string yyc+">";
}

yystatname(yys: int): string
{
	if(yys >= 0 && yys < len yystates && yystates[yys] != nil)
		return yystates[yys];
	return "<"+string yys+">\n";
}

yylex1(yylex: ref YYLEX): int
{
	c : int;
	yychar := yylex.lex();
	if(yychar <= 0)
		c = yytok1[0];
	else if(yychar < len yytok1)
		c = yytok1[yychar];
	else if(yychar >= YYPRIVATE && yychar < YYPRIVATE+len yytok2)
		c = yytok2[yychar-YYPRIVATE];
	else{
		n := len yytok3;
		c = 0;
		for(i := 0; i < n; i+=2) {
			if(yytok3[i+0] == yychar) {
				c = yytok3[i+1];
				break;
			}
		}
		if(c == 0)
			c = yytok2[1];	# unknown char
	}
	if(yydebug >= 3)
		yysys->fprint(yystderr, "lex %.4ux %s\n", yychar, yytokname(c));
	return c;
}

YYS: adt
{
	yyv: YYSTYPE;
	yys: int;
};

yyparse(yylex: ref YYLEX): int
{
	if(yydebug >= 1 && yysys == nil) {
		yysys = load YYSys "$Sys";
		yystderr = yysys->fildes(2);
	}

	yys := array[YYMAXDEPTH] of YYS;

	yyval: YYSTYPE;
	yystate := 0;
	yychar := -1;
	yynerrs := 0;		# number of errors
	yyerrflag := 0;		# error recovery flag
	yyp := -1;
	yyn := 0;

yystack:
	for(;;){
		# put a state and value onto the stack
		if(yydebug >= 4)
			yysys->fprint(yystderr, "char %s in %s", yytokname(yychar), yystatname(yystate));

		yyp++;
		if(yyp >= len yys)
			yys = (array[len yys * 2] of YYS)[0:] = yys;
		yys[yyp].yys = yystate;
		yys[yyp].yyv = yyval;

		for(;;){
			yyn = yypact[yystate];
			if(yyn > YYFLAG) {	# simple state
				if(yychar < 0)
					yychar = yylex1(yylex);
				yyn += yychar;
				if(yyn >= 0 && yyn < YYLAST) {
					yyn = yyact[yyn];
					if(yychk[yyn] == yychar) { # valid shift
						yychar = -1;
						yyp++;
						if(yyp >= len yys)
							yys = (array[len yys * 2] of YYS)[0:] = yys;
						yystate = yyn;
						yys[yyp].yys = yystate;
						yys[yyp].yyv = yylex.lval;
						if(yyerrflag > 0)
							yyerrflag--;
						if(yydebug >= 4)
							yysys->fprint(yystderr, "char %s in %s", yytokname(yychar), yystatname(yystate));
						continue;
					}
				}
			}
		
			# default state action
			yyn = yydef[yystate];
			if(yyn == -2) {
				if(yychar < 0)
					yychar = yylex1(yylex);
		
				# look through exception table
				for(yyxi:=0;; yyxi+=2)
					if(yyexca[yyxi] == -1 && yyexca[yyxi+1] == yystate)
						break;
				for(yyxi += 2;; yyxi += 2) {
					yyn = yyexca[yyxi];
					if(yyn < 0 || yyn == yychar)
						break;
				}
				yyn = yyexca[yyxi+1];
				if(yyn < 0){
					yyn = 0;
					break yystack;
				}
			}

			if(yyn != 0)
				break;

			# error ... attempt to resume parsing
			if(yyerrflag == 0) { # brand new error
				yylex.error("syntax error");
				yynerrs++;
				if(yydebug >= 1) {
					yysys->fprint(yystderr, "%s", yystatname(yystate));
					yysys->fprint(yystderr, "saw %s\n", yytokname(yychar));
				}
			}

			if(yyerrflag != 3) { # incompletely recovered error ... try again
				yyerrflag = 3;
	
				# find a state where "error" is a legal shift action
				while(yyp >= 0) {
					yyn = yypact[yys[yyp].yys] + YYERRCODE;
					if(yyn >= 0 && yyn < YYLAST) {
						yystate = yyact[yyn];  # simulate a shift of "error"
						if(yychk[yystate] == YYERRCODE)
							continue yystack;
					}
	
					# the current yyp has no shift onn "error", pop stack
					if(yydebug >= 2)
						yysys->fprint(yystderr, "error recovery pops state %d, uncovers %d\n",
							yys[yyp].yys, yys[yyp-1].yys );
					yyp--;
				}
				# there is no state on the stack with an error shift ... abort
				yyn = 1;
				break yystack;
			}

			# no shift yet; clobber input char
			if(yydebug >= 2)
				yysys->fprint(yystderr, "error recovery discards %s\n", yytokname(yychar));
			if(yychar == YYEOFCODE) {
				yyn = 1;
				break yystack;
			}
			yychar = -1;
			# try again in the same state
		}
	
		# reduction by production yyn
		if(yydebug >= 2)
			yysys->fprint(yystderr, "reduce %d in:\n\t%s", yyn, yystatname(yystate));
	
		yypt := yyp;
		yyp -= yyr2[yyn];
#		yyval = yys[yyp+1].yyv;
		yym := yyn;
	
		# consult goto table to find next state
		yyn = yyr1[yyn];
		yyg := yypgo[yyn];
		yyj := yyg + yys[yyp].yys + 1;
	
		if(yyj >= YYLAST || yychk[yystate=yyact[yyj]] != -yyn)
			yystate = yyact[yyg];
		case yym {
			
1=>
#line	55	"template.y"
{ return yys[yypt-0].yyv.c; }
2=>
yyval.c = yys[yyp+1].yyv.c;
3=>
#line	59	"template.y"
{ yyval.c = yys[yypt-2].yyv.c || yys[yypt-0].yyv.c; }
4=>
yyval.c = yys[yyp+1].yyv.c;
5=>
#line	63	"template.y"
{ yyval.c = yys[yypt-2].yyv.c && yys[yypt-0].yyv.c; }
6=>
#line	67	"template.y"
{ yyval.c = ! yys[yypt-0].yyv.c; }
7=>
#line	69	"template.y"
{
		(have, nil, nil, nil) := findvar(yys[yypt-0].yyv.v, parsepairs, parselpairs, parseforeach);
		yyval.c = have;
	}
8=>
#line	73	"template.y"
{ yyval.c = 1; }
9=>
#line	74	"template.y"
{ yyval.c = 0; }
10=>
#line	75	"template.y"
{ yyval.c = yys[yypt-2].yyv.s < yys[yypt-0].yyv.s; }
11=>
#line	76	"template.y"
{ yyval.c = yys[yypt-2].yyv.s > yys[yypt-0].yyv.s; }
12=>
#line	77	"template.y"
{ yyval.c = yys[yypt-2].yyv.s <= yys[yypt-0].yyv.s; }
13=>
#line	78	"template.y"
{ yyval.c = yys[yypt-2].yyv.s >= yys[yypt-0].yyv.s; }
14=>
#line	79	"template.y"
{ yyval.c = yys[yypt-2].yyv.s == yys[yypt-0].yyv.s; }
15=>
#line	80	"template.y"
{ yyval.c = yys[yypt-2].yyv.s != yys[yypt-0].yyv.s; }
16=>
#line	84	"template.y"
{ yyval.s = yys[yypt-0].yyv.s; }
17=>
#line	85	"template.y"
{ yyval.s = string yys[yypt-0].yyv.c; }
18=>
yyval.c = yys[yyp+1].yyv.c;
19=>
#line	89	"template.y"
{ yyval.c = yys[yypt-2].yyv.c * yys[yypt-0].yyv.c; }
20=>
#line	90	"template.y"
{ yyval.c = yys[yypt-2].yyv.c / yys[yypt-0].yyv.c; }
21=>
#line	91	"template.y"
{ yyval.c = yys[yypt-2].yyv.c + yys[yypt-0].yyv.c; }
22=>
#line	92	"template.y"
{ yyval.c = yys[yypt-2].yyv.c - yys[yypt-0].yyv.c; }
23=>
yyval.c = yys[yyp+1].yyv.c;
24=>
#line	96	"template.y"
{ yyval.c = yys[yypt-0].yyv.c; }
25=>
#line	97	"template.y"
{ yyval.c = - yys[yypt-0].yyv.c; }
26=>
yyval.c = yys[yyp+1].yyv.c;
27=>
#line	101	"template.y"
{ yyval.c = yys[yypt-1].yyv.c; }
28=>
#line	102	"template.y"
{ yyval.c = len yys[yypt-0].yyv.s; }
29=>
#line	104	"template.y"
{
		(have, t) := find(yys[yypt-0].yyv.v, parselists);
		if(have) {
			yyval.c = len t;
		} else {
			(nil, nil, nil, value) := findvar(yys[yypt-0].yyv.v, parsepairs, parselpairs, parseforeach);
			# xxx print warning if variable is missing
			yyval.c = len value;
		}
	}
30=>
#line	117	"template.y"
{ yyval.s = yys[yypt-0].yyv.s; }
31=>
#line	119	"template.y"
{
		(have, nil, nil, value) := findvar(yys[yypt-0].yyv.v, parsepairs, parselpairs, parseforeach);
		# xxx print warning if variable is missing
if(!have)
	sys->fprint(sys->fildes(2), "missing var %q\n", yys[yypt-0].yyv.v);
		yyval.s = value;
	}
		}
	}

	return yyn;
}
