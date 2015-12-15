(** Evaluation of computations *)

(** Auxiliary printing functions. *)

let print_term env e =
    let xs = Environment.used_names env in
      Tt.print_term xs e

let print_ty env t =
    let xs = Environment.used_names env in
      Tt.print_ty xs t

let print_value env v =
    let xs = Environment.used_names env in
      Value.print_value xs v

(** Notation for the monadic bind *)
let (>>=) = Value.bind

(** A filter that verifies the result is a term. *)
let as_term ~loc v =
  let e = Value.as_term ~loc v in
    Value.return e

let as_handler ~loc v =
  let e = Value.as_handler ~loc v in
  Value.return e

(** A helper function to install a beta hint for an atom. *)
let add_beta ~loc z ctx hyps e t env  =
  let hint_key = Hint.mk_beta ~loc env ctx hyps ([], (t, Tt.mk_atom ~loc z, e))  in
  Environment.add_beta hint_key env


(** Evaluate a computation -- infer mode. *)
let rec infer env (c',loc) =
  match c' with
    | Syntax.Bound i ->
       let v = Environment.lookup_bound i env in
       Value.return v

    | Syntax.Type ->
       let e = Tt.mk_type ~loc in
       let t = Tt.mk_type_ty ~loc in
       let et = Judgement.mk_term Context.empty e t in
       Value.return_term et

    | Syntax.Function (x, c) ->
       let f v =
         let env = Environment.add_bound x v env in
         infer env c
       in
       let v = Value.Closure f in
       Value.return v

    | Syntax.Rec (f, x, c) ->
       let rec g v =
         let env = Environment.add_bound f (Value.Closure g) env in
         let env = Environment.add_bound x v env in
         infer env c
       in
       Value.return (Value.Closure g)

    | Syntax.Tag (t, cs) ->
       let rec fold vs = function
         | [] ->
            let vs = List.rev vs in
            let v = Value.Tag (t, vs) in
            Value.return v
         | c :: cs ->
            infer env c >>= (fun v -> fold (v :: vs) cs)
       in
       fold [] cs

    | Syntax.Handler {Syntax.handler_val; handler_ops; handler_finally} ->
       let handler_val =
         begin match handler_val with
         | None -> None
         | Some (x, c) ->
            let f v =
              let env = Environment.add_bound x v env in
              infer env c
            in
            Some f
         end
       and handler_ops =
         begin
           let close2 x1 c v1 v2 =
             let env = Environment.add_bound x1 v1 env in
             let env = Environment.set_continuation v2 env in
             infer env c
           in
           List.map (fun (op, (x, c)) -> (op, close2 x c)) handler_ops
         end
       and handler_finally =
         begin match handler_finally with
         | None -> None
         | Some (x, c) -> 
            let f v =
              let env = Environment.add_bound x v env in
              infer env c
            in
            Some f
         end
       in
       let v = Value.Handler (Value.{handler_val; handler_ops; handler_finally}) in
       Value.return v

  | Syntax.Operation (op, c) ->
     infer env c >>= 
       (fun v ->
        let k u = Value.Return u in
        Value.Operation (op, v, k))

  | Syntax.With (c1, c2) ->
     infer env c1 >>= as_handler ~loc >>=
       (fun h ->
        let r = infer env c2 in
        handle_result env h r)

  | Syntax.Let (xcs, c) ->
     let_bind env xcs >>= (fun env -> infer env c)

  | Syntax.Assume ((x, t), c) ->
     check_ty env t >>= fun t ->
     let _, _ , env = Environment.add_fresh ~loc env x t in
     infer env c

  | Syntax.Where (c1, c2, c3) ->
    infer env c2 >>= as_term ~loc >>= fun j ->
    (* NB: we do not care why c2 normalises to an atom, only that it does *)
    Equal.Monad.run (Equal.as_atom env j) >>= fun ((ctxa, a, ta),_) ->
    infer env c1 >>= as_term ~loc >>= fun (ctx, e1, t1) ->
    let ctx = Context.join ~loc ctxa ctx in
    check env c3 (ctx, ta) >>= fun (ctx, e2) ->
    let ctx_s = Context.substitute ~loc a (ctx,e2,ta) in
    let te_s = Tt.instantiate [e2] (Tt.abstract [a] e1) in
    let ty_s = Tt.instantiate_ty [e2] (Tt.abstract_ty [a] t1) in
    let ctx_s = Context.restrict ctx_s (Tt.assumptions_term te_s) in
    let j_s = Judgement.mk_term ctx_s te_s ty_s in
    Value.return_term j_s

  | Syntax.Match (c, cases) ->
     infer env c >>=
       fun v ->
       let rec fold = function
         | [] ->
            Error.typing ~loc "No match found for %t" (print_value env v)
         | (xs, p, c) :: cases ->
            begin match Environment.match_pattern env xs p v with
                  | Some env -> infer env c
                  | None -> fold cases
            end
       in
       fold cases

  | Syntax.Beta (xscs, c) ->
    beta_bind env xscs >>= (fun env -> infer env c)

  | Syntax.Eta (xscs, c) ->
    eta_bind env xscs >>= (fun env -> infer env c)

  | Syntax.Hint (xscs, c) ->
    hint_bind env xscs >>= (fun env -> infer env c)

  | Syntax.Inhabit (xscs, c) ->
    inhabit_bind env xscs >>= (fun env -> infer env c)

  | Syntax.Unhint (xs, c) ->
    let env = Environment.unhint xs env in
    infer env c

  | Syntax.Whnf c ->
    infer env c >>= as_term ~loc >>= fun (ctx, e, t) ->
    Equal.Monad.run (Equal.whnf_ty env ctx t) >>= fun ((ctx,t),hyps) ->
    Equal.Monad.run (Equal.whnf env ctx e) >>= fun ((ctx,e),_) ->
    let j = Judgement.mk_term ctx (Tt.mention_atoms hyps e) t in
    Value.return_term j

  | Syntax.External s ->
     begin
       match External.lookup s with
       | None -> Error.runtime ~loc "unknown external %s" s
       | Some v -> Value.return v
     end

  | Syntax.Typeof c ->
    (* In future versions this is going to be a far less trivial computation,
       as it might actually fail when there is no way to name a type with a term. *)
    infer env c >>= as_term ~loc >>=
    (fun (ctx, _, Tt.Ty t) ->
     let j = Judgement.mk_term ctx t Tt.typ in
         Value.return_term j)

  | Syntax.Ascribe (c1, c2) ->
     check_ty env c2 >>= fun ((_,t') as t) ->
     check env c1 t >>= fun (ctx, e) ->
     let j = Judgement.mk_term ctx e t' in
     Value.return_term j

  | Syntax.Constant (x, cs) ->

    let yts, u =
      begin match Environment.lookup_constant x env with
      | Some ytsu -> ytsu
      | None -> Error.typing "unknown constant %t" (Name.print_ident x)
      end in
    let rec fold ctx es yts cs =
      match yts, cs with
      | [], [] ->
        let u = Tt.instantiate_ty es u
        and e = Tt.mk_constant ~loc x (List.rev es) in
        let eu = Judgement.mk_term ctx e u in
        Value.return_term eu

      | (y,(reducing,t))::yts, c::cs ->
        let t = Tt.instantiate_ty es t in
        let jt = Judgement.mk_ty ctx t in
        check env c jt >>= fun (ctx, e) ->
        (* TODO why are we doing this here? *)
        (if reducing
          then Equal.Monad.run (Equal.whnf env ctx e)
          else Value.return ((ctx, e), Name.AtomSet.empty)) >>= fun ((ctx,e),_) ->
        fold ctx (e :: es) yts cs

      | _::_, [] ->
        Error.typing ~loc "too few arguments in a primitive operation (%d missing)"
          (List.length yts)

      | _, _::_ ->
        Error.impossible ~loc "too many arguments in a primitive operation (%d extra)"
          (List.length cs)
    in
    fold Context.empty [] yts cs

  | Syntax.Lambda (xus, c) ->
     infer_lambda env ~loc xus c >>=
       (fun (ctx, lam, prod) -> Value.return_term (Judgement.mk_term ctx lam prod))

  | Syntax.Spine (c, []) ->
     infer env c >>= as_term ~loc >>= Value.return_term

  | Syntax.Spine (c, cs) ->
    let rec fold v cs =
      match v with
        | Value.Term j ->
          spine ~loc env j cs
        | Value.Closure f ->
          begin match cs with
            | [] -> Error.impossible ~loc "empty spine in Eval.infer"
            | [c] ->
              infer env c >>=
              f
            | c::(_::_ as cs) ->
              infer env c >>=
              f >>= fun v ->
              fold v cs
          end
        | Value.Ty _ | Value.Handler _ | Value.Tag _ ->
          Error.runtime ~loc "%t expressions cannot be applied" (Value.print_value_key v)
    in
    infer env c >>= fun v -> fold v cs

  | Syntax.Prod (xts, c) ->
    infer_prod env ~loc xts c

  | Syntax.Eq (c1, c2) ->
     infer env c1 >>= as_term ~loc:(snd c1) >>= fun (ctx, e1, t1') ->
     let t1 = Judgement.mk_ty ctx t1' in
     check env c2 t1 >>= fun (ctx, e2) ->
     let eq = Tt.mk_eq ~loc t1' e1 e2 in
     let typ = Tt.mk_type_ty ~loc in
     let j = Judgement.mk_term ctx eq typ in
     Value.return_term j

  | Syntax.Refl c ->
     infer env c >>= as_term ~loc:(snd c) >>= fun (ctxe, e, t) ->
     let e' = Tt.mk_refl ~loc t e
     and t' = Tt.mk_eq_ty ~loc t e e in
     let et' = Judgement.mk_term ctxe e' t' in
     Value.return_term et'

  | Syntax.Bracket c ->
    check_ty env c >>= fun (ctxt, t') ->
    let t' = Tt.mk_bracket ~loc t' in
    let typ = Tt.mk_type_ty ~loc in
    let j = Judgement.mk_term ctxt t' typ in
    Value.return_term j

  | Syntax.Inhab ->
    Error.typing ~loc "cannot infer the type of []"

  | Syntax.Signature xcs ->
    let rec fold env ctx ys ts xts = function
      | [] ->
        let xts = List.rev xts in
        let te = Tt.mk_signature ~loc xts in
        let typ = Tt.mk_type_ty ~loc in
        let j = Judgement.mk_term ctx te typ in
        Value.return_term j
      | (lbl,x,c) :: rem ->
        check_ty env c >>= fun (ctxt,t) ->
        Value.mk_abstractable ~loc ctxt ys >>= fun (ctxt,zs,es) ->
        let t = Tt.substitute_ty zs es t in
        let jt = Judgement.mk_ty ctxt t in
        let _, y, env = Environment.add_fresh ~loc env x jt in
        let ctxt = Context.abstract ~loc ctxt ys ts in
        let tabs = Tt.abstract_ty ys t in
        let ctx = Context.join ~loc ctx ctxt in
        fold env ctx (y :: ys) (t::ts) ((lbl, x, tabs) :: xts) rem
      in
    fold env Context.empty [] [] [] xcs

  | Syntax.Structure xcs ->
    let rec fold env ctx ys ts xtes = function
      | [] ->
        let xtes = List.rev xtes in
        let te = Tt.mk_structure ~loc xtes in
        let ty = Tt.mk_signature_ty ~loc (List.map (fun (l,x,t,_) -> l,x,t) xtes) in
        let j = Judgement.mk_term ctx te ty in
        Value.return_term j
      | (lbl,x,c) :: rem ->
        infer env c >>= as_term ~loc >>= fun (ctxt,te,ty) ->
        Value.mk_abstractable ~loc ctxt ys >>= fun (ctxt,zs,es) ->
        let te = Tt.substitute zs es te
        and ty = Tt.substitute_ty zs es ty in
        let jty = Judgement.mk_ty ctxt ty in
        let _, y, env = Environment.add_fresh ~loc env x jty in
        let ctxt = Context.abstract ~loc ctxt ys ts in
        let te_abs = Tt.abstract ys te
        and ty_abs = Tt.abstract_ty ys ty in
        let ctx = Context.join ~loc ctx ctxt in
        fold env ctx (y::ys) (ty::ts) ((lbl,x,ty_abs,te_abs)::xtes) rem
      in
    fold env Context.empty [] [] [] xcs

  | Syntax.Projection (c,p) ->
    infer env c >>= as_term ~loc >>= fun (ctx,te,ty) ->
    let jty = Judgement.mk_ty ctx ty in
    Equal.Monad.run (Equal.as_signature env jty) >>= fun ((ctx,xts),hyps) ->
    let te = Tt.mention_atoms hyps te in
    let ty = Tt.field_type ~loc xts te p in
    let te = Tt.mk_projection ~loc te xts p in
    let j = Judgement.mk_term ctx te ty in
    Value.return_term j

  | Syntax.Yield ->
    begin match Environment.lookup_continuation env with
      | Some y -> Value.return y
      | None -> Error.impossible ~loc "yield without continuation set"
    end

and require_equal ~loc env ((lctx,lte,lty) as ljdg) ((rctx,rte,rty) as rjdg)
                  (f : Context.t -> Name.AtomSet.t -> 'a Value.result) error : 'a Value.result =
  (let ctx = Context.join ~loc lctx rctx in
    Equal.Opt.run (Equal.equal_ty env ctx lty rty) >>= function
      | Some (ctx,hyps) -> Equal.Opt.run (Equal.equal env ctx lte rte lty) >>= begin function
        | Some (ctx,hyps') -> Value.return (Some (ctx,Name.AtomSet.union hyps hyps'))
        | None -> Value.return None
        end
      | None -> Value.return None) >>= function
  | Some (ctx,hyps) -> f ctx hyps
  | None ->
    let lval = Value.Term ljdg in
    let rval = Value.Term rjdg in
    let opval = Value.Tag (Name.make "pair", [lval;rval]) in
    let k v =
      let tsome = Name.make "some" in
      let tnone = Name.make "none" in
      match v with
        | Value.Tag (t, [v]) when (Name.eq_ident t tsome) ->
          let (ctxeq,eq,teq) = Value.as_term ~loc v in
          let tgoal = Tt.mk_eq_ty ~loc lty lte rte in
          if Tt.alpha_equal_ty teq tgoal
          then
            let ctx = Context.join ~loc ctxeq (Context.join ~loc lctx rctx) in (* user may have done something surprising somehow *)
            let hyps = Tt.assumptions_term eq in
            f ctx hyps
          else
            Error.typing ~loc:(eq.Tt.loc) "this expression should have type@ %t@ but has type@ %t"
                         (print_ty env tgoal) (print_ty env teq)
        | Value.Tag (t, []) when (Name.eq_ident t tnone) ->
          error ()
        | _ -> Error.typing ~loc "#equal returned unexpected value %t@ , expected eq option" (print_value env v)
    in
    Value.Operation ("equal", opval, k)

and require_equal_ty ~loc env (lctx,Tt.Ty lte) (rctx,Tt.Ty rte) f error : 'a Value.result =
  require_equal ~loc env (lctx,lte,Tt.mk_type_ty ~loc:(lte.Tt.loc))
                         (rctx,rte,Tt.mk_type_ty ~loc:(rte.Tt.loc))
                         f error

and check env ((c',loc) as c) (((ctx_check, t_check') as t_check) : Judgement.ty) : (Context.t * Tt.term) Value.result =
  match c' with

  | Syntax.Type
  | Syntax.Bound _
  | Syntax.Function _
  | Syntax.Rec _
  | Syntax.Handler _
  | Syntax.External _
  | Syntax.Tag _
  | Syntax.Where _
  | Syntax.With _
  | Syntax.Typeof _
  | Syntax.Match _
  | Syntax.Constant _
  | Syntax.Prod _
  | Syntax.Eq _
  | Syntax.Spine _
  | Syntax.Bracket _
  | Syntax.Signature _
  | Syntax.Projection _
  | Syntax.Yield ->
    (** this is the [check-infer] rule, which applies for all term formers "foo"
        that don't have a "check-foo" rule *)

    infer env c >>= as_term ~loc >>= fun (ctxe, e, t') ->
    let k ctx hyps = Value.return (ctx, Tt.mention_atoms hyps e) in
    require_equal_ty ~loc env t_check (ctxe,t') k
      (fun () -> Error.typing ~loc:(e.Tt.loc)
                              "this expression should have type@ %t@ but has type@ %t"
                              (print_ty env t_check') (print_ty env t'))

  | Syntax.Operation (op, c) ->
     infer env c >>= fun ve ->
     let k v =
       let (ctxe, e', t') = Value.as_term ~loc v in
       let k ctx hyps = Value.return (ctx, Tt.mention_atoms hyps e') in
       require_equal_ty ~loc env t_check (ctxe,t') k
         (fun () -> Error.typing ~loc:(e'.Tt.loc)
                                 "this expression should have type@ %t@ but has type@ %t"
                                 (print_ty env t_check') (print_ty env t'))
     in
     Value.Operation (op, ve, k)

  | Syntax.Let (xcs, c) ->
     let_bind env xcs >>= (fun env -> check env c t_check)

  | Syntax.Assume ((x, t), c) ->
     check_ty env t >>= fun t ->
     let _,_,env = Environment.add_fresh ~loc env x t in
     check env c t_check

  | Syntax.Beta (xscs, c) ->
     beta_bind env xscs >>= (fun env -> check env c t_check)

  | Syntax.Eta (xscs, c) ->
    eta_bind env xscs >>= (fun env -> check env c t_check)

  | Syntax.Hint (xscs, c) ->
    hint_bind env xscs >>= (fun env -> check env c t_check)

  | Syntax.Inhabit (xscs, c) ->
    inhabit_bind env xscs >>= (fun env -> check env c t_check)

  | Syntax.Unhint (xs, c) ->
    let env = Environment.unhint xs env in
    check env c t_check

  | Syntax.Whnf c ->
    check env c t_check >>= fun (ctx, e) ->
    Equal.Monad.run (Equal.whnf env ctx e) >>= fun ((ctx,e),_) ->
    Value.return (ctx, e)

  | Syntax.Ascribe (c1, c2) ->
     check_ty env c2 >>= fun (ctx',t') ->
     let k ctx hyps =
       let jt = Judgement.mk_ty ctx t' in
       check env c1 jt >>= fun (ctx,e) ->
       Value.return (ctx,Tt.mention_atoms hyps e)
     in
     require_equal_ty ~loc env t_check (ctx',t') k
       (fun () -> Error.typing ~loc:(snd c2)
                               "this type should be equal to@ %t"
                               (print_ty env t_check'))

  | Syntax.Lambda (abs, c) ->
    check_lambda env ~loc t_check abs c

  | Syntax.Refl c ->
    Equal.Monad.run (Equal.as_eq env t_check) >>= fun ((ctx, t', e1, e2),hyps) ->
    let t = Judgement.mk_ty ctx t' in
    check env c t >>= fun (ctx, e) ->
    let k1 ctx hyps1 =
      let k2 ctx hyps2 =
        let e = Tt.mk_refl ~loc t' e in
        let e = Tt.mention_atoms hyps e in
        let e = Tt.mention_atoms hyps1 e in
        let e = Tt.mention_atoms hyps2 e in
        Value.return (ctx, e)
      in
      require_equal ~loc env (ctx,e,t') (ctx,e2,t') k2
        (fun () -> Error.typing ~loc
                                "failed to check that the term@ %t is equal to@ %t"
                                (print_term env e) (print_term env e2))
   in
   require_equal ~loc env (ctx,e,t') (ctx,e1,t') k1
     (fun () -> Error.typing ~loc
                             "failed to check that the term@ %t is equal to@ %t"
                             (print_term env e) (print_term env e1))

  | Syntax.Inhab ->
     Equal.Monad.run (Equal.as_bracket env t_check) >>= fun ((ctx,t'),hyps) ->
     let t = Judgement.mk_ty ctx t' in
     Equal.Opt.run (Equal.inhabit_bracket ~subgoals:true ~loc env t) >>=
       begin function
         | Some ((ctx,_),hyps') ->
            let e = Tt.mk_inhab ~loc t' in
            let e = Tt.mention_atoms hyps e in
            let e = Tt.mention_atoms hyps' e in
            Value.return (ctx, e)
         | None -> Error.typing ~loc "do not know how to inhabit %t"
                                (print_ty env t')
       end

  | Syntax.Structure xcs ->
     Equal.Monad.run (Equal.as_signature env t_check) >>= fun ((ctx, yts),hyps) ->
     let rec fold env ctx ys ts xtes = function
       | [], [] ->
          let ctx = Context.abstract ~loc ctx ys ts in
          let xtes = List.rev xtes in
          let str = Tt.mk_structure ~loc xtes in
          Value.return (ctx, Tt.mention_atoms hyps str)

       | (lbl1, _, c) :: xcs, (lbl2, x, ty) :: yts ->
          if not (Name.eq_label lbl1 lbl2)
          then Error.typing ~loc "expected field %t but got field %t"
                            (Name.print_label lbl2)
                            (Name.print_label lbl1)
          else
            let ty_inst = Tt.unabstract_ty ys ty in
            let jty = Judgement.mk_ty ctx ty_inst in
            check env c jty >>= fun (ctx, e) ->
            Value.mk_abstractable ~loc ctx ys >>= fun (ctx,zs,es) ->
            let e = Tt.substitute zs es e in
            let ctx, y, env = Environment.add_fresh ~loc env x jty in
            let hyps = Name.AtomSet.add y (Tt.assumptions_term e) in
            let env = add_beta ~loc y ctx hyps e ty_inst env in
            let e_abs = Tt.abstract ys e in
            fold env ctx (y::ys) (ty_inst::ts) ((lbl2,x,ty,e_abs) :: xtes) (xcs, yts)

       | _::_, [] -> Error.typing ~loc "this structure has too many fields"
       | [], _::_ -> Error.typing ~loc "this structure has too few fields"
     in
     fold env ctx [] [] [] (xcs, yts)


and handle_result env {Value.handler_val; handler_ops; handler_finally} r =
  begin match r with
  | Value.Return v ->
     begin match handler_val with
     | Some f -> f v
     | None -> r
     end
  | Value.Operation (op, ve, cont) ->
     let h = Value.{handler_val; handler_ops; handler_finally=None} in
     let wrap cont v = handle_result env h (cont v) in
     begin
       try
         let f = List.assoc op handler_ops in
         f ve (Value.Closure (wrap cont))
       with
         Not_found ->
          Value.Operation (op, ve, (wrap cont))
     end
  end >>=
  (fun v ->
     match handler_finally with
     | Some f -> f v
     | None -> Value.Return v)

and infer_lambda env ~loc xus c =
  let rec fold env ctx ys ts xws  = function
      | [] ->
         infer env c >>= as_term ~loc:(snd c) >>= fun (ctxe, e, t) ->
         Value.context_abstract ~loc ctxe ys ts >>= fun (ctxe,zs,es) ->
         let ctx = Context.join ~loc ctx ctxe in
         let e = Tt.abstract ys (Tt.substitute zs es e) in
         let t = Tt.abstract_ty ys (Tt.substitute_ty zs es t) in
         let xws = List.rev xws in
         let lam = Tt.mk_lambda ~loc xws e t in
         let prod = Tt.mk_prod_ty ~loc xws t in
         Value.return (ctx, lam, prod)
      | (x, None) :: _ ->
         Error.runtime ~loc "cannot infer the type of %t" (Name.print_ident x)
      | (x, Some c) :: xus ->
         check_ty env c >>= fun (ctxu, ((Tt.Ty {Tt.loc=uloc;_}) as u)) ->
         Value.mk_abstractable ~loc ctxu ys >>= fun (ctxu,zs,es) ->
         let u = Tt.substitute_ty zs es u in
         let ju = Judgement.mk_ty ctxu u in
         let _, y, env = Environment.add_fresh ~loc:uloc env x ju in
         let ctxu = Context.abstract ~loc ctxu ys ts in
         let u_abs = Tt.abstract_ty ys u in
         let ctx = Context.join ~loc ctx ctxu in
         fold env ctx (y :: ys) (u::ts) ((x, u_abs) :: xws) xus
  in
  fold env Context.empty [] [] [] xus

and infer_prod env ~loc xus c =
  let rec fold env ctx ys ts xws  = function
      | [] ->
        check_ty env c >>= fun (ctxt, t) ->
        Value.context_abstract ~loc ctxt ys ts >>= fun (ctxt,zs,es) ->
        let ctx = Context.join ~loc ctx ctxt in
        let t = Tt.abstract_ty ys (Tt.substitute_ty zs es t) in
        let xws = List.rev xws in
        let prod = Tt.mk_prod ~loc xws t in
        let typ = Tt.mk_type_ty ~loc in
        let j = Judgement.mk_term ctx prod typ in
        Value.return_term j
      | (x, c) :: xus ->
        check_ty env c >>= fun (ctxu, ((Tt.Ty {Tt.loc=uloc;_}) as u)) ->
        Value.mk_abstractable ~loc ctxu ys >>= fun (ctxu,zs,es) ->
        let u = Tt.substitute_ty zs es u in
        let ju = Judgement.mk_ty ctxu u in
        let _, y, env = Environment.add_fresh ~loc:uloc env x ju in
        let ctxu = Context.abstract ~loc ctxu ys ts in
        let u_abs = Tt.abstract_ty ys u in
        let ctx = Context.join ~loc ctx ctxu in
        fold env ctx (y :: ys) (u::ts) ((x, u_abs) :: xws) xus
  in
  fold env Context.empty [] [] [] xus


and check_lambda env ~loc ((ctx_check, t_check') as t_check) abs body : (Context.t * Tt.term) Value.result =
  (* If the abstractions are fully annotated with types then we
     infer the type of the lambda and compare it to [t],
     otherwise we express [t] as a product and descend into
     the abstraction. *)

  let all_tagged = List.for_all (function (_, None) -> false | (_, Some _) -> true) abs in

  if all_tagged then
    begin
      (* try to infer and check equality. this might not be the end of the
         story, [as_*] could be operations *)
      (* for instance, an alternative would be to make a fresh pi-type and check
         whether the type at hand [t] is equal to the fresh pi by a general hint,
         and then continue with that one *)

      (* XXX this generalisation should be done also in [fold] below and in
         [spine], same for other [as_*] functions  *)

      infer_lambda env ~loc abs body >>= fun (ctxe, e, t') ->
      let k ctx hyps = Value.return (ctx, Tt.mention_atoms hyps e) in
      require_equal_ty ~loc env t_check (ctxe,t') k
        (fun () -> Error.typing ~loc
                                "this expression is an abstraction but should have type %t"
                                (print_ty env t_check'))
    end
  else (* not all_tagged *)
    begin
      (Equal.Monad.run (Equal.as_prod env t_check) >>= function
        | ((_, (_::_, _)),_) as ctx_xtst -> Value.return ctx_xtst
        | ((_, ([], _)),_) -> Error.typing ~loc "this type %t should be a product" (print_ty env t_check')
      ) >>= fun ((ctx, (zus, t_body)),hyps) ->

      (** [ys] are what got added to the environment, [xts] are what should be
          used to check the body, [abs] comes from the binder, [zus] come from
          the type [t] we're checking against, [hyps] ensure that previous
          [abs] and [zus] are equal *)
      let rec fold env ctx hyps ys ts xts abs zus =

        let finally t_body =
          let t_body' = Tt.unabstract_ty ys t_body in
          let j_t_body' = Judgement.mk_ty ctx t_body' in
          check env body j_t_body' >>= fun (ctx, e) ->
          Value.context_abstract ~loc ctx ys ts >>= fun (ctx,zs,es) ->
          let e = Tt.abstract ys (Tt.substitute zs es e) in
          let hyps = List.fold_left (fun hyps y -> Name.AtomSet.remove y hyps) hyps ys in
          let xts = List.rev xts in
          Value.return (ctx, Tt.mention_atoms hyps (Tt.mk_lambda ~loc xts e t_body))
        in

        match abs, zus with
        | (x,t)::abs, (z,u)::zus ->

          let u = Tt.unabstract_ty ys u in

          let k ctx hyps' t =
            let jt = Judgement.mk_ty ctx t in
            let ctx, y, env = Environment.add_fresh ~loc env x jt in
            let t_abs = Tt.abstract_ty ys t in
            fold env ctx (Name.AtomSet.union hyps hyps') (y::ys) (t::ts) ((x,t_abs)::xts) abs zus in

          begin match t with
            | None -> Print.debug "untagged variable %t in lambda, using %t as type"
                        (Name.print_ident x) (print_ty env u);
               k ctx Name.AtomSet.empty u

            | Some c ->
               check_ty env c >>= fun (ctxt, t) ->
               Value.mk_abstractable ~loc ctxt ys >>= fun (ctxt,zs,es) ->
               let t = Tt.substitute_ty zs es t in
               require_equal_ty ~loc env (ctxt,t) (ctx,u) (fun ctx hyps -> k ctx hyps t)
                 (fun () -> Error.typing ~loc
                                         "in this lambda, the variable %t should have a type@ %t\nFound type@ %t"
                                         (Name.print_ident x)
                                         (print_ty env u)
                                         (print_ty env t))
          end

        | [], [] -> finally t_body

        | [], _::_ -> finally (Tt.mk_prod_ty ~loc zus t_body)

        | _::_, [] ->
           Error.typing ~loc
                        "tried to check against a type with a too short abstraction@ %t"
                        (print_ty env t_check')
      in
      fold env ctx_check hyps [] [] [] abs zus
    end (* not all_tagged *)

(** Suppose [e] has type [t], and [cs] is a list of computations [c1, ..., cn].
    Then [spine env e t cs] computes [xeus], [u] and [v] such that we can make
    a spine from [e], [xeus] and [u], and the type of the resulting expression
    is [v].
  *)
and spine ~loc env ((_, e_head, t_head) as j_head) cs =
  Equal.Monad.run (Equal.as_prod env (Judgement.typeof j_head)) >>= begin function
    | ((_, (_::_, _)),_) as ctx_xtst -> Value.return ctx_xtst
    | ((_, ([], _)),_) ->
       Error.typing ~loc "this expression is applied but its type is not a product"
  end >>= fun ((ctx, (xts, t_result)),hyps) ->
  let e_head = Tt.mention_atoms hyps e_head in
  let rec fold es xus ctx xts cs =
  match xts, cs with
  | xts, [] ->
     let xus = List.rev xus in
     let u = Tt.mk_prod_ty ~loc xts t_result in
     let e = Tt.mk_spine ~loc e_head xus u (List.rev es)
     and v = Tt.instantiate_ty es u in
     let j = Judgement.mk_term ctx e v in
     Value.return_term j
  | (x, t)::xts, c::cs ->
     let t' = Tt.instantiate_ty es t in
     check env c (Judgement.mk_ty ctx t') >>= fun (ctx, e) ->
     fold (e :: es) ((x,t) :: xus) ctx xts cs
  | [], ((_ :: _) as cs) ->
     let xus = List.rev xus in
     let e = Tt.mk_spine ~loc e_head xus t_result (List.rev es)
     and t = Tt.instantiate_ty es t_result in
     let j = Judgement.mk_term ctx e t in
     spine ~loc env j cs
  in
  fold [] [] ctx xts cs

and let_bind env xcs =
  let rec fold env' = function
    | [] -> Value.return env'
    | (x,c) :: xcs ->
      (* NB: must use [env] in [infer env c], not [env'] because this is parallel let *)
      infer env c >>= fun v ->
      let env' = Environment.add_bound x v env' in
      fold env' xcs
    in
  fold env xcs

and beta_bind env xscs =
  let rec fold xshs = function
    | (xs, ((_,loc) as c)) :: xscs ->
      infer env c >>= as_term ~loc:(snd c) >>= fun ((_,e,_) as je) ->
      let t = Judgement.typeof je in
      Equal.Monad.run (Equal.as_universal_eq env t) >>= fun ((ctx, (xts, (t, e1, e2))),hyps) ->
      let hyps = Name.AtomSet.union hyps (Tt.assumptions_term e) in
      let h = Hint.mk_beta ~loc env ctx hyps (xts, (t, e1, e2)) in
      fold ((xs, h) :: xshs) xscs
    | [] ->
       let env = Environment.add_betas xshs env in
       Print.debug "Installed beta hints@ %t" (Print.sequence (fun (tags, (_, h)) ppf ->
         Print.print ppf "@[tags: %s ;@ hint: %t@]"
           (String.concat " " tags) (Pattern.print_beta_hint [] h)) "," xshs);
       Value.return env
  in fold [] xscs

and eta_bind env xscs =
  let rec fold xshs = function
    | (xs, ((_,loc) as c)) :: xscs ->
      infer env c >>= as_term ~loc:(snd c) >>= fun ((_,e,_) as j) ->
      let jt = Judgement.typeof j in
      Equal.Monad.run (Equal.as_universal_eq env jt) >>= fun ((ctx, (xts, (t, e1, e2))),hyps) ->
      let hyps = Name.AtomSet.union hyps (Tt.assumptions_term e) in
      let h = Hint.mk_eta ~loc env ctx hyps (xts, (t, e1, e2)) in
      fold ((xs, h) :: xshs) xscs
    | [] -> let env = Environment.add_etas xshs env in
      Print.debug "Installed eta hints@ %t" (Print.sequence (fun (tags, (_, h)) ppf ->
        Print.print ppf "@[tags: %s ;@ hint: %t@]"
          (String.concat " " tags) (Pattern.print_eta_hint [] h)) "," xshs);
      Value.return env
  in fold [] xscs

and hint_bind env xscs =
  let rec fold xshs = function
    | (xs, ((_,loc) as c)) :: xscs ->
      infer env c >>= as_term ~loc:(snd c) >>= fun ((_,e,_) as j) ->
      let jt = Judgement.typeof j in
      Equal.Monad.run (Equal.as_universal_eq env jt) >>= fun ((ctx, (xts, (t, e1, e2))),hyps) ->
      let hyps = Name.AtomSet.union hyps (Tt.assumptions_term e) in
      let h = Hint.mk_general ~loc env ctx hyps (xts, (t, e1, e2)) in
      fold ((xs, h) :: xshs) xscs
    | [] -> let env = Environment.add_generals xshs env in
      Print.debug "Installed hints@ %t"
        (Print.sequence (fun (tags, (k, h)) ppf ->
             Print.print ppf "@[tags: %s ; keys: %t ;@ hint: %t@]"
               (String.concat " " tags)
               (Pattern.print_general_key k)
               (Pattern.print_hint [] h)) "," xshs);
      Value.return env
  in fold [] xscs

and inhabit_bind env xscs =
  let rec fold xshs = function
    | (xs, ((_,loc) as c)) :: xscs ->
      infer env c >>= as_term ~loc:(snd c) >>= fun ((_,e,_) as j) ->
      let jt = Judgement.typeof j in
      Equal.Monad.run (Equal.as_universal_bracket env jt) >>= fun ((ctx, (xts, t)),hyps) ->
      let hyps = Name.AtomSet.union hyps (Tt.assumptions_term e) in
      let h = Hint.mk_inhabit ~loc env ctx hyps (xts, t) in
      fold ((xs, h) :: xshs) xscs
    | [] -> let env = Environment.add_inhabits xshs env in
      Print.debug "Installed inhabit hints@ %t"
        (Print.sequence (fun (tags, (_, h)) ppf ->
             Print.print ppf "@[tags: %s ;@ hint: %t@]"
               (String.concat " " tags)
               (Pattern.print_inhabit_hint [] h)) "," xshs);
      Value.return env
  in fold [] xscs

and check_ty env c : Judgement.ty Value.result =
  check env c Judgement.ty_ty >>=
  (fun (ctx, e) ->
   let t = Tt.ty e in
   let j = Judgement.mk_ty ctx t in
   Value.return j)

(** Top-level handler. It returns a value, or reports a run-time error if an unhandled
    operation is encountered. Note that this is a recursive handler which keeps handling
    until a value is returned. *)
let rec top_handle ~loc env = function
  | Value.Return v -> v
  | Value.Operation (op, v, k) ->
     begin match Environment.lookup_handle op env with
      | None -> Error.runtime ~loc "unhandled operation %t" (Name.print_op op)
      | Some (x, c) ->
         let r = infer (Environment.add_bound x v env) c >>= k in
         top_handle ~loc env r
     end

let comp_value env ((_, loc) as c) =
  let r = infer env c in
  top_handle ~loc env r

let comp_ty env ((_,loc) as c) =
  let r = check_ty env c in
  top_handle ~loc env r

