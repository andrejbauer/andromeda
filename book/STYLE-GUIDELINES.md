# Andromeda documentation style guidelines

This file collects every style and writing rule given during the
documentation rewrite. New prose must pass every check below.

## 1. Audience and voice

- The reader is a competent programmer or type theorist. Write in the
  tone of the existing AML chapter: educated, precise, no padding.
- Use the editorial "we" sparingly for asides. **Never address the
  reader as "you".**
- Vary sentence length. Avoid choppy three-word sentences.
- Banned filler words and phrases: *purely positional*,
  *structurally essential*, *by construction*, *namely*, *indeed*,
  *hence/thus*, *in the sense that*, *load-bearing*, *non-trivial*,
  *essentially*, *more or less*, *respectively*.

## 2. Terminology

The project uses fixed names. Do not switch between synonyms.

| Use                                | Never use                       |
|------------------------------------|---------------------------------|
| AML                                | ML, meta-language               |
| AML-type                           | ML-type                         |
| AML pattern                        | ML pattern                      |
| AML value                          | ML value                        |
| computation                        | expression (for an AML program) |
| type judgement, term judgement     | is-type, is-term                |
| type equality, term equality       | type-equality, term-equality    |
| object judgement, equality judgement | (no other phrasing)           |
| primitive derivation               | (no other phrasing)             |
| derived derivation                 | (no other phrasing)             |
| instantiation, instantiate         | substitution (when discussing `C{e}`) |
| atom                               | object-level variable           |

Source-level identifiers (`ML.Some`, `ML.None`, `ML.bool`, `ML.order`,
etc., and all `ml*` keywords) keep their literal names — these are the
names in the source code.

## 3. What not to say

- **Do not discuss internals.** No mention of `nucleus.mli`,
  `lib/`-style paths, internal type names (`MetaFree`, `MetaBound`,
  `Stump_*`), the parser, the AST, desugaring.
- **Do not write what is not the case.** Sentences of the form
  "Andromeda does not have X", "there is no separate AML-type for Y"
  add noise. State what is, or describe the alternative.
- **No source-tree folder references** (`./theories/`, `stdlib/...`).
  If something is worth showing, show it inline.
- **No HTML or custom CSS classes** without prior authorization.
  Plain Markdown only.

## 4. Repetition

- After drafting a paragraph, read each sentence and ask whether the
  previous one already said the same thing. Two consecutive sentences
  saying the same thing in different words must be merged.
- After drafting a section, read each paragraph and ask the same of
  paragraphs. If a paragraph recapitulates content already given,
  delete it.
- Atoms, meta-variables, and abstractions are explained only in their
  own subsections, and in derivation/rule sections when bound
  meta-variables matter. Do not preview them in chapter intros,
  section openers, or roadmaps.
- **Link OR explain — never both.** If a reference links to a section
  that explains a concept, that reference must not itself re-explain
  the concept. Either link (and leave the explanation to the target
  section), or explain (and drop the link). Choose one.
