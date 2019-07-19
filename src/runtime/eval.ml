(** Evaluation of computations *)

(** Notation for the monadic bind *)
let (>>=) = Runtime.bind

let return = Runtime.return

let as_atom ~loc v =
  Runtime.lookup_signature >>= fun sgn ->
  let j = Runtime.as_is_term ~loc v in
  match Nucleus.invert_is_term sgn j with
    | Nucleus.Stump_TermAtom x -> return x
    | Nucleus.(Stump_TermConstructor _ | Stump_TermMeta _ | Stump_TermConvert _) ->
       Runtime.(error ~loc (ExpectedAtom j))

let mlfalse, _, _ = Typecheck.Builtin.mlfalse
let mltrue, _, _ = Typecheck.Builtin.mltrue

let as_bool ~loc v =
  match v with
  | Runtime.Tag (l, []) ->
     if Runtime.equal_tag l mlfalse then
       return false
     else if Runtime.equal_tag l mltrue then
       return true
     else
     Runtime.(error ~loc (BoolExpected v))

  | (Runtime.Tag (_, _::_) | Runtime.IsTerm _ | Runtime.IsType _ | Runtime.EqTerm _ | Runtime.EqType _ |
     Runtime.Closure _ | Runtime.Handler _ | Runtime.Tuple _ | Runtime.Ref _ | Runtime.Dyn _ | Runtime.String _) ->
     Runtime.(error ~loc (BoolExpected v))


(* as_handler: loc:Location.t -> Runtime.value -> Runtime.handler Runtime.comp *)
let as_handler ~loc v =
  let e = Runtime.as_handler ~loc v in
  return e

(* as_ref: loc:Location.t -> Runtime.value -> Runtime.ref Runtime.comp *)
let as_ref ~loc v =
  let e = Runtime.as_ref ~loc v in
  return e

let as_dyn ~loc v =
  let e = Runtime.as_dyn ~loc v in
  return e

