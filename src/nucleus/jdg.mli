(** A judgement context. *)
type ctx

(** Possibly abstracted judgement that something is a term, i.e.,
    [ctx |- e : t] or [ctx |- {x1 : t1} .... {xn : tn} (e : t)] *)
type is_term

(** Judgement [(x : t) in ctx] *)
type is_atom

(** Possibly abstracted judgement [ctx |- t type] *)
type is_type

(** Possibly abstracted judgement [ctx |- e1 == e2 : t] *)
type eq_term

(** Possibly abstracted judgement [ctx |- t1 == t2] *)
type eq_type

(** An argument to a term or type constructor *)
type premise =
  | PremiseIsType of is_type
  | PremiseIsTerm of is_term
  | PremiseEqType of eq_type
  | PremiseEqTerm of eq_term

(** Contains enough information to construct a new judgement *)
type shape_is_term =
  | Atom of is_atom
  | TermConstructor of Name.constructor * premise list
  | TermAbstract of is_atom * is_term
  (* obsolete *)
  | Constant of Name.constant

and shape_is_type =
  | TypeConstructor of Name.constructor * premise list
  | TypeAbstract of is_atom * is_type
  (* obsolete *)
  | El of is_term
  | Type (* universe *)

module Ctx : sig
  (** The type of contexts. *)
  type t = ctx

  val add_fresh : loc:Location.t -> is_type -> Name.ident -> is_atom

  (** [elements ctx] returns the elements of [ctx] sorted into a list so that all dependencies
      point forward in the list, ie the first atom does not depend on any atom, etc. *)
  val elements : t -> is_atom list

end

module Rule : sig

  module Schema : sig
    (** A rule concluding that something is a type. *)
    type is_type

    (** A rule concluding that something is a term. *)
    type is_term

    (** A rule concluding that two types are equal. *)
    type eq_type

    (** A rule concluding that two terms are equal. *)
    type eq_term
  end

  (** Given a type formation rule and a list of premises, match the rule
   against the given premises, make sure they fit the rule, and return the
   judgement corresponding to the conclusion of the rule.

      The head of the conclusion (the parts in square brackets) is not really
   there because it is fully prescribed by the premises and the judgement
   class; we just specify it here for readability.


      Schema:
      ⊢ A type    x:A ⊢ B type
      ————————————————————————
      ⊢ [Π A B] type

      Instance:
      Γ₁ ⊢ A₁ type    Γ₂ ⊢ {y:A₂} B₁ type
      ——————————————————————————————————— {Γ₁,Γ₂}↑Δ, A₁ =α= A₂
      Δ ⊢ Π A B type

      Schema:
      ⊢ A type    x:A ⊢ B type   y:A ⊢ s : B{y}
      —————————————————————————————————————————
      ⊢ [λ A B s] : Π A B

      Instance:
      Γ₁ ⊢ A₁ type    Γ₂ | {0:A₂} ⊢ B₁ type   Γ₃ | {0:A₃} ⊢ s : B₂
      ————————————————————————————————————————————————————————————
      check: {Γ₁,Γ₂,Γ₃}↑Δ, A₁ =α= A₂ =α= A₃, B₁ =α= B₂
      Δ ⊢ λ A₁ B₁ s : Π A₁ B₁


  *)
  val form_is_type : Schema.is_type -> premise list -> is_type

  (** Given a term rule and a list of premises, match the rule against the given
   premises, make sure they fit the rule, and return the list of arguments that the term
   constructor should be applied to, together with the natural type of the resulting term.
   *)
  val form_is_term : Schema.is_term -> premise list -> TT.argument list * TT.ty

  (** Given an equality type rule and a list of premises, match the rule against the given
   premises, make sure they fit the rule, and return the conclusion of the instance of the rule
   so obtained. *)
  (* XXX TODO what about context joins and assumption sets? *)
  val form_eq_type : Schema.eq_type -> premise list -> TT.ty * TT.ty

  (** Given an terms equality type rule and a list of premises, match the rule
   against the given premises, make sure they fit the rule, and return the conclusion of
   the instance of the rule so obtained. *)
  val form_eq_term : Schema.eq_term -> premise list -> TT.term * TT.term * TT.ty

  (** Given a term judgment and the arguments of the corresponding term constructor, match
   the arguments against the rule to invert them to the premises of the rule, as well as
   to the natural type of the conclusion. *)
  val invert_is_term : Schema.is_term -> TT.argument list -> premise list * TT.ty

  (** Given a type judgment and the arguments of the corresponding term constructor, match
   the arguments against the rule to invert them to the premises of the rule. *)
  val invert_is_type : Schema.is_type -> TT.argument list -> premise list

end

module Signature : sig
  type t

  val empty : t

  val add_constant : Name.constant -> is_type -> t -> t
end

(** An error emitted by the nucleus *)
type error

exception Error of error Location.located

(** Print a nucleus error *)
val print_error : penv:TT.print_env -> error -> Format.formatter -> unit

(** The jdugement that [Type] is a type. *)
val ty_ty : is_type

(** The type judgement of a term judgement. *)
val typeof : is_term -> is_type

(** Typeof for atoms *)
val atom_is_type : is_atom -> is_type

(** Convert atom judgement to term judgement *)
val atom_is_term : loc:Location.t -> is_atom -> is_term

