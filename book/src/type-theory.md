# The object type theory

An object type theory in Andromeda is given by postulating its
inference rules with `rule` declarations; Andromeda itself is generic
in this choice. The vocabulary of the object level has three
principal kinds of value:

- A [*judgement*](#judgements), of AML-type `judgement`, is formal
  evidence of one of four judgement forms.
- A [*boundary*](#boundaries), of AML-type `boundary`, is a
  classifier for judgements, describing the shape of a judgement
  that is to be constructed.
- A [*derivation*](#declaring-inference-rules), of AML-type
  `derivation`, is a parametric proof-builder: it takes judgements
  for its formal parameters and produces a judgement of a specified
  shape. *Primitive* derivations are introduced at the top level by
  [`rule` declarations](#the-rule-declaration); *derived* ones are
  produced by the [`derive` computation](#derivations).

Every judgement, boundary, and derivation originates in the
*nucleus*, the small trusted component of the implementation. The
nucleus admits two kinds of inference rule: those the user has
postulated, and a fixed collection of general structural rules —
congruence rules, and the reflexivity, symmetry, and transitivity of
judgemental equality. From this design follows the central
correctness guarantee:

> [!IMPORTANT]
> **Soundness.** Every value of AML-type `judgement` computed by
> Andromeda is derivable from the inference rules declared by the
> user and the built-in structural rules.

## Judgements

There are four primitive judgement forms:

| Form | Concrete syntax | Reading |
|---|---|---|
| type judgement | `A type` | `A` is a well-formed type. |
| term judgement | `e : A` | `e` is a well-formed term, and its type is `A`. |
| type equality | `A ≡ B` | `A` and `B` are judgementally equal types. |
| term equality | `e₁ ≡ e₂ : A` | `e₁` and `e₂` are judgementally equal terms at type `A`. |

Each form asserts a specific kind of well-formedness
or judgemental equality; together they make up the entire body of
statements that the nucleus can certify.

The type judgement and the term judgement are the *object judgements*;
they assert that something has been constructed. The type equality
and the term equality are the *equality judgements*; they assert that
two object judgements identify the same thing.

A judgement records its context. When several judgements are
combined — by applying a rule, by appealing to an equality — the
nucleus joins their contexts in the result.

The expressions appearing in a judgement are built by applying the
inference rules of the object theory, and may additionally contain
[atoms](#atoms), [meta-variables](#meta-variables), and
[abstractions](#abstractions).

### Atoms

An *atom* is a free variable of the object theory. (We prefer “atom” to
“object-level variable” as it is shorter and avoids confusion between
different kinds of variables.)

An atom is introduced into a judgement by the
[`fresh` construct](#fresh) and discharged from its context by the
dual [`abstract` construct](#abstract).
In the body of an abstraction, a bound variable appears as an atom.

### Meta-variables

A *meta-variable* is a named placeholder standing for a
yet-to-be-supplied judgement. Every meta-variable carries a *boundary*
that classifies it: a type meta-variable stands for a type, a term
meta-variable for a term of a known type, an equational meta-variable
for a judgemental equality.

A meta-variable is introduced into a judgement by the
[`meta` construct](#meta), and most often arises as a formal
parameter of a [derivation](#declaring-inference-rules).

### Abstractions

An *abstraction* `{x : A} J` parametrises a judgement (or a boundary)
`J` over an atom `x` of type `A`. (The curly braces do *not* indicate
implicit arguments, as Andromeda has no implicit arguments.) An
abstracted judgement is itself of AML-type `judgement`, and an
abstracted boundary of AML-type `boundary`. Abstractions nest, and
binders that share a type may be grouped: `{x y z : A} J` is the
same as `{x : A} {y : A} {z : A} J`, and `{x : A} {y : B{x}} J`
abstracts over `x` and `y` in turn.

An abstraction is *instantiated* by writing `C{e}`: if `C` evaluates
to an abstracted judgement `{x : A} J` and `e` to a term of type
`A`, then `C{e}` is the result of instantiating `x` with `e` in `J`.
Successive instantiations are written `C{e₁, e₂}`, peeling off two
binders in order. For example, assuming we have a type `A` and an
element `a : A`, the abstraction `{x : A} x` instantiated at `a`
gives:

    # let f = {x : A} x ;;
    val f :> judgement = ⊢ {x : A} x : A
    # f {a} ;;
    - :> judgement = ⊢ a : A


## Boundaries

A *boundary* specifies the shape of a judgement that is to be constructed.
In a computation a boundary expresses a goal to be reached.
There are four boundary forms, one for each judgement form:

| Boundary | Concrete syntax | “The goal is to construct a …” |
|---|---|---|
| type-judgement boundary | `⁇ type` | “… type” |
| term-judgement boundary | `⁇ : A` | “… term of type `A`” |
| type-equality boundary | `A ≡ B by ⁇` | “… proof that `A ≡ B`” |
| term-equality boundary | `e₁ ≡ e₂ : A by ⁇` | “… proof that `e₁ ≡ e₂ : A`” |

The `⁇` marker (ASCII `??`) stands at the position where the *head* of the
judgement needs to be filled in; the rest of the boundary fixes the data the
judgement must agree with.

Boundaries, like judgements, can be abstracted. An abstracted
boundary `{x : A} B` classifies abstracted judgements `{x : A} J`
in which the body `J` is classified by `B`.

### Boundary ascription

A computation

    c :? B

where `B` computes to a boundary evaluates `c` in *checking mode* against `B`.
At runtime, the result `j` of `c` is checked against `B`.
A mismatch triggers the operation `ML.coerce j B`. A user-defined handler may
catch `ML.coerce j B` and resume the computation by passing any judgement `j'`
whose boundary is `B`. Of course, the intended use is that `j'` be computed from `j`.

> [!TIP]
> Consider the postulates for a Tarski-syle universe `U` with a decoding `El`
> and a code `bool : U`.
> ```
> rule U type ;;
> rule El (a : U) type ;;
> rule bool : U ;;
> ```
> We must always write `El bool` when a type is expected. This works
> ```
> # rule false : El bool ;;
> Rule false is postulated.
> ```
> but this does not
> ```
> # rule true : bool ;;
> Runtime error: unhandled operation ML.coerce (⊢ bool : U) (⊢ ⁇ type)
> ```
> We may instrument an implicit coercion from `U` to types by installing
> a global handler for the `ML.coerce` operations:
> ```
> with
> | operation ML.coerce (?a : U) (?? type) -> El a
> end
> ```
> Now code are coerced to types they encode:
> ```
> # rule true : bool ;;
> Rule true is postulated.
> ```

## Inference rules

A `rule` declaration introduces a primitive derivation; the
[`derive` computation](#derivations) builds a derived one inside AML.

### The `rule` declaration

A top-level rule declaration has the form

    rule NAME premise₁ premise₂ ... premiseₙ : conclusion

where `NAME` is the rule's name, each `premiseᵢ` describes a premise
together with its boundary, and `conclusion` fixes the shape of the
resulting judgement. The declaration introduces `NAME` as a value of
AML-type `derivation` and applies it to its premises by ordinary
juxtaposition. For example:

    # rule A type ;;
    Rule A is postulated.
    # A
    - :> judgement = ⊢ A type
    # rule a : A ;;
    Rule a is postulated.
    # rule F (x : A) type ;;
    Rule F is postulated.
    # F
    - :> derivation = derive (x : A) → F x type
    # F a
    - :> judgement = ⊢ F a type

`A` and `a` are zero-premise rules and so evaluate directly to the
corresponding judgements. `F` is a one-premise rule and its bare
name is the derivation that takes a term of type `A` to a type
judgement; applying it to `a` yields the judgement `⊢ F a type`.

### Premises

A premise is enclosed in parentheses and has two presentations.
The **basic form** spells out the boundary explicitly with `:?`,

    (z :? B)

where `z` names the premise and `B` is the boundary. The
**shorthand** drops the `:?` and the `⁇` marker, lets the boundary
terminator (`type`, `: T`, `≡ … by …`) stand for the shape of the
boundary, and lifts any local-context prefix out of the boundary
parentheses. The two presentations are interchangeable. For each
of the four boundary forms:

| Basic form | Shorthand | Meaning |
|---|---|---|
| `(z :? ⁇ type)`         | `(z type)`        | `z` is a type-judgement premise. |
| `(z :? ⁇ : A)`          | `(z : A)`         | `z` is a term-judgement premise of type `A`. |
| `(z :? A ≡ B by ⁇)`     | `(A ≡ B by z)`    | `z` witnesses the equality `A ≡ B`. |
| `(z :? a ≡ b : A by ⁇)` | `(a ≡ b : A by z)`| `z` witnesses the equality  `a ≡ b : A`. |

In the equality shorthand the name sits after `by`, not before the
body, since the body is the equation itself.

A premise may also be **abstracted** over local atoms by prefixing
a local context `{x : A} …`. In the basic form the local context
sits inside the boundary; in the shorthand it is lifted to the
front of the premise. The dependent-product formation rule, with
one type premise and one type premise indexed by an element of the
first, illustrates the contrast:

> [!TIP]
> ```
> (* Basic form throughout *)
> rule Π (A :? ⁇ type) (B :? {x : A} ⁇ type) type
>
> (* Shorthand throughout — what one writes in practice *)
> rule Π (A type) ({x : A} B type) type
> ```

Both declarations produce the same derivation. The J-rule for the
identity type carries a deeper local context. Assuming `Id` and
`refl` have been postulated as

> [!TIP]
> ```
> rule Id (A type) (a : A) (b : A) type ;;
> rule refl (A type) (a : A) : Id A a a ;;
> ```

the J-rule reads

> [!TIP]
> ```
> rule J
>   (A type)
>   ({x y : A} {p : Id A x y} C type)
>   ({x : A} c : C{x, x, refl A x})
>   (a : A)
>   (b : A)
>   (q : Id A a b)
>   : C{a, b, q}
> ```

The motive premise `({x y : A} {p : Id A x y} C type)` has a
three-binder local-context prefix; its basic-form equivalent is
`(C :? {x y : A} {p : Id A x y} ⁇ type)`.

## Derivations

In Andromeda the user may *derive* complex rules from primitive ones using
the computation

    derive premise₁ ... premiseₙ -> body

The body of the derivation is checked by the nucleus only once at creation.
(This is to be distinguished from an AML-level function
 `fun j₁ ... jₙ -> j` which accepts some judgements and computes a judgement `j`; the nucleus will check `j` at each function call, which is more expensive but also more flexible as it allows
 implementation of *admissible* rules.)

Each `premiseᵢ` introduces a fresh meta-variable bound under the premise's name in the `body`;
the body evaluates to the conclusion judgement.

A derivation `d` is applied to premises `j₁`, …, `jₙ` with

    judgement d j₁ ... jₙ

A short-hand notation

    d j₁ ... jₙ

is allowed when at least one premise is present.

>[!TIP]
> We may derive reflexivity of types using the [`congruence`](#congruence) computation
> as follows:
> ```
> # let reflexivity = derive (A type) -> A ≡ A by (congruence A A) ;;      
> val reflexivity :> derivation = derive (A type) → A ≡ A
> # rule X type
> Rule X is postulated.
> # judgement reflexivity X
> - :> judgement = ⊢ X ≡ X
> # reflexivity X
> - :> judgement = ⊢ X ≡ X
> ```


## Judgement computations in AML

AML offers a small set of computations that construct, transform,
or inspect nucleus judgements.

### `fresh`

The computation `fresh x : A`, generates a
previously-unseen atom `xᵢ` of type `A` and returns the judgement
stating that `xᵢ` has type `A` in context `xᵢ : A`:

    # fresh x : A
    - :> judgement = x₀ : A ⊢ x₀ : A

AML reports that it computed the judgement `x₀ : A ⊢ x₀ : A`, whose
AML type is `judgement`. Running the same computation again yields a
different atom:

    # fresh x : A
    - :> judgement = x₁ : A ⊢ x₁ : A

The identifier `x` in `fresh x : A` is the display name carried into
the atom; the subscript `ᵢ` is added by the pretty-printer so that
atoms which happen to share a display name are still distinguishable
on the page.

### `abstract`

The computation `abstract a c` takes a free
atom `a` and a judgement (or boundary) `c`, and returns the
abstracted judgement `{a : T} c`, in which `a` no longer occurs free.
A typical session opens with `fresh` to bring an atom into scope,
builds up a judgement that depends on it, and closes with `abstract`
to discharge the atom. Assuming there is a type `A` and a term constructor `f`:

    # let y = fresh y : A
    val y :> judgement = y₀ : A ⊢ y₀ : A
    # f y
    - :> judgement = y₀ : A ⊢ f y₀ : A
    # abstract y (f y)
    - :> judgement = ⊢ {y : A} f y : A

The result of the last computation is the abstracted term judgement
`{y : A} f y : A`; its context is now empty, as `y` has been
discharged.

### `meta`

The computation `meta x` introduces a fresh
meta-variable in a checking-mode position. The name `x` becomes the
meta's display name; successive uses of `meta x` produce distinct
meta-variables, disambiguated in the pretty-printer by subscripts:

    # rule A type ;;
    Rule A is postulated.
    # meta x :? ?? type
    - :> judgement = ?x₀ type ⊢ ?x₀ type
    # meta x :? (?? : A)
    - :> judgement = ?x₁ : A ⊢ ?x₁ : A

### `convert`

The computation `convert e ξ` transports a
term `e` of type `A` along a type equality `ξ : A ≡ B` to obtain a
term of type `B`. Assuming a postulated equality `eq : A ≡ B` and a
term `e : A`:

    # convert e eq
    - :> judgement = ⊢ e : B

### `congruence`

The computation

    congruence j₁ j₂ ξ₁ ... ξₖ

proves an equality between two judgements `j₁` and `j₂` that share
the same head, given equality witnesses `ξᵢ` for each pair of
corresponding sub-arguments. The result is an equality judgement
relating `j₁` to `j₂`.

### `rewrite`

The computation

    rewrite j ξ₁ ... ξₖ

applies the equalities `ξᵢ` as rewrites inside the judgement `j`,
returning a pair: the equality witness that relates the input to
the rewritten judgement, and the rewritten judgement itself.

### `context`

The computation `context j` yields the list
of free atoms on which the judgement `j` depends, each presented as
a term judgement giving the atom and its type:

    # rule A type ;;
    Rule A is postulated.
    # let x = fresh x : A in context x
    - :> list judgement = (x₀ : A ⊢ x₀ : A) :: []

### `occurs`

The computation `occurs x j` tests whether
the atom `x` occurs free in the judgement `j`. The result is
`ML.None` if `x` does not appear in `j`, or `ML.Some t` where `t`
is the type judgement giving `x`'s type:

    # rule A type ;;
    Rule A is postulated.
    # let x = fresh x : A in occurs x x
    - :> ML.option judgement = ML.Some (⊢ A type)

### `natural`

For a term judgement `e : A`, the computation
`natural e` returns the type equality `B ≡ A`, where `B` is the
*natural* type of `e` (the type read off `e`'s head) and `A` is
the type at which `e` is currently held. When no conversion has
intervened the natural type and the current type coincide, and
the resulting equality is reflexive:

    # rule A type ;;
    Rule A is postulated.
    # rule a : A ;;
    Rule a is postulated.
    # natural a
    - :> judgement = ⊢ A ≡ A


## Judgement and boundary patterns

The judgement and boundary patterns, listed in the AML chapter under
[Judgement and boundary patterns](language.md#judgement-and-boundary-patterns),
destructure nucleus judgements and boundaries by their form. The
semantic content of each pattern is:

| Pattern             | Matches and binds                                                                  |
|---|---|
| `p type`            | a type judgement; `p` matches the type                                             |
| `p₁ : p₂`           | a term judgement; `p₁` matches the term, `p₂` its type                             |
| `p₁ ≡ p₂`           | a type equality; `p₁` and `p₂` match the two sides                                 |
| `p₁ ≡ p₂ : p₃`      | a term equality; `p₁` and `p₂` match the two sides, `p₃` matches the type          |
| `⁇ type`            | a type-judgement boundary                                                          |
| `⁇ : p`             | a term-judgement boundary; `p` matches the type                                    |
| `p₁ ≡ p₂ by ⁇`      | a type-equality boundary; `p₁` and `p₂` match the two sides                        |
| `p₁ ≡ p₂ : p₃ by ⁇` | a term-equality boundary; `p₁` and `p₂` match the two sides, `p₃` matches the type |
| `{x : p₁} p₂`       | an abstraction; `x` is bound as an atom, `p₁` matches its type, `p₂` the body      |
| `_atom p`           | an atom; `p` matches the atom's type                                               |

### The linearity requirement

For a derivation to be registered with the equality checker as a
rule (see [Equality checking](#equality-checking-via-the-standard-library)
below), each of its premise meta-variables must appear exactly once
in the head of the conclusion. The checker uses this *linearity* to
recover the premises from the shape of the goal.


## Equality checking via the standard library

Andromeda's nucleus only sees syntactic (α-)equality. Substantive
judgemental equality is delegated to user code through the
`equal_type` and `coerce` operations the runtime triggers when a
boundary needs to be matched. The standard library installs
handlers for these operations that run an extensible *equality
checker*, configured by adding derivations as equality rules.

### The `eq` module

The `eq` module exposes the equality checker. Its principal names
are `add_rule` for registering a derivation as a rule,
`add_locally` for scoping a rule to a sub-computation, and
`normalize_type` and `normalize_term` for driving a judgement
toward a normal form. The module also installs the runtime
handlers that consult the checker when `equal_type` or `coerce` is
raised.

### Adding rules: `eq.add_rule`

`eq.add_rule drv` registers the derivation `drv` as an equality
rule with the global checker. The rule must satisfy the
[linearity requirement](#the-linearity-requirement); the checker
classifies the rule as either a β-rule or an extensionality rule by
inspecting its shape.

### Local rules: `eq.add_locally`

`eq.add_locally drv (fun () -> c)` adds `drv` to the checker for
the duration of the computation `c` and retracts it afterwards.
This is the idiom for using an equality rule only inside a
particular derivation.

### Normalisation: `eq.normalize_type`, `eq.normalize_term`

`eq.normalize_type chk sgn t` and `eq.normalize_term chk sgn e`
repeatedly apply the β-rules registered with the checker `chk`
until no rule fires, returning a pair of (the equality witness
relating the input to its normal form, the normal-form judgement
itself).

### β-rules and extensionality rules

The checker accepts two shapes of equality rule.

A *β-rule* (or *computation rule*) rewrites a redex. Its
conclusion has the form `head … ≡ … : T`, where the left-hand
side's head is a recognisable constructor and the right-hand side
is the redex's reduct. The β-rule for the dependent product, for
instance, reduces `app A B (λ A' B' s) a` to `s{a}`.

An *extensionality rule* equates two terms by exhibiting agreement
of their components. Its conclusion has the form `x ≡ y : T`,
where `x` and `y` are the last two premises and `T` constrains
the type at which they are compared. Function extensionality —
two functions are equal when they agree pointwise — is the
standard example.


## A worked example: the dependent product

The type former Π takes a type `A` and a type `B` indexed by an
element of `A`, and yields a type:

    rule Π (A type) ({x : A} B type) type

The introduction λ takes the same two premises plus a body — a
term of `B{x}` parametric in `x : A` — and yields a term of type
`Π A B`:

    rule λ (A type) ({x : A} B type) ({x : A} e : B{x}) : Π A B

The elimination `app` takes a function `s : Π A B` and an argument
`a : A`, yielding a term of `B{a}`:

    rule app (A type) ({x : A} B type) (s : Π A B) (a : A) : B{a}

These three rules give the *shape* of the dependent product;
behaviour is supplied by equality rules registered with the
checker. The β rule reduces an application of λ to its argument.
The full declaration carries extra premises so that the rule
applies up to definitional equality of the domain and codomain:

    rule Π_β (A type) ({x : A} B type)
             (A' type) ({x : A'} B' type)
             ({x : A'} s : B'{x}) (a : A)
             (A' ≡ A by ξ) ({x : A'} B'{x} ≡ B{convert x ξ} by ζ)
             :?
             (eq.add_locally (derive -> ξ) (fun () ->
               eq.add_locally (derive (x : A') -> ζ{x}) (fun () ->
                 app A B (λ A' B' s) a ≡ s{a} : B{a} by ??
               )))
    eq.add_rule Π_β

Extensionality says two functions are equal when they agree
pointwise:

    rule Π_ext (A type) ({x : A} B type)
               (f : Π A B) (g : Π A B)
               ({x : A} app A B f x ≡ app A B g x : B{x})
               : f ≡ g : Π A B
    eq.add_rule Π_ext

Once these declarations are in scope, the checker handles
β-reduction and function extensionality automatically wherever a
boundary is to be matched.
