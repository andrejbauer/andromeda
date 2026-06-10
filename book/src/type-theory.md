# Object type theories

*This chapter is under construction. The section headings below
indicate the planned structure; short paragraphs under each name what
the section will contain when filled in.*


## What Andromeda's object level is

Andromeda is organised in two layers: a *meta-language*, in which the
user writes programs that construct and manipulate proofs, and an
*object type theory*, whose judgements those programs reason about.
The meta-language is AML, documented in
[The Andromeda meta-language](language.md). The object type theory is
declared by the user, by postulating its inference rules with `rule`
declarations; Andromeda itself is generic in this choice, and the
contents of `./theories/` illustrate how different theories — the
dependent product, the identity type, full Martin-Löf type theory, and
others — arise from such postulations.

Every value of ML-type `judgement` originates in the *nucleus*, the
small trusted component of the implementation. The nucleus admits two
kinds of inference rule: those the user has postulated, and a fixed
collection of general structural rules — congruence rules, and the
reflexivity, symmetry, and transitivity of judgemental equality. From
this design follows the central correctness guarantee.

<div class="claim">
<strong>Soundness.</strong> Every value of ML-type
<code>judgement</code> produced during the execution of an Andromeda
program is derivable, in the inference rules the user has postulated
together with the built-in structural rules, from the assumptions
recorded in its context.
</div>

A judgement records, as part of its representation, every free atom
and every meta-variable on which it depends. Combining several
judgements — by applying a rule, by appealing to an equality, by
abstracting over an atom — yields a result whose context is the union
of the input contexts, computed by Andromeda itself.

The rest of the chapter develops these ideas, in order: the four
forms of judgement; the boundaries that classify them; the syntax of
`rule` declarations; the AML expressions that build and inspect
judgements; the patterns over judgements and boundaries; and the
equality checker exposed by `stdlib/eq.m31`.


## Judgements

> *Stub: the four primitive judgement forms, together with atoms,
> meta-variables, and the abstraction operation that nests over them.*

### The four judgement forms

> *Stub: the shapes `A type`, `e : A`, `A ≡ B`, `e₁ ≡ e₂ : A`, and
> their intended readings as is-type, is-term, type-equality, and
> term-equality judgements.*

### Atoms

> *Stub: free variables of the object theory, introduced via `fresh`;
> their typing by the carried is-type judgement; and the role they
> play in abstractions and rule premises.*

### Meta-variables

> *Stub: named placeholders that stand for a yet-to-be-supplied
> judgement, classified by their boundary. The `meta` primitive (the
> primitive form, taking an optional display name and requiring a
> known boundary); the `?` operator from `stdlib/prelude.m31` as a
> derived convenience; and the three flavours: type, term, and
> equational meta-variables.*

### Abstractions

> *Stub: the form `{x : A} J`, which generalises a judgement over an
> atom of type `A`; the nesting of abstractions; the instantiation
> form `C{e}`; and an explicit note that curly braces denote
> *explicit* substitution rather than implicit arguments in the sense
> of some other proof assistants.*


## Boundaries

> *Stub: boundaries are classifiers — each boundary describes the
> shape of an acceptable judgement in a given position, without
> committing to its content. Boundaries themselves can be abstracted,
> mirroring abstractions of judgements.*

### What a boundary is

> *Stub: motivation and rough description; the four boundary forms
> as the duals of the four judgement forms.*

### The four boundary forms

> *Stub: `?? type`, `?? : A`, `A ≡ B by ??`, `e₁ ≡ e₂ : A by ??`,
> with the `??` (or `⁇`) marker indicating the position in which a
> judgement of the named shape would sit.*

### Boundary ascription `:?`

> *Stub: the construct `c :? bdry`, which places `c` under
> checking-mode evaluation against the boundary `bdry`. The standard
> position in which `meta x` may be used, together with the other
> positions in which a checking-mode boundary is supplied.*

### Why boundaries

> *Stub: the role boundaries play in directing checking-mode
> evaluation, in supplying the information needed to introduce a
> fresh meta-variable, and in allowing handlers to observe the
> shape of the judgement being asked for.*


## Declaring inference rules

> *Stub: how the object theory is given. The `rule` declaration, its
> premises and conclusion, and the relationship between rule premises
> and the boundary-classifier discussion of the previous section.*

### The `rule` declaration

> *Stub: the top-level form `rule NAME premises : conclusion`; the
> value this introduces into the meta-language (a `derivation`); the
> notational conventions for premises and conclusion.*

### Premises

