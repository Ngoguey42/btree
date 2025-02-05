module type S = sig
  type t
  (** The type of vertex mapping type [key] to type [value] *)

  type key

  type value

  type address

  type store

  val create : store -> Field.kind -> address -> t
  (** [create s p k1 k2] creates a new empty table, stored at address [p] in [s], with initial size
      [Params.fanout] *)

  val load : store -> address -> t
  (** [load s p] loads the table stored at address [p] in [s]. *)

  val reconstruct : t -> Field.kind -> (key * value) list -> unit
  (** [reconstruct t kvs] overwrite [t] with the list of bindings [kvs] which is assumed to be
      sorted *)

  val migrate : string list -> Field.kind -> string
  (** [migrate kvs kind] is the representation of the key-value association list [kvs] in a vertex
      of type [kind] *)

  val clear : t -> (key -> bool) -> unit
  (** [clear t predicate] clears every binding from [k] to [v] in [t] that satisfies [predicate k] *)

  val leftmost : t -> key
  (** [leftmost t] is the smallest key bound in [t] *)

  val shrink : t -> unit
  (** [shrink t] launches a garbage collection process that shrinks the size of [t] to a minimum. *)

  val split : t -> address -> key * t
  (** [split t s p] moves every binding in [t] from [k] to [v] that satisfies [k >= pivot], where
      [pivot] is the middle key bounded in [t] for the natural key ordering, to a new table [t_mv]
      stored at address [p], and returns [pivot, t_mv]. *)

  val replace : t -> key -> key -> unit
  (** [replace t k1 k2] replaces key [k1] in [t] with [k2] *)

  val add : t -> key -> value -> unit
  (** [add t x y] adds a binding from [x] to [y] in [t]. Contrary to [Map.add], previous bindings
      from [x] are not hidden, but deleted. *)

  val find : t -> key -> value
  (** [find t k] returns the current binding of [k] in [t], or raises [Not_found] if no such binding
      exists. *)

  type neighbour = {
    main : key * value;
    neighbour : (key * value) option;
    order : [ `Lower | `Higher ];
  }

  val find_with_neighbour : t -> key -> neighbour

  val mem : t -> key -> bool
  (** [mem t k] checks if [k] is bound in [t]. *)

  val iter : t -> (key -> value -> unit) -> unit
  (** [iter t func] applies [func key value] on every bindings [(key, value)] stored in [t] *)

  val fold_left : ('a -> key * value -> 'a) -> 'a -> t -> 'a

  val merge : t -> t -> [ `Partial | `Total ] -> unit
  (** [merge t1 t2 mode] merges bindings in [t1] and [t2]. A partial merge merely redistribute the
      keys evenly among the nodes, a total merge moves all keys from [t2] to [t1]. It is assumed,
      and relied upon, that all keys from [t2] are greater than every key from [t1]. *)

  val remove : t -> key -> unit
  (** [remove t k] removes the binding of [k] in [t], or raises [Not_found] if no such binding
      exists. *)

  val length : t -> int
  (** [length t] is the number of keys bound in [t]. It takes constant time. *)

  val depth : t -> int
  (** [depth t] is the depth of the vertex [t] in the btree it is part of *)

  val pp : t Fmt.t
  (** [pp ppf t] outputs a human-readable representation of [t] to the formatter [ppf] *)
end

module type BOUND = sig
  (* what is bound in the vertex *)
  type t

  val set : marker:(unit -> unit) -> bytes -> off:int -> t -> unit

  val get : bytes -> off:int -> t

  val size : int

  val pp : t Fmt.t

  val kind : [ `Leaf | `Node ]
end

module type LEAFMAKER = functor
  (Params : Params.S)
  (Store : Store.S)
  (Key : Data.K)
  (Value : Data.V)
  ->
  S
    with type key := Key.t
     and type value := Value.t
     and type store = Store.t
     and type address = Store.address

module type NODEMAKER = functor (Params : Params.S) (Store : Store.S) (Key : Data.K) ->
  S
    with type key := Key.t
     and type value := Field.MakeCommon(Params).Address.t
     and type store = Store.t
     and type address = Store.address

module type MAKER = functor (Params : Params.S) (Store : Store.S) (Key : Data.K) (Bound : BOUND) ->
  S
    with type key := Key.t
     and type value := Bound.t
     and type store = Store.t
     and type address = Store.address

module type Vertex = sig
  module LeafMake : LEAFMAKER

  module NodeMake : NODEMAKER
end
