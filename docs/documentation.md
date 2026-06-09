---
title: Documentation
navigation: documentation
layout: page
use_math: true
---

**Warning (2025-08-10):** The second part of this documentation refers to the old Andromeda 1. Until this warning is deleted, your best chance is to consult the `./theories` and `./stdlib` subdirectories to see how Andromeda 2 supports user-defined type theories.**

### Table of contents

* [About the Andromeda meta-language](#about-the-andromeda-meta-language)
* [ML-types](#ml-types)
   * [ML-type definitions](#ml-type-definitions)
   * [Inductive ML-datatypes](#inductive-ml-datatypes)
   * [Predefined ML-types](#predefined-ml-types)
* [General-purpose programming](#general-purpose-programming)
   * [`let`-binding](#let-binding)
   * [Functions](#functions)
   * [Recursive functions](#recursive-functions)
   * [Sequencing](#sequencing)
   * [Predefined data values](#predefined-data-values)
   * [`match` statements and patterns](#match-statements-and-patterns)
   * [Operations and handlers](#operations-and-handlers)
   * [Mutable references](#mutable-references)
* [Judgment computations](#judgment-computations)
   * [Inferring and checking mode](#inferring-and-checking-mode)
   * [Equality checking](#equality-checking)
   * [The universe](#the-universe)
   * [Constants](#constants)
   * [Assumptions](#assumptions)
   * [Substitution](#substitution)
   * [Product](#product)
   * [$λ$-abstraction](#abstraction)
   * [Application](#application)
   * [Equality type](#equality-type)
     * [Reflexivity](#reflexivity)
     * [Reduction](#reduction)
     * [Congruences](#congruences)
     * [Extensionality](#extensionality)
   * [Type ascription](#type-ascription)
   * [Context and occurs check](#context-and-occurs-check)
   * [Hypotheses](#hypotheses)
   * [Externals](#externals)
* [Toplevel commands](#toplevel-commands)
   * [Toplevel let binding](#toplevel-let-binding)
   * [Toplevel dynamic variables](#toplevel-dynamic-variables)
   * [Declarations](#declarations)
   * [`Do` command](#do-command)
   * [`Fail` command](#fail-command)
   * [Toplevel handlers](#toplevel-handlers)
   * [Include](#include)
   * [Verbosity](#verbosity)
   * [Help](#help)
   * [Environment](#environment)
   * [Quit](#quit)

### About the Andromeda meta-language

Andromeda is a proof assistant designed as a programming language, following the tradition
of Robin Milner's
[Logic for computable functions](http://i.stanford.edu/pub/cstr/reports/cs/tr/72/288/CS-TR-72-288.pdf)
(LCF). We call it the **Andromeda meta-language (AML)**.

AML is a functional call-by-value language with algebraic effects and handlers.
It is statically typed, with Hindley-Milner-style parametric polymorphism and
type inference.

We refer to AML expressions as
**computations** to emphasize that they may have *effects* (such as printing
things on the screen or instantiating a meta-variable).

Andromeda is a *generic* proof checker. The user defines their own type theory,
with respect to which andromeda computes derivable judgments. Any judgement
computed by Andromeda is guaranteed to be derivable from the inference rules
postulated by the user.

While Robin Milner's LCF and its HOL-style descendants compute judgments in
*simple* type theory, AML supports *dependent* type theories. This creates a
significant overhead in the complexity. While [John
Harisson](http://www.cl.cam.ac.uk/~jrh13/) could print the [HOL Light
kernel](http://www.cl.cam.ac.uk/~jrh13/) on a T-shirt, we may need a cape to
print the 1800 lines of [Andromeda
nucleus](https://en.wikipedia.org/wiki/Andromeda_Galaxy#Nucleus).


### ML-types

The AML types are called **ML-types**, and are separate from from the types
appearing in the object type theory. They follow closely the usual ML-style
parametric polymorphism.

#### ML-Type definitions

An ML-type abbreviation may be defined as

    mltype foo = ...

An ML-type may be parametrized:

    mltype foo α β ... γ = ...

A disjoint sum is defined as

    mltype foo =
      | constr₁ of t₁
      ...
      | constrⱼ of tⱼ
    end

Data constructors `constrᵢ` need not be capitalized and must be fully applied.

The empty ML-type is defined as

    type empty = |

#### Inductive ML-datatypes

A recursive ML-type may be defined as

    mltype rec t α β ... γ = ...

The recursion must be guarded by data constructors, i.e., we only allow *inductive*
definitions. E.g., the ML-type of binary trees can be defined as

    mltype rec tree α =
      | Empty
      | Tree of α * α tree * α tree

#### Predefined ML-types

The following types are predefined by Andromeda:

* `mlunit` is the unit type whose only value is the empty tuple `()`
* `mlstring` is the type of [strings](#strings)
* `mllist α` is the type of [lists](#lists)
* `ML.option α` is the type of [optional values](#optional-values)
* `ML.bool` is the type of [booleans](#booleans)
* `ML.order` is the type used for [comparison](#comparison) of ML values


### General-purpose programming

AML is a general-purpose programming language which supports the following programming features:

* `let-`bindings of values
* first-class functions
* (mutually) recursive definitions of functions
* datatypes (lists, tuples, and user-definable data types)
* `match` statements and pattern matching
* operations and handlers
* mutable references

##### `let`-binding

A binding of the form

    let x = c₁ in c₂

computes `c₁` to a value `v`, binds `x` to `v`, and computes `c₂`. Thus, whenever `x` is
encountered in `c₂` it is replaced by `v`.

A `let`-binding may be annotated with a type:

    # let cow :> mlstring = "cow"
    val cow :> mlstring = "cow"

It is possible to bind several values simultaneously:

    let x₁ = c₁
    and x₂ = c₂
     ⋮
    and xᵢ = cᵢ in
      c

The bound names `x₁`, ..., `xᵢ` do *not* refer to each other, thus:

    # let x = "foo"
    val x :> mlstring = "foo"
    # let y = "bar"
    val y :> mlstring = "bar"
    # let x = y and y = x in (x, y)
    - :> mlstring * mlstring = ("bar", "foo")

You may use patterns in `let`-bindings, in which case the bound variables should be marked with `?`:

    # let (?a, ?b) = ("a", "b")
    val a :> mlstring = "a"
    val b :> mlstring = "b"
    # let (ML.Some ?p) = ML.Some ["p"]
    val p :> list mlstring = "p" :: []


##### Functions

An AML function has the form

    fun x -> c

Example:

    # fun x -> (x, x)
    - :> mlforall α, α → α * α = <function>
    # (fun x -> (x, x)) "foo"
    - :> mlstring * mlstring = ("foo", "foo")

The arguments may be annotated with a type, in which case it is considered a pattern, so any bound variables must be
marked with `?`:

    # fun (?x :> mlstring) -> x
    - :> mlstring → mlstring = <function>

An iterated function

    fun x₁ -> fun x₂ -> ... -> fun xᵢ -> c

may be written as

    fun x₁ x₂ ... xᵢ -> c

A `let`-binding of the form

    let f x₁ ... xᵢ = c

is a shorthand for

    let f = (fun x₁ x₂ ... xᵢ -> c)

You may use patterns in function arguments, in which case the bound variables must be marked with `?`:

     # let fst = fun (?x, _) -> x
     val fst :> mlforall α β, α * β → α = <function>
     # let snd (_, ?y) = y
     val snd :> mlforall α β, α * β → β = <function>

##### Recursive functions

Recursive functions can be defined:

    let rec f x₁ ... xᵢ = c₁ in
      c₂

is a local recursive function definition. Multiple mutually recursive functions may be
defined with

    let rec f₁ x₁ x₂ ... = c₁
        and f₂ y₁ y₂ ... = c₂
         ⋮
        and fⱼ z₁ z₂ ... = cⱼ

The inferred type of a recursive function is never polymorphic:

    # let rec f x = x
    val f :> _α → _α
    # f "foo"
    - :> mlstring = "foo"
    # f
    - :> mlstring → mlstring = <function>

To define a polymorphic recursive function, we have to annotate it explicitly:

    # let rec f x :> mlforall a, a -> a = x
    val f :> mlforall α, α → α

##### Sequencing

The sequencing construct

    c₁ ; c₂

computes `c₁`, discards the result, and computes `c₂`. It is equivalent to

    let _ = c₁ in c₂

If `c₁` has type other than `mlunit`, a warning is printed.

#### Predefined data values

#### Strings

A string is a sequence of characters delimited by quotes, e.g.

    "This string contains forty-two characters."

Its type is `mlstring`.
There are at present no facilities to manipulate strings in AML other than printing.

#### Tuples

A meta-level tuple is written as `(c₁, ..., cᵢ)`. Its type is `t₁ * ... tᵢ` where `tⱼ` is
the type of `cⱼ`.

#### Optional values

The value `ML.None` indicates a lack of value and `ML.Some c` indicates the presence of value
`c`. The type of `ML.None` is `mlforall α, ML.option α` and the type of `Some v` is `ML.option t` if `t` is the
type of `c`.

#### Lists

The empty list is written as `[]`. The list whose head is `c₁` and the tail is `c₂` is
written as `c₁ :: c₂`. The computation

    [c₁; c₂; ... cᵢ]

is shorthand for

    c₁ :: (c₂ :: ... (cᵢ :: []))

A list of type `list t` must hold values of type `t`.

##### `match` statements and patterns

A `match` statement is also known as `case` in some languages and is simulated by
successive `if`-`else if`-...-`else if`-`else` in others. The general form is

    match c with
    | p₁ -> c₁
    | p₂ -> c₂
      ...
    | pᵢ -> cᵢ
    end

The first clause whose pattern matches `c` is evaluated. The variables bound in `pᵢ` are available in `cᵢ`.
If no pattern matches `v` then an error is reported.

The first bar `|` may be omitted. A pattern may be *guarded* with a boolean condition:

    | pᵢ when bᵢ -> cᵢ

In this case, `c` has to match `pᵢ` and the guard `bᵢ` must evaluate to
`ML.true`. The variables bound in `pᵢ` are available in `bᵢ`.

Example:

    match ["foo","bar","baz"] with
    | [] => []
    | ?x :: (?y :: _) => (y, x)
    end

computes to `("bar", "foo")` because the second pattern matches the list and binds `x` to
`"foo"` and `y` to `"bar"`.

###### ML patterns

The patterns are:

   |---|---|
   | `_` | match any value |
   | `p as ?x` | match according to pattern `p` and also bind the value to `x` |
   | `p :> t` | match according to pattern `p` of type `t` |
   | `?x` | match any value and bind it to `x` |
   | `Constr p` | match a datatype constructor and its argument |
   | `[]` | match the empty list |
   | `p₁ :: p₂` | match the head and the tail of a non-empty list |
   | `[p₁; ...; pᵢ]` | match the elements of the list |
   | `(p₁, ..., pᵢ)` | match the elements of a tuple |
   | `"..."` | match a string literal |
   | `p type` | match a type judgment |
   | `p₁ : p₂` | match a term judgment |
   | `p₁ ≡ p₂` | match a type equality judgment |
   | `p₁ ≡ p₂ : p₃` | match a term equality judgment |
   | `⁇ type` | match a type boundary |
   | `⁇ : j₃` | match a term boundary |
   | `p₁ ≡ p₂ by ⁇` | match a type equality judgment |
   | `p₁ ≡ p₂ : p₃ by ⁇` | match a term equality boundary |
   | `{x : p₁} p₂` | match an abstraction |
   | `_atom p` | match an atom (free variable) |

Patterns must be linear, i.e., in a pattern each pattern variable `?x` may appear at most once.

TODO: Explain the judgement and boundary patterns.

#### Operations and handlers

The AML operations and handlers are similar to those of the [Coop](https://github.com/andrejbauer/coop) programming language.
We first explain the syntax and give several examples below.

##### Operations

A new operation is declared by

    operation op : t₁ → t₂ → ... → tᵢ → u

where `op` is the operation name, `t₁`, ..., `tᵢ` are the types of the operation
arguments, and `u` is its return type. There need not be any arguments, i.e., it is
valid to declare

    operation op : u

An operation is then invoked with

    op c₁ .. cᵢ

where `cⱼ` must have type `tⱼ`, and the type of the computation is `u`.

One way to think of an operation as a generalized resumable exception: when an
operation is invoked it propagates outward to the innermost handler that handles it. The
handler may perform some computations, after which it either resumes execution by passing a value with `yield`,
or it raises an exception.

##### Handlers

A handler has the form

    handler
    | case₁
    | case₂
    ...
    | caseⱼ
    end

where each `case₁` is an operation case, an exception case, or a value case. The
first case that matches is evaluated.. If no cases matches, the value, exception,
or operation propagates outwards.

###### The operation cases

An operation case has the form

    | operation op p₁ ... pᵢ -> c

or the form

    | operation op p₁ ... pᵢ : p -> c

The first form matches an invoked operation `op' v₁ ... vᵢ`
when `op` equals `op'` and each `vⱼ` matches the corresponding pattern `pⱼ`.
The second form matches an invoked operation `op' v₁ ... vᵢ`
when `op` equals `op'`, each `vⱼ` matches the corresponding `pⱼ`
*and* if the operation was invoked in [checking mode](#inferring-and-checking-mode) at type
`t`, `ML.Some t` matches `p`, otherwise `ML.None` matches `p`.

When an operation case matches the corresponding computation `c` is computed, with the
pattern variables appearing in the patterns bound to the corresponding values.
The computed value `v` is passed to the continuation, unless an eception is raised.

###### The value cases

A value case has the form

    | val ?p => c

It is used when the handler handles a computation that did *not* invoke a computation but
rather computed to a value `v`. In this case the value cases are matched against the value
and the first one that matches is used.

If no value case is present in the handler, it is considered to be the trivial case `val ?x => x`.

If at least one value case is present, but the handled computation evaluates to
a value which is matched by none of them, a runtime error will occur.

###### The exception cases

An exception case has the form

    | raise Exn ?p => c

It catches an exception, and evaluates `c`. An exception is non-resumable, so
the final value is whatever `c` evaluates to.

##### The handling construct

To actually handle a computation `c` with a handler `h` write

    with h try c

The notation

    try
     c
    with
    | handler-case₁
    ...
    | handler-caseᵢ
    end

is a shorthand for

    with
      handler
      | handler-case₁
      ...
      | handler-caseᵢ
      end
    try
      c

Several handlers may be stacked on top of each other, for instance

    with h₁ try
      ...
      with h₂ try
        ...
        c
        ...

When a computation `c` invokes an operation, the operation is handled by the innermost
handler that has a matching case for that operation.

##### Top-level handlers

A top-level handler may be declared at top-level with

    with
      | op-case₁
      ...
      | op-caseᵢ
    end


#### Mutable references

Mutable references are as in OCaml:
* a fresh reference is introduced by `ref c` where `c` evaluates to its initial value
* if `c` evaluates to a reference, its value can be accessed by `! c`
* if `c` evaluates to a reference, its value can be modified by `c := c'` where `c'` evaluates to the new value.


### Judgment computations

**WARNING: Everything past this point is obsolete, as it still refers to Andromeda 1.**

There is no way in Andromeda to create a bare type-theoretic term $\e$, only a complete
typing judgment $\isterm{\G}{\e}{\tyA}$. Even those computations that *look* like terms
actually compute judgments. For instance, if `c₁` computes to

$$\isterm{\G}{\e_1}{\Prod{\x}{\tyA} \tyB}$$

and `c₂` computes to

$$\isterm{\D}{\e_2}{\tyA},$$

then the "application" `c₁ c₂` computes to

$$\isterm{\G \bowtie \D}{\app{\e_1}{\x}{\tyA}{\tyB}{\e_2}}{\subst{\tyB}{\x}{\e_2}}$$

where $\G \bowtie \D$ is the *join* of contexts $\G$ and $\D$, satisfying the property
that $\G \bowtie \D$ contains both $\G$ and $\D$ (the two contexts $\G$ and $\D$ may be
incompatible, in which case Andromeda reports an error).

Even though Andromeda always computes an entire judgment $\isterm{\G}{\e}{\tyA}$ it is
useful to think of it as just a term $\e$ with a known type $\tyA$ and assumptions $\G$
which Andromeda is kindly keeping track of.

##### Inferring and checking mode

A judgment is computed in one of two modes, the **inferring** or the **checking** mode.

In the inferring mode the judgment that is being computed is unrestrained.

In checking mode there is a given type $\tyA$ (actually a judgment $\istype{\G}{\tyA}$) and
the judgment that is being computed must have the form $\isterm{\D}{\e}{\tyA}$. In other
words, the type is prescribed in advanced. For example, an equality type

    c₁ ≡ c₂

proceeds as follows:

1. Compute `c₁` in inferring mode to obtain a judgment $\isterm{\G}{\e}{\tyA}$.
2. Compute `c₂` in checking mode at type $\tyA$.

#### Equality checking

The nucleus and AML only know about syntactic equality (also known as α-equality), and
delegate all other equality checks to the user level via a handlers mechanism. There are
several situations in which AML triggers an operation that requires the user to provide
evidence of an equality (see the section on [equality type](#equality-type) for
information on how to generate evidence of equality).

##### Operation `equal`

When AML requires evidence of an equality `e₁ ≡ e₂` at type `A` it triggers the operation
`equal e₁ e₂`. The user provided handler must yield

* `None` if the equality is to be considered invalid (which results in a runtime error),
* `Some (⊢ ξ : e₁ ≡ e₂)` if the equality is valid and `ξ` is evidence for it.

##### Operation `as_prod`

When AML requires evidence that a type `A` is a dependent product it triggers the operation `as_prod A`. The user provided handler must yield

* `None` if `A` is to be considered as not equal to a dependent product (which results in
  a runtime error),
* `Some (⊢ ξ : A ≡ ∏ (x : A), B)` if `A` is equal to the dependent product `∏ (x : A), B`
  and `ξ` is evidence for it.

##### Operation `as_eq`

When AML requires evidence that a type `A` is an equality type it triggers the operation
`as_eq A`. The user provided handler must yield

* `None` if `A` is to be considered as not equal to an equality type (which results in
  a runtime error),
* `Some (⊢ ξ : A ≡ (B ≡ C)` if `A` is equal to the equality type `B ≡ C` and `ξ` is
  evidence for it.

##### Operation `coerce`

AML evaluates an inferring judgment computation `c` in checking mode at type `B` as follows:

* evaluate `c` to a judgement `⊢ e : A`,
* if `A` and `B` are syntactically equal, evaluate to `⊢ e : B`,
* otherwise, trigger the operation `coerce (⊢ e : A) (⊢ B : Type)`

The user provided handler must yield a value of type `coercible`, as follows:

* `NotCoercible` if `e` is to be considered as not coercible to type `B` (which results in
  a runtime error),
* `Convertible (⊢ ξ : A ≡ B)` if the types `A` and `B` are equal, as witnessed by `ξ`, and hence no coercion of `e` is required. In this case the result is `⊢ e : B`.
* `Coercible (⊢ e' : B)` if `e` can be coerced to `e'` of type `B`.

##### Operation `coerce_fun`

AML evaluates an application `c₁ c₂` as follows:

* Evaluate `c₁` in inferring mode to a judgement `⊢ e₁ : A`.
* if `A` is syntactically equal to a product `∏ (x : B), C`, evaluate `c₂` in checking mode at type `B` to a judgement `⊢ e₂ : B`. In this case the result is `⊢ e₁ e₂ : C[e₂/x]`.
* otherwise, trigger the operation `coerce_fun (⊢ e₁ : A)`.

The user provided handler must yield a value of type `coercible` as follows:

* `NotCoercible` if `e₁` is to be considered as not coercible to a product type (which results in
  a runtime error),
* `Convertible (⊢ ξ : A ≡ ∏ (x : B), C)` if th types `A` is equal to the product `∏ (x :
  B), C`, as witnessed by `ξ`, and hence no coercion of `e₁` in required. In this case the
  result is `⊢ e₁ e₂ : C[e₂/x]`.
* `Coercible (⊢ e₁' : ∏ (x : B), C)` if `e₁` can be coerced to `e₁'` of the product type `∏ (x : B), C`. In this the result is `⊢ e₁' e₂ : C[e₂/x]`.

#### The universe

The computation

    Type

computes the judgment $\istype{}{\Type}$ which is valid by [the rule `ty-type`](type-theory.html#ty-type). Example:

    # do Type
    ⊢ Type : Type

Having `Type` in `Type` is unsatisfactory because it renders the type theory inconsistent
in the sense that every type is inhabited. We consider this to be a temporary feature of
the system that simplifies development. In the future there will be a (user-definable)
universe mechanism.

#### Constants

At the toplevel a new constant `a` (axiom) of type `A` may be declared with

    constant a : A

Several constants of the same type may be declared with

    constant a₁ a₂ ... aᵢ : A

A primitive type `T` is declared with

    constant T : Type

#### Assumptions

If computation `c₁` computes to judgment $\istype{\G}{\tyA}$ then

    assume x : c₁ in c₂

binds `x` to $\isterm{\ctxextend{\G}{\x'}{\tyA}}{\x'}{\tyA}$,
then it evaluates `c₂`. The judgment is valid by
[rule `ctx-var`](type-theory.html#term-var) and
[rule `ctx-extend`](type-theory.html#ctx-extend). Example:

    # constant A : Type
    Constant A is declared.
    # constant B : A → Type
    Constant B is declared.
    # do assume a : A in B a
    a₁₁ : A ⊢ B a₁₁ : Type

The judgment that was generated is $\istype{a_{11} \colon
A}{\app{B}{x}{A}{\Type}{a_{11}}}$, but Andromeda is not showing the typing annotations.
Every time `assume` is evaluated it generates a fresh variable $\x'$ that has never been seen before:

    # do assume a : A in B a
    a₁₂ : A ⊢ B a₁₂ : Type
    # do assume x : A in B a
    a₁₃ : A ⊢ B a₁₃ : Type

If we make several assumptions but then use only some of them, the context will contain those that are actually needed:

    # constant A : Type
    Constant A is declared.
    # constant f : A → A → A
    Constant f is declared.
    # do assume a : A in (assume b : A in (assume c : A in f a c))
    a₁₄ : A, c₁₆ : A ⊢ f a₁₄ c₁₆ : A

#### Substitution

We can get rid of an assumption with a *substitution*

    c₁ where x = c₂

which replaces in `c₁` the assumption bound to `x` with the judgment that computed by
`c₂`, as follows:

    # constant A : Type
    Constant A is declared.
    # constant a : A
    Constant a is declared.
    # constant f : A → A
    Constant f is declared.
    # let x = (assume x : A in x)
    x is defined.
    # do x
    x₁₂ : A ⊢ x₁₂ : A
    # let b = f x
    b is defined.
    # do b
    x₁₂ : A ⊢ f x₁₂ : A
    # do b where x = a
    ⊢ f a : A

The idiom `let x = assume x : A in x` is a common one and it serves as a way of
introducing a new fresh variable of a given type. There is no reason to use `x` both in
`let` and in `assume`, we could write `let z = assume y : A in y` but then `z` would be
bound to something like `y₄₂` which is perhaps a bit counter-intuitive.

If we compute a term without first storing the assumed variables

    # let d = assume y : A in f y
    d is defined.
    # do d
    y₁₃ : A ⊢ f y₁₃ : A

then it is a bit harder to get our hands on `y₁₃`, but is still doable using `context`,
see below.

#### Product

A product is computed with

    ∏ (x : c₁), c₂

An iterated product may be computed with

    ∏ (x₁₁ ... x₁ⱼ : c₁) ... (xᵢ₁ .... xᵢⱼ : cᵢ), c

Instead of the character `∏` you may also use `Π`, `∀` or `forall`.

A non-dependent product is written as

    c₁ → c₂

The arrow `→` associates to the right so that `c₁ → c₂ → c₃` is equivalent to `c₁ → (c₂ →
c₃)`. Instead of `→` you can also write `->`.

#### λ-abstraction

A λ-abstraction is computed with

    λ (x : c₁), c₂

An iterated λ-abstraction is computed with

    λ (x₁₁ ... x₁ⱼ : c₁) ... (xᵢ₁ .... xᵢⱼ : cᵢ), c

In checking mode the types of the bound variables may be omitted, so we can write

    λ x₁ x₂ ... xᵢ, c

We can also mix bound variables with and without typing annotations.

Instead of the character `λ` you may use `lambda`.

#### Application

An application is computed with

    c₁ c₂

Application associates to the left so that `c₁ c₂ c₃` is the same as `(c₁ c₂) c₃`.

#### Equality type

The equality type is computed with

    c₁ ≡ c₂

Instead of the character `≡` you may use `==`. There are a number of constructors for
generating elements of the equality types, as follows.

###### Reflexivity

The reflexivity term is computed with

    refl c

If `c` evaluates to $\isterm{\G}{\e}{\tyA}$ then `refl c` evaluates to $\isterm{\G}{\juRefl{\tyA} \e}{\JuEqual{\tyA}{\e}{\e}}$.

##### Reduction

The rule [`prod-beta`](./type-theory.html#prod-beta) is available through

    beta_step x A B e₁ e₂

where:

* `A` evaluates to a type $\istype{\G}{\tyA}$
* `x` evaluates to an atom $\isterm{\G}{\x}{\tyA}$
* `B` evaluates to a type $\istype{\ctxextend{\G}{\x}{\tyA}}{\tyB}$
* `e₁` evaluates to a term $\isterm{\ctxextend{\G}{\x}{\tyA}}{\e_1}{\tyB}$
* `e₂` evaluates to a term $\isterm{\G}{\e_2}{\tyA}$

If this is the case, then the computation evaluates to a term of equality type witnessing
the fact that

$$
   \eqterm{\G}
   {\app{(\lam{\x}{\tyA}{\tyB} \e_1)}{\x}{\tyA}{\tyB}{\e_2}}
   {\subst{\e_1}{\x}{\e_2}}
   {\subst{\tyB}{\x}{\e_2}}
$$

###### Congruences

The following computations generate evidence for congruence rules. Each one corresponds to
an inference rule.

###### `congr_prod` (rule [`cong-prod`](./type-theory.html#cong-prod))

Assuming

* `x` evaluates to an atom $\isterm{\G}{\x}{\tyA_1}$
* `ξ` evaluates to evidence of $\eqtype{\G}{\tyA_1}{\tyA_2}$
* `ζ` evaluates to evidence of $\eqtype{\ctxextend{\G}{\x}{\tyA_1}}{\tyB_1}{\tyB_2}$

the computation

    congr_prod x ξ ζ

evaluates to evidence of $\eqtype{\G}{\Prod{\x}{\tyA_1}{\tyA_2}}{\Prod{\x}{\tyB_1}{\tyB_2}}$.

###### `congr_apply` (rule [`congr-apply`](./type-theory.html#congr-apply))

Assuming

* `x` evaluates to an atom $\isterm{\G}{\x}{\tyA_1}$
* `η` evaluates to evidence of $\eqterm{\G}{\e_1}{\e'_1}{\Prod{\x}{\tyA_1}{\tyA_2}}$
* `θ` evaluates to evidence of $\eqterm{\G}{\e_2}{\e'_2}{\tyA_1}$
* `ξ` evaluates to evidence of $\eqtype{\G}{\tyA_1}{\tyB_1}$
* `̣ζ` evaluates to evidence of $\eqtype{\ctxextend{\G}{\x}{\tyA_1}}{\tyA_2}{\tyB_2}$

the computation

    congr_apply x η θ ξ ζ

evaluates to evidence of $\eqterm{\G}{(\app{\e_1}{\x}{\tyA_1}{\tyA_2}{\e_2})}{(\app{\e'_1}{\x}{\tyB_1}{\tyB_2}{\e'_2})}{\subst{\tyA_2}{\x}{\e_2}}$.


###### `congr_lambda` (rule [`congr-lambda`](./type-theory.html#congr-lambda))

Assuming

* `x` evaluates to an atom $\isterm{\G}{\x}{\tyA_1}$
* `η` evaluates to evidence of $\eqtype{\G}{\tyA_1}{\tyB_1}$
* `θ` evaluates to evidence of $\eqtype{\ctxextend{\G}{\x}{\tyA_1}}{\tyA_2}{\tyB_2}$
* `ξ` evaluates to evidence of $\eqterm{\ctxextend{\G}{\x}{\tyA_1}}{\e_1}{\e_2}{\tyA_2}$

the computation

    congr_apply x η θ ξ

evaluates to evidence of $\eqterm{\G}{(\lam{\x}{\tyA_1}{\tyA_2}{\e_1})}
              {(\lam{\x}{\tyB_1}{\tyB_2}{\e_2})}
              {\Prod{\x}{\tyA_1}{\tyA_2}}$.

###### `congr_eq` (rule [`congr-eq`](./type-theory.html#congr-eq))

Assuming

* `η` evaluates to evidence of $\eqtype{\G}{\tyA}{\tyB}$
* `θ` evaluates to evidence of $\eqterm{\G}{\e_1}{\e'_1}{\tyA}$
* `ξ` evaluates to evidence of $\eqterm{\G}{\e_2}{\e'_2}{\tyA}$

the computation

    congr_eq η θ ξ

evaluates to evidence of $\eqtype{\G}{\JuEqual{\tyA}{\e_1}{\e_2}}{\JuEqual{\tyB}{\e'_1}{\e'_2}}$.

###### `congr_refl` (rule [`congr-refl`](./type-theory.html#congr-refl))

Assuming

* `η` evaluates to evidence of $\eqterm{\G}{\e_1}{\e_2}{\tyA}$
* `θ` evaluates to evidence of $\eqtype{\G}{\tyA}{\tyB}$

the computation

    congr_refl η θ

evaluates to evidence of $\eqterm{\G}{\juRefl{\tyA} \e_1}{\juRefl{\tyB} \e_2}{\JuEqual{\tyA}{\e_1}{\e_1}}$.


##### Extensionality

Extensionality rules such as function extensionality and uniqueness of identity proofs are
not built-in. They may be defined at user level, which indeed they are, see the standard
library.

For instance, function extensionality may be axiomatized as

    constant funext :
      ∏ (A : Type) (B : A → Type) (f g : ∏ (x : A), B x),
        (∏ (x : A), f x ≡ g x) → f ≡ g

The constant `funext` can then be used by the standard equality checking algorithm
(implemented in the standard library) as an η-rule:

    now etas = add_eta funext

#### Type ascription

Type ascription

    c₁ : c₂

first computes `c₂`, which must evaluate to a type $\istype{\G}{\tyA}$. It then computes
`c₁` in checking mode at type $\tyA$ thereby guaranteeing that the result will be a judgment
of the form $\isterm{\D}{\e}{\tyA}$.

#### Context and occurs check

The computation

    context c

computes `c` to a judgment $\isterm{\G}{\e}{\tyA}$ and gives the list of all assumptions in
$\Gamma$. Example:

    # constant A : Type
    Constant A is declared.
    # constant f : A -> A -> Type
    Constant f is declared.
    # let b = assume x : A in assume y : A in f x y
    b is defined.
    # do context b
    [(y₁₃ : A ⊢ y₁₃ : A), (x₁₂ : A ⊢ x₁₂ : A)]

The computation

    occurs x c

computes `x` to a judgment $\isterm{\D}{\x}{A}$ and `c` to a judgment $\isterm{\G}{\e}{\tyA}$ such that $x$ is a variable.
It evaluates to `None` if $x$ does not occur in $\G$, and to
`Some U` if $x$ occurs in $\G$ as an assumption of type `U`.

    # constant A : Type
    Constant A is declared.
    # constant f : A -> A -> A
    Constant f is declared.
    # let x = assume x : A in x
    x is defined.
    # do occurs x (f x x)
    Some (⊢ A : Type)
    # do occurs x f
    None

#### Hypotheses

In AML computations happen *inside* products and λ-abstractions, i.e., under binders.
It is sometimes important to get the list of the binders.
This is done with

    hypotheses

Example:

    # constant A : Type
    Constant A is declared.
    # constant F : A → Type
    Constant F is declared.
    # do ∏ (a : A), F ((λ (x : A), (print hypotheses; x)) a)
    [(x₁₄ : A ⊢ x₁₄ : A), (a₁₃ : A ⊢ a₁₃ : A)]
    ⊢ Π (a : A), F ((λ (x : A), x) a) : Type

Here `hypotheses` returned the list `[(x₁₄ : A ⊢ x₁₄ : A), (a₁₃ : A ⊢ a₁₃ : A)]` which was printed, after which `⊢ Π (a : A), F ((λ (x : A), x) a) : Type` was computed as the result.

The handling of operations invoked under a binder is considered to be computed under that binder:

    # do handle ∏ (a : A), Hole with Hole => hypotheses end
    [(a₁₃ : A ⊢ a₁₃ : A)]

#### Externals

Externals provide a way to call certain OCaml functions.
Each function has a name like `"print"` and is invoked with

    external "print"

The name `print` is bound to the external `"print"` in the standard library.

The available externals are:

   |---|---|
   | `"print"` | A function taking one value and printing it to the standard output |
   | `"time"` | TODO describe time |
   | `"config"` | A function allowing dynamic modification of some options |
   | `"exit"` | Exit Andromeda ML |

The `"config"` external can be invoked with the following options:

   |---|---|
   | `"ascii"` | Future printing only uses ASCII characters |
   | `"no-ascii"` | Future printing uses UTF-8 characters such as `∏` (default) |
   | `"debruijn"` | Print De Bruijn indices of bound variables in terms |
   | `"no-debruijn"` | Do not print De Bruijn indices of bound variables in terms (default) |
   | `"annotate"` | Print typing annotations (partially implemented) |
   | `"no-annotate"` | Do not print typing annotations (default) |
   | `"dependencies"` | Print dependency information in contexts and terms |
   | `"no-dependencies"` | Do not print dependency information |

The arguments to `external` and `external "config"` are case sensitive.


#### Toplevel commands

An Andromeda program is a stream of top-level commands.

##### Toplevel let binding

The top-level can bind variables to values and define recursive functions like inside computations:

    let x = c
    and y = c'

and

    let rec f x = c
    and g y = c'

##### Toplevel dynamic variables

The top-level can create new dynamic variables

    dynamic x = c

and update them for the rest of the program

    now x = c

##### Declarations

The top-level can create new basic values:
* type theoretic constants as `constant a b : T`
* type theoretic signatures as `signature s = { foo as x : Type, bar : x }`
* operations of given arities as `operation hippy 0`
* data constructors of given arities as `data Some 1`

##### Do command

At the toplevel the `do c` construct computes `c`:

    do c

You *cannot* just write `c` because that would create ambiguities. For instance,

    let x = c₁
    c₂

could mean `let x = c₁ c₂` or

    let x = c₁
    do c₂

We could do without `do` if we requires that toplevel computations be terminated with `;;`
a la OCaml. We do not have a strong opinion about this particular syntactic detail.

##### Fail command

The construct

    fail c

is the "opposite" of `do c` in the sense that it will succeed *only if* `c` reports an
error. This is useful for testing AML.

If `c` has side effects they are canceled:

    # let x = ref None
    x is defined.
    # fail x := Some (); None None
    The command failed with error:
    File "?", line 2, characters 20-23: Runtime error
      cannot apply a data tag
    # do !x
    None

##### Toplevel handlers

A global handler may be installed at the toplevel with

    handle
    | op-case₁
    | op-case₂
    ...
    | op-caseᵢ
    end

Top-level handlers may only be simple callbacks: the cases may not contain patterns
(to avoid confusion, as new cases replace old ones completely)
and for case `op ?x => c`, `yield` may not appear in `c`. Instead the result of `c` is passed to the continuation.

Thus a top-level operation case `op ?x => c` is equivalent to a general handler case `op ?x => yield c`.

##### Include

`#include "<file>"` includes the given file.

`#include_once "<file>"` includes the given file if it has not been included yet.

The path is relative to the current file.

##### Verbosity

`#verbosity <n>` sets the verbosity level. The levels are:

- `0`: only success messages
- `1`: errors
- `2`: warnings
- `3`: debugging messages

##### Help

`#help` prints the internal help.

##### Environment

`#environment` prints information about the runtime environment.

##### Quit

`#quit` ends evaluation.
