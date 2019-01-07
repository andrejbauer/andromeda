(** Desugared input syntax *)

(** Bound variables are de Bruijn indices *)
type bound = int

(** ML type declarations are referred to by de Bruijn levels *)
type level = int

type 'a located = 'a Location.located

type ml_judgement =
  | ML_IsType
  | ML_IsTerm
  | ML_EqType
  | ML_EqTerm

type ml_abstracted_judgement =
  | ML_NotAbstract of ml_judgement
  | ML_Abstract of ml_abstracted_judgement

type ml_ty = ml_ty' located
and ml_ty' =
  | ML_Arrow of ml_ty * ml_ty
  | ML_Prod of ml_ty list
  | ML_TyApply of Path.t * level * ml_ty list
  | ML_Handler of ml_ty * ml_ty
  | ML_Ref of ml_ty
  | ML_Dynamic of ml_ty
  | ML_Judgement of ml_abstracted_judgement
  | ML_String
  | ML_Bound of bound
  | ML_Anonymous

type ml_schema = ml_schema' located
and ml_schema' = ML_Forall of Name.t option list * ml_ty

type arg_annotation =
  | Arg_annot_none
  | Arg_annot_ty of ml_ty

type let_annotation =
  | Let_annot_none
  | Let_annot_schema of ml_schema

type tt_pattern = tt_pattern' located
and tt_pattern' =
  | Patt_TT_Anonymous
  | Patt_TT_Var of Name.t
  | Patt_TT_As of tt_pattern * tt_pattern
  | Patt_TT_Constructor of Path.t * tt_pattern list
  | Patt_TT_GenAtom of tt_pattern
  | Patt_TT_IsType of tt_pattern
  | Patt_TT_IsTerm of tt_pattern * tt_pattern
  | Patt_TT_EqType of tt_pattern * tt_pattern
  | Patt_TT_EqTerm of tt_pattern * tt_pattern * tt_pattern
  | Patt_TT_Abstraction of Name.t option * tt_pattern * tt_pattern

type ml_pattern = ml_pattern' located
and ml_pattern' =
  | Patt_Anonymous
  | Patt_Var of Name.t
  | Patt_As of ml_pattern * ml_pattern
  | Patt_Judgement of tt_pattern
  | Patt_Constructor of Path.t * ml_pattern list
  | Patt_Tuple of ml_pattern list

(** Desugared computations *)
type comp = comp' located
and comp' =
  | Open of bound * comp
  | Bound of bound
  | Function of Name.t * arg_annotation * comp
  | Handler of handler
  | MLConstructor of Path.t * comp list
  | Tuple of comp list
  | Operation of Path.t * comp list
  | With of comp * comp
  | Let of let_clause list * comp
  | LetRec of letrec_clause list * comp
  | MLAscribe of comp * ml_schema
  | Now of comp * comp * comp
  | Current of comp
  | Lookup of comp
  | Update of comp * comp
  | Ref of comp
  | Sequence of comp * comp
  | Assume of (Name.t option * comp) * comp
  | Match of comp * match_case list
  | Ascribe of comp * comp
  | TTConstructor of Path.t * comp list
  | Apply of comp * comp
  | Abstract of Name.t * comp option * comp
  | Substitute of comp * comp
  | Yield of comp
  | String of string
  | Occurs of comp * comp
  | Context of comp
  | Natural of comp

and let_clause =
  | Let_clause of ml_pattern * let_annotation * comp (* [let (?p :> t) = c] *)

and letrec_clause =
  | Letrec_clause of Name.t * (Name.t * arg_annotation) * let_annotation * comp

and handler = {
  handler_val: match_case list;
  handler_ops: match_op_case list Ident.map;
  handler_finally : match_case list;
}

and match_case = ml_pattern * comp option * comp

(** Match multiple patterns at once, with shared pattern variables *)
and match_op_case = ml_pattern list * tt_pattern option * comp

type ml_tydef =
  | ML_Sum of (Name.t * ml_ty list) list
  | ML_Alias of ml_ty

type local_context = (Name.t * comp) list

type premise = premise' located
and premise' =
  | PremiseIsType of Name.t option * local_context
  | PremiseIsTerm of Name.t option * local_context * comp
  | PremiseEqType of Name.t option * local_context * (comp * comp)
  | PremiseEqTerm of Name.t option * local_context * (comp * comp * comp)

(** Desugared toplevel commands *)
type toplevel = toplevel' located
and toplevel' =
  | RuleIsType of Name.t * premise list
  | RuleIsTerm of Name.t * premise list * comp
  | RuleEqType of Name.t * premise list * (comp * comp)
  | RuleEqTerm of Name.t * premise list * (comp * comp * comp)
  | DefMLType of (Name.t * (Name.t option list * ml_tydef)) list
  | DefMLTypeRec of (Name.t * (Name.t option list * ml_tydef)) list
  | DeclOperation of Name.t * (ml_ty list * ml_ty)
  | DeclExternal of Name.t * ml_schema * string
  | TopLet of let_clause list
  | TopLetRec of letrec_clause list
  | TopComputation of comp
  | TopDynamic of Name.t * arg_annotation * comp
  | TopNow of comp * comp
  | Verbosity of int
  | MLModules of (Name.t * toplevel list) list
