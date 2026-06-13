# Introduction

Andromeda 2 is a proof checker for user-definable dependently-typed theories.
It follows the design of [LCF](https://en.wikipedia.org/wiki/Logic_for_Computable_Functions)-style theorem provers.

There is an abstract datatype `judgement` whose values can only be constructed by a *nucleus*, a small trusted component of the proof checker. The user interacts with the nucleus by writing programs in a high-level, statically typed *Andromeda meta-language (AML)*. Normalization, unification, and other proof development techniques reside outside the trusted nucleus. They are implemented in AML, or in some cases in OCaml. Andromeda 2 uses algebraic effects and handlers as a control mechanism for directing proof search.

Andromeda is a *generic* proof checker. The user defines their own type theory,
with respect to which Andromeda computes derivable judgements. Any judgement
computed by Andromeda is guaranteed to be derivable from the inference rules
postulated by the user.

While Robin Milner's LCF and its HOL-style descendants compute judgements in
*simple* type theory, AML supports *dependent* type theories. This creates a
significant overhead in the complexity. While [John
Harrison](http://www.cl.cam.ac.uk/~jrh13/) could print the [HOL Light
kernel](http://www.cl.cam.ac.uk/~jrh13/) on a T-shirt, we may need a cape to
print the 4000 lines of the [Andromeda
nucleus](https://en.wikipedia.org/wiki/Andromeda_Galaxy#Nucleus).



## Developers

* [Andrej Bauer](https://andrej.com/)
* [Gaëtan Gilbert](https://github.com/SkySkimmer)
* [Philipp G. Haselwarter](https://www.haselwarter.org/~philipp/)
* [Anja Petković Komel](https://anjapetkovic.com/)
* [Matija Pretnar](http://matija.pretnar.info/)
* [Chris Stone](https://www.cs.hmc.edu/~stone/)

## A bit of history

Andromeda 1 was first conceived by Andrej Bauer during the [Univalent
Foundations of Mathematics](https://www.ias.edu/math/sp/univalent) 2012/13
program at the [Institute for Advanced Study](https://www.ias.edu). The original
idea was to use algebraic effects and handlers as a mechanism for implementing a
proof checker for extensional type theory. In 2017 Andrej Bauer and Philipp
Haselwarter implemented Andromeda 2, which allowed user-defined type theories,
of which extensional type theory was just one example.

In conversations with Vladimir Voevodsky about type theory and its role in
formal proof checking, we would sometimes talk about “sending proofs to a far
away place where they will check them independently, like Brazil”. Thus, in the
beginning the name of the proof checker was Brazil. It later turned out Brazil
was not quite far enough. Martin Escardó suggested the name Andromeda. We hope
that nobody will claim that our neighboring galaxy is a nearby place.

## Support

This material is based upon work supported by the Air Force Office of Scientific Research,
Air Force Materiel Command, USAF under Award No. FA9550-14-1-0096. Any opinions, findings,
and conclusions or recommendations expressed in this publication are those of the
author(s) and do not necessarily reflect the views of the Air Force Office of Scientific
Research, Air Force Materiel Command, USAF.
