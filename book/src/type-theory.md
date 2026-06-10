# Object type theories

*Skeleton chapter — sections will be filled in iteratively. Each
section's stub names what it will cover; nothing here is yet a
reference claim.*


## What Andromeda's object level is

The split between the AML meta-language and the user-defined object
type theory; the role of the nucleus; what it means for a judgement
to be "derivable from the postulated rules". Sets up the rest of the
chapter.


## Judgements

The four judgement forms and the auxiliary notions (atoms,
meta-variables, abstractions) that appear inside them.

### The four judgement forms

`A type`, `e : A`, `A ≡ B`, `e₁ ≡ e₂ : A` — what each one asserts.

### Atoms

Free variables of the object theory, introduced by `fresh`. Their
relationship to abstractions.

### Meta-variables

Holes that can be instantiated to judgements. The `?` operator from
[`stdlib/prelude.m31`](../stdlib/prelude.m31) and the `meta` keyword.

### Abstractions

`{x : A} J` — generalising a judgement over an atom. How
abstractions nest, and how they appear as rule premises.


## Boundaries

The dual notion to judgements: the *shape* an expected judgement
should satisfy, without its data.

### What a boundary is

A "judgement with its conclusion blanked out". The role boundaries
play in checking-mode evaluation and partial rule application.

### The four boundary forms

is-type, is-term `: A`, type-equality `A ≡ B by ⁇`, term-equality
`e₁ ≡ e₂ : A by ⁇` — one boundary per judgement form, with the
"hole" marked by `⁇`.

### Boundary ascription `:?`

The `c :? bdry` form for asking that `c` produce a judgement of the
shape `bdry`.

### Why boundaries

Why this concept exists: directing checking mode, supplying enough
context for rule premises to be inferred, letting handlers observe
what kind of judgement is being asked for.


## Declaring inference rules

How the user postulates the inference rules of their type theory.

### The `rule` declaration

The top-level form `rule NAME premises : conclusion`. What it
introduces into the signature.

### Premises

The shapes a premise can take.

#### is-type and is-term premises

`(A type)`, `(a : A)` — the basic premise forms.

#### Equality premises with named witnesses (`… by ξ`)

`(A ≡ B by ξ)`, `(a ≡ b : A by ξ)` — equality premises that bind a
name to the proof of the equality.

#### Abstracted premises (`{x : A} J`)

Premises that themselves depend on local atoms, like
`({x : A} B type)`.

#### Local-context prefix in a premise

The shared local-context prefix in front of a premise, e.g.
`(x : A, y : B, ... bdry)`.

### Conclusions

The shapes the rule's conclusion may take: `type`, `: T`,
`… ≡ … by …`, `:? …`.

### A worked example: dependent product

A line-by-line walk-through of `theories/dependent_product.m31`,
covering `Π`, `λ`, `app`, the β rule `Π_β`, and the extensionality
rule `Π_ext`.


## Judgement-level expressions in AML

The AML expressions that build, transform, or observe nucleus
judgements. Each subsection: signature, one-sentence description,
one-line example.

### Applying a declared rule

How a `rule`-declared name is invoked as a judgement-former.

### `meta`

Referring to a meta-variable; how `meta hole :? bdry` produces a
fresh meta with a given boundary.

### `derive`

Building a derivation parametric in its premises.

### `convert`

Transporting a judgement across a type equality.

### `congruence`

Congruence rule application.

### `rewrite`

Applying an equality as a rewrite rule.

### `abstract`

Abstracting an atom out of a judgement.

### `context`

Listing the free atoms of a judgement.

### `occurs`

Testing whether an atom occurs in a judgement.

### `natural`

(To document — what `natural e` computes.)

### `fresh`

Introducing a fresh atom of a given type.


## Judgement and boundary patterns

The patterns introduced briefly in the
[language chapter](language.md#judgement-and-boundary-patterns),
explained in semantic detail.

### Recap and full reference

For each pattern, what it accesses inside the judgement or boundary
it matches.

### Worked match from `stdlib/eq.m31`

A realistic match-on-judgement example, walked through.


## Equality checking via `stdlib/eq.m31`

The equality checker exposed by the standard library.

### The `eq` module at a glance

The names that `stdlib/eq.m31` provides, and what each is for.

### Adding rules: `eq.add_rule`

Registering a derivation as a global equality rule.

### Local rules: `eq.add_locally`

Scoping an equality rule to a sub-computation.

### Normalisation: `eq.normalize_type`, `eq.normalize_term`

Driving the checker forward to a normal form.

### β-rules and extensionality rules

The two shapes of equality rule the checker accepts.

### The linearity requirement

Why each pattern variable in a rule must appear exactly once in the
conclusion's head.
