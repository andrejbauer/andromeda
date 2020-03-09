open Nucleus_types

let empty : signature = Ident.empty

let add_rule c rule (sgn : signature) =
  assert (not (Ident.mem c sgn)) ; Ident.add c rule sgn

let lookup_rule c (sgn : signature) = Ident.find c sgn
