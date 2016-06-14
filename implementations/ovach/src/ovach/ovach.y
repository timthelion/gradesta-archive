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
And from https://golang.org/src/cmd/yacc/testdata/expr/expr.y?m=text

*/
%{

package main

import (
	"bytes"
	"fmt"
	"io"
	"log"
	"unicode/utf8"
	"unicode"
        "strconv"
	"gopkg.in/readline.v1"
	"os"
	"strings"
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
  value_bool bool
}

type TableFormat struct {
  head Statement
  columns []Hole
  foot Statement
}

var (
     table_format TableFormat
)

type Expr func() (ret Value)
type Hole func(fill Expr) ()
type Statement func()
%}

// fields inside this union end up as the fields in a structure known
// as ${PREFIX}SymType, of which a reference is passed to the lexer.
%union{
  statement Statement
  exprs []Expr
  expr Expr
  hole Hole
  holes []Hole
  val Value
  symbol string
  symbols []string
}

%start line
%type  <val> literal
%token <val> STRING NUMBER BOOL
%type  <symbol> symbol
%token <symbol> BUILT_IN_COMMAND LOWERCASE UPPERCASE
%type  <symbols> keyword_arguments symbols slot_identifier
%type  <expr> expr
%type  <exprs> table_body_columns
%type  <statement> sentences sentence
%type  <hole> holy_sentence table_heading_column
%type  <holes> table_heading_columns
%token STATEMENT_MARKER TABLE_HEADING_MARKER TABLE_BODY_MARKER TABLE_MODE_TRANSITION
%left ','
%left '.'
%left TO
%left AND OR
%left '>' '<' LTEQ GTEQ EQ NEQ
%left '+' '-'
%left '/'
%left '*'
%left UMINUS
%% /* Rules section */
line
    : TABLE_HEADING_MARKER sentences ',' table_heading_columns ',' sentences
    {
      table_format = TableFormat{
	head: $2,
	columns: $4,
	foot: $6,
      }
      fmt.Println("TABLE_HEADING")
    }
    | TABLE_BODY_MARKER table_body_columns
    {
      table_format.head()
      for i :=0 ; i < len($2); i++ {
	if $2[i] != nil {
	  table_format.columns[i]($2[i])
	}
      }
      table_format.foot()
      fmt.Println("TABLE_BODY")
    }
    | STATEMENT_MARKER sentences
    {
      $2()
      fmt.Println("STATEMENT")
    }
    | TABLE_HEADING_MARKER TABLE_MODE_TRANSITION
    | TABLE_BODY_MARKER TABLE_MODE_TRANSITION
    | STATEMENT_MARKER TABLE_MODE_TRANSITION
    | TABLE_MODE_TRANSITION
    ;
table_heading_columns
    : table_heading_column
    {
      $$ = []Hole{$1}
    }
    | table_heading_columns ',' table_heading_column
    {
      $$ = append($1,$3)
    }
    ;
table_heading_column
    : holy_sentence
    | sentences '.' holy_sentence '.' sentences
    {
      $$ = func(expr Expr){
	$1()
	$3(expr)
	$5()
      }
    }
    | holy_sentence '.' sentences
    {
      $$ = func(expr Expr){
	$1(expr)
	$3()
      }
    }
    | sentences '.' holy_sentence
    {
      $$ = func(expr Expr){
	$1()
	$3(expr)
      }
    }
table_body_columns
    :
    {
      $$ = nil
    }
    | expr
    {
      $$ = []Expr{$1}
    }
    | table_body_columns ',' expr
    {
      $$ = append($1,$3)
    }
    ;
sentences
    : sentence
    {
      $$ = $1
    }
    | sentences '.'
    {
      $$ = $1
    }
    | sentences '.' sentence
    {
      $$ = func(){
	$1()
	$3()
      }
    }
    ;
sentence
    : BUILT_IN_COMMAND keyword_arguments
    {
      $$ = func(){
        if $1 == "exit"{
          fmt.Println("Bye...")
	  os.Exit(0)
	}
      }
    }
    | expr
    {
      $$ = func(){
        fmt.Println("",$1())
      }
    }
    | expr TO slot_identifier
    {
      expr, si := $1, $3
      $$ = func(){
	fmt.Println("",expr(),si)
      }
    }
    ;
holy_sentence
    : '_' TO slot_identifier
    {
      si := $3
      $$ = func(expr Expr){
	fmt.Println("",expr(),si)
      }
    }
    ;
keyword_arguments
    :
    {
      $$ = []string{}
    }
    | keyword_arguments symbol
    {
      $$ = append($1,$2)
    }
    ;
symbols
    :
    {
      $$ = []string{}
    }
    | symbols symbol
    {
      $$ = append($1,$2)
    }
    ;
symbol
    : UPPERCASE
    | LOWERCASE
    ;
literal
    : STRING
    | NUMBER
    | BOOL
    ;
slot_identifier
    : symbols
    ;
