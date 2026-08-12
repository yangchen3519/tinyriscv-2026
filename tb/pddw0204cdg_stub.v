`timescale 1ns/1ps

// Functional-only PAD stub for compiling tinyriscv_4core_top_IO in RTL
// simulation.  Real synthesis/backend runs must use the course TSMC180 PAD
// library model/netlist instead of this file.
module PDDW0204CDG(
    input  wire OEN,
    input  wire I,
    inout  wire PAD,
    output wire C,
    input  wire DS,
    input  wire PE,
    input  wire IE
);
    assign PAD = OEN ? 1'bz : I;
    assign C = IE ? PAD : 1'b0;
endmodule
