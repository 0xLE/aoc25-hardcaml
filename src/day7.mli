open! Core
open! Hardcaml

val num_bits : int

module I : sig
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; (* Preprocessed input bitstream: 1 = '^', 0 = not-caret. Valid when [data_in_valid] is high. *)
      data_in : 'a
    ; data_in_valid : 'a
    ; (* Column index of 'S'. Valid when [s_valid] is high. *)
      s_col : 'a [@bits num_bits]
    ; s_valid : 'a
    ; (* Grid width. Valid when [width_valid] is high. *)
      width : 'a [@bits num_bits]
    ; width_valid : 'a
    }
  [@@deriving hardcaml]
end

module O : sig
  type 'a t = { answer : 'a With_valid.t [@bits num_bits] } [@@deriving hardcaml]
end

val hierarchical : Scope.t -> Signal.t I.t -> Signal.t O.t
