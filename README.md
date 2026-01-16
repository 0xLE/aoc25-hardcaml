# AOC 25 (Hardcaml)

This repository contains my Advent of Code solutions written using Hardcaml. Warning: the code may not be very idiomatic. See `src/` for implementation and `test/` for the reference implementation, test harness, and preprocessing code.

## Day 7 (part 2)

Part 2 consists of row-by-row update based on where "splitters" are located.

The input is preprocessed to avoid having to implement ASCII parsing and whatnot inside FPGA. Each bit represents a column, where lo represents no splitter, and hi represents a splitter. The first splitter column's position is provided separately.
The output is a 64-bit bus consisting of the answer. 64 bits is used here as the output and the intermediary values can be quite large. This may have to be reconsidered if the input is even larger. Latching is used to allow the circuit to advance deterministically.

A state machine exists to track the state of the program. During the running phase, it will split the "values" to its neighbors. It will then advance the current col and increment row when necessary.
