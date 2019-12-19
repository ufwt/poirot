open Base

(* get the first symbol of the rhs of a rule *)
let extract_left_symbol (r : rule) : element option = match r.right_part with
    | [] -> None
    | t::_ -> Some(t)

(* TODO: faire en sorte que le symbol en lui-même n'apparaisse pas dans la liste (sauf s'il est accessible récursivement *)

(* get the last symbol of the rhs of a rule *)
let extract_right_symbol (r : rule) : element option = match List.length r.right_part with
    | 0 -> None
    | n -> assert (n > 0); Some(List.nth r.right_part (n-1))

(* get the list of proper prefix/suffix. By proper prefix, it means that A is a proper prefix of A if A is recursively reachable from A *)
let rec symbol_list_aux (f : rule -> element option) (g: grammar) (tasks: element list) (seen: element list) (first: bool): element list = match tasks with
    | [] -> seen
    | t::q when List.mem t seen -> (symbol_list_aux [@tailcall]) f g q seen false
    | t::q -> let new_seen = (List.filter_map f (List.filter (fun r -> r.left_symbol = t) g.rules)) in
        if first then
            (symbol_list_aux [@tailcall]) f g (new_seen@q) [] false
        else (symbol_list_aux [@tailcall]) f g (new_seen@q) (t::seen) false

(* get the list of symbols that can be a prefix of the derivation of element *)
let left_symbol_list (g: grammar) (task: element) : element list =
    symbol_list_aux extract_left_symbol g [task] [] true

(* get the list of symbols that can be a suffix of the derivation of element *)
let right_symbol_list (g: grammar) (task: element) : element list =
    symbol_list_aux extract_right_symbol g [task] [] true

(* get the list of rules that can directly derive this element *)
let get_generative_rules (g: grammar) (e: element) : ext_rule list =
    List.filter_map (fun r -> if List.mem e r.right_part then Some(ext_rule_of_rule r) else None) g.rules

(* get the list of rules with some left-hand side *)
let get_rules (g: grammar) (e: element) : ext_rule list =
    List.filter_map (fun r -> if r.left_symbol = e then Some(ext_rule_of_rule r) else None) g.rules

let quotient_mem (g: grammar) =
    (* all the computed rules *)
    let mem : (ext_rule list) ref = ref (List.map ext_rule_of_rule g.rules)
    (* has an ext_element been computed before ? *)
    and seen : (ext_element, bool) Hashtbl.t = Hashtbl.create 100
    and all_sym : (element list) = get_all_symbols g in

    let all_non_terminal : (element list) = List.filter (is_non_terminal) all_sym
    and create_useless (e: element) : ext_element list =
        let useful = left_symbol_list g e in
        let check_useless (p : element) : ext_element option =
            if not (List.mem p useful) then Some({pf=[p];e=e;sf=[]})
            else None
        in
        List.filter_map check_useless all_sym
    in

    (* we don't need to compute the useless of terminal since their "quotientability" is trivial *)
    let useless : (ext_element, bool) Hashtbl.t = Hashtbl.create 100 in
    List.iter (fun e -> Hashtbl.add useless e true) (List.flatten (List.map create_useless all_non_terminal));

    (* apply a quotient of a single rule with a prefix that is a single element *)
    let quotient_by_one_element (pf: element) (r: ext_rule) : (ext_rule list) * (ext_element list)  =
        let new_lhs = {pf=r.ext_left_symbol.pf@[pf]; e=r.ext_left_symbol.e; sf=r.ext_left_symbol.sf} in
        match r.ext_right_part with
        | [] -> [],[]
        (* A -> aBC with prefix = a *)
        | t::q when t.e=pf && is_ext_element_terminal t -> assert (t.pf=[] && t.sf=[]); [new_lhs ---> q],[]
        (* A -> aBC with prefix != a *)
        | t::q when is_ext_element_terminal t -> assert (t.pf=[] && t.sf=[]); [],[]
        (* A -> BC with prefix = B *)
        | t::q when t.e=pf && t.pf=[] -> let new_elem = {pf=[pf];e=t.e;sf=t.sf} in
            (* if B can't derive a leftmost B *)
            if Hashtbl.mem useless new_elem then
                [new_lhs ---> q],[]
            (* if B can derive a leftmost B *)
            else
                [new_lhs ---> q; new_lhs ---> (new_elem::q)],[new_elem]
        (* A -> B_{D|}C *)
        | t::q -> let new_elem = {pf=t.pf@[pf];e=t.e;sf=t.sf} in
            if Hashtbl.mem useless new_elem then [],[]
            else [new_lhs ---> (new_elem::q)],[new_elem]
    in

    (* apply a quotient of rules with a prefix *)
    let rec quotient_rules (rlist: ext_rule list) (pf: part) (new_sym: ext_element list) : ext_element list = match pf with
        | [] -> new_sym
        | t::q -> let (new_rlist,new_new_sym) = List.split (List.map (quotient_by_one_element t) rlist) in
            let new_rlist = List.flatten new_rlist and new_new_sym = List.flatten new_new_sym in
            mem := new_rlist@(!mem);
            print_endline ("New rules:\n"^(string_of_ext_rules new_rlist));
            (quotient_rules [@tailcall]) new_rlist q (new_new_sym@new_sym)
    in

    (* compute the rules of a ext_element and do it recursively with every new symbol *)
    let rec quotient_symbols (elist: ext_element list) : ext_rule list =
        match elist with
        | [] -> !mem
        | t::q when Hashtbl.mem seen t -> print_endline ("Seen: "^(string_of_ext_element t)); (quotient_symbols [@tailcall]) q
        | t::q -> let new_elist = quotient_rules (get_rules g t.e) t.pf [] in
            Hashtbl.add seen t true;
            (quotient_symbols [@tailcall]) (new_elist@elist)
    in
    fun (e: ext_element) : ext_grammar -> Clean.clean (e@@@(quotient_symbols [e]))

(*     print_endline "Useless:";
    List.iter (fun e -> print_endline (string_of_ext_element e)) !useless; *)
    (* quotient_by_one_element *)
    (* quotient_rules *)
