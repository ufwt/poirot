open Base
open Quotient

let blackbox prefix suffix grammaire injections = isInLanguageListe grammaire (List.map (fun p -> prefix @ p @ suffix) injections)

type tree_state = partie * element * partie

let print_tree (a,b,c) = print_string ((partie2string a)^" ["^(element2string b)^"] "^(partie2string c)^"\n")

let get_grammar_from_tree grammaire (p,e,s) = genererGrammaireInjectionAveugle p s (e@@grammaire.regles)

(* renvoie les règles dont la partie droite contient l'élément cherché *)

let trouve_regles grammaire elem = List.filter (fun r -> List.mem elem r.partiedroite) grammaire.regles

let rec is_accessible_from_axiom grammaire s reachable =
    if List.mem s reachable then true
    else
        let rules = List.filter (fun r -> List.mem r.elementgauche reachable) grammaire.regles in
        let new_reachable = List.sort_uniq compare (List.flatten (List.map (fun r -> r.partiedroite) rules)) in
            if (List.length reachable) = (List.length new_reachable) then false
            else (is_accessible_from_axiom grammaire [@tailcall]) s new_reachable

let symboles_parents grammaire axiome = List.sort_uniq compare (List.map (fun r -> r.elementgauche) (List.filter (fun r -> List.mem axiome r.partiedroite) grammaire.regles))

let trim = function
    | Terminal(s) -> Terminal(s)
    | Nonterminal(s) -> (*print_string s; flush stdout;*) let index = String.index_opt s '.' in match index with
        | None -> Nonterminal(s)
        | Some(i) -> Nonterminal(String.sub s 0 i)

let rec distance_to_goal grammaire goal = function
    | [] -> failwith "Can't reach at all"
    | (s,nb)::q when is_accessible_from_axiom grammaire goal [s] -> nb 
    | (s,nb)::q -> (distance_to_goal [@tailcall]) grammaire goal (q@(List.map (fun e -> (e,nb+1)) (symboles_parents grammaire s)))

let rec is_accessible s = function
    | [] -> false
    | r::q -> List.mem s r.partiedroite || s = r.elementgauche || (is_accessible [@tailcall]) s q

let is_symbol_accessible g s = is_accessible s g.regles

let rec get_prefix_suffix_partie elem prefix = function
    | [] -> []
    | t::q when t=elem -> (List.rev prefix,q)::(get_prefix_suffix_partie elem (t::prefix) q)
    | t::q -> get_prefix_suffix_partie elem (t::prefix) q

let construct_trees grammaire (p,e,s) =
    List.flatten (List.map (fun r -> let l=get_prefix_suffix_partie e [] r.partiedroite in List.map (fun (p2,s2) -> p2@p,r.elementgauche,s@s2) l) (trouve_regles grammaire e))

let get_all_tokens grammaire = List.sort_uniq compare (List.concat (List.map (fun r -> List.filter isTerminal r.partiedroite) grammaire.regles))

(* let fuzzer g = deriverLongueur 10 g [g.axiome] *)

let fuzzer g =
    let term = List.filter (is_symbol_accessible g) (get_all_tokens g) in
    List.map (derive_word_with_symbol g) term

let check_grammar_validity blackbox g = blackbox (fuzzer g)

(* A* avec heuristique : distance à l'objectif *)

let rec insert_in_list distance tree = function
    | [] -> [(distance,tree)]
    | (d,t)::q when d > distance -> (distance,tree)::((d,t)::q)
    | t::q -> t::(insert_in_list distance tree q)

let rec insert_all_in_list grammaire interest l = function
    | [] -> l
    | (a,b,c)::q -> insert_all_in_list grammaire interest (insert_in_list (distance_to_goal grammaire interest [trim b,0]) (a,b,c) l) q

(* TODO: conserver les arbres/grammaires visitées pour les réutiliser *)

let rec is_prefix a l = match a with
    | [] -> true
    | t::q -> match l with
        | [] -> false
        | t2::q2 when t=t2 -> (is_prefix [@tailcall]) q q2
        | _ -> false

let is_suffix c c2 = is_prefix (List.rev c) (List.rev c2)

let is_extension (a,b,c) (a2,b2,c2) = b = b2 && (is_prefix a2 a) && (is_suffix c2 c)

let grammar_of_longest_tree (g,(a,b,c)) (g2,(a2,b2,c2)) = if (List.length a + List.length c) > (List.length a2 + List.length c2) then g,(a,b,c) else g2,(a2,b2,c2)

let extend_grammar (g,t) = g

let rec search blackbox interest grammaire step visited = function
    | [] -> None
    | (_,t)::q -> print_string ("Search "^(string_of_int step)^"\n"); print_tree t; flush stdout;
        if (List.exists (fun (_,tree) -> tree=t) visited) then begin
            print_string "Visited\n"; (search [@tailcall]) blackbox interest grammaire (step+1) visited q
        end else begin
(*            let extensions = List.filter (fun (_,tree) -> is_extension t tree) visited in
            let g = match extensions with
            | [] -> get_grammar_from_tree grammaire t 
            | t::q -> let (base_g,base_t) = (List.fold_left grammar_of_longest_tree t q) in print_string "Extension of:\n"; print_tree base_t; extend_grammar (base_g,base_t)
            in *)
            let g = get_grammar_from_tree grammaire t in
            afficherGrammaire g;
            (*print_string "Grammaire contruite\n"; flush stdout;*)
            (*print_string ("Accessible from "^(element2string g.axiome)^": "); print_bool (is_accessible_from_axiom grammaire interest [g.axiome]); flush stdout;*)
            (*print_string ("Distance: "^(string_of_int (distance_to_goal grammaire interest [(trim g.axiome,0)])));*)
            if not (check_grammar_validity blackbox g) then begin (* invalid : ignore *)
                print_string "Invalid\n"; (search [@tailcall]) blackbox interest grammaire (step+1) visited q
            end else if (*print_string "AA"; flush stdout;*) is_symbol_accessible g interest then begin (* found ! *)
                print_string "Found!\n"; Some(g)
            end else begin (* we explore in this direction *)
                print_string "Explore\n";
                (search [@tailcall]) blackbox interest grammaire (step+1) ((g,t)::visited) (insert_all_in_list grammaire interest q (construct_trees grammaire t))
            end
        end

let search_api blackbox interest grammaire init_tokens =
    search blackbox interest grammaire 0 [] (insert_all_in_list grammaire interest [] init_tokens)

let get_injection_tokens blackbox grammaire = List.filter (fun p -> blackbox [[p]]) (get_all_tokens grammaire)

let get_injection_leaves blackbox grammaire = List.map (fun e -> ([],e,[])) (get_injection_tokens blackbox grammaire)
