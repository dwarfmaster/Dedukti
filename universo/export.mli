type model = Basic.name -> Term.term

module type Solver =
sig
  type t

  val mk_var  : string -> t

  val mk_prop : t

  val mk_type : int -> t

  val mk_succ : t -> t

  val mk_max  : t -> t -> t

  val mk_rule : t -> t -> t

  val mk_eq   : t -> t -> unit

  val solve   : unit -> int * model

  val reset   : unit -> unit
end

module Z3Syn : Solver
