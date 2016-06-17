/*
This is the single file source code for the ovach binary, parser, well, everything.

This compiles to a binary, which can be used to either run an interactive ovach repl, or to execute graphovach script files.

--
_ to b GTK WidgetType. b GTK Widget to h Widget, _ to h Widget LabelText, _ to h Widget OnPressed, h Widget to h WidgetStack Widgets
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
	"reflect"
)
/*
  Types
*/
type Value struct{
  empty bool
  v ValueContents
}
type ValueContents interface{
  Eq(ValueContents) ValueContents
  Neq(ValueContents) ValueContents
  And(ValueContents) ValueContents
  Or(ValueContents) ValueContents
  Gt(ValueContents) ValueContents
  Lt(ValueContents) ValueContents
  Lte(ValueContents) ValueContents
  Gte(ValueContents) ValueContents
  Add(ValueContents) ValueContents
  Subtract(ValueContents) ValueContents
  Multiply(ValueContents) ValueContents
  Divide(ValueContents) ValueContents
  Negate() ValueContents
}
//Value Types
type BoolValue        bool
type Int64Value       int64
type UInt64Value      uint64
type Float64Value     float64
type TextValue        string
type DataValue        []byte
//type SlotValue        Slot
//type ApplianceValue   Appliance

type SlotListing struct{
  slot_identifier SlotIdentifier
  value_type int32
}
type SlotListings []SlotListing
type Expr func() (ret Value)
type Hole func(fill Expr) ()
type Statement func()
type SlotIdentifier []string
type MapovachValue struct{
  mapovach Mapovach
  slot Value
}
type Mapovach map[string]MapovachValue
type Provider interface{
  Ls(appliance SlotIdentifier) (SlotListing, bool)
  Set(slot SlotIdentifier, value Value) Value
  Get(slot SlotIdentifier) (Value, bool)
  Delete(slot SlotIdentifier) bool
}
type TableFormat struct {
  head Statement
  columns []Hole
  foot Statement
}

/*
  Globals
*/
var (
     table_format TableFormat
     localProvider int
     currentProvider int
     providers []Provider
)
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
      s1, s2, s3 := $1, $3, $5
      $$ = func(expr Expr){
	s1()
	s2(expr)
	s3()
      }
    }
    | holy_sentence '.' sentences
    {
      s1, s2 := $1, $3
      $$ = func(expr Expr){
	s1(expr)
	s2()
      }
    }
    | sentences '.' holy_sentence
    {
      s1, s2 := $1, $3
      $$ = func(expr Expr){
	s1()
	s2(expr)
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
      s1, s2 := $1, $3
      $$ = func(){
	s1()
	s2()
      }
    }
    ;
sentence
    : BUILT_IN_COMMAND keyword_arguments
    {
      command, _ /*args*/ := $1, $2
      $$ = func(){
        switch command{
	  case "exit":
            fmt.Println("Bye...")
	    os.Exit(0)
	  /*case "ls":
	    if len(args) > 0{
	      root := args[0]
	      if root == "h" || root == "b" {
                localProvider.Ls(args)
              } else {
                currentProvider.Ls(args)
              }
	    }
*/
	}
      }
    }
    | expr
    {
      expr := $1
      $$ = func(){
        fmt.Println("",expr())
      }
    }
    | expr TO slot_identifier
    {
      //expr, si := $1, $3
      $$ = func(){
	//set_slot(expr(),si)
      }
    }
    ;
holy_sentence
    : '_' TO slot_identifier
    {
      //si := $3
      $$ = func(expr Expr){
	//set_slot(expr(),si)
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
    | expr EQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
        if reflect.TypeOf(val1.v) == reflect.TypeOf(val2.v){
          return Value{empty:false,v: val1.v.Eq(val2.v)}
        } else {
          log.Printf("Type error, types do not match.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
/*    | expr NEQ expr
    {

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
      si := $1
      $$ = func() (value Value){
	if si[0] == "h"{
	    val, ok := hand[si[1]]
	    if ok{
	      return val
	    }
	}
	return Value{}
      }
    }*/
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
        float := false
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		switch c {
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '.', 'e', 'E':
			add(&b, c)
		        if c == '.'{
		          float = true
			}
		default:
			break L
		}
	}
	if c != eof {
		x.peek = c
	}

	if !float {
	  n, err := strconv.ParseInt(b.String(),10,64)
	  if err != nil {
		log.Printf("bad number %q", b.String())
		return eof
	  }
	  yylval.val = Value{empty:false,v:Int64Value(n)}
	} else {
	  n, err := strconv.ParseFloat(b.String(),64)
	  if err != nil {
		log.Printf("bad number %q", b.String())
		return eof
	  }
	  yylval.val = Value{empty:false,v:Float64Value(n)}
	}
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
	    yylval.val = Value{empty:false,v:BoolValue(true)}
	    return BOOL
	  case "false":
	    yylval.val = Value{empty:false,v:BoolValue(false)}
	    return BOOL
	  case "exit", "ls", "cd":
            yylval.symbol = s
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
	  case ">", "<", "+", "-", "*", "/", "(", ")", ",", "_", ".":
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
	/*
	  Init runtime
	 */
	//hand = make(map[string]Value)
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

/*
  Type interfaces
*/
// Helpers
func testEqSlice(a, b []byte) bool {
    // http://stackoverflow.com/questions/15311969/checking-the-equality-of-two-slices
    if a == nil && b == nil {
        return true;
    }

    if a == nil || b == nil {
        return false;
    }

    if len(a) != len(b) {
        return false
    }

    for i := range a {
        if a[i] != b[i] {
            return false
        }
    }

    return true
}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Eq(b2 ValueContents) (result ValueContents){
 switch v := b2.(type){case BoolValue:return BoolValue(b1 == v)}
 return BoolValue(false)}
func (b1 Int64Value) Eq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 == v)}
  return BoolValue(false)}
func (b1 UInt64Value) Eq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 == v)}
  return BoolValue(false)}
