// Source/adaptation: Efinix-Inc/evsoc; raster-stream adaptation, no CPU hw_accel_sobel_edge_detection; widened signed gradients and direction
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

// Three stages: weighted sums, signed differences, L1 magnitude/direction.
module sobel_gradient #(parameter COMPUTE_DIRECTION=1)(input wire clk,rst,input wire [71:0] w,
 output reg [10:0] mag,output reg [1:0] dir);
 reg [9:0] left_s,right_s,top_s,bottom_s;
 reg signed [10:0] gx,gy;
 wire [10:0] ax=gx[10]?-gx:gx, ay=gy[10]?-gy:gy;
 // tan(22.5deg) approx 106/256. Direction follows image y increasing downward.
 wire [20:0] ay256={ay,8'b0}, ax256={ax,8'b0};
 // Constant 106 = 64+32+8+2; no DSP multipliers are needed for directions.
 wire [20:0] ax106=({10'd0,ax}<<6)+({10'd0,ax}<<5)+({10'd0,ax}<<3)+({10'd0,ax}<<1);
 wire [20:0] ay106=({10'd0,ay}<<6)+({10'd0,ay}<<5)+({10'd0,ay}<<3)+({10'd0,ay}<<1);
 always @(posedge clk) begin
  if(rst) begin left_s<=0;right_s<=0;top_s<=0;bottom_s<=0;gx<=0;gy<=0;mag<=0;dir<=0;end
  else begin
   left_s<={2'b0,w[0+:8]}+({2'b0,w[24+:8]}<<1)+{2'b0,w[48+:8]};
   right_s<={2'b0,w[16+:8]}+({2'b0,w[40+:8]}<<1)+{2'b0,w[64+:8]};
   top_s<={2'b0,w[0+:8]}+({2'b0,w[8+:8]}<<1)+{2'b0,w[16+:8]};
   bottom_s<={2'b0,w[48+:8]}+({2'b0,w[56+:8]}<<1)+{2'b0,w[64+:8]};
   gx<=$signed({1'b0,right_s})-$signed({1'b0,left_s});
   gy<=$signed({1'b0,bottom_s})-$signed({1'b0,top_s});
   mag<=ax+ay;
   if(!COMPUTE_DIRECTION) dir<=0;
   else if(ay256<=ax106) dir<=0;
   else if(ax256<=ay106) dir<=2;
   else dir<=(gx[10]==gy[10])?1:3;
  end
 end
endmodule

`default_nettype wire
