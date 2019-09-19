{
    open Parserbnf
    open Scanf
    open List
    exception UnknownToken of char
}

let eol = "\n"|"\r"|"\r\n"

rule token = parse
    | "#" [^ '\n' '\r']* eol { token lexbuf } (* comment *)

    | [' ' '\t']* { token lexbuf } (* whitespace *)
    | eol* { token lexbuf } (* new line *)

    | ';' { END_RULE } (* end of a rule or of the axiom *)

    | eof { EOF } (* end of file *)

    | "::=" { SEP } (* separator of the rule *)

    | "'" (([^ '\'' '\n' '\r']|"\\\'")* as s) "'" { TERM (true,unescaped s) } (* terminal *)
    | '"' (([^ '"' '\n' '\r']|"\\\"")* as s) '"' { TERM (true,unescaped s) } (* terminal *)
    | ['A'-'Z' 'a'-'z' '0'-'9' '_']* as s { NTERM (false,s) } (* nonterminal *)

    | _ as c { raise (UnknownToken c)}