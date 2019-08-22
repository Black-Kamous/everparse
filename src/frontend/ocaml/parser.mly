%{
  open Lexing
  open Ast
  let mk_td i j k = {
    typedef_name = i;
    typedef_abbrev = j;
    typedef_ptr_abbrev = k
  }

  let mk_pos (l:Lexing.position) =
      let col = (l.pos_cnum - l.pos_bol + 1) in
      {
        filename=l.pos_fname;
        line=Z.of_int l.pos_lnum;
        col=Z.of_int col;
      }

  let with_range (x:'a) (l:Lexing.position) : 'a withrange =
      { v = x;
        range = (mk_pos l, mk_pos l)
      }

%}

%token<int>     INT
%token<string>  COMMENT XINT
%token<Ast.ident>   IDENT
%token          EQ AND OR EOF SIZEOF ENUM TYPEDEF STRUCT CASETYPE SWITCH CASE THIS
%token          DEFINE LPAREN RPAREN LBRACE RBRACE COMMA SEMICOLON COLON
%token          STAR MINUS PLUS LBRACK RBRACK
%start <Ast.decl list> prog
%start <Ast.expr> expr_top

%nonassoc EQ
%left OR
%left AND
%left PLUS
%left MINUS


%%

right_flexible_list(SEP, X):
  |     { [] }
  | x=X { [x] }
  | x=X SEP xs=right_flexible_list(SEP, X) { x :: xs }

right_flexible_nonempty_list(SEP, X):
  | x=X { [x] }
  | x=X SEP xs=right_flexible_list(SEP, X) { x :: xs }

constant:
  | i=INT { Int (Z.of_int i) }
  | x=XINT { XInt x }

rel_op:
  | EQ { Eq }

expr_no_range:
  | i=IDENT { Identifier i }
  | THIS    { This }
  | c=constant
    { Constant c }
  | l=expr o=rel_op r=expr %prec EQ
    { App (o, [l;r]) }
  | l=expr AND r=expr
    { App (And, [l;r]) }
  | l=expr OR r=expr
    { App (Or, [l;r]) }
  | l=expr MINUS r=expr
    { App (Minus, [l;r]) }
  | l=expr PLUS r=expr
    { App (Plus, [l;r]) }
  | SIZEOF LPAREN e=expr RPAREN
    { App (SizeOf, [e]) }

expr:
  | e=expr_no_range { with_range e $startpos }

arguments:
 | es=right_flexible_nonempty_list(COMMA, expr)  { es }

typ_no_range:
  | i=IDENT { Type_app(i, []) }
  | hd=IDENT LPAREN a=arguments RPAREN { Type_app(hd, a) }

typ:
  | t=typ_no_range { with_range t $startpos }

constraint_opt:
  |  { None }
  | LBRACE o=rel_op e=expr RBRACE { Some (with_range (App(o, [with_range This $startpos(o); e])) $startpos($4)) }

array_size_opt:
  |  { None }
  | LBRACK e=expr RBRACK { Some e }

struct_field:
  | t=typ fn=IDENT aopt=array_size_opt c=constraint_opt { {field_dependence=false; field_ident=fn; field_type=t; field_constraint=c} }

field_no_range:
  | l=COMMENT { FieldComment l }
  | f=struct_field { Field f }

field:
  | f = field_no_range { with_range f $startpos }

parameter:
  | t=typ i=IDENT { (t, i) }

parameters:
  |  { [] }
  | LPAREN ps=right_flexible_nonempty_list(COMMA, parameter) RPAREN { ps }

case:
  | CASE i=IDENT COLON f=field { (with_range (Identifier i) $startpos(i), f) }

cases:
  | cs=right_flexible_nonempty_list(SEMICOLON, case) { cs }

decl_no_range:
  | l=COMMENT { Comment l }
  | DEFINE i=IDENT c=constant { Define (i, c) }
  | t=IDENT ENUM i=IDENT LBRACE es=right_flexible_nonempty_list(COMMA, IDENT) RBRACE
    { Enum(with_range (Type_app (t, [])) ($startpos(t)), i, es) }
  | TYPEDEF STRUCT i=IDENT ps=parameters
    LBRACE fields=right_flexible_nonempty_list(SEMICOLON, field)
    RBRACE j=IDENT COMMA STAR k=IDENT SEMICOLON
    { Record(mk_td i j k, ps, fields) }
  | CASETYPE i=IDENT ps=parameters
    LBRACE SWITCH LPAREN e=IDENT RPAREN
           LBRACE cs=cases
           comms=list(COMMENT)
           RBRACE
    RBRACE j=IDENT COMMA STAR k=IDENT SEMICOLON
    { let td = mk_td i j k in CaseType(td, ps, (with_range (Identifier e) ($startpos(i)), cs)) }

decl:
  | d=decl_no_range { with_range d ($startpos) }

expr_top:
  | e=expr EOF { e }

prog:
  | d=decl EOF { [d] }
  | d=decl p=prog { d :: p }
