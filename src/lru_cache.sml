structure LruCache : sig
    val cache : Cache.cache
end = struct


(* Mono *)

open Mono

val dummyLoc = ErrorMsg.dummySpan
val stringTyp = (TFfi ("Basis", "string"), dummyLoc)
val optionStringTyp = (TOption stringTyp, dummyLoc)
fun withTyp typ = map (fn exp => (exp, typ))

fun ffiAppCache' (func, index, argTyps) =
    EFfiApp ("Sqlcache", func ^ Int.toString index, argTyps)

fun check (index, keys) =
    ffiAppCache' ("check", index, withTyp stringTyp keys)

fun store (index, keys, value) =
    ffiAppCache' ("store", index, (value, stringTyp) :: withTyp stringTyp keys)

fun flush (index, keys) =
    ffiAppCache' ("flush", index, withTyp optionStringTyp keys)


(* Cjr *)

open Print
open Print.PD

fun setupQuery {index, params} =
    let

        val i = Int.toString index

        fun paramRepeat itemi sep =
            let
                fun f n =
                    if n < 0 then ""
                    else if n = 0 then itemi (Int.toString 0)
                    else f (n-1) ^ sep ^ itemi (Int.toString n)
            in
                f (params - 1)
            end

        fun paramRepeatRev itemi sep =
            let
                fun f n =
                    if n < 0 then ""
                    else if n = 0 then itemi (Int.toString 0)
                    else itemi (Int.toString n) ^ sep ^ f (n-1)
            in
                f (params - 1)
            end

        fun paramRepeatInit itemi sep =
            if params = 0 then "" else sep ^ paramRepeat itemi sep

        val typedArgs = paramRepeatInit (fn p => "uw_Basis_string p" ^ p) ", "

        val revArgs = paramRepeatRev (fn p => "p" ^ p) ", "

    in
        Print.box
            [string ("static uw_sqlcache_Cache cacheStruct" ^ i ^ " = {"),
             newline,
             string "  .table = NULL,",
             newline,
             string "  .timeInvalid = 0,",
             newline,
             string "  .lru = NULL,",
             newline,
             string ("  .height = " ^ Int.toString (params - 1) ^ "};"),
             newline,
             string ("static uw_sqlcache_Cache *cache" ^ i ^ " = &cacheStruct" ^ i ^ ";"),
             newline,
             newline,

             string ("static uw_Basis_string uw_Sqlcache_check" ^ i),
             string ("(uw_context ctx" ^ typedArgs ^ ") {"),
             newline,
             string ("  char *ks[] = {" ^ revArgs ^ "};"),
             newline,
             string ("  uw_sqlcache_CacheValue *v = uw_sqlcache_check(cache" ^ i ^ ", ks);"),
             newline,
             string "  if (v) {",
             newline,
             string ("    puts(\"SQLCACHE: hit " ^ i ^ ".\");"),
             newline,
             string "    uw_write(ctx, v->output);",
             newline,
             string "    return v->result;",
             newline,
             string "  } else {",
             newline,
             string ("    puts(\"SQLCACHE: miss " ^ i ^ ".\");"),
             newline,
             string "    uw_recordingStart(ctx);",
             newline,
             string "    return NULL;",
             newline,
             string "  }",
             newline,
             string "}",
             newline,
             newline,

             string ("static uw_unit uw_Sqlcache_store" ^ i),
             string ("(uw_context ctx, uw_Basis_string s" ^ typedArgs ^ ") {"),
             newline,
             string ("  char *ks[] = {" ^ revArgs ^ "};"),
             newline,
             string ("  uw_sqlcache_CacheValue *v = malloc(sizeof(uw_sqlcache_CacheValue));"),
             newline,
             string "  v->result = strdup(s);",
             newline,
             string "  v->output = uw_recordingRead(ctx);",
             newline,
             string ("  puts(\"SQLCACHE: stored " ^ i ^ ".\");"),
             newline,
             string ("  uw_sqlcache_store(cache" ^ i ^ ", ks, v);"),
             newline,
             string "  return uw_unit_v;",
             newline,
             string "}",
             newline,
             newline,

             string ("static uw_unit uw_Sqlcache_flush" ^ i),
             string ("(uw_context ctx" ^ typedArgs ^ ") {"),
             newline,
             string ("  char *ks[] = {" ^ revArgs ^ "};"),
             newline,
             string ("  uw_sqlcache_flush(cache" ^ i ^ ", ks);"),
             newline,
             string "  return uw_unit_v;",
             newline,
             string "}",
             newline,
             newline]
    end

val setupGlobal = string "/* No global setup for LRU cache. */"


(* Bundled up. *)

(* For now, use the toy implementation if there are no arguments. *)
fun toyIfNoKeys numKeys implLru implToy args =
    if numKeys args = 0
    then implToy args
    else implLru args

val cache =
    let
        val {check = toyCheck,
             store = toyStore,
             flush = toyFlush,
             setupQuery = toySetupQuery,
             ...} = ToyCache.cache
    in
        {check = toyIfNoKeys (length o #2) check toyCheck,
         store = toyIfNoKeys (length o #2) store toyStore,
         flush = toyIfNoKeys (length o #2) flush toyFlush,
         setupQuery = toyIfNoKeys #params setupQuery toySetupQuery,
         setupGlobal = setupGlobal}
    end

end
