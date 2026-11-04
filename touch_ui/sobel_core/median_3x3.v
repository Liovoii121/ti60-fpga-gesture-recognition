// Source/adaptation: opencv/opencv (Apache-2.0); algorithm translated to pipelined Verilog
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

module median_3x3 #(parameter HT=1344,W=1024,H=600,COMPACT_META=0)(
 input wire clk,rst,input wire [7:0] din,input wire [34:0] meta,
 output wire [7:0] dout,output wire [34:0] m_meta,
 output wire [7:0] center_gray);
 wire [71:0] w;wire [34:0] cm;wire [7:0] med;
 window_3x3 #(8,HT,COMPACT_META) win(clk,rst,din,meta,w,cm);
 median9 sort(clk,rst,w,med);
 raster_meta_delay #(9,COMPACT_META) md(clk,rst,cm,m_meta);
 // Reuse the existing middle row instead of another HT-long bypass RAM.
 stream_delay #(8,9) center_align(clk,rst,w[4*8+:8],center_gray);
 wire interior=m_meta[32] && m_meta[15:0]>0 && m_meta[15:0]<W-1 && m_meta[31:16]>0 && m_meta[31:16]<H-1;
 assign dout=interior?med:8'd0;
endmodule

`default_nettype wire
