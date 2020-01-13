open Grammar

let quoted_string_of_element : element -> string = function
    | Terminal x -> "\""^(String.escaped x)^"\""
    | Nonterminal x -> x

let bnf_string_of_part : part -> string = string_of_list " " "" string_of_element

let bnf_string_of_ext_element (e: ext_element) : string = match e.pf,e.sf with
    | [],[] -> quoted_string_of_element e.e
    | _,_ -> (string_of_element e.e) ^ "_[" ^ (bnf_string_of_part (List.rev e.pf)) ^ "|" ^ (bnf_string_of_part e.sf) ^ "]"

let bnf_string_of_ext_part : ext_part -> string = string_of_list " " "" bnf_string_of_ext_element

let bnf_string_of_ext_rule (r: ext_rule) : string = (bnf_string_of_ext_element r.ext_left_symbol) ^ " ::= " ^ (bnf_string_of_ext_part r.ext_right_part) ^ ";\n"

let bnf_string_of_ext_rules : ext_rule list -> string = string_of_list "" "" bnf_string_of_ext_rule

let bnf_string_of_ext_grammar (g : ext_grammar) : string = (bnf_string_of_ext_element g.ext_axiom) ^ ";\n" ^ (bnf_string_of_ext_rules g.ext_rules)

let rec read_part (part : (bool*string) list) (output : element list) : part = match part with
    | [] -> List.rev output
    | t::q when fst t -> (read_part [@tailcall]) q (Terminal(snd t)::output)
    | t::q -> (read_part [@tailcall]) q (Nonterminal(snd t)::output)

let rec read_rules (ext_rules : ((bool*string) * ((bool*string) list)) list) (output : rule list) : rule list = match ext_rules with
    | [] -> output
    | (n,l)::q -> assert (not (fst n)); (read_rules [@tailcall]) q ((Nonterminal(snd n) --> read_part l [])::output)

let convert_grammar (tokens : ((bool*string) * (((bool*string) * ((bool*string) list)) list))) : grammar =
    assert (not (fst (fst tokens))); (* the ext_axiom must be a nonterminal *)
    Nonterminal(snd (fst tokens)) @@ read_rules (snd tokens) []

let read_bnf_grammar (filename : string) : grammar =
    let lexbuf = Lexing.from_channel (open_in filename) in
    convert_grammar (Parserbnf.start Lexerbnf.token lexbuf)

let rec read_tokens_from_ch (ch: Lexing.lexbuf) : element list =
    let token = Lexerbnf.token ch in match token with
    | Parserbnf.EOF -> []
    | Parserbnf.NTERM(b,str) -> Nonterminal(str)::(read_tokens_from_ch ch)
    | Parserbnf.TERM(b,str) -> Terminal(str)::(read_tokens_from_ch ch)
    | _ -> failwith "Error token"

let read_tokens (str : string) : element list =
    read_tokens_from_ch (Lexing.from_string str)

(*let bnf_of_grammar (g: grammar) : string =
    bnf_string_of_grammar g*)

let export_bnf (fname : string) (g: ext_grammar) =
    let channel = open_out fname in
    output_string channel (bnf_string_of_ext_grammar g);
    close_out channel


(* add an edge in the graphviz output *)
let add_edge_in_graph (graph_channel: out_channel option) (color: string) (from: ext_element) (dest: ext_element): unit =
        Option.iter (fun ch -> output_string ch ("\""^(string_of_ext_element from)^"\"->\""^(string_of_ext_element dest)^"\" ["^color^"]\n")) graph_channel

(* set the node attribute in the graphviz output *)
let set_node_attr (graph_channel: out_channel option) (attr: string) (e: ext_element) : unit =
    Option.iter (fun ch -> output_string ch ("\""^(string_of_ext_element e)^"\""^attr^"\n")) graph_channel

(* color a node in the graphviz output *)
let set_node_color_in_graph (graph_channel: out_channel option) (e: ext_element) (c: string): unit =
    set_node_attr graph_channel ("[color="^c^",style=filled]") e
