open Types

           (* ********************************************* *)

let mk_prelude lc name =
  Global.debug 1 lc "Module name is '%a'." pp_ident name

let mk_declaration lc id pty =
  Global.debug 1 lc "Declaration of symbol '%a'." pp_ident id;
  let ty = Inference.is_a_type pty in
    Env.add_decl lc id ty

let mk_definition lc id ty_opt pte =
  Global.debug 1 lc "Definition of symbol '%a'." pp_ident id ;
  let (te,ty) =
    match ty_opt with
      | None          -> Inference.infer pte
      | Some pty      -> Inference.check pte pty
  in
    Env.add_def lc id te ty

let mk_opaque lc id ty_opt pte =
  Global.debug 1 lc "Opaque definition of symbol '%a'." pp_ident id ;
  let (_,ty) =
    match ty_opt with
      | None          -> Inference.infer pte
      | Some pty      -> Inference.check pte pty
  in
    Env.add_decl lc id ty

let mk_rule (pr:prule) : rule =
  let (lc,_,id,_,_) = pr in
    Global.debug 1 lc "Rewrite rule for symbol '%a'." pp_ident id ;
    Inference.check_rule pr

let mk_rules (prs:prule list) : unit =
  let rs = List.map mk_rule prs in
    List.iter (fun r -> Global.debug_no_loc 1 "%a" Pp.pp_rule r ) rs ;
    Env.add_rw rs

let mk_command lc _ = assert false (*function FIXME
  | Whnf pte          ->
      let (te,_) = scope_and_infer pte in
        Pp.pp_term stdout (Reduction.whnf te)
  | Hnf pte           ->
      let (te,_) = scope_and_infer pte in
        Pp.pp_term stdout (Reduction.hnf te)
  | Snf pte           ->
      let (te,_) = scope_and_infer pte in
        Pp.pp_term stdout (Reduction.snf te)
  | OneStep pte       ->
      let (te,_) = scope_and_infer pte in
        ( match Reduction.one_step te with
            | None    -> Global.print "Already in weak head normal form."
            | Some t' -> Pp.pp_term stdout t')
  | Conv (pte1,pte2)  ->
      let (t1,_) = scope_and_infer pte1 in
      let (t2,_) = scope_and_infer pte2 in
        if Reduction.are_convertible t1 t2 then Global.print "OK"
        else Global.print "KO"
  | Check (pte1,pte2) ->
      let (t1,ty1) = scope_and_infer pte1 in
      let ty2 = check_type [] pte2 in
        if Reduction.are_convertible ty1 ty2 then Global.print "OK"
        else Global.print "KO"
  | Infer pte         ->
      let (ty,te) = scope_and_infer pte in Pp.pp_term stdout ty
  | Gdt (m,v)         ->
      ( match Env.get_infos lc m v with
          | Decl_rw (_,_,i,g)   -> ( Pp.pp_rw stdout (m,v,i,g) ; print_newline () )
          | _                   -> Global.print "No GDT." )
  | Print str         -> pp_ident stdout str
  | Other (cmd,_)     -> Global.debug 1 lc "Unknown command '%s'." cmd *)

let mk_ending _ =
  Env.export_and_clear ()
