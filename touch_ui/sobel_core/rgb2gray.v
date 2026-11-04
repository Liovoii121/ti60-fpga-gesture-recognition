// Source/adaptation: Efinix-Inc/evsoc; raster-stream adaptation, no CPU cam_rgb2gray reused unchanged, one output register
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

module rgb2gray(input wire clk,rst,input wire [23:0] rgb,
 input wire [34:0] meta,output reg [7:0] gray,output reg [34:0] m_meta);
 wire [7:0] g;
 cam_rgb2gray #(.DATA_WIDTH(8),.PPC(1)) core(rgb[23:16],rgb[15:8],rgb[7:0],g);
 always @(posedge clk) if(rst) begin gray<=0;m_meta<=0;end
 else begin gray<=meta[32]?g:0;m_meta<=meta;end
endmodule

`default_nettype wire