func (b1 Float64Value) Eq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 == v)}
  return BoolValue(false)}
func (b1 TextValue) Eq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 == v)}
  return BoolValue(false)}
func (b1 DataValue) Eq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case DataValue: return BoolValue(testEqSlice(b1,v))}
  return BoolValue(false)}
//type SlotValue        Slot
//type ApplianceValue   Appliance
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Neq(b2 ValueContents) (result ValueContents){
 switch v := b2.(type){case BoolValue:return BoolValue(b1 != v)}
 return BoolValue(false)}
func (b1 Int64Value) Neq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 != v)}
  return BoolValue(false)}
func (b1 UInt64Value) Neq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 != v)}
  return BoolValue(false)}
func (b1 Float64Value) Neq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 != v)}
  return BoolValue(false)}
func (b1 TextValue) Neq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 != v)}
  return BoolValue(false)}
func (b1 DataValue) Neq(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case DataValue: return BoolValue(!testEqSlice(b1,v))}
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) And(b2 ValueContents) (result ValueContents){
 switch v := b2.(type){case BoolValue:return BoolValue(b1 && v)}
 return BoolValue(false)}
func (b1 Int64Value) And(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 UInt64Value) And(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 Float64Value) And(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 TextValue) And(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 DataValue) And(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Or(b2 ValueContents) (result ValueContents){
 switch v := b2.(type){case BoolValue:return BoolValue(b1 || v)}
 return BoolValue(false)}
func (b1 Int64Value) Or(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 UInt64Value) Or(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 Float64Value) Or(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 TextValue) Or(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
func (b1 DataValue) Or(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Gt(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Gt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 > v)}
  return BoolValue(false)}
func (b1 UInt64Value) Gt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 > v)}
  return BoolValue(false)}
func (b1 Float64Value) Gt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 > v)}
  return BoolValue(false)}
func (b1 TextValue) Gt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 > v)}
  return BoolValue(false)}
func (b1 DataValue) Gt(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Lt(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Lt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 < v)}
  return BoolValue(false)}
func (b1 UInt64Value) Lt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 < v)}
  return BoolValue(false)}
func (b1 Float64Value) Lt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 < v)}
  return BoolValue(false)}
func (b1 TextValue) Lt(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 < v)}
  return BoolValue(false)}
func (b1 DataValue) Lt(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Gte(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Gte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 >= v)}
  return BoolValue(false)}
func (b1 UInt64Value) Gte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 >= v)}
  return BoolValue(false)}
func (b1 Float64Value) Gte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 >= v)}
  return BoolValue(false)}
func (b1 TextValue) Gte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 >= v)}
  return BoolValue(false)}
func (b1 DataValue) Gte(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Lte(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Lte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return BoolValue(b1 <= v)}
  return BoolValue(false)}
