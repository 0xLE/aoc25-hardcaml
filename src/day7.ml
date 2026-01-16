open! Core
open! Hardcaml
open! Signal

(* The numbers can become quite large, so we use 64 bits *)
let num_bits = 64

(* My personal input was 140, but we use 200 here just in case *)
let max_width = 200
let mem_size = max_width + 2
let addr_bits = 8

module I = struct
  type 'a t =
    { clock : 'a
    ; clear : 'a
    ; start : 'a
    ; finish : 'a
    ; data_in : 'a
    ; data_in_valid : 'a
    ; s_col : 'a [@bits num_bits]
    ; s_valid : 'a
    ; width : 'a [@bits num_bits]
    ; width_valid : 'a
    }
  [@@deriving hardcaml]
end

module O = struct
  type 'a t = { answer : 'a With_valid.t [@bits num_bits] } [@@deriving hardcaml]
end

module States = struct
  type t =
    | Idle
    | Running
    | Done
  [@@deriving sexp_of, compare ~localize, enumerate]
end

let addr_of (x : Signal.t) = uresize ~width:addr_bits x
let one64 = of_int_trunc ~width:num_bits 1

let create (_scope : Scope.t) (i : _ I.t) : _ O.t =
  let open Always in
  let spec = Reg_spec.create ~clock:i.clock ~clear:i.clear () in
  let sm = State_machine.create (module States) spec in
  let w = Variable.reg spec ~width:num_bits in
  let s = Variable.reg spec ~width:num_bits in
  let col = Variable.reg spec ~width:num_bits in
  (* Number of completed rows *)
  let row = Variable.reg spec ~width:num_bits in
  let answer = Variable.reg spec ~width:num_bits in
  let answer_valid = Variable.reg spec ~width:1 in
  (* Input latch *)
  let w_lat = Variable.reg spec ~width:num_bits in
  let s_lat = Variable.reg spec ~width:num_bits in
  let in_bit = Variable.reg spec ~width:1 in
  let in_valid = Variable.reg spec ~width:1 in
  let mem = Array.init mem_size ~f:(fun _ -> Variable.reg spec ~width:num_bits) in
  let w_minus_1 = w_lat.value -:. 1 in
  let mem_now = Array.to_list (Array.map mem ~f:(fun r -> r.value)) in
  let read_mem (a : Signal.t) = mux a mem_now in
  (* mem[col+1] is the current cell. On split, it zeroes and adds to neighbors *)
  let a0 = addr_of col.value in
  let a1 = addr_of (col.value +:. 1) in
  let a2 = addr_of (col.value +:. 2) in
  let r0 = read_mem a0 in
  let r1 = read_mem a1 in
  let r2 = read_mem a2 in
  (* Skip first row *)
  let processing_enabled = row.value <>:. 0 in
  let v = r1 in
  (* Use the latched input, so we can advance deterministically *)
  let do_split = in_valid.value &: in_bit.value &: processing_enabled &: (v <>:. 0) in
  let r0_upd = mux2 do_split (r0 +: v) r0 in
  let r1_upd = mux2 do_split (zero num_bits) r1 in
  let r2_upd = mux2 do_split (r2 +: v) r2 in
  let mem_next_cells =
    List.init mem_size ~f:(fun j ->
      let j_sig = of_int_trunc ~width:addr_bits j in
      let hit0 = a0 ==: j_sig in
      let hit1 = a1 ==: j_sig in
      let hit2 = a2 ==: j_sig in
      mux2 hit0 r0_upd (mux2 hit1 r1_upd (mux2 hit2 r2_upd mem.(j).value)))
  in
  let write_mem_next_stmts =
    List.mapi mem_next_cells ~f:(fun j next -> mem.(j) <-- next)
  in
  let clear_mem_stmts = List.init mem_size ~f:(fun j -> mem.(j) <-- zero num_bits) in
  let seed_mem_stmts (s_col : Signal.t) =
    let seed_addr = addr_of (s_col +:. 1) in
    List.init mem_size ~f:(fun j ->
      let j_sig = of_int_trunc ~width:addr_bits j in
      mem.(j) <-- mux2 (seed_addr ==: j_sig) one64 (zero num_bits))
  in
  (* Sum all splitters. *)
  let sum_mem_expr = List.fold mem_now ~init:(zero num_bits) ~f:( +: ) in
  let reset_run_stmts () =
    [ col <-- zero num_bits
    ; row <-- zero num_bits
    ; answer <-- zero num_bits
    ; answer_valid <-- gnd
    ; in_bit <-- gnd
    ; in_valid <-- gnd
    ]
    @ clear_mem_stmts
    @ seed_mem_stmts s_lat.value
  in
  compile
    [ sm.switch
        [ ( Idle
          , [ answer_valid <-- gnd
            ; when_ i.width_valid [ w_lat <-- i.width; w <-- i.width ]
            ; when_ i.s_valid [ s_lat <-- i.s_col; s <-- i.s_col ]
            ; when_ i.start (reset_run_stmts () @ [ sm.set_next Running ])
            ] )
        ; ( Running
          , [ (* Latch input whenever it arrives *)
              when_ i.data_in_valid [ in_bit <-- i.data_in; in_valid <-- vdd ]
            ; (* Advance one cell per cycle once we have latched a valid input *)
              when_
                in_valid.value
                (write_mem_next_stmts
                 @ [ (* After consuming this cell, clear latch so we don't double-consume it *)
                     in_valid <-- gnd
                   ; if_
                       (col.value ==: w_minus_1)
                       [ col <-- zero num_bits; row <-- row.value +:. 1 ]
                       [ col <-- col.value +:. 1 ]
                   ])
            ; (* Finish must win even if we didn't just consume a cell this cycle *)
              when_
                i.finish
                [ answer <-- sum_mem_expr; answer_valid <-- vdd; sm.set_next Done ]
            ] )
        ; ( Done
          , [ answer_valid <-- vdd
            ; when_ i.width_valid [ w_lat <-- i.width; w <-- i.width ]
            ; when_ i.s_valid [ s_lat <-- i.s_col; s <-- i.s_col ]
            ; when_ i.start (reset_run_stmts () @ [ sm.set_next Running ])
            ] )
        ]
    ];
  { answer = { value = answer.value; valid = answer_valid.value } }
;;

let hierarchical scope =
  let module Scoped = Hierarchy.In_scope (I) (O) in
  Scoped.hierarchical ~scope ~name:"day7" create
;;
