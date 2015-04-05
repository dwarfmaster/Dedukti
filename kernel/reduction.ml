open Basics
open Term
open Rule

type env = term Lazy.t LList.t

type state = {
  ctx:env;              (*context*)
  term : term;          (*term to reduce*)
  stack : stack;        (*stack*)
}
and stack = state list

type cloture = { cenv:env; cterm:term; }

let rec cloture_eq : (cloture*cloture) list -> bool = function
  | [] -> true
  | (c1,c2)::lst ->
       ( match c1.cterm, c2.cterm with
           | Kind, Kind | Type _, Type _ -> cloture_eq lst
           | Const (_,m1,v1), Const (_,m2,v2) ->
               ident_eq v1 v2 && ident_eq m1 m2 && cloture_eq lst
           | Lam (_,_,_,t1), Lam (_,_,_,t2) ->
               let arg = Lazy.lazy_from_val (mk_DB dloc qmark 0) in
               let c3 = { cenv=LList.cons arg c1.cenv; cterm=t1; } in
               let c4 = { cenv=LList.cons arg c2.cenv; cterm=t2; } in
                 cloture_eq ((c3,c4)::lst)
           | Pi (_,_,a1,b1), Pi (_,_,a2,b2) ->
               let arg = Lazy.lazy_from_val (mk_DB dloc qmark 0) in
               let c3 = { cenv=c1.cenv; cterm=a1; } in
               let c4 = { cenv=c2.cenv; cterm=a2; } in
               let c5 = { cenv=LList.cons arg c1.cenv; cterm=b1; } in
               let c6 = { cenv=LList.cons arg c2.cenv; cterm=b2; } in
                 cloture_eq ((c3,c4)::(c5,c6)::lst)
           | App (f1,a1,l1), App (f2,a2,l2) ->
               ( try
                   let aux lst0 t1 t2 =
                     ( { cenv=c1.cenv; cterm=t1; },
                       { cenv=c2.cenv; cterm=t2; } )::lst0
                   in
                     cloture_eq (List.fold_left2 aux lst (f1::a1::l1) (f2::a2::l2))
                 with Invalid_argument _ -> false
               )
           | DB (_,_,n), _ when n<c1.cenv.LList.len ->
               let c3 =
                 { cenv=LList.nil; cterm=Lazy.force (LList.nth c1.cenv n); } in
               cloture_eq ((c3,c2)::lst)
           | _, DB (_,_,n) when n<c2.cenv.LList.len ->
               let c3 =
                 { cenv=LList.nil; cterm=Lazy.force (LList.nth c2.cenv n); } in
                 cloture_eq ((c1,c3)::lst)
           | DB (_,_,n1), DB (_,_,n2) (* ni >= ci.cenv.len *) ->
               ( n1-c1.cenv.LList.len ) = ( n2-c2.cenv.LList.len )
               && cloture_eq lst
           | _, _ -> false
       )

let rec add2 l1 l2 lst =
  match l1, l2 with
    | [], [] -> Some lst
    | s1::l1, s2::l2 -> add2 l1 l2 ((s1,s2)::lst)
    | _,_ -> None

let rec state_eq : (state*state) list -> bool = function
  | [] -> true
  | (s1,s2)::lst ->
      ( match add2 s1.stack s2.stack lst with
          | None -> cloture_eq [ {cenv=s1.ctx; cterm=s1.term},
                                 {cenv=s2.ctx;cterm=s2.term} ]
          | Some lst2 -> cloture_eq [ {cenv=s1.ctx; cterm=s1.term},
                                      {cenv=s2.ctx;cterm=s2.term} ]
            && state_eq lst2
      )

let rec term_of_state {ctx;term;stack} : term =
  let t = ( if LList.is_empty ctx then term else Subst.psubst_l ctx 0 term ) in
    match stack with
      | [] -> t
      | a::lst -> mk_App t (term_of_state a) (List.map term_of_state lst)

let rec split_stack (i:int) : stack -> (stack*stack) option = function
  | l  when i=0 -> Some ([],l)
  | []          -> None
  | x::l        -> map_opt (fun (s1,s2) -> (x::s1,s2) ) (split_stack (i-1) l)

