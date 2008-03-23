(* Copyright (C) 2008 Vesa Karvonen
 *
 * This code is released under the MLton license, a BSD-style license.
 * See the LICENSE file or http://mlton.org/License for details.
 *)

(** Signature for iterator or loop combinators. *)
signature ITER = sig
   type 'a t = ('a, Unit.t) CPS.t
   (** The type of iterator functions. *)

   (** == Running Iterators == *)

   val for : 'a t -> ('a, Unit.t) CPS.t
   (**
    *> for [<>]                f = ()
    *> for [<x(0), x(1), ...>] f = (f x(0) ; for [<x(1), ...>] f)
    *
    * This is actually the identity function and is provided purely for
    * syntactic sugar.
    *)

   val fold : ('a * 'b -> 'b) -> 'b -> 'a t -> 'b
   (**
    *> fold f s [<>]                      = s
    *> fold f s [<x(0), x(1), ..., x(n)>] =
    *>    fold f (f (x(0), s)) [<x(1), ..., x(n)>]
    *)

   val find : 'a UnPr.t -> 'a t -> 'a Option.t
   (**
    *> find p [<>]                = NONE
    *> find p [<x(0), x(1), ...>] =
    *>    if p x(0) then SOME x(n) else find p [<x(1), ...>]
    *)

   val reduce : 'b -> 'b BinOp.t -> ('a -> 'b) -> 'a t -> 'b
   (** {reduce zero plus one = fold plus zero o Monad.map one} *)

   val collect : 'a t -> 'a List.t
   (** {collect [<x(0), x(1), ..., x(n)>] = [x(0), x(1), ..., x(n)]} *)

   val first : 'a t -> 'a Option.t
   (**
    *> first [<>]                = NONE
    *> first [<x(0), x(1), ...>] = SOME x(0)
    *
    * Only the first element, if any, of the iterator will be computed.
    *)

   val last : 'a t -> 'a Option.t
   (**
    *> first [<>]                      = NONE
    *> first [<x(0), x(1), ..., x(n)>] = SOME x(n)
    *
    * Note that all elements of the iterator will be computed.
    *)

   (** == Monad == *)

   include MONADP_CORE where type 'a monad = 'a t
   structure Monad : MONADP where type 'a monad = 'a t

   (** == Unfolding == *)

   val unfold : ('a, 's) Reader.t -> 's -> 'a t
   (**
    *> unfold g s f =
    *>    case g s of NONE        => ()
    *>              | SOME (x, s) => (f x ; unfold g s f)
    *)

   val iterate : 'a UnOp.t -> 'a -> 'a t
   (** {iterate f x = [<x, f x, f (f x), ...>]} *)

   (** == Combinators == *)

   val by : 'a t * ('a -> 'b) -> 'b t
   (**
    *> [<x(0), x(1), ...>] by f = [<f x(0), f x(1), ...>]
    *
    * {s by f} is the same as {Monad.map f s}.
    *)

   val unless : 'a t * 'a UnPr.t -> 'a t
   val when : 'a t * 'a UnPr.t -> 'a t
   (** {m when p = m unless neg p} *)

   val >< : 'a t * 'b t -> ('a, 'b) Product.t t
   (**
    *> [<x(0), x(1), ...>] >< [<y(0), y(1), ..., y(n)>] =
    *>    [<x(0) & y(0), x(0) & y(1), ..., x(0) & y(n),
    *>      x(1) & y(0), x(1) & y(1), ..., x(1) & y(n),
    *>      ...>]
    *
    * This is the same as {Monad.><}.
    *)

   (** == Repetition == *)

   val repeat : 'a -> 'a t
   (** {repeat x = [<x, x, ...>]} *)

   val replicate : Int.t -> 'a -> 'a t
   (** {replicate n x = [<x, x, ..., x>]} *)

   val cycle : 'a t UnOp.t
   (**
    *> cycle [<x(0), x(1), ..., x(n)>] =
    *>    [<x(0), x(1), ..., x(n),
    *>      x(0), x(1), ..., x(n),
    *>      ...>]
    *)

   (** == Stopping == *)

   val take : Int.t -> 'a t UnOp.t
   (**
    *> take n [<x(0), x(1), ..., x(m)>] = [<x(0), x(1), ..., x(m)>], m <= n
    *> take n [<x(0), x(1), ..., x(n-1), ...>] = [<x(0), x(1), ..., x(n-1)>]
    *)

   val until : 'a t * 'a UnPr.t -> 'a t
   (**
    * {[<x(0), x(1), ...>] until p = [<x(0), x(1), ..., x(n)>]} where {p
    * x(i) = false} for all {0<=i<=n} and {p x(n+1) = true}.
    *)

   val until' : 'a t * 'a UnPr.t -> 'a t
   (**
    * {[<x(0), x(1), ...>] until' p = [<x(0), x(1), ..., x(n)>]} where {p
    * x(i) = false} for all {0<=i<n} and {p x(n) = true}.
    *)

   val whilst : 'a t * 'a UnPr.t -> 'a t
   (** {m whilst p = m until neg p} *)

   val whilst' : 'a t * 'a UnPr.t -> 'a t
   (** {m whilst' p = m until' neg p} *)

   (** == Indexing == *)

   val indexFromBy : Int.t -> Int.t -> 'a t -> ('a, Int.t) Product.t t
   (**
    *> indexFromBy i d [<x(0), x(1), ...>] = [<x(0) & i+0*d, x(1) & i+1*d, ...>]
    *)

   val indexFrom : Int.t -> 'a t -> ('a, Int.t) Product.t t
   (** {indexFrom i = indexFromBy i 1} *)

   val index : 'a t -> ('a, Int.t) Product.t t
   (** {index = indexFrom 0} *)

   (** == Iterating over Integers ==
    *
    * Note that the semantics of the {range[By]} iterators are different
    * from the semantics of the {(up|down)[To[By]]} iterators.
    *
    * Given an invalid specification of a range, the iterators over
    * integers raise {Subscript}.
    *)

   val up : Int.t -> Int.t t
   (** {up l = [<l, l+1, ...>]} *)

   val upTo : Int.t -> Int.t -> Int.t t
   (** {upTo l u = [<l, l+1, ..., u-1>]} *)

   val upToBy : Int.t -> Int.t -> Int.t -> Int.t t
   (** {upToBy l u d = [<l + 0*d, l + 1*d, ..., l + (u-l) div d * d>]} *)

   val down : Int.t -> Int.t t
   (** {down u = [<u-1, u-2, ...>]} *)

   val downTo : Int.t -> Int.t -> Int.t t
   (** {downTo u l = [<u-1, u-2, ..., l>]} *)

   val downToBy : Int.t -> Int.t -> Int.t -> Int.t t
   (**
    *> downToBy u l d = [<u - 1*d, u - 2*d, ..., u - (u-l+d-1) div d * d>]
    *
    * Note that {u - (u-l+d-1) div d * d} may be less than {l}.
    *)

   val range : Int.t -> Int.t -> Int.t t
   (** {range f t = if f < t then rangeBy f t 1 else rangeBy f t ~1} *)

   val rangeBy : Int.t -> Int.t -> Int.t -> Int.t t
   (**
    *> rangeBy f t d = [<f + 0*d, f + 1*d, ..., f + (t-f) div d * d>]
    *
    * If {f < t} then it must be that {0 < d}.  If {f > t} then it must be
    * that {0 > d}.
    *)

   val integers : Int.t t
   (** {integers = [<0, 1, 2, ...>]} *)

   (** == Iterators Over Standard Sequences == *)

   val inList : 'a List.t -> 'a t

   val inArray : 'a Array.t -> 'a t
   val inArraySlice : 'a ArraySlice.t -> 'a t
   val inVector : 'a Vector.t -> 'a t
   val inVectorSlice : 'a VectorSlice.t -> 'a t

   val inCharArray : CharArray.t -> Char.t t
   val inCharArraySlice : CharArraySlice.t -> Char.t t
   val inCharVector : CharVector.t -> Char.t t
   val inCharVectorSlice : CharVectorSlice.t -> Char.t t
   val inString : String.t -> Char.t t
   val inSubstring : Substring.t -> Char.t t
   val inWord8Array : Word8Array.t -> Word8.t t
   val inWord8ArraySlice : Word8ArraySlice.t -> Word8.t t
   val inWord8Vector : Word8Vector.t -> Word8.t t
   val inWord8VectorSlice : Word8VectorSlice.t -> Word8.t t
end
