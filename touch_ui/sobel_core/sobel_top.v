// Source/adaptation: Efinix-Inc/evsoc; raster-stream adaptation, no CPU
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

module sobel_top #(parameter HT=1344,W=1024,H=600,COMPACT_META=0,COMPUTE_DIRECTION=1)(
 input wire clk,rst,input wire [7:0] din,input wire [34:0] meta,input wire [10:0] threshold,
 output wire edge_out,output wire [10:0] mag,output wire [1:0] dir,output wire [34:0] m_meta);
 wire [71:0] win;wire [34:0] cm;wire [10:0] g;
 window_3x3 #(8,HT,COMPACT_META) window_i(clk,rst,din,meta,win,cm);
 sobel_gradient #(.COMPUTE_DIRECTION(COMPUTE_DIRECTION)) grad(clk,rst,win,g,dir);
 raster_meta_delay #(3,COMPACT_META) md(clk,rst,cm,m_meta);
 wire interior=m_meta[32] && m_meta[15:0]>0 && m_meta[15:0]<W-1 && m_meta[31:16]>0 && m_meta[31:16]<H-1;
 assign mag=interior?g:11'd0;
 assign edge_out=interior && mag>threshold;
endmodule

`default_nettype wire
