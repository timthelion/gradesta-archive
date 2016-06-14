/*
This is the single file source code for the ovach binary, parser, well, everything.

This compiles to a binary, which can be used to either run an interactive ovach repl, or to execute ovach script files or to execute ovachograph script files.

--
_ > b GTK WidgetType ; b GTK Widget > h Widget, _ > h Widget LabelText, _ > h Widget OnPressed, h Widget > h WidgetStack Widgets
--
# Widget type, label text   , on pressed
  "Label"    , "Hello World",
  "Button"   , "OK"         , b App Close
--

Some of this stuff is stolen from https://github.com/golang-samples/yacc/blob/master/simple/calc.y Thanks!

*/
%{

package main

import (
	"bufio"
	"bytes"
	"fmt"
	"io"
	"log"
	"os"
	"unicode/utf8"
        "strconv"
)

const (
       TYPE_EMPTY = iota
       TYPE_BOOL
       TYPE_INT32
       TYPE_INT64
       TYPE_STRING
       TYPE_BYTES
       TYPE_FLOAT
       TYPE_TIMESTAMP
       TYPE_APPLIANCE
       TYPE_SLOT
)

var (
       NULL = Value{}
)

type Value struct{
  value_type int32
  value_int32 int32
}

%}

// fields inside this union end up as the fields in a structure known
// as ${PREFIX}SymType, of which a reference is passed to the lexer.
%union{
  val Value
  values []Value
}

%start line
%type  <val> keyword_arguments symbols symbol literal slot_identifier expr
%type  <values> table_body_columns
%token <val> STATEMENT TABLE_HEADING TABLE_BODY LOWERCASE UPPERCASE STRING NUMBER BUILT_IN_COMMAND HOLE
%left ','
%left '.'
%left TO
%left AND OR
%left GT LT LTEQ GTEQ EQ NEQ
%left '+' '-'
%left '/'
%left '*'
%left UMINUS
%% /* Rules section */
line
    : TABLE_HEADING sentences ',' table_heading_columns ',' sentences
    | TABLE_BODY table_body_columns
    | STATEMENT sentences
    ;
table_heading_columns
    : potentially_holy_sentences
    | table_heading_columns ',' potentially_holy_sentences
    ;
potentially_holy_sentences
    : sentence
    | holy_sentence
    | potentially_holy_sentences '.' holy_sentence
    | potentially_holy_sentences '.' sentence
    ;
table_body_columns
    : expr
    {
      $$ = []Value{}
    }
    | table_body_columns ',' expr
    {
      $$ = []Value{}
    }
    ;
sentences
    : sentence
    | sentences '.'
    | sentences '.' sentence
    ;
sentence
    : BUILT_IN_COMMAND keyword_arguments
    | expr
    {
      fmt.Println("%v",$1.value_int32)
    }
    | expr TO slot_identifier
    ;
holy_sentence
    : '_' TO slot_identifier
    ;
keyword_arguments
    :
    {
      $$ = NULL
    }
    | keyword_arguments symbol
    {
      $$ = NULL
    }
    ;
symbols
    :
    {
      $$ = NULL
    }
    | symbols symbol
    {
      $$ = NULL
    }
    ;
symbol
    : UPPERCASE
    | LOWERCASE
    | literal
    ;
literal
    : STRING
    | NUMBER
    ;
slot_identifier
    : symbols
    ;
