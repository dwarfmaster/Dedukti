
open Types
(*
val incr_NbConvTest : unit -> unit
val incr_NbTrivialTest : unit -> unit
val print_stats : unit -> unit
 *)
(* *** Global Options *** *)


val name        : ident ref
val out         : out_channel ref
val quiet       : bool ref
val export      : bool ref
val raphael     : bool ref
val color       : bool ref
val tpdb        : bool ref
val tpdb_file   : out_channel ref
(*val unsafe_mode : bool ref*)
val display_db  : bool ref
val autodep     : bool ref

val set_name     : ident -> unit
val set_filename : string -> unit
val set_out      : string -> unit
val set_tpdb     : string -> unit

(*
val unset_linearity : loc -> unit
val unset_constant_applicative : loc -> unit
 *)

(* *** Info messages *** *)

val sprint      : string -> unit        (* Print a string on standard output *)
val print_out   : string -> unit        (* Print a string on out (set by -o) *)
val eprint      : string -> unit        (* Print a string on standard error *)
val vprint      : loc -> string Lazy.t -> unit  (* Print a string on standard error if in verbose mode *)
val vprint2     : string Lazy.t -> unit
val error       : loc -> string -> unit (* Print an error message and exit *)
val warning     : loc -> string -> unit (* Print an warning message *)
val print_ok    : string -> unit        (* Print a success message *)
val print_version : unit -> unit


val parse_cmd : loc -> string -> preterm list -> cmd
