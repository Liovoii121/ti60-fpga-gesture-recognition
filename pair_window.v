`timescale 1ns/1ps
`default_nettype none
// Two adjacent pixels per cycle. Metadata x is the PAIR index.
// Shared two line buffers, exact neighboring pixels across pair boundaries.
module pair_window #(parameter HT=800)(
 input wire clk,rst,input wire [15:0] din,input wire [34:0] meta,
 output wire [71:0] w0,w1,output wire [34:0] cm);
 wire [143:0] pairs;
 window_3x3 #(16,HT,1) win(clk,rst,din,meta,pairs,cm);
 genvar r;
 generate for(r=0;r<3;r=r+1)begin: rows
 assign w0[r*24+:24]={pairs[(r*3+1)*16+8+:8],pairs[(r*3+1)*16+:8],pairs[(r*3)*16+8+:8]};
 assign w1[r*24+:24]={pairs[(r*3+2)*16+:8],pairs[(r*3+1)*16+8+:8],pairs[(r*3+1)*16+:8]};
 end endgenerate
endmodule
`default_nettype wire
