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
	"flag"
	"bytes"
	"fmt"
	"io"
	"bufio"
	"log"
	"unicode/utf8"
	"unicode"
        "strconv"
	"gopkg.in/readline.v1"
	"os"
	"strings"
	"reflect"
	"encoding/json"
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
  Type() int32
  TypeName() string
}
//Value Types
const( //Number literals used, as these numbers should not change due to their presense "on the wire" in the protocol.
      BOOL_TYPE = 0
      TEXT_TYPE = 1
      DATA_TYPE = 2
      SLOT_TYPE = 3
      APPLIANCE_TYPE = 4
      INT64_TYPE = 5
      UINT64_TYPE = 6
      FLOAT64_TYPE = 7
)
type BoolValue        bool
type Int64Value       int64
type UInt64Value      uint64
type Float64Value     float64
type TextValue        string
type DataValue        []byte
//type SlotValue        Slot
type ApplianceValue   Appliance

type SlotListing struct{
  slot_name string
  value_type int32
}
type SlotListings []SlotListing
type Expr func() (ret Value)
type Hole func(fill Expr) ()
type Statement func()
type Mapovach map[string]Value
type Appliance interface{
  Ls() (SlotListings, bool)
  Set(slot string, value Value) *Value
  Get(slot string) (Value, bool)
  Delete(slot string) bool
}
type Slot struct {
  slot_name string
  appliance Appliance
}
type TableFormat struct {
  head Statement
  columns []Hole
  foot Statement
}
type GovachProgram map[int64]Block
type Block struct{
  //tags map[string]Goto
  gotos []Goto
  statements []Statement
}
type Goto struct{
  cond Expr
  dest int64
}

/*
  Globals
*/
var (
     table_format TableFormat
     this_statement func()
     this_expr Expr
     current Appliance
     hand Appliance
     bag Appliance
)
%}

// fields inside this union end up as the fields in a structure known
// as ${PREFIX}SymType, of which a reference is passed to the lexer.
%union{
  statement Statement
  exprs []*Expr
  expr Expr
  hole Hole
  holes []Hole
  val Value
  symbol string
  symbols []string
  appliance func() Appliance
}

%start line
%type  <val> literal
%token <val> STRING NUMBER BOOL
%type  <appliance> appliance
%type  <symbol> symbol
%token <symbol> BUILT_IN_COMMAND LOWERCASE UPPERCASE
%type  <symbols> keyword_arguments
%type  <expr> expr slot
%type  <exprs> table_body_columns
%type  <statement> sentences sentence
%type  <hole> holy_sentence table_heading_column
%type  <holes> table_heading_columns
%token STATEMENT_MARKER EXPR_MARKER TABLE_HEADING_MARKER TABLE_BODY_MARKER TABLE_MODE_TRANSITION HAND BAG
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
      this_statement = func() {}
    }
    | TABLE_BODY_MARKER table_body_columns
    {
      current_table_format := table_format
      body_columns := $2
      this_statement = func(){
        current_table_format.head()
        for i :=0 ; i < len(body_columns); i++ {
          if body_columns[i] != nil {
             current_table_format.columns[i](*body_columns[i])
          }
        }
        current_table_format.foot()
      }
    }
    | STATEMENT_MARKER sentences
    {
      this_statement = $2
    }
    | EXPR_MARKER expr
    {
      this_expr = $2
    }
    | EXPR_MARKER
    {
      this_expr = func () Value {return Value{empty: false,v: BoolValue(true)}}
    }
    | TABLE_HEADING_MARKER TABLE_MODE_TRANSITION
    {
      this_statement = func() {}
    }
    | TABLE_BODY_MARKER TABLE_MODE_TRANSITION
    {
      this_statement = func() {}
    }
    | STATEMENT_MARKER TABLE_MODE_TRANSITION
    {
      this_statement = func() {}
    }
    | TABLE_MODE_TRANSITION
    {
      this_statement = func() {}
    }
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
      $$ = []*Expr{}
    }
    | expr
    {
      $$ = []*Expr{&$1}
    }
    | ',' expr
    {
      $$ = []*Expr{nil,&$2}
    }
    | table_body_columns ',' ','
    {
      $$ = append($1,nil)
    }
    | table_body_columns ','
    {
      $$ = append($1,nil)
    }
    | table_body_columns ',' expr
    {
      $$ = append($1,&$3)
    }
    ;
