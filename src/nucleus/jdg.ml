module ConstantMap = Name.IdentMap
module SignatureMap = Name.IdentMap

type env = {
  constants : Tt.ty ConstantMap.t;
  signatures : Tt.sig_def SignatureMap.t
}

let empty = {
  constants = ConstantMap.empty;
  signatures = SignatureMap.empty;
}

type term = Term of Context.t * Tt.term * Tt.ty

type atom = JAtom of Context.t * Name.atom

type ty = Ty of Context.t * Tt.ty

let typeof (Term (ctx, _, t)) = Ty (ctx, t)

let atom_ty (JAtom (ctx,x)) =
  match Context.lookup_ty x ctx with
    | Some t ->
      Ty (ctx,t)
    | None ->
      Error.impossible ~loc:Location.unknown "Bad atom judgement"

let atom_term (JAtom (ctx,x)) =
  match Context.lookup_ty x ctx with
    | Some t ->
      Term (ctx,Tt.mk_atom ~loc:Location.unknown x,t)
    | None ->
      Error.impossible ~loc:Location.unknown "Bad atom judgement"

let term_of_ty (Ty (ctx,Tt.Ty ({Tt.loc=loc;_} as t))) = Term (ctx,t,Tt.mk_type_ty ~loc)

let mk_term ctx e t = Term (ctx, e, t)

let mk_ty ctx t = Ty (ctx, t)

let ty_ty = Ty (Context.empty, Tt.typ)

let strengthen (Term (ctx,e,t)) =
  let hyps = Name.AtomSet.union (Tt.assumptions_term e) (Tt.assumptions_ty t) in
  let ctx = Context.restrict ctx hyps in
  Term (ctx,e,t)

let print_term ~penv ?max_level (Term (ctx, e,t)) ppf =
  Print.print ?max_level ~at_level:Level.jdg ppf
              "%t%s @[<hv>@[<hov>%t@]@;<1 -2>: @[<hov>%t@]@]"
              (Context.print ~penv ctx)
              (Print.char_vdash ())
              (Tt.print_term ~penv ~max_level:Level.highest e)
              (Tt.print_ty ~penv ~max_level:Level.highest t)

(** Environment *)
let constant_type c env =
  ConstantMap.find c env.constants

let signature_def s env =
  SignatureMap.find s env.signatures

let add_constant c t env =
  {env with constants = ConstantMap.add c t env.constants}

let add_signature s def env =
  {env with signatures = SignatureMap.add s def env.signatures}

(** Destructors *)
type 'a abstraction = atom * 'a

type signature = Name.signature * (atom, term) Tt.constrain list

type structure = ty * term list

type sig_def = (Name.label * Name.atom * ty) list

type shape =
  | Type
  | Atom of atom
  | Constant of Name.constant
  | Prod of ty abstraction
  | Lambda of term abstraction
  | Apply of term * term
  | Eq of term * term
  | Refl of term
  | Signature of signature
  | Structure of structure
  | Projection of term * Name.label


let mk_fresh x (Ty (ctx,a)) =
  let y,ctx = Context.add_fresh ctx x a in
  ctx,y,JAtom (ctx,y)

let shape_sig ~loc ctx ((s, shares) : Tt.signature) (def : Tt.sig_def) : signature =
  (* [vs] instantiate types from the signature definition, [ys] instantiate constraint terms *)
  let rec fold ctx vs ys shares = function
    | [] ->
      let shares = List.rev shares in
      (s, shares)
    | (Tt.Unconstrained x, (_, _, t)) :: rem ->
      let t = Tt.instantiate_ty vs t in
      let y, ctx = Context.add_fresh ctx x t in
      let e = Tt.mk_atom ~loc y in
      fold ctx (e :: vs) (y :: ys) (Tt.Unconstrained (JAtom (ctx, y)) :: shares) rem
    | (Tt.Constrained e, (_, _, t)) :: rem ->
      let t = Tt.instantiate_ty vs t
      and e = Tt.unabstract ys e in
      let j = mk_term ctx e t in
      fold ctx (e :: vs) ys ((Tt.Constrained j) :: shares) rem
  in
  fold ctx [] [] [] (List.combine shares def)

let shape_struct ~loc ctx ((s, _) as str : Tt.structure) (def : Tt.sig_def) : structure =
  let s = Tt.mk_signature_ty ~loc s in
  let s = mk_ty ctx s in
  let fields = Tt.struct_combine ~loc str in
  let rec fold vs js = function
    | [] ->
      let js = List.rev js in
      (s, js)
    | (Tt.Shared e, _) :: fields ->
      fold (e :: vs) js fields
    | (Tt.Explicit e, (_, _, t)) :: fields ->
      let t = Tt.instantiate_ty vs t in
      let j = mk_term ctx e t in
      fold (e :: vs) (j :: js) fields
  in
  fold [] [] (List.combine fields def)

let shape ~loc env (Term (ctx,e,t)) =
  match e.Tt.term with
    | Tt.Type -> Type

    | Tt.Atom x -> Atom (JAtom (ctx,x))

    | Tt.Constant c -> Constant c

    | Tt.Prod ((x,a),b) ->
      let ja = mk_ty ctx a in
      let ctx,y,jy = mk_fresh x ja in
      let b = Tt.unabstract_ty [y] b in
      let jb = mk_ty ctx b in
      Prod (jy,jb)

    | Tt.Lambda ((x,a),(e,b)) ->
      let ja = mk_ty ctx a in
      let ctx,y,jy = mk_fresh x ja in
      let b = Tt.unabstract_ty [y] b
      and e = Tt.unabstract [y] e in
      let je = mk_term ctx e b in
      Lambda (jy,je)


    | Tt.Apply (e1,((x,a),b),e2) ->
      let je2 = mk_term ctx e2 a in
      let prod = Tt.mk_prod_ty ~loc:e.Tt.loc x a b in
      let je1 = mk_term ctx e1 prod in
      Apply (je1,je2)

    | Tt.Eq (a,e1,e2) ->
      let je1 = mk_term ctx e1 a
      and je2 = mk_term ctx e2 a in
      Eq (je1,je2)

    | Tt.Refl (a,e) ->
      let e = mk_term ctx e a in
      Refl e

    | Tt.Signature ((s, _) as si) ->
      let def = signature_def s env in
      let si = shape_sig ~loc ctx si def in
      Signature si

    | Tt.Structure (((s, _), _) as str) ->
      let def = signature_def s env in
      let str = shape_struct ~loc ctx str def in
      Structure str

    | Tt.Projection (e,xts,l) ->
      let t = Tt.mk_signature_ty ~loc:e.Tt.loc xts in
      let je = mk_term ctx e t in
      Projection (je,l)

    | Tt.Bound _ -> Error.impossible ~loc:e.Tt.loc "Unbound variable in judgement"

let shape_ty ~loc env j = shape ~loc env (term_of_ty j)

