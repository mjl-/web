REQUEST_METHOD=GET
QUERY_STRING='a=b&c=d&e=f'
#QUERY_STRING=bad^`{zeros 1 1}^lala'=b'  # has nul in it

load std expr
cgiargs=${split `{zeros 1 1} "{cgiparse}}
# note: cgiparse errors are not propagated...

# find a variable.  first is var name, second is optional default.
# environment var $cgivars is used as a list of key value pairs.
# if no default and variable not present, an error is set.
subfn cgifind {
	var=$1
	result=''
	if {~ $#* 2} {
		result=$2
		error=0
	} {
		error=1
	}
	vars=$cgiargs
	while {~ 1 ${expr $#vars 2 '>='}} {
		if {~ ${hd $vars} $var} {
			result=${hd ${tl $vars}}
			error=0
			vars=()
		} {
			vars=${tl ${tl $vars}}
		}
	}
	if{~ $error 1} { raise 'no such variable' }
}

a=${cgifind a ''}  # a is present, should yield "b"
b=${cgifind x 'nox'}  # x not present, should yield "nox"
c=${cgifind y ''}  # y not present, should yield ""
d=${cgifind bogus}  # bogus not present, and no default, should yield error