expr
    : '(' expr ')'
    {
      $$ = NULL
    }
    | expr GT expr
    {
      $$ = NULL
    }
    | expr LT expr
    {
      $$ = NULL
    }
    | expr LTEQ expr
    {
      $$ = NULL
    }
    | expr GTEQ expr
    {
      $$ = NULL
    }
    | expr EQ expr
    {
      $$ = NULL
    }
    | expr NEQ expr
    {
      $$ = NULL
    }
    | expr '+' expr
    {
      if($1.value_type == TYPE_INT32 && $1.value_type == TYPE_INT32) {
        $1.value_int32 = $1.value_int32 + $3.value_int32
      }
      $$ = $1
    }
    | expr '-' expr
    {
      if($1.value_type == TYPE_INT32 && $1.value_type == TYPE_INT32) {
        $1.value_int32 = $1.value_int32 - $3.value_int32
      }
      $$ = $1
    }
    | expr '/' expr
    {
      if($1.value_type == TYPE_INT32 && $1.value_type == TYPE_INT32) {
        $1.value_int32 = $1.value_int32 / $3.value_int32
      }
      $$ = $1
    }
    | expr '*' expr
    {
      if($1.value_type == TYPE_INT32 && $1.value_type == TYPE_INT32) {
        $1.value_int32 = $1.value_int32 * $3.value_int32
      }
      $$ = $1
    }
    | '-' expr %prec UMINUS
    {
      if($2.value_type == TYPE_INT32) {
        $2.value_int32 = -($2.value_int32)
      }
      $$ = $2
    }
    | slot_identifier
    | literal
    ;

%% /* Program section */

// The parser expects the lexer to return 0 on EOF.  Give it a name
// for clarity.
const eof = 0

// The parser uses the type <prefix>Lex as a lexer.  It must provide
// the methods Lex(*<prefix>SymType) int and Error(string).
type OvachLex struct {
	line []byte
	peek rune
}

const(
      STATEMENT_MODE = iota
      TABLE_HEADING_MODE
      TABLE_BODY_MODE
      CONT
)

var(
    parse_mode int = STATEMENT_MODE
)

func (x *OvachLex) Lex(yylval *OvachSymType) int {
	for {
	        if parse_mode == STATEMENT_MODE {
		    parse_mode = CONT
		    return STATEMENT
		}
		c := x.next()
		switch c {
		case eof:
		        parse_mode = STATEMENT_MODE
			return eof
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			return x.num(c, yylval)
		case '+', '-', '*', '/', '(', ')':
			return int(c)

		// Recognize Unicode multiplication and division
		// symbols, returning what the parser expects.
		case '×':
			return '*'
		case '÷':
			return '/'

		case ' ', '\t', '\n', '\r':
		default:
			log.Printf("unrecognized character %q", c)
		}
	}
}

// Lex a number.
func (x *OvachLex) num(c rune, yylval *OvachSymType) int {
	add := func(b *bytes.Buffer, c rune) {
		if _, err := b.WriteRune(c); err != nil {
			log.Fatalf("WriteRune: %s", err)
		}
	}
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		switch c {
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', 'e', 'E':
			add(&b, c)
		default:
			break L
		}
	}
	if c != eof {
		x.peek = c
	}
	integer, err := strconv.ParseInt(b.String(),10,32)
	if err != nil {
		log.Printf("bad number %q", b.String())
		return eof
	}
	yylval.val.value_type = TYPE_INT32
	yylval.val.value_int32 = int32(integer)
	return NUMBER
}

// Return the next rune for the lexer.
func (x *OvachLex) next() rune {
	if x.peek != eof {
		r := x.peek
		x.peek = eof
		return r
	}
	if len(x.line) == 0 {
		return eof
	}
	c, size := utf8.DecodeRune(x.line)
	x.line = x.line[size:]
	if c == utf8.RuneError && size == 1 {
		log.Print("invalid utf8")
		return x.next()
	}
	return c
}

// The parser calls this method on a parse error.
func (x *OvachLex) Error(s string) {
	log.Printf("parse error: %s", s)
}

func main() {
	in := bufio.NewReader(os.Stdin)
	for {
		if _, err := os.Stdout.WriteString("> "); err != nil {
			log.Fatalf("WriteString: %s", err)
		}
		line, err := in.ReadBytes('\n')
		if err == io.EOF {
			return
		}
		if err != nil {
			log.Fatalf("ReadBytes: %s", err)
		}

		OvachParse(&OvachLex{line: line})
	}
}
