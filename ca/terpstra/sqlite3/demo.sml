val () = print ("SQLite version: " ^ SQL.version ^ "\n")

fun die x = (
   print ("Caught exception: " ^ x ^ "\n");
   OS.Process.exit OS.Process.failure)

val (dbname, query) = case CommandLine.arguments () of
     [x, y] => (x, y)
   | _ => die "Expecting: <database name> <query>\n"
val db = SQL.openDB dbname handle SQL.Error x => die x

local
  open SQL.Function
in
  fun concat (a & b) = a ^ b
  fun debug v = Vector.app (fn s => print (s ^ "\n")) v
  fun glom (s & i) = if i = 0 then raise SQL.Error "bad integer" else s ^ Int.toString i
  val () = SQL.registerFunction  (db, "wes", fnS iS iS $ concat)
  val () = SQL.registerFunction  (db, "debug", fnN iAS $ debug)
  val () = SQL.registerFunction  (db, "glom", fnS iS iI $ glom)
  val () = SQL.registerCollation (db, "sless", String.compare)
end

local
  open SQL.Query
in
  val Q1 = prepare db "select x, y from peanuts\n\
                      \where y="iI" or x="iS";" oS oI $
           handle SQL.Error x => die x
  val Q2 = prepare db query oAS $
           handle SQL.Error x => die x
end

fun dumpP (s & i) = print (s ^ " " ^ Int.toString i ^ "\n")
fun dumpV v = (Vector.app (fn s => print (s ^ " ")) v; print "\n")

val () = SQL.app dumpP Q1 (4 & "hi") handle SQL.Error x => die x
val () = SQL.app dumpV Q2 ()         handle SQL.Error x => die x

val () = SQL.Query.close Q1          handle SQL.Error x => die x
val () = SQL.Query.close Q2          handle SQL.Error x => die x
val () = SQL.closeDB db              handle SQL.Error x => die x