expr
    : '(' expr ')'
    {
      $$ = $2
    }
    | expr AND expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_BOOL && val2.value_type == TYPE_BOOL) {
           val1.value_bool = val1.value_bool && val2.value_bool
        }
	return val1
      }
    }
    | expr OR expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_BOOL && val2.value_type == TYPE_BOOL) {
           val1.value_bool = val1.value_bool || val2.value_bool
        }
	return val1
      }
    }
    | expr '>' expr
    {
      expr1, expr2 := $1, $3
      $$ = func()  (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 > val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr '<' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 > val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr LTEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 < val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr GTEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 >= val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr EQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 == val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr NEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_bool = val1.value_int32 != val2.value_int32
           val1.value_type = TYPE_BOOL
        }
	return val1
      }
    }
    | expr '+' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_int32 = val1.value_int32 + val2.value_int32
        }
	return val1
      }
    }
    | expr '-' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_int32 = val1.value_int32 - val2.value_int32
        }
	return val1
      }
    }
    | expr '/' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_int32 = val1.value_int32 / val2.value_int32
        }
	return val1
      }
    }
    | expr '*' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
	val1, val2 := expr1(), expr2()
        if(val1.value_type == TYPE_INT32 && val2.value_type == TYPE_INT32) {
           val1.value_int32 = val1.value_int32 * val2.value_int32
        }
	return val1
      }
    }
    | '-' expr %prec UMINUS
    {
      expr1 := $2
      $$ = func() (value Value){
	val1 := expr1()
        if val1.value_type == TYPE_INT32 {
           val1.value_int32 = -val1.value_int32
        }
	return val1
      }
    }
    | slot_identifier
    {
      $$ = func() (value Value){
	return Value{}
      }
    }
    | literal
    {
      val := $1
      $$ = func() (value Value){
	return val
      }
    }
    ;

%% /* Program section */

// The parser expects the lexer to return 0 on EOF.  Give it a name
// for clarity.
const eof = 0

// The parser uses the type <prefix>Lex as a lexer.  It must provide
// the methods Lex(*<prefix>SymType) int and Error(string).
type OvachLex struct {
	line string
	peek rune
}

const(
      STATEMENT_MODE = iota
      TABLE_HEADING_MODE
      TABLE_BODY_MODE
)

var(
    parse_mode int = STATEMENT_MODE
    within_line bool = false
)

func (x *OvachLex) Lex(yylval *OvachSymType) int {
	for {
	        if !within_line{
		  within_line = true
                  switch parse_mode{
                     case STATEMENT_MODE:
		        return STATEMENT_MARKER
		     case TABLE_HEADING_MODE:
		        return TABLE_HEADING_MARKER
		     case TABLE_BODY_MODE:
		        return TABLE_BODY_MARKER
		  }
		}
		c := x.next()
		switch c {
		case eof:
		        within_line = false
			return eof
		case '#':
			return eof
		case '(',')':
		        return int(c)
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			return x.num(c, yylval)
		case '\n':
		  within_line = false
		case ' ', '\t', '\r':
		default:
		        if unicode.IsLower(c) {
			    return x.lowercase(c, yylval)
			} else if unicode.IsSymbol(c) || unicode.IsPunct(c) {
			    return x.operator(c, yylval)
			} else {
			  log.Printf("unrecognized character %q", c)
			}
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

func (x *OvachLex) lowercase(c rune, yylval *OvachSymType) int {
	add := func(b *bytes.Buffer, c rune) {
		if _, err := b.WriteRune(c); err != nil {
			log.Fatalf("WriteRune: %s", err)
		}
	}
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		if unicode.IsLower(c) || unicode.IsUpper(c){
			add(&b, c)
		} else {
			break L
		}
	}
	if c != eof {
		x.peek = c
	}
	s := b.String()
	switch s {
	  case "true":
	    yylval.val.value_type = TYPE_BOOL
	    yylval.val.value_bool = true
	    return BOOL
	  case "false":
	    yylval.val.value_type = TYPE_BOOL
	    yylval.val.value_bool = false
	    return BOOL
	  case "exit":
            yylval.symbol = "exit"
	    return BUILT_IN_COMMAND
	  case "to":
	    return TO
	  default:
            yylval.symbol = s
	    return LOWERCASE
	}
}

func (x *OvachLex) operator(c rune, yylval *OvachSymType) int {
	add := func(b *bytes.Buffer, c rune) {
		if _, err := b.WriteRune(c); err != nil {
			log.Fatalf("WriteRune: %s", err)
		}
	}
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		if c != '(' && unicode.IsSymbol(c) || unicode.IsPunct(c) {
			add(&b, c)
		} else {
			break L
		}
	}
	if c != eof {
		x.peek = c
	}
	s := b.String()
	switch s {
	  case "&&":
	    return AND
	  case "||":
	    return OR
	  case "==":
	    return EQ
	  case "!=":
	    return NEQ
	  case ">=":
	    return GTEQ
	  case "<=":
	    return LTEQ
	  case ">", "<", "+", "-", "*", "/", "(", ")", ",", "_":
	    return int(s[0])
          // Recognize Unicode multiplication and division
          // symbols, returning what the parser expects.
	  case "×":
	    return '*'
	  case "÷":
	    return '/'

	  default:
	    if strings.HasPrefix(s,"---"){
		switch parse_mode{
		  case TABLE_HEADING_MODE: parse_mode = TABLE_BODY_MODE
		  case TABLE_BODY_MODE:    parse_mode = STATEMENT_MODE
		  case STATEMENT_MODE:     parse_mode = TABLE_HEADING_MODE
		}
		return TABLE_MODE_TRANSITION
	    } else {
	      log.Printf("unrecognized operator %s", s)
	    }
	}
	return 0
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
	c, size := utf8.DecodeRuneInString(x.line)
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
        rl, err := readline.New("> ")
        if err != nil {
          panic(err)
        }
        defer rl.Close()
	for {
	        switch parse_mode{
		    case TABLE_HEADING_MODE:
		      rl.SetPrompt("||")
		    case TABLE_BODY_MODE:
		      rl.SetPrompt("| ")
		    case STATEMENT_MODE:
		      rl.SetPrompt("> ")
		}
                line, err := rl.Readline()
                if err != nil { // io.EOF, readline.ErrInterrupt
                  break
                }
		if err == io.EOF {
			return
		}
		OvachParse(&OvachLex{line: line})
	}
}
