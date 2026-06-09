
# The Andromeda meta-language


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
Harrison](http://www.cl.cam.ac.uk/~jrh13/) could print the [HOL Light
kernel](http://www.cl.cam.ac.uk/~jrh13/) on a T-shirt, we may need a cape to
print the 4000 lines of the [Andromeda
nucleus](https://en.wikipedia.org/wiki/Andromeda_Galaxy#Nucleus).


## ML-types

The AML types are called **ML-types**, and are separate from the types
appearing in the object type theory. They follow closely the usual ML-style
parametric polymorphism, with the addition of `judgement`, `boundary`,
and `derivation`, the reflection of nucleus values into AML.

### ML-type definitions

An ML-type abbreviation may be defined as

    mltype foo = t

An ML-type may be parametrized:

    mltype foo α β ... γ = t

A disjoint sum is defined as

    mltype foo =
      | constr₁ of t₁
      ...
      | constrⱼ of tⱼ

A leading `|` is optional and the declaration is terminated by `;;` or by
the next top-level command.

Each constructor takes at most one argument. To pack several values into
a constructor, use a tuple: `| Pair of α * β`. Constructors are
namespaced under the current [module](#modules) — `foo` declared at the
top level introduces the bare names `constr₁ … constrⱼ`. They need not
be capitalized but they must be fully applied when used as values.

The empty ML-type is defined with no constructors:

    mltype empty = | ;;

An ML-type may be declared *abstractly*, without any constructors. Such
a type can be used wherever a type is expected, but it has no
introduction or elimination forms inside AML — values of an abstract
type are typically produced by externals. The declaration takes the
form `mltype NAME` or `mltype NAME α β ... γ`.

### Inductive ML-datatypes

A recursive ML-type is declared with `mltype rec`:

    mltype rec t α β ... γ =
      | constr₁ of t₁
      ...
      | constrⱼ of tⱼ

The recursion must be guarded by data constructors, i.e., we only allow
*inductive* definitions. ML-type application is *prefix* (`t α`, not
`α t`), so the standard tree datatype reads

    mltype rec tree α =
      | Empty
      | Tree of α * tree α * tree α

Mutually recursive types are joined with `and`:

    mltype rec even =
      | Zero
      | SuccE of odd
    and odd =
      | SuccO of even

### Predefined ML-types

Andromeda binds the following ML-types before any user code runs.

The built-in ML-types, which are reserved keywords and have no
user-level constructors:

* `mlunit` is the unit type whose only value is the empty tuple `()`
* `mlstring` is the type of [strings](#strings)
* `judgement` is the type of nucleus judgements
* `boundary` is the type of nucleus boundaries
* `derivation` is the type of nucleus derivations
* `ref t` is the type of mutable references to a value of type `t`

The datatypes pre-defined in the standard library:

* `list α` is the type of [lists](#lists), with constructors `[]` and
  `::`
* `ML.option α` is the type of [optional values](#optional-values), with
  constructors `ML.None` and `ML.Some`
* `ML.bool` is the type of booleans, with constructors
  `ML.true` and `ML.false`
* `ML.order` is the type used for comparison of ML
  values, with constructors `ML.less`, `ML.equal`, `ML.greater`

The `judgement`, `boundary`, and `derivation` ML-types are reflections of the
nucleus's trusted datatypes; their use is covered under the object type
theory reference (forthcoming). The `ref` type and the operations on it
appear in [Mutable references](#mutable-references).


## General-purpose programming

AML is a general-purpose programming language which supports the following programming features:

* [`let`-bindings](#let-binding) of values
* first-class [functions](#functions)
* (mutually) [recursive functions](#recursive-functions)
* datatypes ([lists](#lists), [tuples](#tuples), and [user-definable data types](#ml-type-definitions))
* [`match` statements and pattern matching](#match-statements-and-patterns)
* [operations and handlers](#operations-and-handlers)
* [exceptions](#exceptions)
* [mutable references](#mutable-references)
* [modules](#modules)

### `let`-binding

A binding of the form

    let x = c₁ in c₂

computes `c₁` to a value `v`, binds `x` to `v`, and computes `c₂`. Thus, whenever `x` is
encountered in `c₂` it is replaced by `v`.

A `let`-binding may be annotated with an ML-type schema using `:>`:

    # let cow :> mlstring = "cow"
    val cow :> mlstring = "cow"

The `:>` is the *ML schema* ascription. A binding annotated with `:` (no
`>`) is read instead as a typing-judgement ascription on a judgement
computation, and is covered under the object type theory reference
(forthcoming).

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

You may use [patterns](#ml-patterns) in `let`-bindings, in which case the bound variables should be marked with `?`:

    # let (?a, ?b) = ("a", "b")
    val a :> mlstring = "a"
    val b :> mlstring = "b"
    # let (ML.Some ?p) = ML.Some ["p"]
    val p :> list mlstring = "p" :: []


### Functions

An AML function has the form

    fun x -> c

Example:

    # fun x -> (x, x)
    - :> mlforall α, α → α * α = <function>
    # (fun x -> (x, x)) "foo"
    - :> mlstring * mlstring = ("foo", "foo")

The arguments may be annotated with a type, in which case it is considered a [pattern](#ml-patterns), so any bound variables must be
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

### Recursive functions

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

### Sequencing

The sequencing construct

    c₁ ; c₂

computes `c₁`, discards the result, and computes `c₂`. It is equivalent to

    let _ = c₁ in c₂

If `c₁` has type other than `mlunit`, a warning is printed.

### Predefined data values

#### Strings

A string is a sequence of characters delimited by quotes, e.g.

    "This string contains forty-two characters."

Its type is `mlstring`. There are no built-in operations on strings other
than printing; equality and comparison are exposed by the standard
library via the `compare` external.

#### Tuples

A meta-level tuple is written as `(c₁, ..., cᵢ)`. Its type is
`t₁ * ... * tᵢ` where `tⱼ` is the type of `cⱼ`. The unit value `()` has
type `mlunit`.

#### Optional values

The value `ML.None` indicates a lack of value and `ML.Some c` indicates
the presence of value `c`. The type of `ML.None` is
`mlforall α, ML.option α`; the type of `ML.Some c` is `ML.option t` if
`t` is the type of `c`.

#### Lists

The empty list is written as `[]`. The list whose head is `c₁` and the
tail is `c₂` is written as `c₁ :: c₂`. The computation

    [c₁; c₂; ... cᵢ]

is shorthand for

    c₁ :: (c₂ :: ... (cᵢ :: []))

Note the **semicolon** separator inside the brackets; commas would build
a tuple. A list of type `list t` must hold values of type `t`.

### `match` statements and patterns

A `match` statement is also known as `case` in some languages and is
simulated by successive `if`-`else if`-...-`else if`-`else` in others.
The general form is

    match c with
    | p₁ -> c₁
    | p₂ -> c₂
      ...
    | pᵢ -> cᵢ
    end

The first clause whose pattern matches `c` is evaluated. The variables
bound in `pᵢ` are available in `cᵢ`. If no pattern matches the value, a
runtime error is reported.

The leading bar `|` may be omitted. A pattern may be *guarded* with a
boolean condition:

    | pᵢ when bᵢ -> cᵢ

In this case, the value of `c` has to match `pᵢ` *and* the guard `bᵢ`
must evaluate to `ML.true`. The variables bound in `pᵢ` are available in
both `bᵢ` and `cᵢ`.

Example:

    # match ["foo"; "bar"; "baz"] with
      | ?x :: (?y :: _) -> ML.Some (y, x)
      | _              -> ML.None
      end
    - :> ML.option (mlstring * mlstring) = ML.Some (("bar", "foo"))

The first pattern matches the list, binding `x` to `"foo"` and `y` to
`"bar"`.

#### ML patterns

The patterns that match ordinary ML values are:

| Pattern | Matches |
|---|---|
| `_` | any value |
| `?x` | any value, binding it to `x` |
| `p as ?x` | values matched by `p`, also binding the value to `x` |
| `p :> t` | values matched by `p` of ML-type `t` |
| `Constr p` | a datatype constructor applied to its argument |
| `[]` | the empty list |
| `p₁ :: p₂` | the head and the tail of a non-empty list |
| `[p₁; ...; pᵢ]` | a list with exactly the given elements |
| `(p₁, ..., pᵢ)` | a tuple of the given elements |
| `"..."` | a string literal |

Patterns must be linear, i.e., in a pattern each pattern variable `?x` may appear at most once.

#### Judgement and boundary patterns

In addition to the ML patterns above, AML has patterns that destructure
the nucleus's judgements and boundaries. The full story — what
judgements and boundaries *are*, how they arise, and how the four forms
relate to the rules of the object type theory — belongs to the object
type theory reference (forthcoming). For pattern-matching purposes
only, the available forms are:

| Pattern | Matches |
|---|---|
| `p type` | an is-type judgement |
| `p₁ : p₂` | an is-term judgement with type matched by `p₂` |
| `p₁ ≡ p₂` | a type-equality judgement |
| `p₁ ≡ p₂ : p₃` | a term-equality judgement at type matched by `p₃` |
| `⁇ type` | an is-type boundary |
| `⁇ : p` | an is-term boundary with type matched by `p` |
| `p₁ ≡ p₂ by ⁇` | a type-equality boundary |
| `p₁ ≡ p₂ : p₃ by ⁇` | a term-equality boundary at type matched by `p₃` |
| `{x : p₁} p₂` | an abstraction binding an atom of type matched by `p₁` |
| `_atom p` | an atom (free variable) |

The marker `⁇` (or its ASCII form `??`) signals the *shape* of a
boundary; it does not bind. The boundary patterns appear naturally in
operation cases, where the checking-mode boundary flows in after the
colon, e.g.

    with
      | operation (?) : ML.Some (⁇ : ?t) -> ...
    end

binds `?t` to the type carried by the term boundary.

### Operations and handlers

AML operations and handlers are similar to those of the
[Coop](https://github.com/andrejbauer/coop) programming language. They
let the user-level code intercept and react to events that arise during
evaluation — equality questions, coercion requests, missing
information — rather than baking them into the nucleus.

#### Operations

A new operation is declared by

    operation op : t₁ → t₂ → ... → tᵢ → u

where `op` is the operation name, `t₁`, ..., `tᵢ` are the types of the
operation arguments, and `u` is its return type. There need not be any
arguments, i.e., it is valid to declare

    operation op : u

An operation is then invoked with

    op c₁ .. cᵢ

where `cⱼ` must have type `tⱼ`, and the type of the computation is `u`.

When an operation is invoked, it propagates outward to the innermost
[handler](#handlers) that has a matching case for it. The handler
decides what value to return; that value is then resumed back into the
computation that invoked the operation. Operations are like resumable
[exceptions](#exceptions) — control returns to the point of invocation,
unless the handler raises a proper exception instead.

#### Handlers

A handler value has the form

    handler
    | case₁
    | case₂
    ...
    | caseⱼ
    end

where each `caseᵢ` is an [operation case](#operation-cases), an
[exception case](#exception-cases), or a [value case](#value-cases).
The first case that matches is used. If no case matches, the value,
exception, or operation propagates outward to the next enclosing
handler.

##### Operation cases

An operation case in a `handler … end` value has the form

    | op p₁ ... pᵢ -> c

or the form

    | op p₁ ... pᵢ : p -> c

The first form matches an invoked [operation](#operations)
`op' v₁ ... vᵢ` when `op` equals `op'` and each `vⱼ` matches the
corresponding pattern `pⱼ`. The second form additionally matches the
*checking-mode boundary* against `p`: when the operation was invoked in
checking mode with boundary `bdry`, then `ML.Some bdry` matches `p`; in
inferring mode, `ML.None` matches `p`. The
[boundary patterns](#judgement-and-boundary-patterns) can be used here
to destructure the boundary.

When an operation case matches, the body `c` is evaluated with the
pattern variables bound to the corresponding values. The value `v`
produced by `c` is passed back to the point of operation invocation,
unless `c` itself raises an [exception](#exceptions).

##### Value cases

A value case has the form

    | val p -> c

It is used when the handled computation evaluates to a value `v`
without invoking any [operation](#operations). The first value case
whose pattern matches `v` is used.

If no value case is present in the handler, the trivial case
`val ?x -> x` is assumed. If at least one value case is present but the
handled computation evaluates to a value matched by none of them, a
runtime error occurs.

##### Exception cases

An exception case has the form

    | raise p -> c

It catches an exception matched by `p` and evaluates `c`. An exception
is non-resumable, so the value of `c` becomes the value of the entire
`with … try …` construct.

#### The handling construct

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

When a computation `c` invokes an [operation](#operations), the
operation is handled by the innermost enclosing [handler](#handlers)
that has a matching [case](#operation-cases) for it.

#### Exceptions

Exception types are declared at the top level. The declaration

    exception Exn

introduces a nullary exception, and

    exception Exn of t

introduces an exception that carries one piece of data of ML-type `t`.

An exception is raised with

    raise (Exn c)

(or `raise Exn` for a nullary exception), and caught by an
[exception case](#exception-cases) in a handler. Exceptions are
*non-resumable*: when caught, control does not return to the `raise`
site, it stays in the handler's body.

For example:

    # exception StrExn of mlstring
    Exception StrExn is declared.
    # let g = handler | raise StrExn ?s -> s end
    val g :> mlstring ⇒ mlstring = <handler>
    # with g try raise (StrExn "msg")
    - :> mlstring = "msg"

#### Top-level handlers

[Handlers](#handlers) may also be installed globally with a top-level
command:

    with
      | operation op₁ p₁₁ ... -> c₁
      ...
      | operation opᵢ pᵢ₁ ... -> cᵢ
    end

Note that *top-level* operation cases are introduced by the keyword
`operation`, whereas [operation cases](#operation-cases) inside a
`handler … end` value are not. A top-level handler installation
replaces whatever handler was previously installed for the named
operations. There can be no value or exception case at the top level —
the cases are operation cases only.


### Mutable references

Mutable references are as in OCaml:
* a fresh reference is introduced by `ref c` where `c` evaluates to its initial value
* if `c` evaluates to a reference, its value can be accessed by `! c`
* if `c` evaluates to a reference, its value can be modified by `c := c'` where `c'` evaluates to the new value.

The ML-type of a mutable cell holding values of type `t` is `ref t`.

### Modules

Andromeda has a simple module system for grouping declarations and
controlling namespaces. There are four constructs:

#### Defining a module inline

A submodule may be defined directly in the source:

    module M = struct
      let greeting = "hello"
      mltype color = | Red | Green | Blue
    end

After this declaration, the names inside `M` are accessible with dotted
qualification: `M.greeting`, `M.Red`, `M.color`. Module names are
ordinary identifiers; by convention they are capitalised, but the
parser does not require it.

#### `require`

The toplevel command

    require X

looks for a file named `X.m31` and processes it as a module. The search
path is the directory of the current file followed by any directories
supplied via the `-I` command-line flag. Each file is loaded at most
once per session — re-requiring an already-loaded module is a no-op.

The standard library (`./stdlib/`) is automatically on the search path
unless `--no-stdlib` is given. The stock prelude is loaded automatically
unless `--no-prelude` is given.

Several modules may be required at once:

    require base, eq

#### `include`

    include M

copies the bindings of module `M` into the current namespace. The
copied bindings remain accessible after the inclusion both unqualified
(`greeting`) and as members of `M` (`M.greeting`). Use `include` when
you want the included names to be re-exported as part of the enclosing
module.

#### `open`

    open M

makes the bindings of `M` accessible without qualification in
subsequent code, but does *not* re-export them. After `open M`, you
write `greeting` directly; clients of the surrounding module still need
`M.greeting` (unless they too `open M`).

Qualified paths may have several components: `Module.Submodule.name`.