let rec safe_find m v = function
  | []                  -> None
  | (_,m',v',tr)::tl       ->
      if ident_eq v v' && ident_eq m m' then Some tr
      else safe_find m v tl

let rec add_to_list lst (s:stack) (s':stack) =
  match s,s' with
    | [] , []           -> Some lst
    | x::s1 , y::s2     -> add_to_list ((x,y)::lst) s1 s2
    | _ ,_              -> None

let pp_env out (ctx:env) =
  let pp_lazy_term out lt = pp_term out (Lazy.force lt) in
    pp_list ", " pp_lazy_term out (LList.lst ctx)

let pp_state out { ctx; term; stack } =
   Printf.fprintf out "[ e=[...](%i) | %a | [...] ] { %a } "
     (LList.len ctx)
     pp_term term
     pp_term (term_of_state { ctx; term; stack })

let pp_stack out (st:stack) =
  let aux out state =
    pp_term out (term_of_state state)
  in
    Printf.fprintf out "[ %a ]\n" (pp_list "\n | " aux) st

(* ********************* *)

let rec beta_reduce : state -> state = function
    (* Weak heah beta normal terms *)
    | { term=Type _ }
    | { term=Kind }
    | { term=Const _ }
    | { term=Pi _ }
    | { term=Lam _; stack=[] } as config -> config
    | { ctx={ LList.len=k }; term=DB (_,_,n) } as config when (n>=k) -> config
    (* DeBruijn index: environment lookup *)
    | { ctx; term=DB (_,_,n); stack } (*when n<k*) ->
        beta_reduce { ctx=LList.nil; term=Lazy.force (LList.nth ctx n); stack }
    (* Beta redex *)
    | { ctx; term=Lam (_,_,_,t); stack=p::s } ->
        beta_reduce { ctx=LList.cons (lazy (term_of_state p)) ctx; term=t; stack=s }
    (* Application: arguments go on the stack *)
    | { ctx; term=App (f,a,lst); stack=s } ->
        (* rev_map + rev_append to avoid map + append*)
        let tl' = List.rev_map ( fun t -> {ctx;term=t;stack=[]} ) (a::lst) in
          beta_reduce { ctx; term=f; stack=List.rev_append tl' s }

(* ********************* *)

type find_case_ty =
  | FC_Lam of dtree*state
  | FC_Const of dtree*state list
  | FC_DB of dtree*state list
  | FC_None

let rec find_case (st:state) (cases:(case*dtree) list) : find_case_ty =
  match st, cases with
    | _, [] -> FC_None
    | { term=Const (_,m,v); stack } , (CConst (nargs,m',v'),tr)::tl ->
        if ident_eq v v' && ident_eq m m' then
          ( assert (List.length stack == nargs);
            FC_Const (tr,stack) )
        else find_case st tl
    | { term=DB (l,x,n); stack } , (CDB (nargs,n'),tr)::tl ->
        if n==n' && (List.length stack == nargs) then (*TODO explain*)
             FC_DB (tr,stack)
        else find_case st tl
    | { ctx; term=Lam (_,_,_,_) } , ( CLam , tr )::tl ->
        begin
          match term_of_state st with
            | Lam (_,_,_,te) ->
                FC_Lam ( tr , { ctx=LList.nil; term=te; stack=[] } )
            | _ -> assert false
        end
    | _, _::tl -> find_case st tl


let rec reduce (sg:Signature.t) (st:state) : state =
  match beta_reduce st with
    | { ctx; term=Const (l,m,v); stack } as config ->
        begin
          match Signature.get_dtree sg l m v with
            | None -> config
            | Some (i,g) ->
                begin
                  match split_stack i stack with
                    | None -> config
                    | Some (s1,s2) ->
                        ( match rewrite sg s1 g with
                            | None -> config
                            | Some (ctx,term) -> reduce sg { ctx; term; stack=s2 }
                        )
                end
        end
    | config -> config

(*TODO implement the stack as an array ? (the size is known in advance).*)
and rewrite (sg:Signature.t) (stack:stack) (g:dtree) : (env*term) option =
  let rec test ctx = function
    | [] -> true
    | (Linearity (t1,t2))::tl ->
      if state_conv sg [ { ctx; term=t1; stack=[] } , { ctx; term=t2; stack=[] } ] then
        test ctx tl
      else false
    | (Bracket (t1,t2))::tl ->
      if state_conv sg [ { ctx; term=t1; stack=[] } , { ctx; term=t2; stack=[] } ] then
        test ctx tl
      else
        failwith "Error while reducing a term: a guard was not satisfied." (*FIXME*)
  in
    (*dump_stack stack ; *)
    match g with
      | Switch (i,cases,def) ->
          begin
            let arg_i = reduce sg (List.nth stack i) in
              match find_case arg_i cases with
                | FC_DB (g,s) | FC_Const (g,s) -> rewrite sg (stack@s) g
                | FC_Lam (g,te) -> rewrite sg (stack@[te]) g
                | FC_None -> bind_opt (rewrite sg stack) def
          end
      | Test (Syntactic ord,[],right,def) ->
          begin
            match get_context_syn sg stack ord with
              | None -> bind_opt (rewrite sg stack) def
              | Some ctx -> Some (ctx, right)
          end
      | Test (Syntactic ord, eqs, right, def) ->
          begin
            match get_context_syn sg stack ord with
              | None -> bind_opt (rewrite sg stack) def
              | Some ctx ->
                  if test ctx eqs then Some (ctx, right)
                  else bind_opt (rewrite sg stack) def
          end
      | Test (MillerPattern lst, eqs, right, def) ->
          begin
              match get_context_mp sg stack lst with
                | None -> bind_opt (rewrite sg stack) def
                | Some ctx ->
                      if test ctx eqs then Some (ctx, right)
                      else bind_opt (rewrite sg stack) def
          end

and state_conv (sg:Signature.t) : (state*state) list -> bool = function
  | [] -> true
  | (s1,s2)::lst ->
      if state_eq [s1,s2] then
        state_conv sg lst
      else
        match reduce sg s1, reduce sg s2 with
          | { term=Kind; stack=s } , { term=Kind; stack=s' }
          | { term=Type _; stack=s } , { term=Type _; stack=s' } ->
              begin
                assert ( s = [] && s' = [] ) ;
                state_conv sg lst
              end
          | { ctx=e;  term=DB (_,_,n);  stack=s },
            { ctx=e'; term=DB (_,_,n'); stack=s' }
              when (n-e.LList.len)==(n'-e'.LList.len) ->
              begin
                match add_to_list lst s s' with
                  | None          -> false
                  | Some lst'     -> state_conv sg lst'
              end
          | { term=Const (_,m,v);   stack=s },
            { term=Const (_,m',v'); stack=s' } when ident_eq v v' && ident_eq m m' ->
              begin
                match (add_to_list lst s s') with
                  | None          -> false
                  | Some lst'     -> state_conv sg lst'
              end
          | { ctx=e;  term=Lam (_,_,_,b);   stack=s },
            { ctx=e'; term=Lam (_,_,_',b'); stack=s'} ->
              begin
                assert ( s = [] && s' = [] ) ;
                let arg = Lazy.lazy_from_val (mk_DB dloc qmark 0) in
                let lst' =
                  ( {ctx=LList.cons arg e;term=b;stack=[]},
                    {ctx=LList.cons arg e';term=b';stack=[]} ) :: lst in
                  state_conv sg lst'
              end
          | { ctx=e;  term=Pi  (_,_,a,b);   stack=s },
            { ctx=e'; term=Pi  (_,_,a',b'); stack=s'} ->
              begin
                assert ( s = [] && s' = [] ) ;
                let arg = Lazy.lazy_from_val (mk_DB dloc qmark 0) in
                let lst' =
                  ( {ctx=e;term=a;stack=[]}, {ctx=e';term=a';stack=[]} ) ::
                  ( {ctx=LList.cons arg e;term=b;stack=[]},
                    {ctx=LList.cons arg e';term=b';stack=[]} ) :: lst in
                  state_conv sg lst'
              end
          | _, _ -> false

and unshift sg q te =
  try Subst.unshift q te
  with Subst.UnshiftExn ->
    Subst.unshift q (snf sg te)

and get_context_syn (sg:Signature.t) (stack:stack) (ord:pos LList.t) : env option =
  try Some (LList.map (
    fun p ->
      if ( p.depth = 0 ) then
        lazy (term_of_state (List.nth stack p.position) )
      else
        Lazy.from_val
          (unshift sg p.depth (term_of_state (List.nth stack p.position) ))
  ) ord )
  with Subst.UnshiftExn -> ( (*Print.debug "Cannot unshift";*) None )

and get_context_mp (sg:Signature.t) (stack:stack) (pb_lst:abstract_pb LList.t) : env option =
  let aux (pb:abstract_pb)  =
    Lazy.from_val ( unshift sg pb.depth2 (
      (Matching.resolve pb.dbs (term_of_state (List.nth stack pb.position2))) ))
  in
  try Some (LList.map aux pb_lst)
  with
    | Subst.UnshiftExn
    | Matching.NotUnifiable -> None

(* ********************* *)

(* Weak Normal Form *)
and whnf sg term = term_of_state ( reduce sg { ctx=LList.nil; term; stack=[] } )

(* Strong Normal Form *)
and snf sg (t:term) : term =
  match whnf sg t with
    | Kind | Const _
    | DB _ | Type _ as t' -> t'
    | App (f,a,lst)     -> mk_App (snf sg f) (snf sg a) (List.map (snf sg) lst)
    | Pi (_,x,a,b)        -> mk_Pi dloc x (snf sg a) (snf sg b)
    | Lam (_,x,a,b)       -> mk_Lam dloc x None (snf sg b)

(* Head Normal Form *)
let rec hnf sg t =
  match whnf sg t with
    | Kind | Const _ | DB _ | Type _ | Pi (_,_,_,_) | Lam (_,_,_,_) as t' -> t'
    | App (f,a,lst) -> mk_App (hnf sg f) (hnf sg a) (List.map (hnf sg) lst)

(* Convertibility Test *)
let are_convertible sg t1 t2 =
  state_conv sg [ ( {ctx=LList.nil;term=t1;stack=[]} , {ctx=LList.nil;term=t2;stack=[]} ) ]

(* One-Step Reduction *)
let rec state_one_step (sg:Signature.t) : state -> state option = function
    (* Weak heah beta normal terms *)
    | { term=Type _ }
    | { term=Kind }
    | { term=Pi _ }
    | { term=Lam _; stack=[] } -> None
    | { ctx={ LList.len=k }; term=DB (_,_,n) } when (n>=k) -> None
    (* DeBruijn index: environment lookup *)
    | { ctx; term=DB (_,_,n); stack } (*when n<k*) ->
        state_one_step sg { ctx=LList.nil; term=Lazy.force (LList.nth ctx n); stack }
    (* Beta redex *)
    | { ctx; term=Lam (_,_,_,t); stack=p::s } ->
        Some { ctx=LList.cons (lazy (term_of_state p)) ctx; term=t; stack=s }
    (* Application: arguments go on the stack *)
    | { ctx; term=App (f,a,lst); stack=s } ->
        (* rev_map + rev_append to avoid map + append*)
        let tl' = List.rev_map ( fun t -> {ctx;term=t;stack=[]} ) (a::lst) in
          state_one_step sg { ctx; term=f; stack=List.rev_append tl' s }
    (* Constant Application *)
    | { ctx; term=Const (l,m,v); stack } ->
        begin
          match Signature.get_dtree sg l m v with
            | None -> None
            | Some (i,g) ->
                begin
                  match split_stack i stack with
                    | None -> None
                    | Some (s1,s2) ->
                        ( match rewrite sg s1 g with
                            | None -> None
                            | Some (ctx,term) -> Some { ctx; term; stack=s2 }
                        )
                end
        end

let one_step sg t =
  map_opt term_of_state (state_one_step sg { ctx=LList.nil; term=t; stack=[] })
