// Source/adaptation: Efinix-Inc/evsoc; raster-stream adaptation, no CPU hw_accel_line_buffer; fixed raster cadence, centered metadata
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

// Raster period HT includes horizontal blanking. Center latency HT+2.
// w[0*BITS+:BITS] is top-left; w[8*BITS+:BITS] is bottom-right.
// meta: {vs,hs,de,y[15:0],x[15:0]}; negative blank coordinates are legal.
module window_3x3 #(parameter BITS=8,HT=1344,COMPACT_META=0)(
 input wire clk,rst,input wire [BITS-1:0] din,input wire [34:0] meta,
 output wire [9*BITS-1:0] w,output wire [34:0] center_meta);
 wire [BITS-1:0] row1,row2;
 wire [BITS-1:0] clean=meta[32]?din:{BITS{1'b0}};
 stream_delay #(BITS,HT) l1(clk,rst,clean,row1);
 stream_delay #(BITS,HT) l2(clk,rst,row1,row2);
 reg [BITS-1:0] a0,a1,a2,b0,b1,b2,c0,c1,c2;
 always @(posedge clk) begin
  if(rst) begin a0<=0;a1<=0;a2<=0;b0<=0;b1<=0;b2<=0;c0<=0;c1<=0;c2<=0;end
  else begin
   a2<=row2;a1<=a2;a0<=a1;
   b2<=row1;b1<=b2;b0<=b1;
   c2<=clean;c1<=c2;c0<=c1;
  end
 end
 assign w={c2,c1,c0,b2,b1,b0,a2,a1,a0};
 raster_meta_delay #(HT+2,COMPACT_META) md(clk,rst,meta,center_meta);
endmodule

`default_nettype wire