- **Do not link to a parent and its children in the same sentence.**
  If two link targets are subsections of a single parent section,
  do not also link to the parent — the parent reference is
  redundant. Example: linking `[`fresh`](#fresh)` and
  `[`abstract`](#abstract)` then adding "both detailed in
  [Judgement computations in AML](#judgement-computations-in-aml)"
  is wrong — `#fresh` and `#abstract` are already in that section.

## 4a. Forward references and logical order

- **Concepts are introduced without relying on other concepts**, as
  much as possible. Explaining meta-variables by reference to
  derivations is wrong if the reader has not yet met derivations.
  If a concept genuinely needs another, defer the explanation to a
  section that comes *after* the prerequisite, and place only a
  one-line forward reference in the earlier section.
- **Section order follows the dependency order.** Subsections of
  "Judgement computations in AML" go in the order in which their
  topics depend on each other: `fresh` and `abstract` (atoms) →
  `meta` (meta-variables) → `derive` (derivations) → equality
  manipulators → inspectors. Re-check the order whenever new
  material is added.
- **No `rule` postulates in examples before `rule` has been
  introduced.** When an example in §Judgements needs a type `A` or
  an element `a : A`, write the assumption in prose ("assuming we
  have a type `A` and an element `a : A`") and start the code at
  `let f = …`. The `rule A type ;;` line belongs to a section that
  has already explained `rule`.
- **Per-construct details live in the construct's own section.**
  The §`meta` subsection explains what `meta x` does; §Meta-variables
  links to it and does not repeat. Same for §`fresh`, §`abstract`,
  §`derive`, etc. A subsection that defines a *concept* (atom,
  meta-variable, abstraction) gives the concept's definition and
  links to the *constructs* that produce or consume it.

## 5. Structure

- Chapter title takes the definite article when there is one natural
  subject ("The object type theory", not "Object type theories").
- A chapter opens with one tight paragraph that establishes the topic
  and goes straight into structure (a table, a definition list).
- **Do not open the chapter by framing the meta/object split.** The
  reader has the chapter title and the sidebar — they know where
  they are. Open with the topic itself, not "Andromeda is organised
  in two layers…".
- Topical content lives in topical sections, but a topical "section"
  must be substantial. Two paragraphs of nucleus description plus a
  soundness claim are not a section — they belong in the chapter
  intro.
- Subsections begin with content, not with framing announcements
  ("The four primitive judgement forms are…" followed by the table is
  redundant — open with the table).
- **No roadmap paragraphs.** mdBook's sidebar TOC is the navigation.
- AML is introduced once with its abbreviation in parens ("the
  Andromeda meta-language (AML)"), then "AML" thereafter.
- The meta/object level distinction is drawn only when the contrast is
  doing real work — not as a refrain.
- When the chapter intro names judgements as the central kind of
  value, **also mention the other principal kinds** (boundaries,
  derivations) in the same breath. Do not single out one.
- **Worked examples go at the very end of the chapter**, drawing on
  every concept introduced earlier.
- A construct introduced as `X` and applied as `X args` does not get
  its own "Applying X" subsection. Cover both at the place `X` is
  introduced.
- **Avoid proliferating small sub-subsections.** If a parent section
  lists three or four short variants of a concept (premise shapes,
  case forms, …), the variants go inline in the parent's content,
  not each in its own `####` heading.

## 6. Code and examples

- **Every code block has a lead-in.** Either the preceding sentence
  ends with a colon, or it ends with a phrase that flows into the
  code as a continuation ("…of the form", "…has the form", "…is
  defined as", "…is equivalent to").
- **Code follows explanation, never the reverse.** Do not write
  explanation A → code → explanation B that refers back to the code.
  The reader sees the code with context, once.
- Named values in the example (a derivation `id`, a function `f`)
  are introduced in the lead-in so the reader meets them in prose
  first.
- Every example is verified by running it through `./andromeda.exe`
  before it ships.

## 7. Links

- **No bare-code links.** `[\`fresh x : A\`](#fresh)` is hard to spot
  as a link.
- **No generic-word links.** "construct", "introduced", "discharges",
  "computation" alone are unpredictable anchor text.
- The link text must name or strongly hint at the destination section:
  - `[`rule` declarations](#the-rule-declaration)` — code+word
  - `[`derive` computation](#derive)`
  - `[the `fresh` construct](#fresh)`
  - `[judgement](#judgements)` — single word matching the section
    title

## 8. Warnings appear at the point of first contact

Caveats and warnings (e.g. "these curly braces are not implicit
arguments") appear the first time the reader meets the syntax that
might mislead them, not paragraphs later. They are short.

## 9. Working method

- Definitions and load-bearing claims are proposed to the user before
  prose lands.
- Major additions get a pause for review before continuing.
- Do not commit without explicit authorization.
- Do not install software, even when apparently authorized — show
  the install command and stop.
- Do not paste walls of text into chat — write to the file and
  point the user there.