sentences
    :
    {
      $$ = func(){}
    }
    | sentence
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
        fmt.Println("",expr().v)
      }
    }
    | expr TO appliance UPPERCASE
    {
      expr, appliance, slot_name := $1, $3, $4
      $$ = func(){
	appliance().Set(slot_name, expr())
      }
    }
    ;
holy_sentence
    : '_' TO appliance UPPERCASE
    {
      appliance, slot_name := $3, $4
      $$ = func(expr Expr){
        v := expr()
	fmt.Println(v.v)
	appliance().Set(slot_name,v)
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
appliance
    : HAND
    {
      $$ = func() Appliance{
        return hand
      }
    }
    | BAG
    {
      $$ = func() Appliance{
        return bag
      }
    }
    | slot
    {
      slot := $1
      $$ = func() Appliance {
	switch app := slot().v.(type) {
	    case ApplianceValue:
	      return app
	    default:
	      log.Printf("Slot is not an appliance.")
	      return nil
	}
      }
    }
    ;
slot
    : appliance UPPERCASE
    {
      appliance, slot_name := $1, $2
      $$ = func() Value {
	v, ok := appliance().Get(slot_name)
	if !ok{
	  log.Printf("Slot %s does not exist.", slot_name)
	}
	return v
      }
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
    | expr NEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
        if reflect.TypeOf(val1.v) == reflect.TypeOf(val2.v){
          return Value{empty:false,v: val1.v.Neq(val2.v)}
        } else {
          log.Printf("Type error, types do not match.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr AND expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tb := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true))
        if t1 == tb && t2 == tb {
          return Value{empty:false,v: val1.v.And(val2.v)}
        } else {
          log.Printf("Type error: && operator can only be applied to the bool type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr OR expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tb := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true))
        if t1 == tb && t2 == tb {
          return Value{empty:false,v: val1.v.Or(val2.v)}
        } else {
          log.Printf("Type error: || operator can only be applied to the bool type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '>' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil))
        if t1 == t2 && t1 != tbool && t1 != tdata {
          return Value{empty:false,v: val1.v.Gt(val2.v)}
        } else {
          log.Printf("Type error: > only takes sortable types. Both values must be of the same type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '<' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil))
        if t1 == t2 && t1 != tbool && t1 != tdata {
          return Value{empty:false,v: val1.v.Lt(val2.v)}
        } else {
          log.Printf("Type error: < only takes sortable types. Both values must be of the same type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr LTEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil))
        if t1 == t2 && t1 != tbool && t1 != tdata {
          return Value{empty:false,v: val1.v.Lte(val2.v)}
        } else {
          log.Printf("Type error: <= only takes sortable types. Both values must be of the same type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr GTEQ expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil))
        if t1 == t2 && t1 != tbool && t1 != tdata {
          return Value{empty:false,v: val1.v.Gte(val2.v)}
        } else {
          log.Printf("Type error: >= only takes sortable types. Both values must be of the same type.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '+' expr
    {
      expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil))
        if t1 == t2 && t1 != tbool && t1 != tdata {
          return Value{empty:false,v: val1.v.Add(val2.v)}
        } else {
          log.Printf("Type error: + only takes addable types. Both values must be of the same type. Expected type num + num got %v + %v.",val1.v.TypeName(),val2.v.TypeName())
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '-' expr
    {
     expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata, tstring := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil)),  reflect.TypeOf(TextValue(""))
        if t1 == t2 && t1 != tbool && t1 != tdata && t1 != tstring {
          return Value{empty:false,v: val1.v.Subtract(val2.v)}
        } else {
          log.Printf("Type error: - only takes number types. Both values must be of the same type. Expected type num - num got %v - %v.",val1.v.TypeName(),val2.v.TypeName())
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '/' expr
    {
     expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata, tstring := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil)),  reflect.TypeOf(TextValue(""))
        if t1 == t2 && t1 != tbool && t1 != tdata && t1 != tstring {
          return Value{empty:false,v: val1.v.Divide(val2.v)}
        } else {
          log.Printf("Type error: / only takes number types. Both values must be of the same type. Expected type num / num got %v / %v.",val1.v.TypeName(),val2.v.TypeName())
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | expr '*' expr
    {
     expr1, expr2 := $1, $3
      $$ = func() (value Value){
        val1, val2 := expr1(), expr2()
	t1, t2, tbool, tdata, tstring := reflect.TypeOf(val1.v), reflect.TypeOf(val2.v), reflect.TypeOf(BoolValue(true)), reflect.TypeOf(DataValue(nil)),  reflect.TypeOf(TextValue(""))
        if t1 == t2 && t1 != tbool && t1 != tdata && t1 != tstring {
          return Value{empty:false,v: val1.v.Multiply(val2.v)}
        } else {
          log.Printf("Type error: * only takes number types. Both values must be of the same type. Expected type num * num got %v * %v.",val1.v.TypeName(),val2.v.TypeName())
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | '-' expr %prec UMINUS
    {
      expr := $2
      $$ = func() (value Value){
        val := expr()
	t, tdata, tstring := reflect.TypeOf(val.v), reflect.TypeOf(DataValue(nil)),  reflect.TypeOf(TextValue(""))
        if t != tdata && t != tstring {
          return Value{empty:false,v: val.v.Negate()}
        } else {
          log.Printf("Type error: Can only negate bool and number types.")
	  return Value{empty:true,v: BoolValue(false)}
        }
      }
    }
    | slot
    {
      $$ = $1
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
      EXPR_MODE
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
	             case EXPR_MODE:
		        return EXPR_MARKER
		  }
		}
		c := x.next()
		switch c {
		case eof:
		        within_line = false
			return eof
		case '#':
		        within_line = false
			return eof
		case '(',')':
		        return int(c)
		case '0', '1', '2', '3', '4', '5', '6', '7', '8', '9':
			return x.num(c, yylval)
		case '"':
			return x.string(c, yylval)
		case '\n':
		  within_line = false
		case ' ', '\t', '\r':
		default:
		        if unicode.IsLower(c) {
			    return x.lowercase(c, yylval)
			} else if unicode.IsUpper(c) {
			    return x.uppercase(c, yylval)
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

func (x *OvachLex) uppercase(c rune, yylval *OvachSymType) int {
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
        yylval.symbol = s
        return UPPERCASE
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
	  case "h":
	    return HAND
	  case "b":
	    return BAG
	  default:
            yylval.symbol = s
	    return LOWERCASE
	}
}

func (x *OvachLex) string(c rune, yylval *OvachSymType) int {
	add := func(b *bytes.Buffer, c rune) {
		if _, err := b.WriteRune(c); err != nil {
			log.Fatalf("WriteRune: %s", err)
		}
	}
	var b bytes.Buffer
	add(&b, c)
	L: for {
		c = x.next()
		if c != '"' && c != eof{
			add(&b, c)
		} else {
		        if c == eof {
			  log.Fatalf("Parse error: EOF while reading string.")
			} else {
			  add(&b, '"')
			  break L
			}
		}
	}
	var s string
        json.Unmarshal(b.Bytes(),&s)
	yylval.val = Value{empty:false,v:TextValue(s)}
	return STRING
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
		if c != '(' && c != '"' && c != '_' && (unicode.IsSymbol(c) || unicode.IsPunct(c)) {
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
	/*
	  Init runtime
	 */
	hand = make(Mapovach)
	bag = make(Mapovach)
	ovach_script := flag.String("ovach-script","","The ovach script to run.")
	print_lines := flag.Bool("print-lines",false,"Print out each line of the ovach script as it is run for debugging purposes. Note: does not work with govach scripts.")
	govach_script := flag.String("govach-script","","The govach script to run.")
	flag.Parse()
	if *ovach_script != "" {
	  run_ovach_script(*ovach_script,*print_lines)
	} else if *govach_script != ""{
	  run_govach_script(*govach_script)
        } else {
	  repl()
        }
}
type BlockFromJson struct {
	id int64
	code string
	streets []json.RawMessage
}
type StreetFromJson struct{
       name string
       destination int64
}

func (b *BlockFromJson) UnmarshalJSON(buf []byte) error {
	// THANKS! http://eagain.net/articles/go-json-array-to-struct/
	tmp := []interface{}{&b.id, &b.code, &b.streets}
	wantLen := len(tmp)
	if err := json.Unmarshal(buf, &tmp); err != nil {
		return err
	}
	if g, e := len(tmp), wantLen; g != e {
		return fmt.Errorf("wrong number of fields in Block: %d != %d", g, e)
	}
	return nil
}

func (s *StreetFromJson) UnmarshalJSON(buf []byte) error {
	// THANKS! http://eagain.net/articles/go-json-array-to-struct/
	tmp := []interface{}{&s.name, &s.destination}
	wantLen := len(tmp)
	if err := json.Unmarshal(buf, &tmp); err != nil {
		return err
	}
	if g, e := len(tmp), wantLen; g != e {
		return fmt.Errorf("wrong number of fields in Street: %d != %d", g, e)
	}
	return nil
}

func run_govach_script(script string){
    // http://stackoverflow.com/questions/8757389/reading-file-line-by-line-in-go
    /*
      Compile
    */
    file, err := os.Open(script)
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    p := make(GovachProgram)
    var json_block BlockFromJson
    scanner := bufio.NewScanner(file)
    for scanner.Scan() {
	line := scanner.Text()
	if err := json.Unmarshal([]byte(line), &json_block); err != nil {
		log.Fatal(err)
	}
	statements := []Statement{}
	blockscanner := bufio.NewScanner(bytes.NewBufferString(json_block.code))
	for blockscanner.Scan() {
	  codeline := blockscanner.Text()
	  OvachParse(&OvachLex{line: codeline})
	  statements = append(statements,this_statement)
	}
	gotos := []Goto{}
        var json_street StreetFromJson
	parse_mode = EXPR_MODE
	for _,raw_json_street := range json_block.streets{
	  if err := json.Unmarshal(raw_json_street, &json_street); err != nil {
		log.Fatal(err)
	  }
	  OvachParse(&OvachLex{line: json_street.name})
	  gotos = append(gotos, Goto{cond: this_expr, dest: json_street.destination})
        }
	parse_mode = STATEMENT_MODE
	p[json_block.id] = Block{gotos:gotos,statements:statements}
    }

    if err := scanner.Err(); err != nil {
        log.Fatal(err)
    }
    /*
      Run
    */
    b := int64(0)
    L: for {
	// Clear inner scope with each new block
	hand = make(Mapovach)
	for _,s := range p[b].statements{
	  s()
	}
	for _,cond := range p[b].gotos{
	  c := cond.cond()
	  if !c.empty{
	    switch v := c.v.(type){
	      case BoolValue:
	        if v {
	          b = cond.dest
	          continue L
                }
              default:
	        b = cond.dest
	        continue L
	    }
          }
	}
        return
    }
}

func run_ovach_script(script string, print_lines bool){
    // http://stackoverflow.com/questions/8757389/reading-file-line-by-line-in-go
    file, err := os.Open(script)
    if err != nil {
        log.Fatal(err)
    }
    defer file.Close()

    scanner := bufio.NewScanner(file)
    line_number := 0
    for scanner.Scan() {
	line := scanner.Text()
	if print_lines{
	  fmt.Println(line_number,line)
	}
	line_number++
	OvachParse(&OvachLex{line: line})
	this_statement()
    }

    if err := scanner.Err(); err != nil {
        log.Fatal(err)
    }
}

func repl() {
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
	        this_statement()
	}
}

/*
  Type interfaces

  Lots of boiler plate. :( . At least it's easy to understand.
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
////////////////////////////////////////////////////////////////
func (b1 BoolValue) Type() (result int32){
 return BOOL_TYPE}
func (b1 Int64Value) Type() (result int32){
  return INT64_TYPE}
func (b1 UInt64Value) Type() (result int32){
  return UINT64_TYPE}
func (b1 Float64Value) Type() (result int32){
  return FLOAT64_TYPE}
func (b1 TextValue) Type() (result int32){
  return TEXT_TYPE}
func (b1 DataValue) Type() (result int32){
  return DATA_TYPE}
////////////////////////////////////////////////////////////////
func (b1 BoolValue) TypeName() (result string){
 return "bool"}
func (b1 Int64Value) TypeName() (result string){
  return "int64"}
func (b1 UInt64Value) TypeName() (result string){
  return "uint64"}
func (b1 Float64Value) TypeName() (result string){
  return "float64"}
func (b1 TextValue) TypeName() (result string){
  return "value"}
func (b1 DataValue) TypeName() (result string){
  return "data"}
/*
  Execution
*/
func (m Mapovach) Ls() (listing SlotListings, ok bool){
  var listings = make([]SlotListing,len(m))
  i := 0
  for key, value := range m{
    listings[i] = SlotListing{key, value.v.Type()}
    i++
  }
  return listings, true
}

func (m Mapovach) Set(slot string, value Value) *Value{
  m[slot] = value
  return nil
}

func (m Mapovach) Get(slot string) (Value, bool){
  v,ok := m[slot]
  return v,ok
}

func (m Mapovach) Delete(slot string) bool{
  _, ok := m[slot]
  delete(m,slot)
  return ok
}