(** Evaluate a computation -- infer mode. *)
(*   infer : Rsyntax.comp -> Runtime.value Runtime.comp *)
let rec infer {Location.thing=c'; loc} =
  match c' with
    | Rsyntax.Bound i ->
       Runtime.lookup_bound i

    | Rsyntax.Value pth ->
       Runtime.lookup_ml_value pth

    | Rsyntax.Function c ->
       let f v =
         Runtime.add_bound v
           (infer c)
       in
       Runtime.return_closure f

    | Rsyntax.MLConstructor (t, cs) ->
       let rec fold vs = function
         | [] ->
            let vs = List.rev vs in
            return vs
         | c :: cs ->
            infer c >>= fun v ->
            fold (v :: vs) cs
       in
       fold [] cs >>= fun vs ->
       let v = Runtime.mk_tag t vs in
       return v

    | Rsyntax.IsTypeConstructor (c, cs) ->
       Runtime.lookup_signature >>= fun sgn ->
       let rap = Nucleus.form_rap_is_type sgn c in
       check_arguments rap cs >>= fun e ->
       let v = Runtime.mk_is_type (Nucleus.abstract_not_abstract e) in
       return v

    | Rsyntax.IsTermConstructor (c, cs) ->
       Runtime.lookup_signature >>= fun sgn ->
       let rap = Nucleus.form_rap_is_term sgn c in
       check_arguments rap cs >>= fun e ->
       let v = Runtime.mk_is_term (Nucleus.abstract_not_abstract e) in
       return v

    | Rsyntax.EqTypeConstructor (c, cs) ->
       Runtime.lookup_signature >>= fun sgn ->
       let rap = Nucleus.form_rap_eq_type sgn c in
       check_arguments rap cs >>= fun e ->
       let v = Runtime.mk_eq_type (Nucleus.abstract_not_abstract e) in
       return v

    | Rsyntax.EqTermConstructor (c, cs) ->
       Runtime.lookup_signature >>= fun sgn ->
       let rap = Nucleus.form_rap_eq_term sgn c in
       check_arguments rap cs >>= fun e ->
       let v = Runtime.mk_eq_term (Nucleus.abstract_not_abstract e) in
       return v

    | Rsyntax.Tuple cs ->
      let rec fold vs = function
        | [] -> return (Runtime.mk_tuple (List.rev vs))
        | c :: cs -> (infer c >>= fun v -> fold (v :: vs) cs)
      in
      fold [] cs

    | Rsyntax.Handler {Rsyntax.handler_val; handler_ops; handler_finally} ->
        let handler_val =
          begin match handler_val with
          | [] -> None
          | _ :: _ ->
            let f v =
              match_cases ~loc handler_val infer v
            in
            Some f
          end
        and handler_ops = Ident.mapi (fun op cases ->
            let f {Runtime.args=vs;checking} =
              match_op_cases ~loc op cases vs checking
            in
            f)
          handler_ops
        and handler_finally =
          begin match handler_finally with
          | [] -> None
          | _ :: _ ->
            let f v =
              match_cases ~loc handler_finally infer v
            in
            Some f
          end
        in
        Runtime.return_handler handler_val handler_ops handler_finally

  | Rsyntax.Operation (op, cs) ->
     let rec fold vs = function
       | [] ->
          let vs = List.rev vs in
          Runtime.operation op vs
       | c :: cs ->
          infer c >>= fun v ->
          fold (v :: vs) cs
     in
     fold [] cs

  | Rsyntax.With (c1, c2) ->
     infer c1 >>= as_handler ~loc >>= fun h ->
     Runtime.handle_comp h (infer c2)

  | Rsyntax.Let (xcs, c) ->
     let_bind ~loc xcs (infer c)

  | Rsyntax.LetRec (fxcs, c) ->
     letrec_bind fxcs (infer c)

  | Rsyntax.Now (x,c1,c2) ->
     let xloc = x.Location.loc in
     infer x >>= as_dyn ~loc:xloc >>= fun x ->
     infer c1 >>= fun v ->
     Runtime.now x v (infer c2)

  | Rsyntax.Current c ->
     infer c >>= as_dyn ~loc:(c.Location.loc) >>= fun x ->
     Runtime.lookup_dyn x

  | Rsyntax.Ref c ->
     infer c >>= fun v ->
     Runtime.mk_ref v

  | Rsyntax.Lookup c ->
     infer c >>= as_ref ~loc >>= fun x ->
     Runtime.lookup_ref x

  | Rsyntax.Update (c1, c2) ->
     infer c1 >>= as_ref ~loc >>= fun x ->
     infer c2 >>= fun v ->
     Runtime.update_ref x v >>= fun () ->
     Runtime.return_unit

  | Rsyntax.Sequence (c1, c2) ->
     infer c1 >>= fun v ->
     sequence ~loc v >>= fun () ->
     infer c2

  | Rsyntax.Assume ((None, c1), c2) ->
     infer_is_type c1 >>= fun _ ->
     infer c2

  | Rsyntax.Assume ((Some x, c1), c2) ->
     infer_is_type c1 >>= fun t ->
     Runtime.add_free x t (fun _ -> infer c2)

  | Rsyntax.Match (c, cases) ->
     infer c >>=
     match_cases ~loc cases infer

  | Rsyntax.Ascribe (c1, c2) ->
     infer_is_type_abstraction c2 >>= fun t ->
     check c1 (Nucleus.BoundaryIsTerm t) >>=
     Runtime.return_is_term

  | Rsyntax.Abstract (x, None, _) ->
    Runtime.(error ~loc (UnannotatedAbstract x))

  | Rsyntax.Abstract (x, Some u, c) ->
     infer_is_type u >>= fun u ->
     Runtime.add_free x u
       (fun a ->
         Reflect.add_abstracting
           (Nucleus.abstract_not_abstract (Nucleus.form_is_term_atom a))
           begin infer c >>=
             function

             | Runtime.IsType abstr -> Runtime.return_is_type (Nucleus.abstract_is_type a abstr)

             | Runtime.IsTerm abstr -> Runtime.return_is_term (Nucleus.abstract_is_term a abstr)

             | Runtime.EqType abstr -> Runtime.return_eq_type (Nucleus.abstract_eq_type a abstr)

             | Runtime.EqTerm abstr -> Runtime.return_eq_term (Nucleus.abstract_eq_term a abstr)

             | (Runtime.Closure _ | Runtime.Handler _ | Runtime.Tag _ |
                Runtime.Tuple _ | Runtime.Ref _ | Runtime.Dyn _ |
                Runtime.String _) as v ->
                Runtime.(error ~loc (JudgementExpected v))

           end)

  | Rsyntax.Substitute (c1, c2) ->
     (*

        Checking is kind of useless:

        c1  ==>  {x:A} jdg     c2  <==  A --> s   jdg[s/x] = C
        ------------------------------------------------------
            c1{c2}  <== C


        Abstractions want to be inferred, like applications.

        * c1 has to be an abstraction (not very useful)
        * either
          + c1  ==>  {x:A} jdg
          + c2  <==  A --> s
        * or
          + c2  ==>  A
          + c1  <==  {x:A} α     for α fresh.
            Mlty doesn't currently allow us to do this because we need to know
            what judgement we're abstracting over.
        ---------------------------------
            c1{c2}  ==>  jdg[s/x]

 *)
     infer c1 >>= fun v1 ->

     let infer_substitute ~loc sbst rtrn abstr =
       match Nucleus.type_at_abstraction abstr with
       | None -> Runtime.(error ~loc (AbstractionExpected v1))
       | Some t ->
          check c2 (Nucleus.BoundaryIsTerm (Nucleus.abstract_not_abstract t)) >>= fun v2 ->
          begin match Nucleus.as_not_abstract v2 with
          | None -> Runtime.(error ~loc (IsTermExpected (Runtime.mk_is_term v2)))
          | Some v2 ->
             Runtime.lookup_signature >>= fun sgn ->
             let v = sbst sgn abstr v2 in
             rtrn v
          end
     in

     begin match v1 with
       | Runtime.IsType abstr ->
          infer_substitute ~loc:c1.Location.loc
            Nucleus.apply_is_type_abstraction
            Runtime.return_is_type
            abstr

       | Runtime.IsTerm abstr ->
          infer_substitute ~loc:c1.Location.loc
            Nucleus.apply_is_term_abstraction
            Runtime.return_is_term
            abstr

       | Runtime.EqTerm abstr ->
          infer_substitute ~loc:c1.Location.loc
            Nucleus.apply_eq_term_abstraction
            Runtime.return_eq_term
            abstr

       | Runtime.EqType abstr ->
          infer_substitute ~loc:c1.Location.loc
            Nucleus.apply_eq_type_abstraction
            Runtime.return_eq_type
            abstr

       | (Runtime.Closure _ | Runtime.Handler _ | Runtime.Tag (_, _)
          | Runtime.Tuple _ | Runtime.Ref _ | Runtime.Dyn _
          | Runtime.String _) as v ->
          Runtime.(error ~loc (JudgementExpected v))
     end

  | Rsyntax.Yield c ->
    infer c >>= fun v ->
    Runtime.continue v

  | Rsyntax.Apply (c1, c2) ->
    infer c1 >>= begin function
      | Runtime.Closure f ->
        infer c2 >>= fun v ->
        Runtime.apply_closure f v
      | Runtime.IsTerm _ | Runtime.IsType _ | Runtime.EqTerm _ | Runtime.EqType _ |
        Runtime.Handler _ | Runtime.Tag _ | Runtime.Tuple _ |
        Runtime.Ref _ | Runtime.Dyn _ | Runtime.String _ as h ->
        Runtime.(error ~loc (Inapplicable h))
    end

  | Rsyntax.String s ->
    return (Runtime.mk_string s)

  | Rsyntax.OccursIsTypeAbstraction (c1, c2) ->
     infer_is_type_abstraction c2 >>= fun abstr ->
     occurs Nucleus.occurs_is_type_abstraction c1 abstr

  | Rsyntax.OccursIsTermAbstraction (c1,c2) ->
     infer_is_term_abstraction c2 >>= fun abstr ->
     occurs Nucleus.occurs_is_term_abstraction c1 abstr

  | Rsyntax.OccursEqTypeAbstraction (c1, c2) ->
     infer_eq_type_abstraction c2 >>= fun abstr ->
     occurs Nucleus.occurs_eq_type_abstraction c1 abstr

  | Rsyntax.OccursEqTermAbstraction (c1, c2) ->
     infer_eq_term_abstraction c2 >>= fun abstr ->
     occurs Nucleus.occurs_eq_term_abstraction c1 abstr

  | Rsyntax.Context c ->
    infer_is_term_abstraction c >>= fun j ->
    let xts = Nucleus.context_is_term_abstraction j in
    let js = List.map (fun j -> Runtime.mk_is_term
                          (Nucleus.abstract_not_abstract (Nucleus.form_is_term_atom j))) xts in
    return (Reflect.mk_list js)

  | Rsyntax.Natural c ->
    infer_is_term c >>= fun j ->
    Runtime.lookup_signature >>= fun signature ->
    let eq = Nucleus.natural_type_eq signature j in
    Runtime.return_eq_type (Nucleus.abstract_not_abstract eq)

and check_arguments :
  'a . 'a Nucleus.rule_application -> Rsyntax.comp list -> 'a Runtime.comp
  = fun rap cs ->
  match rap, cs with
  | Nucleus.RapDone v, [] -> return v
  | Nucleus.RapMore rap, c :: cs ->
     let bdry = Nucleus.rap_boundary rap in
     Runtime.lookup_signature >>= fun sgn ->
     check_argument c bdry >>= fun arg ->
     let rap = Nucleus.rap_apply sgn rap arg in
     check_arguments rap cs
  | Nucleus.RapDone _, _::_ ->
     assert false (* cannot happen, typechecking prevents this *)
  | Nucleus.RapMore _, [] ->
     assert false (* cannot happen, typechecking prevents this *)

and check_argument c bdry =
  match bdry with

  | Nucleus.BoundaryIsType _ ->
     check c bdry >>= fun () -> return (Nucleus.JudgementIsType ())

  | Nucleus.BoundaryIsTerm _ ->
     check c bdry >>= fun t -> return (Nucleus.JudgementIsTerm t)

  | Nucleus.BoundaryEqType bdry ->
     infer_eq_type_abstraction c >>= fun eq ->
     if Nucleus.check_eq_type_boundary eq bdry then
       return (Nucleus.JudgementEqType eq)
     else
       failwith "type equation expected, need a good error message"

  | Nucleus.BoundaryEqTerm bdry ->
     infer_eq_term_abstraction c >>= fun eq ->
     if Nucleus.check_eq_term_boundary eq bdry then
       return (Nucleus.JudgementEqTerm eq)
     else
       failwith "term equation expected, need a good error message"

and occurs
  : 'a . (Nucleus.is_atom -> 'a Nucleus.abstraction -> bool)
    -> Rsyntax.comp
    -> 'a Nucleus.abstraction -> Runtime.value Runtime.comp
  = fun occurs_abstr c1 abstr ->
  infer_atom c1 >>= fun a ->
  begin match occurs_abstr a abstr with
  | true ->
     let t = Nucleus.type_of_atom a in
     let t = Runtime.mk_is_type (Nucleus.abstract_not_abstract t) in
     return (Reflect.mk_option (Some t))
  | false ->
     return (Reflect.mk_option None)
  end

