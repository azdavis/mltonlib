(* Copyright (C) 2007 SSH Communications Security, Helsinki, Finland
 *
 * This code is released under the MLton license, a BSD-style license.
 * See the LICENSE file or http://mlton.org/License for details.
 *)

(************************************************************************)

structure HashMap :> sig
   type ('a, 'b) t
   val new : {eq : 'a BinPr.t, hash : 'a -> Word.t} -> ('a, 'b) t
   val insert : ('a, 'b) t -> ('a * 'b) Effect.t
   val find : ('a, 'b) t -> 'a -> 'b Option.t
   val numItems : ('a, 'b) t -> Int.t
end = struct
   open HashTable
   type ('a, 'b) t = ('a, 'b) hash_table
   fun new {eq, hash} = mkTable (hash, eq) (127, Subscript)
end

(************************************************************************)

signature HASH_UNIV = sig
   type t
   val new : {eq : 'a BinPr.t, hash : 'a -> Word.t} -> ('a, t) Iso.t
   val eq : t BinPr.t
   val hash : t -> Word.t
end

structure HashUniv :> HASH_UNIV = struct
   datatype t = T of {value : Univ.t,
                      methods : {eq : Univ.t BinPr.t, hash : Univ.t -> Word.t}}
   fun new {eq, hash} = let
      val (to, from) = Univ.Emb.new ()
      val methods = {eq = fn (l, r) => case (from l, from r)
                                        of (SOME l, SOME r) => eq (l, r)
                                         | _                => false,
                     hash = hash o valOf o from}
   in
      (fn value => T {value = to value, methods = methods},
       fn T r => valOf (from (#value r)))
   end
   fun eq (T l, T r) = #eq (#methods l) (#value l, #value r)
   fun hash (T r) = #hash (#methods r) (#value r)
end

(************************************************************************)

functor MkIOSMonad (State : T) : sig
   type 'a t
   include MONAD where type 'a monad = 'a t
   val Y : 'a t Tie.t
end = struct
   structure Monad =
      MkMonad (type 'a monad = ('a, State.t) IOSMonad.t open IOSMonad)
   open Monad IOSMonad
   type 'a t = 'a monad
   val Y = Tie.function
end

(************************************************************************)

functor MkIstream (State : T) :> sig
   type 'a t
   include MONAD where type 'a monad = 'a t
   val Y : 'a t Tie.t
   val run : State.t -> 'a t -> (Char.t, 's) IOSMonad.t -> ('a, 's) IOSMonad.t
   val read : Char.t t
   structure State : T where type t = State.t
   val getState : State.t t
   val setState : State.t -> Unit.t t
end = struct
   (* <-- SML/NJ workaround *)
   open TopLevel
   (* SML/NJ workaround --> *)
   datatype t =
      T of {st : Univ.t, rd : (Char.t, Univ.t) IOSMonad.t, us : State.t}
   structure Monad = MkIOSMonad (type t = t)
   open IOSMonad Monad
   fun run us f cM = let
      val (to, from) = Univ.Iso.new ()
   in
      mapState (fn s => T {st = to s, rd = mapState (from, to) cM, us = us},
                fn T r => from (#st r)) f
   end
   fun read (T {st, rd, us}) =
       Pair.map (id, fn st => T {st=st, rd=rd, us=us}) (rd st)
   structure State = State
   fun getState (s as T {us, ...}) = (us, s)
   fun setState us (T {st, rd, ...}) = ((), T {st=st, rd=rd, us=us})
end

(************************************************************************)

functor MkOstream (State : T) :> sig
   type 'a t
   include MONAD where type 'a monad = 'a t
   val Y : 'a t Tie.t
   val run : State.t -> ('a -> Unit.t t) -> (Char.t -> (Unit.t, 's) IOSMonad.t)
                                         -> ('a     -> (Unit.t, 's) IOSMonad.t)
   val write : Char.t -> Unit.t t
   structure State : T where type t = State.t
   val getState : State.t t
   val setState : State.t -> Unit.t t
end = struct
   (* <-- SML/NJ workaround *)
   open TopLevel
   (* SML/NJ workaround --> *)
   datatype t =
      T of {st : Univ.t,
            wr : Char.t -> (Unit.t, Univ.t) IOSMonad.t,
            us : State.t}
   structure Monad = MkIOSMonad (type t = t)
   open IOSMonad Monad
   fun run us f c2uM = let
      val (to, from) = Univ.Iso.new ()
   in
      mapState (fn s => T {st = to s, wr = mapState (from, to) o c2uM, us = us},
                fn T r => from (#st r)) o f
   end
   fun write c (T r) =
       Pair.map (id, fn st => T {st = st, wr = #wr r, us = #us r})
                (#wr r c (#st r))
   structure State = State
   fun getState (s as T {us, ...}) = (us, s)
   fun setState us (T {st, wr, ...}) = ((), T {st=st, wr=wr, us=us})
end

(************************************************************************)

functor WordWithOps (Arg : WORD) = struct
   open Arg
   val ops = {wordSize = wordSize, orb = op orb, << = op <<, ~>> = op ~>>,
              isoWord8 = isoWord8}
end

(************************************************************************)

functor WithPickle (Arg : WITH_PICKLE_DOM) : PICKLE_CASES = struct
   (* <-- SML/NJ workaround *)
   open TopLevel
   infix  8 * div >> << *` / mod ~>> /`
   infix  7 + - ^ andb +` -` ^`
   infix  6 xorb
   infixr 6 ::  @ ::` @`
   infix  5 > >= =  orb == =` < <= <>= ?=
   infix  4 <\ \>
   infixr 4 </ />
   infix  3 o <-->
   infix  2 andAlso >|
   infixr 2 |<
   infix  1 := orElse >>= >>& :=: += -= >>* >>@
   infixr 1 =<<
   infix  0 before <|> &` &
   infixr 0 -->
   (* SML/NJ workaround --> *)

   structure Word = WordWithOps (Word)
   structure Word32 = WordWithOps (Word32)
   structure Word64 = WordWithOps (Word64)
   structure LargeWord = WordWithOps (LargeWord)
   structure LargeRealWord = WordWithOps (CastLargeReal.Bits)
   structure RealWord = WordWithOps (CastReal.Bits)

   structure Dyn = HashUniv

   structure I = MkIstream (type t = (Int.t, Dyn.t) HashMap.t)
   structure O = MkOstream (type t = (Dyn.t, Int.t) HashMap.t)

   structure OptInt = struct
      type t = Int.t Option.t
      local
         fun mk bop =
          fn (SOME l, SOME r) => SOME (bop (l, r))
           | _                => NONE
      in
         val op +   = mk op +
         val op div = mk op div
      end
   end

   type 'a t = {rd : 'a I.t, wr : 'a -> Unit.t O.t, sz : OptInt.t}
   type 'a s = Int.t -> {rd : Int.t -> 'a I.t,
                         wr : (Int.t -> Unit.t O.t) -> 'a -> Unit.t O.t,
                         sz : OptInt.t}

   fun fake msg = {rd = I.thunk (failing msg), wr = failing msg, sz = NONE}

   val op <--> = Iso.<-->
   val swap = Iso.swap
   val word8Ichar = (Byte.byteToChar, Byte.charToByte)

   fun iso' get bT (a2b, b2a) = let
      val {rd, wr, sz} = get bT
   in
      {rd = I.map b2a rd, wr = wr o a2b, sz = sz}
   end

   val char = {rd = I.read, wr = O.write, sz = SOME 1}
   val word8 = iso' id char word8Ichar
   val intAs8  = iso' id char (swap Char.isoInt)

   (* Pickles a positive int using a variable length encoding. *)
   val size =
       {rd = let
           open I
           fun lp (v, m) =
               #rd word8 >>= (fn b =>
               if b < 0wx80
               then return (v + Word8.toInt b * m)
               else lp (v + Word8.toInt (b - 0wx80) * m, m * 0x80))
        in
           lp (0, 1)
        end,
        wr = let
           open O
           fun lp i =
               if i < 0x80
               then #wr word8 (Word8.fromInt i)
               else #wr word8 (Word8.andb (0wx7F, Word8.fromInt i)) >>= (fn () =>
                    lp (Int.quot (i, 0x80)))
        in
           fn i => if i < 0 then fail "Negative size" else return i >>= lp
        end,
        sz = SOME 2}

   (* Encodes either 8, 16, 32, or 64 bits of data and an optional size. *)
   fun bits sized {wordSize=n, orb, <<, ~>>, isoWord8 = (toWord8, fromWord8)}
            (toBits, fromBits) = let
      fun alts ` op o =
          if      n <= 8  then `0w0
          else if n <= 16 then `0w0o`0w8
          else if n <= 32 then `0w0o`0w8o`0w16o`0w24
          else if n <= 64 then `0w0o`0w8o`0w16o`0w24o`0w32o`0w40o`0w48o`0w56
          else fail "Too many bits"
   in
      {rd = let
          open I
          fun ` n = map (fn b => fromWord8 b << n) (#rd word8)
          fun l o r = map op orb (l >>* r)
          val rdBits = map fromBits (alts ` op o)
       in
          if sized
          then #rd size >>= (fn m =>
               if m <> n
               then fail "Wrong number of bits in pickle"
               else rdBits)
          else rdBits
       end,
       wr = fn v => let
               open O
               val bits = toBits v
               val wrBits = alts (fn n => #wr word8 (toWord8 (bits ~>> n))) op >>
            in
               if sized then #wr size n >> wrBits else wrBits
            end,
       sz = SOME ((n + 7) div 8 + Bool.toInt sized)}
   end

   val intAs16 = let
      open Word
   in
      bits false
           {wordSize = 16, orb = op orb, << = op <<, ~>> = op ~>>,
            isoWord8 = isoWord8}
           (swap Word.isoInt)
   end

   (* Encodes fixed size int as a size followed by little endian bytes. *)
   fun mkFixedInt (fromLargeWordX, toLargeWord) =
       {rd = let
           open I
           fun lp (1, s, w) =
               #rd word8 >>= (fn b =>
               return (fromLargeWordX (LargeWord.<< (LargeWord.fromWord8X b, s)
                                       + w)))
             | lp (n, s, w) =
               #rd word8 >>= (fn b =>
               lp (n-1, s+0w8, LargeWord.<< (LargeWord.fromWord8 b, s) + w))
        in
           #rd size >>= (fn 0 => return (fromLargeWordX 0w0)
                          | n => lp (n, 0w0, 0w0))
        end,
        wr = let
           open O
           fun lp (n, w, wr) = let
              val n = n+1
              val b = LargeWord.toWord8 w
              val wr = wr >> #wr word8 b
           in
              if LargeWord.fromWord8X b = w
              then #wr size n >> wr
              else lp (n, LargeWord.~>> (w, 0w8), wr)
           end
        in
           fn i => case toLargeWord i
                    of 0w0 => #wr size 0
                     | w   => lp (0, w, return ())
        end,
        sz = SOME 4}

   val () = if LargeWord.wordSize < valOf FixedInt.precision
            then fail "LargeWord can't hold a FixedInt"
            else ()
   val fixedInt = mkFixedInt LargeWord.isoFixedIntX

   fun cyclic {readProxy, readBody, writeWhole, self} = let
      val (toDyn, fromDyn) = Dyn.new {eq = Arg.eq self, hash = Arg.hash self}
      open I
   in
      {rd = #rd size >>& getState >>= (fn i & mp =>
            if 0 = i
            then readProxy >>= (fn proxy =>
                 (HashMap.insert mp (HashMap.numItems mp, toDyn proxy)
                ; readBody proxy >> return proxy))
            else case HashMap.find mp (i-1)
                  of NONE   => fail "Corrupted pickle"
                   | SOME d => return (fromDyn d)),
       wr = fn v => let
                  val d = toDyn v
                  open O
               in
                  getState >>= (fn mp =>
                  case HashMap.find mp d
                   of SOME i => #wr size (i+1)
                    | NONE   => (HashMap.insert mp (d, HashMap.numItems mp)
                               ; #wr size 0 >> writeWhole v))
               end,
       sz = NONE}
   end

   fun share t {rd = rdE, wr = wrE, sz = _} = let
      val (toDyn, fromDyn) = Dyn.new {eq = Arg.eq t, hash = Arg.hash t}
      open I
   in
      {rd = #rd size >>& getState >>= (fn i & mp =>
            if 0 = i
            then rdE >>= (fn v =>
                 (HashMap.insert mp (HashMap.numItems mp, toDyn v)
                ; return v))
            else case HashMap.find mp (i-1)
                  of NONE   => fail "Corrupted pickle"
                   | SOME d => return (fromDyn d)),
       wr = fn v => let
                  val d = toDyn v
                  open O
               in
                  getState >>= (fn mp =>
                  case HashMap.find mp d
                   of SOME i => #wr size (i+1)
                    | NONE   => #wr size 0 >> wrE v >>= (fn () =>
                                (HashMap.insert mp (d, HashMap.numItems mp)
                               ; return ())))
               end,
       sz = SOME 5}
   end

   fun mutable (methods as {readProxy, readBody, writeWhole, self}) =
       if Arg.mayBeCyclic self
       then cyclic methods
       else share self {rd = let open I in readProxy >>= (fn p =>
                                           readBody p >> return p) end,
                        wr = writeWhole,
                        sz = NONE}

   fun seq {length, toSlice, getItem, fromList} {rd = rdE, wr = wrE, sz = _} =
       {rd = let
           open I
           fun lp (0, es) = return (fromList (rev es))
             | lp (n, es) = rdE >>= (fn e => lp (n-1, e::es))
        in
           #rd size >>= lp /> []
        end,
        wr = let
           open O
           fun lp sl =
               case getItem sl
                of NONE         => return ()
                 | SOME (e, sl) => wrE e >>= (fn () => lp sl)
        in
           fn seq => #wr size (length seq) >>= (fn () =>
                     lp (toSlice seq))
        end,
        sz = NONE : OptInt.t}

   val string =
       share (Arg.string ())
             (seq {length = String.length, toSlice = Substring.full,
                   getItem = Substring.getc, fromList = String.fromList}
                  char)

   val c2b = Byte.charToByte
   val b2c = Byte.byteToChar
   fun h2n c =
       c2b c - (if      Char.inRange (#"0", #"9") c then c2b #"0"
                else if Char.inRange (#"a", #"f") c then c2b #"a" - 0w10
                else if Char.inRange (#"A", #"F") c then c2b #"A" - 0w10
                else fail "Bug in fmt")
   fun n2h n = b2c (n + (if n < 0w10 then c2b #"0" else c2b #"a" - 0w10))
   local
      fun makePos8 i = let
         val n = Word.fromInt (IntInf.log2 (~i))
      in
         i + IntInf.<< (1, Word.andb (Word.~ 0w8, n + 0w8))
      end
   in
      fun i2h i =
          if i < 0
          then let
                val s = IntInf.fmt StringCvt.HEX (makePos8 i)
             in
                if 0w8 <= h2n (String.sub (s, 0)) then s else "ff"^s
             end
          else let
                val s = IntInf.fmt StringCvt.HEX i
                val (t, f) =
                    if Int.isOdd (String.size s)
                    then ("0", "0")
                    else ("00", "")
             in
                (if 0w8 <= h2n (String.sub (s, 0)) then t else f) ^ s
             end
   end
   fun h2i h = let
      val i = valOf (StringCvt.scanString (IntInf.scan StringCvt.HEX) h)
   in
      if 0w8 <= h2n (String.sub (h, 0))
      then i - IntInf.<< (1, Word.fromInt (IntInf.log2 i + 1))
      else i
   end

   val intInf =
       {wr = let
           open O
           fun lp (_, 0) = return ()
             | lp (s, i) = case i - 1 of i => pl (s, i, h2n (String.sub (s, i)))
           and pl (_, 0, b) = #wr word8 b
             | pl (s, i, b) = let
                  val i = i - 1
               in
                  #wr word8 (b + Word8.<< (h2n (String.sub (s, i)), 0w4)) >>=
                   (fn () => lp (s, i))
               end
        in
           fn 0 => #wr size 0
            | i => let
                 val s = i2h i
                 val n = String.length s
              in
                 #wr size (Int.quot (n, 2)) >>= (fn () => lp (s, n))
              end
        end,
        rd = let
           open I
           fun lp (cs, 0) = return (h2i (implode cs))
             | lp (cs, n) =
               #rd word8 >>= (fn b =>
               lp (n2h (Word8.>> (b, 0w4))::n2h (Word8.andb (b, 0wxF))::cs, n-1))
        in
           #rd size >>= (fn 0 => return 0 | n => lp ([], n))
        end,
        sz = NONE : OptInt.t}

   structure Pickle = LayerRep
      (structure Outer = Arg.Rep
       structure Closed = struct
          type 'a t = 'a t and 'a s = 'a s and ('a, 'k) p = 'a t
       end)

   open Pickle.This

   fun pickler t =
       O.run (HashMap.new {eq = Dyn.eq, hash = Dyn.hash}) (#wr (getT t))
   fun unpickler t =
       I.run (HashMap.new {eq = op =, hash = Word.fromInt}) (#rd (getT t))

   fun pickle t = let
      val pA = pickler t (IOSMonad.fromPutter (uncurry Buffer.push))
   in
      fn a => Buffer.toString o Pair.snd o pA a |< Buffer.new ()
   end
   fun unpickle t =
       Pair.fst o unpickler t (IOSMonad.fromReader Substring.getc) o
       Substring.full

   structure Layered = LayerDepCases
     (structure Outer = Arg and Result = Pickle

      fun iso b aIb = let
         val a = iso' getT b aIb
      in
         if case #sz (getT b) of NONE => true | SOME n => 5 < n
         then share (Arg.iso (fn _ => fn _ => ()) b aIb) a
         else a
      end

      fun isoProduct ? = iso' getP ?

      fun isoSum bS (a2b, b2a) i = let
         val {rd, wr, sz} = getS bS i
      in
         {rd = I.map b2a o rd, wr = fn wrTag => wr wrTag o a2b, sz = sz}
      end

      fun op *` (lT, rT) = let
         val {rd = rL, wr = wL, sz = sL} = getP lT
         val {rd = rR, wr = wR, sz = sR} = getP rT
      in
         {rd = let open I in rL >>& rR end,
          wr = let open O in fn l & r => wL l >> wR r end,
          sz = OptInt.+ (sL, sR)}
      end

      val T      = getT
      fun R _    = getT
      val tuple  = getP
      val record = getP

      fun op +` (lT, rT) = let
         val lN = Arg.numAlts lT
         val lS = getS lT
         val rS = getS rT
      in
         fn i => let
               val j = i+lN
               val {rd = rL, wr = wL, sz = sL} = lS i
               val {rd = rR, wr = wR, sz = sR} = rS j
            in
               {rd = fn i => if i < j
                             then I.map INL (rL i)
                             else I.map INR (rR i),
                wr = Sum.sum o Pair.map (wL, wR) o Sq.mk,
                sz = OptInt.+ (sL, sR)}
            end
      end
      val unit = {rd = I.return (), wr = fn () => O.return (), sz = SOME 0}
      fun C0 _ i = {rd = const (I.return ()),
                    wr = fn wrTag => const (wrTag i),
                    sz = SOME 0}
      fun C1 _ t = let
         val {rd, wr, sz} = getT t
      in
         fn i => {rd = const rd, wr = fn wrTag => wrTag i <\ O.>> o wr, sz = sz}
      end
      fun data s = let
         val n = Arg.numAlts s
         val tag =
             if      n < 256   then intAs8
             else if n < 65536 then intAs16
             else fail "Too many tags"
         val {rd, wr, sz} = getS s 0
         open I
      in
         {rd = #rd tag >>= (fn i =>
               if n <= i
               then fail "Corrupted pickle"
               else rd i),
          wr = wr (#wr tag),
          sz = let open OptInt in sz div SOME n + #sz tag end}
      end

      fun Y ? = let open Tie in iso (I.Y *` function *` id NONE) end
                   (fn {rd, wr, sz} => rd & wr & sz,
                    fn rd & wr & sz => {rd = rd, wr = wr, sz = sz}) ?

      fun op --> _ = fake "Pickle.--> unsupported"

      fun refc t = let
         val {rd, wr, sz = _} = getT t
      in
          mutable {readProxy = I.thunk (ref o const (Arg.some t)),
                   readBody = fn proxy => I.map (fn v => proxy := v) rd,
                   writeWhole = wr o !,
                   self = Arg.refc ignore t}
      end

      fun array t = let
         val {rd, wr, sz = _} = getT t
      in
         mutable {readProxy = I.map (Array.array /> Arg.some t) (#rd size),
                  readBody = fn a => let
                     open I
                     fun lp i = if i = Array.length a
                                then return ()
                                else rd >>= (fn e =>
                                     (Array.update (a, i, e)
                                    ; lp (i+1)))
                  in
                     lp 0
                  end,
                  writeWhole = fn a => let
                     open O
                     fun lp i = if i = Array.length a
                                then return ()
                                else wr (Array.sub (a, i)) >>= (fn () => lp (i+1))
                  in
                     #wr size (Array.length a) >>= (fn () => lp 0)
                  end,
                  self = Arg.array ignore t}
      end

      fun list t =
          share (Arg.list ignore t)
                (seq {length = List.length, toSlice = id,
                      getItem = List.getItem, fromList = id} (getT t))

      fun vector t =
          share (Arg.vector ignore t)
                (seq {length = Vector.length, toSlice = VectorSlice.full,
                      getItem = VectorSlice.getItem,
                      fromList = Vector.fromList} (getT t))

      val exns : {rd : String.t -> Exn.t I.t Option.t,
                  wr : Exn.t -> Unit.t O.t Option.t} Buffer.t =
          Buffer.new ()
      val exn : Exn.t t =
          {rd = let
              open I
           in
              #rd string >>= (fn s =>
              case Buffer.findSome (pass s o #rd) exns
               of NONE   => fail ("Unregistered exception constructor: " ^ s)
                | SOME r => r)
           end,
           wr = fn e => case Buffer.findSome (pass e o #wr) exns
                         of NONE   => GenericsUtil.failExn e
                          | SOME r => r,
           sz = NONE}
      fun regExn c {rd, wr, sz=_} (a2e, e2a) = let
         val c = Generics.Con.toString c
         val rd = I.map a2e rd
      in
         (Buffer.push exns)
            {rd = fn c' => if c' = c then SOME rd else NONE,
             wr = Option.map (fn a => O.>> (#wr string c, wr a)) o e2a}
      end
      fun regExn0 c (e, p) = regExn c unit (const e, p)
      fun regExn1 c t = regExn c (getT t)

      val fixedInt = fixedInt
      val largeInt = if isSome LargeInt.precision
                     then iso' id fixedInt (swap FixedInt.isoLarge)
                     else intInf

      val char = char
      val bool = iso' id char (swap Char.isoInt <--> Bool.isoInt)
      val int = if isSome Int.precision
                then iso' id fixedInt Int.isoFixedInt
                else iso' id largeInt Int.isoLargeInt
      val real = bits true RealWord.ops CastReal.isoBits
      val string = string
      val word = mkFixedInt (swap Word.isoLargeX)

      val largeReal = bits true LargeRealWord.ops CastLargeReal.isoBits
      val largeWord = mkFixedInt Iso.id

      val word8  = word8
      val word32 = bits false Word32.ops Iso.id
      val word64 = bits false Word64.ops Iso.id)

   open Layered
end