(** Does this atom occur in this judgement, and if so with what type? *)
val occurs : is_atom -> is_term -> is_atom option

(** The context associated with a term judgement. *)
val contextof : is_term -> Ctx.t

(** Print the judgement that something is a term. *)
val print_is_term : penv:TT.print_env -> ?max_level:Level.t -> is_term -> Format.formatter -> unit

(** Print the judgement that something is a type. *)
val print_is_type : penv:TT.print_env -> ?max_level:Level.t -> is_type -> Format.formatter -> unit

(** Print the judgement that terms are equal. *)
val print_eq_term : penv:TT.print_env -> ?max_level:Level.t -> eq_term -> Format.formatter -> unit

(** Print the judgement that types are equal. *)
val print_eq_type : penv:TT.print_env -> ?max_level:Level.t -> eq_type -> Format.formatter -> unit

(** Destructors *)

(* Inversion principles *)
val invert_is_term : is_term -> shape_is_term
val invert_is_type : is_type -> shape_is_type
val invert_eq_type : eq_type -> is_type * is_type
val invert_eq_term : eq_term -> is_term * is_term * is_type

(** Deconstruct a type judgment into a type abstraction, if possible. *)
val invert_abstract_ty : is_type -> (is_atom * is_type) option

(** Construct a term judgement using the appropriate formation rule. The type is the natural type. *)
val form_is_term : loc:Location.t -> Signature.t -> shape_is_term -> is_term

(** Construct a type judgement using the appropriate formation rule. *)
val form_is_type : loc:Location.t -> Signature.t -> shape_is_type -> is_type

(** Substitution *)

(** [substitute_ty t a v] substitutes [a] with [v] in [t]. *)
val substitute_ty : loc:Location.t -> is_type -> is_atom -> is_term -> is_type

(** [substitute e a v] substitutes [a] with [v] in [e]. *)
val substitute : loc:Location.t -> is_term -> is_atom -> is_term -> is_term

(** Conversion *)

(** Destructors *)
type side = LEFT | RIGHT

val eq_term_side : side -> eq_term -> is_term

val eq_term_typeof : eq_term -> is_type

val eq_type_side : side -> eq_type -> is_type

(** The conversion rule: if [e : A] and [A == B] then [e : B] *)
val convert : loc:Location.t -> is_term -> eq_type -> is_term

(** If [e1 == e2 : A] and [A == B] then [e1 == e2 : B] *)
val convert_eq : loc:Location.t -> eq_term -> eq_type -> eq_term

(** Constructors *)

(** Construct the judgment [e == e : A] from [e : A] *)
val reflexivity : is_term -> eq_term

(** Construct the jdugment [A == A] from [A type] *)
val reflexivity_ty : is_type -> eq_type

(** Given two terms [e1 : A1] and [e2 : A2] construct [e1 == e2 : A1],
    provided [A1] and [A2] are alpha equal and [e1] and [e2] are alpha equal *)
val mk_alpha_equal : loc:Location.t -> is_term -> is_term -> eq_term option

(** Given two types [A] and [B] construct [A == B] provided the types are alpha equal *)
val mk_alpha_equal_ty : loc:Location.t -> is_type -> is_type -> eq_type option

(** Test whether terms are alpha-equal. They may have different types and incompatible contexts even if [true] is returned. *)
val alpha_equal_is_term : is_term -> is_term -> bool

(** Test whether types are alpha-equal. They may have different contexts. *)
val alpha_equal_is_type : is_type -> is_type -> bool

(** Form an equality of two alpha-equal types. They must also have compatible contexts. *)
val alpha_equal_eq_type : loc:Location.t -> is_type -> is_type -> eq_type option

(** If [e1 == e2 : A] then [e2 == e1 : A] *)
val symmetry_term : eq_term -> eq_term

(** If [A == B] then [B == A] *)
val symmetry_type : eq_type -> eq_type

(** If [e1 == e2 : A] and [e2 == e3 : A] then [e1 == e2 : A] *)
val transitivity_term : loc:Location.t -> eq_term -> eq_term -> eq_term

(** If [A == B] and [B == C] then [A == C] *)
val transitivity_type : loc:Location.t -> eq_type -> eq_type -> eq_type

(** Congruence rules *)

(** If [A1 == A2] and [B1 == B2] then [{x : A1} B1 == {x : A2} B2].
    The first atom is used to abstract both sides. The second is used only for the name in the right hand side product. *)
val congr_abstract_type : loc:Location.t -> eq_type -> is_atom -> is_atom -> eq_type -> eq_type

(** If [A1 == A2], [B1 == B2] and [e1 == e2 : B1] then [{x : A1} (e1 : B1) == {x : A2} (e2 : B2) : {x : A1} B1].
    The first atom is used to abstract both sides. The second is used only for the name in the right hand side. *)
val congr_abstract_term : loc:Location.t -> eq_type -> is_atom -> is_atom -> eq_type -> eq_term -> eq_term

(** Derivable rules *)

(** If [e : B] and [A] is the natural type of [e] then [A == B] *)
val natural_eq_type : loc:Location.t -> Signature.t -> is_term -> eq_type

module Json :
sig
  val is_term : is_term -> Json.t

  val is_type : is_type -> Json.t

  val eq_term : eq_term -> Json.t

  val eq_type : eq_type -> Json.t
end