func (b1 UInt64Value) Lte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return BoolValue(b1 <= v)}
  return BoolValue(false)}
func (b1 Float64Value) Lte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return BoolValue(b1 <= v)}
  return BoolValue(false)}
func (b1 TextValue) Lte(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return BoolValue(b1 <= v)}
  return BoolValue(false)}
func (b1 DataValue) Lte(b2 ValueContents) (result ValueContents){
  return BoolValue(false)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Add(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Add(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return Int64Value(b1 + v)}
  return Int64Value(0)}
func (b1 UInt64Value) Add(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return UInt64Value(b1 + v)}
  return UInt64Value(0)}
func (b1 Float64Value) Add(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return Float64Value(b1 + v)}
  return Float64Value(0)}
func (b1 TextValue) Add(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case TextValue:return TextValue(b1 + v)}
  return TextValue("")}
func (b1 DataValue) Add(b2 ValueContents) (result ValueContents){
  return DataValue(nil)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Subtract(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Subtract(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return Int64Value(b1 - v)}
  return Int64Value(0)}
func (b1 UInt64Value) Subtract(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return UInt64Value(b1 - v)}
  return UInt64Value(0)}
func (b1 Float64Value) Subtract(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return Float64Value(b1 - v)}
  return Float64Value(0)}
func (b1 TextValue) Subtract(b2 ValueContents) (result ValueContents){
  return TextValue("")}
func (b1 DataValue) Subtract(b2 ValueContents) (result ValueContents){
  return DataValue(nil)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Multiply(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Multiply(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return Int64Value(b1 * v)}
  return Int64Value(0)}
func (b1 UInt64Value) Multiply(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return UInt64Value(b1 * v)}
  return UInt64Value(0)}
func (b1 Float64Value) Multiply(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return Float64Value(b1 * v)}
  return Float64Value(0)}
func (b1 TextValue) Multiply(b2 ValueContents) (result ValueContents){
  return TextValue("")}
func (b1 DataValue) Multiply(b2 ValueContents) (result ValueContents){
  return DataValue(nil)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Divide(b2 ValueContents) (result ValueContents){
 return BoolValue(false)}
func (b1 Int64Value) Divide(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){ case Int64Value: return Int64Value(b1 / v)}
  return Int64Value(0)}
func (b1 UInt64Value) Divide(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case UInt64Value:return UInt64Value(b1 / v)}
  return UInt64Value(0)}
func (b1 Float64Value) Divide(b2 ValueContents) (result ValueContents){
  switch v := b2.(type){case Float64Value:return Float64Value(b1 / v)}
  return Float64Value(0)}
func (b1 TextValue) Divide(b2 ValueContents) (result ValueContents){
  return TextValue("")}
func (b1 DataValue) Divide(b2 ValueContents) (result ValueContents){
  return DataValue(nil)}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Negate() (result ValueContents){
 return BoolValue(!b1)}
func (b1 Int64Value) Negate() (result ValueContents){
  return Int64Value(-b1)}
func (b1 UInt64Value) Negate() (result ValueContents){
  return UInt64Value(-b1)}
func (b1 Float64Value) Negate() (result ValueContents){
  return Float64Value(-b1)}
func (b1 TextValue) Negate() (result ValueContents){
  return TextValue("")}
func (b1 DataValue) Negate() (result ValueContents){
  return DataValue(nil)}
/*
  Execution
*/
/*
func (m *Mapovach) Ls(appliance SlotIdentifier) (listing SlotListing, ok){
  for i := 0; i < len(appliance); i++{
    m, ok = m[appliance[i]]
    if !ok{
      log.Printf("%s does not exist.",appliance)
    }
  }
  for i := 0; i < len(m); i++{
    fmt.Println("%s : %s", key(m, i), m[i].value_type.Description())
  }
}

func (m *Mapovach) Set
type Mapovach map[string]Value
type Provider interface{
  Ls(appliance SlotIdentifier) (SlotListing, bool)
  Set(slot SlotIdentifier, value Value) SlotError
  Get(slot SlotIdentifier) (Value, bool)
  Delete(slot SlotIdentifier) bool
}

func set_slot(val Value, slot_identifier []string){
  if slot_identifier[0] == "h"{
      val_in_slot,ok := hand[slot_identifier[1]]
      if !ok || val_in_slot.value_type == val.value_type {
	    hand[slot_identifier[1]] = val
      }
  }
}
*/
