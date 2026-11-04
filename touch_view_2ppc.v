`timescale 1ns/1ps
`default_nettype none
// Median, full-strength Gaussian and Sobel retain true full-resolution neighbors.
// 2PPC shares line buffers; no half-width independent-lane filtering.
module touch_view_2ppc #(parameter W=1280,H=720,HT=800)(
 input wire clk,rst,input wire [2:0] view,input wire [7:0] threshold,input wire median_enable,input wire canny_enable,
 input wire [47:0] rgb,input wire hs,vs,de,
 output reg [47:0] out_rgb,output reg out_hs,out_vs,out_de);
 wire [34:0] m0,m1,m2,m3,m4,m5,m6;
 wire [15:0] lum0=rgb[23:16]*16'd77+rgb[15:8]*16'd150+rgb[7:0]*16'd29;
 wire [15:0] lum1=rgb[47:40]*16'd77+rgb[39:32]*16'd150+rgb[31:24]*16'd29;
 reg [15:0] gray;
 always @(posedge clk)if(rst)gray<=0;else gray<=de?{lum1[15:8],lum0[15:8]}:16'd0;
 raster_meta_delay #(1,1) md0(clk,rst,{vs,hs,de,32'd0},m0);
 reg vq;reg canny_sel;reg [2:0] sel;reg [7:0] lim;reg filt;
 always @(posedge clk)begin
 if(rst)begin vq<=1;canny_sel<=0;sel<=0;lim<=48;filt<=0;end
 else begin vq<=vs;if(vs&&!vq)begin sel<=view;canny_sel<=canny_enable;lim<=threshold;filt<=median_enable;end end
 end
 wire [71:0] medw0,medw1;wire [15:0] med,medcenter,filtered;
 pair_window #(HT) mw(clk,rst,gray,m0,medw0,medw1,m1);
 median9 med0(clk,rst,medw0,med[7:0]);median9 med1(clk,rst,medw1,med[15:8]);
 raster_meta_delay #(9,1) md1(clk,rst,m1,m2);
 stream_delay #(16,9) mc(clk,rst,{medw1[32+:8],medw0[32+:8]},medcenter);
 wire iy=m2[32]&&m2[31:16]>0&&m2[31:16]<H-1;
 assign filtered[7:0]=filt&&iy&&m2[15:0]>0?med[7:0]:medcenter[7:0];
 assign filtered[15:8]=filt&&iy&&m2[15:0]<W/2-1?med[15:8]:medcenter[15:8];
 wire [71:0] sw0,sw1;wire [15:0] smooth,denoised;
 pair_window #(HT) sw(clk,rst,filtered,m2,sw0,sw1,m3);
 gentle_gaussian g0(clk,rst,sw0,filt&&m3[32]&&m3[15:0]>0&&m3[31:16]>0&&m3[31:16]<H-1,denoised[7:0]);
 gentle_gaussian g1(clk,rst,sw1,filt&&m3[32]&&m3[15:0]<W/2-1&&m3[31:16]>0&&m3[31:16]<H-1,denoised[15:8]);
 raster_meta_delay #(1,1) md2(clk,rst,m3,m4);
 wire [71:0] ew0,ew1;wire [10:0] mag0,mag1;
 pair_window #(HT) ew(clk,rst,denoised,m4,ew0,ew1,m5);
 wire [1:0] dir0,dir1;
 sobel_gradient #(1) e0(clk,rst,ew0,mag0,dir0);sobel_gradient #(1) e1(clk,rst,ew1,mag1,dir1);
 raster_meta_delay #(3,1) md3(clk,rst,m5,m6);
 wire sobel0=m6[32]&&m6[15:0]>0&&m6[31:16]>0&&m6[31:16]<H-1&&mag0>{3'd0,lim};
 wire sobel1=m6[32]&&m6[15:0]<W/2-1&&m6[31:16]>0&&m6[31:16]<H-1&&mag1>{3'd0,lim};
 wire[34:0] m7;wire[1:0] canny_edges,sobel_edges_aligned;
 canny_2ppc #(HT,W,H) canny(clk,rst,mag0,mag1,dir0,dir1,m6,{3'd0,lim},canny_edges,m7);
 stream_delay #(2,2*(HT+2)) sobel_align(clk,rst,{sobel1,sobel0},sobel_edges_aligned);
 wire edge0=canny_sel?canny_edges[0]:sobel_edges_aligned[0];
 wire edge1=canny_sel?canny_edges[1]:sobel_edges_aligned[1];
 wire [47:0] aligned;
 stream_delay #(48,5*HT+24) rgb_delay(clk,rst,rgb,aligned);
 function [23:0] draw;
 input [23:0] c;input edgebit;input [15:0] x,y;
 reg [15:0] l;
 begin l=c[23:16]*16'd77+c[15:8]*16'd150+c[7:0]*16'd29;
 case(sel)
 1:draw={3{l[15:8]}};
 2:draw={24{edgebit}};
 3:draw=x<W/2?{3{l[15:8]}}:{24{edgebit}};
 4:draw=y<H/2?{3{l[15:8]}}:{24{edgebit}};
 5:draw=edgebit?24'hff4040:c;
 default:draw=c;
 endcase end endfunction
 always @(posedge clk)begin
 if(rst)begin out_rgb<=0;out_hs<=1;out_vs<=1;out_de<=0;end
 else begin
 {out_vs,out_hs,out_de}<=m7[34:32];
 out_rgb<=m7[32]?{draw(aligned[47:24],edge1,{m7[14:0],1'b1},m7[31:16]),draw(aligned[23:0],edge0,{m7[14:0],1'b0},m7[31:16])}:48'd0;
 end end
endmodule
module gentle_gaussian(input wire clk,rst,input wire [71:0] w,input wire enable,output reg [7:0] q);
 wire [11:0] s={4'd0,w[0+:8]}+({4'd0,w[8+:8]}<<1)+{4'd0,w[16+:8]}
 +({4'd0,w[24+:8]}<<1)+({4'd0,w[32+:8]}<<2)+({4'd0,w[40+:8]}<<1)
 +{4'd0,w[48+:8]}+({4'd0,w[56+:8]}<<1)+{4'd0,w[64+:8]}+12'd8;
 wire [8:0] blend={1'b0,s[11:4]}+{1'b0,w[32+:8]}+9'd1;
 always @(posedge clk)if(rst)q<=0;else q<=enable?s[11:4]:w[32+:8];
endmodule
`default_nettype wire
