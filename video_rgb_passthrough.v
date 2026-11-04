`timescale 1ns/1ps
`default_nettype none
// Continuous full origin-based raster. No ready signal or pixel backpressure.
// Common raster reset; VS rising precedes the first active row in Stable LCD.
module video_rgb_passthrough(
 input wire clk,rst,input wire [47:0] in_rgb,input wire in_hs,in_vs,in_de,
 output reg [47:0] out_rgb,output reg out_hs,out_vs,out_de,
 output reg [15:0] out_x,out_y,output reg frame_tick
);
 reg [15:0] x,y;
 reg de_q,vs_q;
 always @(posedge clk)begin
  if(rst)begin
   x<=0;y<=0;de_q<=0;vs_q<=1;
   out_rgb<=0;out_hs<=1;out_vs<=1;out_de<=0;out_x<=16'hffff;out_y<=16'hffff;frame_tick<=0;
  end else begin
   out_rgb<=in_de?in_rgb:24'd0;out_hs<=in_hs;out_vs<=in_vs;out_de<=in_de;
   out_x<=in_de?x:16'hffff;out_y<=in_de?y:16'hffff;frame_tick<=in_vs&&!vs_q;
   de_q<=in_de;vs_q<=in_vs;
   if(in_de)x<=x+16'd2;else x<=0;
   if(in_vs&&!vs_q)y<=0;else if(de_q&&!in_de)y<=y+1'b1;
  end
 end
endmodule
`default_nettype wire
