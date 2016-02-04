
open Parser
open Ulexbuf

let reserved = [
  ("_", UNDERSCORE) ;
  ("_sig", USIG) ;
  ("_struct", USTRUCT) ;
  ("_proj", UPROJ) ;
  ("as", AS) ;
  ("assume", ASSUME) ;
  ("and", AND) ;
  ("constant", CONSTANT) ;
  ("context", CONTEXT) ;
  ("congruence", CONGRUENCE) ;
  ("data", DATA) ;
  ("do", DO) ;
  ("end", END) ;
  ("external", EXTERNAL) ;
  ("finally", FINALLY) ;
  ("fail", FAIL) ;
  ("handle", HANDLE) ;
  ("handler", HANDLER) ;
  ("let", LET) ;
  ("match", MATCH) ;
  ("reduce", REDUCE) ;
  ("forall", PROD) ;
  ("yield", YIELD) ;
  ("∀", PROD) ;
  ("Π", PROD) ;
  ("∏", PROD) ;
  ("fun", FUNCTION) ;
  ("lambda", LAMBDA) ;
  ("λ", LAMBDA) ;
  ("in", IN) ;
  ("operation", OPERATION) ;
  ("rec", REC) ;
  ("ref", REF) ;
  ("refl", REFL) ;
  ("signature", SIGNATURE) ;
  ("Type", TYPE) ;
  ("typeof", TYPEOF) ;
  ("val", VAL) ;
  ("⊢", VDASH) ;
  ("where", WHERE) ;
  ("with", WITH)
]

let ascii_name =
  [%sedlex.regexp? ('_' | 'a'..'z' | 'A'..'Z') ,
                 Star ('_' | 'a'..'z' | 'A'..'Z' | '0'..'9' | '\'')]
let name =
  [%sedlex.regexp? ('_' | alphabetic | math),
                 Star ('_' | alphabetic | math
                      | 185 | 178 | 179 | 8304 .. 8351 (* sub-/super-scripts *)
                      | '0'..'9' | '\'')]

let digit = [%sedlex.regexp? '0'..'9']
let numeral = [%sedlex.regexp? Plus digit]

let project = [%sedlex.regexp? '.', (name | numeral)]

let symbolchar = [%sedlex.regexp?  ('!' | '$' | '%' | '&' | '*' | '+' | '-' | '.' | '/' | ':' | '<' | '=' | '>' | '?' | '@' | '^' | '|' | '~')]

let prefixop = [%sedlex.regexp? ('~' | '?' | '!'), Star symbolchar ]
let infixop0 = [%sedlex.regexp? ('=' | '<' | '>' | '|' | '&' | '$'), Star symbolchar]
let infixop1 = [%sedlex.regexp? ('@' | '^'), Star symbolchar ]
let infixop2 = [%sedlex.regexp? ('+' | '-'), Star symbolchar ]
let infixop3 = [%sedlex.regexp? ('*' | '/' | '%'), Star symbolchar ]
let infixop4 = [%sedlex.regexp? "**", Star symbolchar ]

let start_longcomment = [%sedlex.regexp? "(*"]
let end_longcomment= [%sedlex.regexp? "*)"]

let newline = [%sedlex.regexp? ('\n' | '\r' | "\n\r" | "\r\n")]
let hspace  = [%sedlex.regexp? (' ' | '\t' | '\r')]

let quoted_string = [%sedlex.regexp? '"', Plus (Compl '"'), '"']

let update_eoi ({ pos_end; line_limit;_ } as lexbuf) =
  match line_limit with None -> () | Some line_limit ->
    if pos_end.Lexing.pos_lnum >= line_limit
    then reached_end_of_input lexbuf

let rec token ({ end_of_input;_ } as lexbuf) =
  if end_of_input then EOF else token_aux lexbuf