(** Coerce the value [v] to the given judgement boundary [bdry] *)
and coerce ~loc v (bdry : Nucleus.boundary) =
  match bdry with
  | Nucleus.BoundaryIsType _ ->
     failwith "coercion to a type boundary not implemented"

  | Nucleus.BoundaryIsTerm bdry ->
     let abstr = Runtime.as_is_term_abstraction ~loc v in
     Runtime.lookup_signature >>= fun sgn ->
     Equal.coerce ~loc sgn abstr bdry >>=
       begin function
         | None -> Runtime.(error ~loc (TypeMismatchCheckingMode (abstr, bdry)))
         | Some e -> return e
       end

  | Nucleus.BoundaryEqType _ ->
     failwith "coercion to a type equality boundary not implemented"

  | Nucleus.BoundaryEqTerm _ ->
     failwith "coercion to a term equality boundary not implemented"


and check ({Location.thing=c';loc} as c) bdry =
  match c' with

  (* for these we switch to infer mode *)
  | Rsyntax.Bound _
  | Rsyntax.Value _
  | Rsyntax.Function _
  | Rsyntax.Handler _
  | Rsyntax.Ascribe _
  | Rsyntax.MLConstructor _
  | Rsyntax.IsTypeConstructor _
  | Rsyntax.IsTermConstructor _
  | Rsyntax.EqTypeConstructor _
  | Rsyntax.EqTermConstructor _
  | Rsyntax.Tuple _
  | Rsyntax.With _
  | Rsyntax.Yield _
  | Rsyntax.Apply _
  | Rsyntax.Ref _
  | Rsyntax.Lookup _
  | Rsyntax.Update _
  | Rsyntax.Current _
  | Rsyntax.String _
  | Rsyntax.OccursIsTypeAbstraction _
  | Rsyntax.OccursIsTermAbstraction _
  | Rsyntax.OccursEqTypeAbstraction _
  | Rsyntax.OccursEqTermAbstraction _
  | Rsyntax.Substitute _
  | Rsyntax.Context _
  | Rsyntax.Natural _ ->

    infer c >>= fun v ->
    coerce ~loc v bdry

  | Rsyntax.Operation (op, cs) ->
     let rec fold vs = function
       | [] ->
          let vs = List.rev vs in
          Runtime.operation op ~checking:bdry vs >>= fun v ->
          coerce ~loc v bdry
       | c :: cs ->
          infer c >>= fun v ->
          fold (v :: vs) cs
     in
     fold [] cs

  | Rsyntax.Let (xcs, c) ->
     let_bind ~loc xcs (check c bdry)

  | Rsyntax.Sequence (c1,c2) ->
    infer c1 >>= fun v ->
    sequence ~loc v >>= fun () ->
    check c2 bdry

  | Rsyntax.LetRec (fxcs, c) ->
     letrec_bind fxcs (check c bdry)

  | Rsyntax.Now (x,c1,c2) ->
     let xloc = x.Location.loc in
     infer x >>= as_dyn ~loc:xloc >>= fun x ->
     infer c1 >>= fun v ->
     Runtime.now x v (check c2 bdry)

  | Rsyntax.Assume ((Some x, t), c) ->
     infer_is_type t >>= fun t ->
     Runtime.add_free x t (fun _ ->
     check c bdry)

  | Rsyntax.Assume ((None, t), c) ->
     infer_is_type t >>= fun _ ->
     check c bdry

  | Rsyntax.Match (c, cases) ->
     infer c >>=
     match_cases ~loc cases (fun c -> check c bdry)

  | Rsyntax.Abstract (xopt, uopt, c) ->
    check_abstract ~loc bdry xopt uopt c


(** Run the abstraction [Abstract(x, uopt, c)] in checking mode with boundary [bdry]. *)
and check_abstract ~loc bdry x uopt c =
  (* We need to invert the data-structures here, so we set-up the necessary auxliary function first. *)
  let stump =
    match bdry with
    | Nucleus.BoundaryIsType bdry -> Nucleus.invert_is_type_abstraction ~name:x bdry
    | Nucleus.BoundaryIsTerm bdry -> Nucleus.invert_is_type_abstraction ~name:x bdry
    | Nucleus.BoundaryEqType _ -> failwith "check_abstract"
    | Nucleus.BoundaryEqTerm _ -> failwith "check_abstract"
  in

  match stump with

  | Nucleus.Stump_NotAbstract t ->
     Runtime.(error ~loc (UnexpectedAbstraction t))

  | Nucleus.Stump_Abstract (a, t_check') ->
     (* NB: [a] is a fresh atom at this point. *)
     begin match uopt with

     | None ->
        Runtime.add_bound
          (Runtime.mk_is_term (Nucleus.abstract_not_abstract (Nucleus.form_is_term_atom a)))
          begin
            check c (Nucleus.BoundaryIsTerm t_check') >>= fun e ->
            return (Nucleus.abstract_is_term a e)
          end

     | Some ({Location.loc=u_loc;_} as u) ->
        infer_is_type u >>= fun u ->
        let a_type = Nucleus.type_of_atom a in
        Equal.equal_type ~loc:u_loc a_type u >>=
          begin function
            | None ->
               Runtime.(error ~loc:u_loc (TypeEqualityFail (u, a_type)))
            | Some eq (* : a_type == u *) ->
               Runtime.lookup_signature >>= fun sgn ->
               let a' =
                 Nucleus.abstract_not_abstract
                   (Nucleus.form_is_term_convert sgn
                      (Nucleus.form_is_term_atom a)
                      eq)
               in
               Runtime.add_bound (Runtime.mk_is_term a')
               begin
                 check c bdry >>= fun e ->
                 return (Nucleus.abstract_is_term a e)
               end
          end
     end

and sequence ~loc v =
  match v with
    | Runtime.Tuple [] -> return ()
    | _ ->
      Print.warning "@[<hov 2>%t: this value should be the unit@]@."
        (Location.print loc) ;
      return ()

and let_bind
  : 'a. loc:Location.t -> Rsyntax.let_clause list -> 'a Runtime.comp -> 'a Runtime.comp
  = fun ~loc clauses cmp ->
  let rec fold uss = function
    | [] ->
      (* parallel let: only bind at the end *)
      (* suppose we had the following parallel let:

            let (x, y, z) = (a, b, c)
            and (u, v)    = (1, 2)

        then uss will be [[2;1]; [c; b; a]].
        Here v has de Bruijn index 0 and x has de Bruijn index 4. *)
       List.fold_left
         (List.fold_left (fun cmp u -> Runtime.add_bound u cmp))
         cmp uss
    | Rsyntax.Let_clause (pt, c) :: clauses ->
       infer c >>= fun v ->
       Matching.match_pattern pt v >>= begin function
        | Some us -> fold (us :: uss) clauses
        | None -> Runtime.(error ~loc (MatchFail v))
       end

  in
  fold [] clauses

and letrec_bind
  : 'a . Rsyntax.letrec_clause list -> 'a Runtime.comp -> 'a Runtime.comp
  = fun fxcs ->
  let gs =
    List.map
      (fun (Rsyntax.Letrec_clause c) -> (fun v -> Runtime.add_bound v (infer c)))
      fxcs
  in
  Runtime.add_bound_rec gs

(* [match_cases loc cases eval v] tries for each case in [cases] to match [v] and if
   successful continues on the computation using [eval] with the pattern variables bound.
   *)
and match_cases
  : 'a . loc:Location.t -> Rsyntax.match_case list -> (Rsyntax.comp -> 'a Runtime.comp)
         -> Runtime.value -> 'a Runtime.comp
  = fun ~loc cases eval v ->
  let bind_pattern_vars vs cmp =
    List.fold_left (fun cmp v -> Runtime.add_bound v cmp) cmp vs
  in
  let rec fold = function
    | [] -> Runtime.(error ~loc (MatchFail v))
    | (p, g, c) :: cases ->
      Matching.match_pattern p v >>= begin function
        | None -> fold cases
        | Some vs ->
           begin
             match g with
             | None -> bind_pattern_vars vs (eval c)
             | Some g ->
                Runtime.get_env >>= fun env ->
                bind_pattern_vars vs
                begin
                  check_bool g >>= function
                  | false -> Runtime.with_env env (fold cases)
                  | true -> eval c
                end
           end
      end
  in
  fold cases

and match_op_cases ~loc op cases vs checking =
  let rec fold = function
    | [] ->
      Runtime.operation op ?checking vs >>= fun v ->
      Runtime.continue v
    | (ps, ptopt, c) :: cases ->
      Matching.match_op_pattern ~loc ps ptopt vs checking >>=
        begin function
        | Some vs -> List.fold_left (fun cmp v -> Runtime.add_bound v cmp) (infer c) vs
        | None -> fold cases
      end
  in
  fold cases

(** Run [c] in infer mode and convert the result to an type judgement. *)
and infer_is_type c =
  infer c >>= fun v -> return (Runtime.as_is_type ~loc:c.Location.loc v)

(** Run [c] in infer mode and convert the result to a type abstraction. *)
and infer_is_type_abstraction c =
  infer c >>= fun v -> return (Runtime.as_is_type_abstraction ~loc:c.Location.loc v)

(** Run [c] in infer mode and convert the result to an term judgement. *)
and infer_is_term c =
  infer c >>= fun v -> return (Runtime.as_is_term ~loc:c.Location.loc v)

(** Run [c] in infer mode and convert the result to a term abstraction. *)
and infer_is_term_abstraction c =
  infer c >>= fun v -> return (Runtime.as_is_term_abstraction ~loc:c.Location.loc v)

(** Run [c] in infer mode and convert the result to a type equality abstraction. *)
and infer_eq_type_abstraction c =
  infer c >>= fun v -> return (Runtime.as_eq_type_abstraction ~loc:c.Location.loc v)

(** Run [c] in infer mode and convert the result to a term equality abstraction. *)
and infer_eq_term_abstraction c =
  infer c >>= fun v -> return (Runtime.as_eq_term_abstraction ~loc:c.Location.loc v)

and infer_atom c =
  infer c >>= fun v -> (as_atom ~loc:c.Location.loc v)

(** Run [c] and convert it to a boolean. *)
and check_bool c =
  infer c >>= fun v -> (as_bool ~loc:c.Location.loc v)

(** Move to toplevel monad *)

let comp_value c =
  let r = infer c in
  Runtime.top_handle ~loc:c.Location.loc r

(** Evaluation of rules *)

(* Evaluate the computation [cmp] in local context [lctx].
   Return the evaluated [lctx] and the result of [cmp]. *)
let local_context abstr_u lctx cmp =
  let rec fold = function
    | [] ->
       cmp >>= fun v ->
       return (Nucleus.abstract_not_abstract v)
    | (x, c) :: lctx ->
       infer_is_type c >>= fun t ->
       Runtime.add_free x t
         (fun a ->
            Reflect.add_abstracting
              (Nucleus.abstract_not_abstract (Nucleus.form_is_term_atom a))
              (fold lctx >>= fun abstr ->
               return (abstr_u a abstr)
         ))
  in
  fold lctx

let check_eq_type_boundary (c1, c2) =
  infer_is_type c1 >>= fun t1 ->
  infer_is_type c2 >>= fun t2 ->
  return (t1, t2)

let check_eq_term_boundary (c1, c2, c3) =
  infer_is_type c3 >>= fun t ->
  let t = Nucleus.abstract_not_abstract t in
  check c1 t >>= fun e1 ->
  let e1 = Runtime.as_is_term ~loc:c1.Location.loc (Runtime.mk_is_term e1) in
  check c2 t >>= fun e2 ->
  let e2 = Runtime.as_is_term ~loc:c2.Location.loc (Runtime.mk_is_term e2) in
  let t = Runtime.as_is_type ~loc:c2.Location.loc (Runtime.mk_is_type t) in
  return (e1, e2, t)

let premise {Location.thing=prem;_} =
  match prem with
    | Rsyntax.PremiseIsType (xopt, lctx) ->
       local_context
         Nucleus.abstract_boundary_is_type
         lctx
         (return ())
       >>= fun abstr ->
       Runtime.lookup_signature >>= fun sgn ->
       let x = (match xopt with Some x -> x | None -> Name.anonymous ()) in
       let mv = Nucleus.fresh_is_type_meta x abstr in
       let v = Runtime.mk_is_type (Nucleus.is_type_meta_eta_expanded sgn mv) in
       return ((Nucleus.meta_nonce mv, Nucleus.BoundaryIsType abstr), Some v)

    | Rsyntax.PremiseIsTerm (xopt, lctx, c) ->
       local_context
         Nucleus.abstract_boundary_is_term
         lctx
         (infer_is_type c)
       >>= fun abstr ->
       Runtime.lookup_signature >>= fun sgn ->
       let x = (match xopt with Some x -> x | None -> Name.anonymous ()) in
       let mv = Nucleus.fresh_is_term_meta x abstr in
       let v = Runtime.mk_is_term (Nucleus.is_term_meta_eta_expanded sgn mv) in
       return ((Nucleus.meta_nonce mv, Nucleus.BoundaryIsTerm abstr), Some v)


    | Rsyntax.PremiseEqType (x, lctx, boundary) ->
       local_context
         Nucleus.abstract_boundary_eq_type
         lctx
         (check_eq_type_boundary boundary)
       >>= fun abstr ->
       Runtime.lookup_signature >>= fun sgn ->
       let (mv, v) =
         begin match x with
         | None ->
            let x = Name.anonymous () in
            let mv = Nucleus.fresh_eq_type_meta x abstr in
            (mv, None)
         | Some x ->
            let mv = Nucleus.fresh_eq_type_meta x abstr in
            let v = Runtime.mk_eq_type (Nucleus.eq_type_meta_eta_expanded sgn mv) in
            (mv, Some v)
         end in
       return ((Nucleus.meta_nonce mv, Nucleus.BoundaryEqType abstr), v)

    | Rsyntax.PremiseEqTerm (x, lctx, boundary) ->
       local_context
         Nucleus.abstract_boundary_eq_term
         lctx
         (check_eq_term_boundary boundary)
       >>= fun abstr ->
       Runtime.lookup_signature >>= fun sgn ->
       let (mv, v) =
         begin match x with
         | None ->
            let x = Name.anonymous () in
            let mv = Nucleus.fresh_eq_term_meta x abstr in
            (mv, None)
         | Some x ->
            let mv = Nucleus.fresh_eq_term_meta x abstr in
            let v = Runtime.mk_eq_term (Nucleus.eq_term_meta_eta_expanded sgn mv) in
            (mv, Some v)
         end in
       return ((Nucleus.meta_nonce mv, Nucleus.BoundaryEqTerm abstr), v)

(** Evaluate the premises (should we call them arguments?) of a rule,
    bind them to meta-variables, then evaluate the conclusion [cmp].
    Return the evaulated premises and conclusion for further processing.
*)
let premises prems cmp =
  let rec fold prems_out = function

    | [] ->
       cmp >>= fun v ->
       let prems_out = List.rev prems_out in
       return (prems_out, v)

    | prem :: prems ->
       premise prem >>= fun (x_boundary, vopt) ->
       let cmp = fold (x_boundary :: prems_out) prems in
       match vopt with
       | None -> cmp
       | Some v -> Runtime.add_bound v cmp
  in
  fold [] prems


(** Toplevel commands *)

let (>>=) = Runtime.top_bind
let return = Runtime.top_return

let toplet_bind ~loc ~quiet ~print_annot info clauses =
  let rec fold uss = function
    | [] ->
       (* parallel let: only bind at the end *)
       List.fold_left
         (List.fold_left (fun cmp u -> Runtime.add_ml_value u >>= fun () -> cmp))
         (return uss)
         uss

    | Rsyntax.Let_clause (pt, c) :: clauses ->
       comp_value c >>= fun v ->
       Matching.top_match_pattern pt v >>= begin function
        | None -> Runtime.error ~loc (Runtime.MatchFail v)
        | Some us -> fold (us :: uss) clauses
       end
  in
  fold [] clauses >>= fun uss ->
  Runtime.top_lookup_penv >>= fun penv ->
    if not quiet
    then
      begin
        let vss = List.rev (List.map List.rev uss) in
        List.iter2
          (fun xts xvs ->
            List.iter2
              (fun (x, sch) v ->
                Format.printf "@[<hov 2>val %t :>@ %t@ =@ %t@]@."
                              (Name.print x)
                              (print_annot sch)
                              (Runtime.print_value ~penv v))
              xts xvs)
          info vss
       end ;
    return ()

let topletrec_bind ~loc ~quiet ~print_annot info fxcs =
  let gs =
    List.map
      (fun (Rsyntax.Letrec_clause c) v -> Runtime.add_bound v (infer c))
      fxcs
  in
  Runtime.add_ml_value_rec gs >>= fun () ->
  if not quiet then
    (List.iter
      (fun (f, annot) ->
        Format.printf "@[<hov 2>val %t :>@ %t@]@."
                      (Name.print f)
                      (print_annot annot))
      info) ;
  return ()

let rec toplevel ~quiet ~print_annot {Location.thing=c;loc} =
  match c with

  | Rsyntax.RuleIsType (x, prems) ->
     Runtime.top_lookup_opens >>= fun opens ->
     Runtime.top_handle ~loc (premises prems (Runtime.return ())) >>=
       fun (premises, ()) ->
       let rule = Nucleus.form_rule_is_type premises in
       (if not quiet then
          Format.printf "@[<hov 2>Rule %t is postulated.@]@." (Ident.print ~opens ~parentheses:false x));
       Runtime.add_rule_is_type x rule

  | Rsyntax.RuleIsTerm (x, prems, c) ->
     Runtime.top_lookup_opens >>= fun opens ->
     Runtime.top_handle ~loc (premises prems (infer_is_type c)) >>=
       fun (premises, head) ->
       let rule = Nucleus.form_rule_is_term premises head in
       (if not quiet then
          Format.printf "@[<hov 2>Rule %t is postulated.@]@." (Ident.print ~opens ~parentheses:false x));
       Runtime.add_rule_is_term x rule

  | Rsyntax.RuleEqType (x, prems, boundary) ->
     Runtime.top_lookup_opens >>= fun opens ->
     Runtime.top_handle ~loc (premises prems (check_eq_type_boundary boundary)) >>=
       fun (premises, head) ->
       let rule = Nucleus.form_rule_eq_type premises head in
       (if not quiet then
          Format.printf "@[<hov 2>Rule %t is postulated.@]@." (Ident.print ~opens ~parentheses:false x));
       Runtime.add_rule_eq_type x rule

  | Rsyntax.RuleEqTerm (x, prems, boundary) ->
     Runtime.top_lookup_opens >>= fun opens ->
     Runtime.top_handle ~loc (premises prems (check_eq_term_boundary boundary)) >>=
       fun (premises, head) ->
       let rule = Nucleus.form_rule_eq_term premises head in
       (if not quiet then
          Format.printf "@[<hov 2>Rule %t is postulated.@]@." (Ident.print ~opens ~parentheses:false x));
       Runtime.add_rule_eq_term x rule

  | Rsyntax.DefMLType lst
  | Rsyntax.DefMLTypeRec lst ->
     Runtime.top_lookup_opens >>= fun opens ->
     (if not quiet then
        Format.printf "@[<hov 2>ML type%s %t declared.@]@."
          (match lst with [_] -> "" | _ -> "s")
          (Print.sequence (Path.print ~opens ~parentheses:true) "," lst)) ;
     return ()

  | Rsyntax.DeclOperation (op, k) ->
     Runtime.top_lookup_opens >>= fun opens ->
     (if not quiet then
        Format.printf "@[<hov 2>Operation %t is declared.@]@."
          (Path.print ~opens ~parentheses:true op)) ;
     return ()

  | Rsyntax.DeclExternal (x, sch, s) ->
     begin
       match External.lookup s with
       | None -> Runtime.error ~loc (Runtime.UnknownExternal s)
       | Some v ->
          Runtime.add_ml_value v >>= (fun () ->
           if not quiet then
             Format.printf "@[<hov 2>external %t :@ %t = \"%s\"@]@."
               (Name.print x)
               (print_annot () sch)
               s ;
           return ())
     end

  | Rsyntax.TopLet (info, clauses) ->
     let print_annot = print_annot () in
     toplet_bind ~loc ~quiet ~print_annot info clauses

  | Rsyntax.TopLetRec (info, fxcs) ->
     let print_annot = print_annot () in
     topletrec_bind ~loc ~quiet ~print_annot info fxcs

  | Rsyntax.TopComputation (c, sch) ->
     comp_value c >>= fun v ->
     Runtime.top_lookup_penv >>= fun penv ->
     if not quiet then
       Format.printf "@[<hov 2>- :@ %t@ =@ %t@]@."
           (print_annot () sch)
           (Runtime.print_value ~penv v) ;
     return ()

  | Rsyntax.TopDynamic (x, annot, c) ->
     comp_value c >>= fun v ->
     Runtime.add_dynamic x v

  | Rsyntax.TopNow (x,c) ->
     let xloc = x.Location.loc in
     comp_value x >>= fun x ->
     let x = Runtime.as_dyn ~loc:xloc x in
     comp_value c >>= fun v ->
     Runtime.top_now x v

  | Rsyntax.Open pth ->
     Runtime.top_open_path pth

  | Rsyntax.MLModule (mdl_name, cmds) ->
     if not quiet then Format.printf "@[<hov 2>Processing module %t@]@." (Name.print mdl_name) ;
     Runtime.as_ml_module (toplevels ~quiet ~print_annot cmds)

  | Rsyntax.Verbosity i -> Config.verbosity := i; return ()

and toplevels ~quiet ~print_annot =
  Runtime.top_fold
    (fun () -> toplevel ~quiet ~print_annot)
    ()
