
module I = Input


(** Abstract syntax of terms as given by the user. *)
type term = term' * Common.position
and term' =
  | Var of int
  | Type
  | Lambda of Common.variable * term option * term
  | Pi of Common.variable * term * term
  | App of term * term
  | Ascribe of term * term
  | Operation of operation_tag * term list
  | Handle of term * handler

and operation_tag = I.operation_tag =
  | Inhabit

and computation = computation' * Common.position
and computation' =
  | Return of term
  | Let of Common.variable * term * computation

and handler =
   (operation_tag * term list * computation) list

type toplevel = toplevel' * Common.position
and toplevel' =
  | TopDef of Common.variable * term
  | TopParam of Common.variable list * term
  | Context
  | Help
  | Quit



(** Desugaring of input syntax to internal  *)

(** [index ~loc x xs] finds the location of [x] in the list [xs]. *)
let index ~loc x =
  let rec index k = function
    | [] -> Error.typing ~loc "unknown identifier %s" x
    | y :: ys -> if x = y then k else index (k + 1) ys
  in
    index 0

(** [doExpr xs e] converts an expression of type [I.expr] to type [expr] by
    replacing names in [e] with de Bruijn indices. Here [xs] is the list of names
    currently in scope (i.e., Context.names) *)
let rec doExpr xs (e, loc) =
  (match e with
    | I.Var x -> Var (index ~loc x xs)
    | I.Type  -> Type
    | I.Pi (x, t1, t2) -> Pi (x, doExpr xs t1, doExpr (x :: xs) t2)
    | I.Lambda (x, None  , e) -> Lambda (x, None, doExpr (x :: xs) e)
    | I.Lambda (x, Some t, e) -> Lambda (x, Some (doExpr xs t), doExpr (x :: xs) e)
    | I.App (e1, e2)   -> App (doExpr xs e1, doExpr xs e2)
    | I.Ascribe (e, t) -> Ascribe (doExpr xs e, doExpr xs t)
    | I.Operation (optag, terms) -> Operation (optag, List.map (doExpr xs) terms)
    | I.Handle (term, h) -> Handle (doExpr xs term, handler xs h)
  ),
  loc


and doComputation xs (c, loc) =
  (match c with
    | I.Return e -> Return (doExpr xs e)
    | I.Let (x, term1, c2) -> Let (x, doExpr xs term1, doComputation (x::xs) c2)),
  loc

and handler xs lst = List.map (handler_case xs) lst

and handler_case xs (optag, terms, c) =
  (optag, List.map (doExpr xs) terms, doComputation xs c)

