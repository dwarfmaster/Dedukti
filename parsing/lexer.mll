{
  open Kernel
  open Basic
  open Lexing
  open Tokens
  open Format

  exception Lexer_error of loc * string

  let loc_of_pos pos = mk_loc (pos.pos_lnum) (pos.pos_cnum - pos.pos_bol)

  let get_loc lexbuf = loc_of_pos lexbuf.lex_start_p

  let prerr_loc lc = eprintf "%a " pp_loc lc

  let fail lc msg =
    raise @@ Lexer_error(lc, msg)
}

let space   = [' ' '\t' '\r']
let mident = ['a'-'z' 'A'-'Z' '0'-'9' '_']+
let ident   = ['a'-'z' 'A'-'Z' '0'-'9' '_' '!' '?']['a'-'z' 'A'-'Z' '0'-'9' '_' '!' '?' '\'' ]*
let capital = ['A'-'Z']+

rule token = parse
  | space             { token lexbuf  }
  | '\n'              { new_line lexbuf ; token lexbuf }
  | "(;# eval"        { PRAGMA_EVAL ( get_loc lexbuf ) }
  | "(;# infer"       { PRAGMA_INFER ( get_loc lexbuf ) }
  | "(;# check"       { PRAGMA_CHECK ( get_loc lexbuf ) }
  | "(;# checknot"    { PRAGMA_CHECKNOT ( get_loc lexbuf ) }
  | "(;# assert"      { PRAGMA_ASSERT ( get_loc lexbuf ) }
  | "(;# assertnot"   { PRAGMA_ASSERTNOT ( get_loc lexbuf ) }
  | "(;# print"       { PRAGMA_PRINT ( get_loc lexbuf ) }
  | "(;# gdt"         { PRAGMA_GDT ( get_loc lexbuf ) }
  | "(;#"             { generic_pragma lexbuf }
  | "#;)"             { PRAGMA_END ( get_loc lexbuf ) }
  | "(;"              { comment 0 lexbuf}
  | '.'               { DOT           }
  | ','               { COMMA         }
  | ':'               { COLON         }
  | "=="              { EQUAL         }
  | '['               { LEFTSQU       }
  | ']'               { RIGHTSQU      }
  | '{'               { LEFTBRA       }
  | '}'               { RIGHTBRA      }
  | '('               { LEFTPAR       }
  | ')'               { RIGHTPAR      }
  | "-->"             { LONGARROW     }
  | "->"              { ARROW         }
  | "=>"              { FATARROW      }
  | ":="              { DEF           }
  | "|-"              { VDASH         }
  | "?"               { QUESTION      }
  | "module"          { MODULE ( get_loc lexbuf ) }
  | "with"            { WITH }
  | "_"               { UNDERSCORE ( get_loc lexbuf ) }
  | "Type"            { TYPE       ( get_loc lexbuf ) }
  | "def"             { KW_DEF     ( get_loc lexbuf ) }
  | "defac"           { KW_DEFAC   ( get_loc lexbuf ) }
  | "defacu"          { KW_DEFACU  ( get_loc lexbuf ) }
  | "injective"       { KW_INJ     ( get_loc lexbuf ) }
  | "thm"             { KW_THM     ( get_loc lexbuf ) }
  | "private"         { KW_PRV     ( get_loc lexbuf ) }
  | "assert"          { ASSERT     ( get_loc lexbuf ) }
  | mident as md '.' (ident as id)
                      { QID ( get_loc lexbuf , mk_mident md , mk_ident id ) }
  | ident  as id
                      { ID  ( get_loc lexbuf , mk_ident id ) }
  | '{' '|'           { sident None (Buffer.create 42) lexbuf }
  | mident as md '.' '{' '|'
                      {sident (Some (mk_mident md)) (Buffer.create 42) lexbuf}
  | '"'               { string (Buffer.create 42) lexbuf }
  | _   as s
                      { let msg = sprintf "Unexpected characters '%s'." (String.make 1 s) in
    fail (get_loc lexbuf) msg }
  | eof               { EOF }

and comment i = parse
  | ";)" { if (i=0) then token lexbuf else comment (i-1) lexbuf }
  | '\n' { new_line lexbuf ; comment i lexbuf }
  | "(;" { comment (i+1) lexbuf }
  | _    { comment i lexbuf }
  | eof  { fail (get_loc lexbuf) "Unexpected end of file."  }

and generic_pragma = parse
  | "#;)" { token lexbuf }
  | "\n"  { new_line lexbuf; generic_pragma lexbuf }
  | _     { generic_pragma lexbuf }
  | eof   { fail (get_loc lexbuf) "Unexpected end of file." }

and string buf = parse
  | '\\' (_ as c)
  { Buffer.add_char buf '\\'; Buffer.add_char buf c; string buf lexbuf }
  | '\n'
  { Lexing.new_line lexbuf ; Buffer.add_char buf '\n'; string buf lexbuf }
  | '"'
  { STRING (Buffer.contents buf) }
  | _ as c
  { Buffer.add_char buf c; string buf lexbuf }
  | eof
  { fail (get_loc lexbuf) "Unexpected end of file in string." }

and sident op buf = parse
  | '\\' (_ as c)
  { Buffer.add_char buf '\\'; Buffer.add_char buf c; sident op buf lexbuf }
  | '|' '}' '.' (ident as id)
  { match op with
    | None -> QID (get_loc lexbuf , mk_mident (Buffer.contents buf), mk_ident id)
    | Some _ -> fail (get_loc lexbuf) "The current module system of Dedukti does not allow module inside module, it does not make sense to try to load one."
  }
  | '|' '}' '.' '{' '|'
  { match op with
    | None -> sident (Some (mk_mident (Buffer.contents buf))) (Buffer.create 42) lexbuf
    | Some _ -> fail (get_loc lexbuf) "The current module system of Dedukti does not allow module inside module, it does not make sense to try to load one."
  }
  | '|' '}'
  { match op with
    | None ->  ID  ( get_loc lexbuf , mk_ident ("{|" ^ (Buffer.contents buf) ^ "|}") )
    | Some md -> QID ( get_loc lexbuf , md, mk_ident ("{|" ^ (Buffer.contents buf) ^ "|}") )}
  | '\n'
  { fail (get_loc lexbuf) "Unexpected new line in ident." }
  | _ as c
  { Buffer.add_char buf c; sident op buf lexbuf }
  | eof
  { fail (get_loc lexbuf) "Unexpected end of file in ident." }