> *Stub: the basic form of a premise, `(x :? bdry)`, with an explicit
> boundary, and the shorthand `({local context} x boundary-terminator)`
> in which the boundary terminator (`type`, `: T`, `≡ … by …`) stands
> for the boundary shape and the local-context prefix moves out of
> the boundary into the premise.*

#### is-type and is-term premises

> *Stub: `(A type)` and `(a : A)`, the most common premise shapes.*

#### Equality premises with named witnesses

> *Stub: `(A ≡ B by ξ)` and `(a ≡ b : A by ξ)`, which bind a name to
> the proof of the equality so that subsequent premises and the
> conclusion can refer to it.*

#### Abstracted premises

> *Stub: `({x : A} B type)` and similar — premises that themselves
> depend on local atoms; their relation to abstracted boundaries.*

#### Local-context prefix in a premise

> *Stub: the longer form, with several locally-bound atoms in front
> of a premise, e.g. `({x : A} {y : B{x}} J)`.*

### Conclusions

> *Stub: the four shapes a rule conclusion may take — `type`,
> `: T`, `≡ … by …`, and the explicit `:? bdry` form — and what each
> contributes to the rule's signature.*

### A worked example: the dependent product

> *Stub: a walk-through of `theories/dependent_product.m31`, covering
> the rules `Π`, `λ`, `app`, the β rule `Π_β`, and the extensionality
> rule `Π_ext`. The example will be used throughout the rest of the
> chapter.*


## Judgement-level expressions in AML

> *Stub: the AML expressions that construct, transform, and inspect
> nucleus judgements. Each subsection states the signature of the
> construct in terms of judgements and boundaries, describes what it
> computes, and gives an example.*

### Applying a declared rule

> *Stub: the application form `r j₁ … jₙ`, in which the rule `r`
> declared via `rule` is applied to its premises in order; the
> relation to the rule's premise list.*

### `meta`

> *Stub: the form `meta x`, which introduces a fresh meta-variable in
> a checking-mode position with a prescribed boundary; the display
> convention by which consecutive `meta x` calls produce distinct
> meta-variables disambiguated in print.*

### `derive`

> *Stub: the form `derive (premises) -> body`, which builds a
> derivation parametric in its premises; how the produced derivation
> is invoked as if it were a primitive rule.*

### `convert`

> *Stub: the form `convert e ξ`, which transports a term `e : A`
> along an equality `ξ : A ≡ B` to obtain a term of type `B`.*

### `congruence`

> *Stub: the form for proving an equality between applications of the
> same head, given equalities between corresponding sub-judgements.*

### `rewrite`

> *Stub: the form for applying a registered equality as a rewrite at
> a position inside a judgement.*

### `abstract`

> *Stub: the form `abstract a c`, the inverse of `c{e}` substitution:
> wraps a judgement or boundary `c` in an outer abstraction binding
> the free atom `a`. Typical use is `fresh a : A in … abstract a …`.*

### `context`

> *Stub: the form that yields the list of free atoms on which a
> judgement depends.*

### `occurs`

> *Stub: the form testing whether a given atom occurs free in a
> judgement.*

### `natural`

> *Stub: the form `natural e`. (To be investigated and described.)*

### `fresh`

> *Stub: the form `fresh x : A`, which introduces a fresh atom of
> the given type into the surrounding scope.*


## Judgement and boundary patterns

> *Stub: the patterns introduced briefly in the
> [language chapter](language.md#judgement-and-boundary-patterns),
> together with their semantic content — what each pattern accesses
> inside the judgement or boundary it matches.*

### Recap and full reference

> *Stub: per-pattern semantics, with examples.*

### A worked match from `stdlib/eq.m31`

> *Stub: a realistic match on judgements and boundaries drawn from
> the standard library's equality apparatus, walked through.*


## Equality checking via `stdlib/eq.m31`

> *Stub: the equality checker provided by the standard library, the
> rules it accepts, and the interface it offers to the user.*

### The `eq` module

> *Stub: the names provided by `stdlib/eq.m31` and the role of each.*

### Adding rules: `eq.add_rule`

> *Stub: registration of a derivation as a global equality rule.*

### Local rules: `eq.add_locally`

> *Stub: scoping an equality rule to a sub-computation.*

### Normalisation: `eq.normalize_type`, `eq.normalize_term`

> *Stub: driving the checker towards a normal form.*

### β-rules and extensionality rules

> *Stub: the two shapes of equality rule the checker accepts.*

### The linearity requirement

> *Stub: the requirement that each premise meta-variable in a
> registered rule appear linearly in the conclusion's head.*