and token_aux ({ stream;_ } as lexbuf) =
  let f () = update_pos lexbuf in
  (* [g] updates the lexbuffer state to indicate whether a sensible end of
     input has been found, typically after a dot or a directive *)
  let g () = update_eoi lexbuf in
  match%sedlex stream with
  | newline                  -> f (); new_line lexbuf; token_aux lexbuf
  | start_longcomment        -> f (); comments 0 lexbuf
  | Plus hspace              -> f (); token_aux lexbuf
  | "#environment"               -> f (); g (); ENVIRONMENT
  | "#help"                  -> f (); g (); HELP
  | "#quit"                  -> f (); g (); QUIT
  | "#verbosity"             -> f (); VERBOSITY
  | "#include"               -> f (); INCLUDE
  | "#include_once"          -> f (); INCLUDEONCE
  | quoted_string            -> f (); let s = lexeme lexbuf in QUOTED_STRING (String.sub s 1 (String.length s - 2))
  | '('                      -> f (); LPAREN
  | ')'                      -> f (); RPAREN
  | '['                      -> f (); LBRACK
  | ']'                      -> f (); RBRACK
  | '{'                      -> f (); LBRACE
  | '}'                      -> f (); RBRACE
  | "="                      -> f (); EQ
  | ':'                      -> f (); COLON
  | "::"                     -> f (); COLONCOLON
  | ','                      -> f (); COMMA
  | '?', name                -> f (); PATTVAR (let s = lexeme lexbuf in
                                               let s = String.sub s 1 (String.length s - 1) in
                                               Name.make s)
  | '.', name                -> f (); PROJECTION (let s = lexeme lexbuf in
                                                  let s = String.sub s 1 (String.length s - 1) in
                                                  Name.make s)
  | "|-"                     -> f (); VDASH
  | '|'                      -> f (); BAR
  | "->" | 8594 | 10230      -> f (); ARROW
  | "=>" | 8658 | 10233      -> f (); DARROW
  | "==" | 8801              -> f (); EQEQ
  | '!'                      -> f (); BANG
  | ":="                     -> f (); COLONEQ
  | ';'                      -> f (); SEMICOLON
  | prefixop                 -> f (); PREFIXOP (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Prefix s, Location.of_lexeme lexbuf)
  | infixop0                 -> f (); INFIXOP0 (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Infix0 s, Location.of_lexeme lexbuf)
  | infixop1                 -> f (); INFIXOP1 (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Infix1 s, Location.of_lexeme lexbuf)
  | infixop2                 -> f (); INFIXOP2 (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Infix2 s, Location.of_lexeme lexbuf)
  (* Comes before infixop3 because ** matches the infixop3 pattern too *)
  | infixop4                 -> f (); INFIXOP4 (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Infix4 s, Location.of_lexeme lexbuf)
  | infixop3                 -> f (); INFIXOP3 (let s = lexeme lexbuf in
                                                Name.make ~fixity:Name.Infix3 s, Location.of_lexeme lexbuf)

  | eof                      -> f (); EOF
  | name                     -> f ();
    let n = lexeme lexbuf in
    begin try List.assoc n reserved
    with Not_found -> NAME (Name.make n)
    end
  | numeral                  -> f (); let k = int_of_string (lexeme lexbuf) in NUMERAL k
  | any -> f ();
    let c = lexeme lexbuf in
    Error.syntax ~loc:(Location.of_lexeme lexbuf)
      "Unexpected character: %s" c
  | _ -> f ();
    Error.syntax ~loc:(Location.of_lexeme lexbuf)
      "Unexpected character, failed to parse"

and comments level ({ stream;_ } as lexbuf) =
  match%sedlex stream with
  | end_longcomment ->
    if level = 0 then
      begin update_pos lexbuf; token lexbuf end
    else
      comments (level-1) lexbuf

  | start_longcomment -> comments (level+1) lexbuf
  | '\n'        -> new_line lexbuf; comments level lexbuf
  | eof         ->
    print_endline "Input ended inside (unclosed) comment";
    raise End_of_file
  | any           -> comments level lexbuf
  | _ -> Error.syntax ~loc:(Location.of_lexeme lexbuf)
           "Unexpected character in comment"


(** run a menhir parser with a sedlexer on a t *)
(* the type of run is also:  *)
(* (t -> 'a) -> ('a, 'b) MenhirLib.Convert.traditional -> t -> 'b *)
let run
    ?(line_limit : int option)
    (lexer : t -> 'a)
    (parser : (Lexing.lexbuf -> 'a) -> Lexing.lexbuf -> 'b)
    (lexbuf : t) : 'b =
  set_line_limit line_limit lexbuf;
  let lexer () =
    let token = lexer lexbuf in
    (token, lexbuf.pos_start, lexbuf.pos_end) in
  let parser = MenhirLib.Convert.Simplified.traditional2revised parser in
  try
    parser lexer
  with
  | Parser.Error
  | Sedlexing.MalFormed
  | Sedlexing.InvalidCodepoint _ ->
     let w = Ulexbuf.lexeme lexbuf in
     raise (Parse_Error (w, lexbuf.pos_start, lexbuf.pos_end))


let read_file ?line_limit parse fn =
  try
    let fh = open_in fn in
    let lex = from_channel ~fn fh in
    try
      let terms = run ?line_limit token parse lex in
      close_in fh;
      terms
    with
    (* Close the file in case of any parsing errors. *)
      Error.Error err -> close_in fh; raise (Error.Error err)
  with
  (* Any errors when opening or closing a file are fatal. *)
    Sys_error msg -> Error.fatal ~loc:Location.unknown "%s" msg


let read_toplevel parse () =
  let all_white str =
    let n = String.length str in
    let rec fold k =
      k >= n ||
      (str.[k] = ' ' || str.[k] = '\n' || str.[k] = '\t') && fold (k+1)
    in
    fold 0
  in

  let ends_with_backslash_or_empty str =
    let i = String.length str - 1 in
    if i >= 0 && str.[i] = '\\'
    then (true, String.sub str 0 i)
    else (all_white str, str)
  in

  let rec read_more prompt acc =
    print_string prompt ;
    let str = read_line () in
    let more, str = ends_with_backslash_or_empty str in
    let acc = acc ^ "\n" ^ str in
    if more
    then read_more "  " acc
    else acc
  in

  let str = read_more "# " "" in
  let lex = from_string (str ^ "\n") in
  run token parse lex
