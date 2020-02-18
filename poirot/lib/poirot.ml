type grammar = Grammar.grammar
type element = Grammar.element

let search ?(verbose: bool = false) ?(subst: (element,string) Hashtbl.t option = None) ?(max_depth: int = 10) ?(forbidden_chars: char list = []) ?(sgraph_fname: string option = None) ?(qgraph_fname: string option = None) (oracle_fname: string)  (g: grammar) (goal: element) (start: element list) : grammar option =
    let fuzzer_oracle (subst: (element,string) Hashtbl.t option) (goal: element option) (oracle_fname: string) : (grammar -> Oracle.oracle_status) = let oracle = Oracle.oracle_mem_from_script oracle_fname verbose in (* create the oracle first because it is memoized *)
        fun g -> g |> Tree_fuzzer.fuzzer 0 subst goal verbose |> Option.map Grammar.string_of_word |> oracle in
    let qgraph_channel = Option.map open_out qgraph_fname in
    Option.map Grammar.grammar_of_ext_grammar (Inference.search (fuzzer_oracle subst (Some goal) oracle_fname) g goal (Some start) max_depth forbidden_chars sgraph_fname qgraph_channel verbose)

let read_subst : string -> (element,string) Hashtbl.t = Grammar_io.read_subst

let quotient (g: grammar) (prefix: element list) (suffix: element list) : grammar =
    Grammar.grammar_of_ext_grammar (Clean.clean (Rec_quotient.quotient_mem g None false {pf=List.rev prefix;e=g.axiom;sf=suffix}))

let fuzzer ?(subst: (element,string) Hashtbl.t option = None) ?(complexity: int = 10) ?(goal: element option = None) (g: grammar) : string option =
    Option.map Grammar.string_of_word (Tree_fuzzer.fuzzer complexity subst goal false g)

let to_uppercase (g: grammar) : grammar = Clean.simplify (Clean.to_uppercase g)
let to_lowercase (g: grammar) : grammar = Clean.simplify (Clean.to_lowercase g)

let set_axiom (g: grammar) (axiom: element) : grammar = {axiom; rules=g.rules}

let string_of_grammar : grammar -> string = Grammar.string_of_grammar
let read_bnf_grammar ?(unravel: bool = false) : string -> grammar = Grammar_io.read_bnf_grammar unravel
let read_tokens ?(unravel: bool = false) :  string -> element list = Grammar_io.read_tokens unravel
let read_token ?(unravel: bool = false) :  string -> element = Grammar_io.read_token unravel

let export_antlr4 : string -> grammar -> unit = Grammar_io.export_antlr4
