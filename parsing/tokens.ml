open Kernel.Basic

type token =
  | UNDERSCORE of loc
  | TYPE of loc
  | KW_DEF of loc
  | KW_DEFAC of loc
  | KW_DEFACU of loc
  | KW_THM of loc
  | KW_INJ of loc
  | KW_PRV of loc
  | RIGHTSQU
  | RIGHTPAR
  | RIGHTBRA
  | QID of (loc * mident * ident)
  | NAME of (loc * mident)
  | REQUIRE of (loc * mident)
  | LONGARROW
  | LEFTSQU
  | LEFTPAR
  | LEFTBRA
  | ID of (loc * ident)
  | FATARROW
  | EOF
  | DOT
  | DEF
  | COMMA
  | COLON
  | EQUAL
  | ARROW
  | EVAL of loc
  | INFER of loc
  | CHECK of loc
  | ASSERT of loc
  | CHECKNOT of loc
  | ASSERTNOT of loc
  | PRINT of loc
  | GDT of loc
  | STRING of string
