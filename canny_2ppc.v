`timescale 1ns/1ps
`default_nettype none
// Shared full-width neighborhoods; two pixel lanes must cross pair boundaries.
module pair_window_bits #(parameter B=13,HT=800)(
 input wire clk,rst,input wire[2*B-1:0] data,input wire[34:0] meta,
 output wire[9*B-1:0] a,b,output wire[34:0] center);
 wire[18*B-1:0] pairs;
 window_3x3 #(2*B,HT,1) w(clk,rst,data,meta,pairs,center);
 genvar row;
 generate for(row=0;row<3;row=row+1)begin:r
  assign a[row*3*B+:3*B]={pairs[(row*3+1)*2*B+B+:B],pairs[(row*3+1)*2*B+:B],pairs[(row*3)*2*B+B+:B]};
  assign b[row*3*B+:3*B]={pairs[(row*3+2)*2*B+:B],pairs[(row*3+1)*2*B+B+:B],pairs[(row*3+1)*2*B+:B]};
 end endgenerate
endmodule
module canny_nms(input wire[116:0] w,input wire interior,input wire[10:0] high,output wire[1:0] strength);
 wire[12:0] c=w[52+:13];
 wire[10:0] before_mag=c[12:11]==0?w[39+:11]:c[12:11]==1?w[0+:11]:c[12:11]==2?w[13+:11]:w[26+:11];
 wire[10:0] after_mag=c[12:11]==0?w[65+:11]:c[12:11]==1?w[104+:11]:c[12:11]==2?w[91+:11]:w[78+:11];
 wire[10:0] n=interior&&c[10:0]>=before_mag&&c[10:0]>=after_mag?c[10:0]:11'd0;
 assign strength={n>high,n>(high>>1)};
endmodule
module canny_hysteresis(input wire[17:0] w,input wire de,output wire edgebit);
 wire neighbor=|{w[1],w[3],w[5],w[7],w[11],w[13],w[15],w[17]};
 assign edgebit=de&&(w[9]||(w[8]&&neighbor));
endmodule
// Directional NMS, high/low thresholds, one local 8-neighbor hysteresis pass.
// This preserves the previously implemented streaming approximation, not a
// full-frame recursive weak-edge trace.
module canny_2ppc #(parameter HT=800,W=1280,H=720)(
 input wire clk,rst,input wire[10:0] mag0,mag1,input wire[1:0] dir0,dir1,
 input wire[34:0] meta,input wire[10:0] high,
 output wire[1:0] edges,output wire[34:0] out_meta);
 wire[116:0] a,b;wire[34:0] nmeta;
 pair_window_bits #(13,HT) mw(clk,rst,{dir1,mag1,dir0,mag0},meta,a,b,nmeta);
 reg vq=1;reg[10:0] threshold=128;
 always @(posedge clk)if(rst)begin vq<=1;threshold<=128;end
 else begin vq<=nmeta[34];if(nmeta[34]&&!vq)threshold<=high;end
 wire interior=nmeta[32]&&nmeta[15:0]>0&&nmeta[15:0]<W/2-1&&nmeta[31:16]>1&&nmeta[31:16]<H-2;
 wire[3:0] strength;wire[17:0] sa,sb;
 canny_nms n0(a,interior,threshold,strength[1:0]);
 canny_nms n1(b,interior,threshold,strength[3:2]);
 pair_window_bits #(2,HT) sw(clk,rst,strength,nmeta,sa,sb,out_meta);
 canny_hysteresis h0(sa,out_meta[32],edges[0]);
 canny_hysteresis h1(sb,out_meta[32],edges[1]);
endmodule
`default_nettype wire
