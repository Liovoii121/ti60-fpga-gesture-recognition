`timescale 1ns/1ps
`default_nettype none
module touch_view_stage7 #(parameter W=1280,H=720,HT=1650)(
 input wire clk,rst,input wire [2:0] view,input wire [7:0] threshold,input wire median_enable,
 input wire [23:0] rgb,input wire hs,vs,de,
 output reg [23:0] out_rgb,output reg out_hs,out_vs,out_de);
 reg vs_q,de_q,seen;reg [15:0] x,y;reg [2:0] selected;reg [10:0] limit;
 wire frame_start=vs&&!vs_q;
 wire [15:0] luminance=({8'd0,rgb[23:16]}*16'd77)+({8'd0,rgb[15:8]}*16'd150)+({8'd0,rgb[7:0]}*16'd29);
 reg [7:0] gray;reg [34:0] gray_meta;
 always @(posedge clk)begin
 if(rst)begin vs_q<=1;de_q<=0;seen<=0;x<=0;y<=0;selected<=0;limit<=128;gray<=0;gray_meta<=0;end
 else begin
 vs_q<=vs;de_q<=de;
 if(de)x<=x+1'b1;else x<=0;
 if(frame_start)begin y<=0;seen<=1;selected<=view;limit<={3'd0,threshold};end
 else if(de_q&&!de)y<=y+1'b1;
 gray<=de?luminance[15:8]:0;
 gray_meta<={vs,hs,de&&seen,y,x};
 end
 end
 wire [7:0] median_gray,median_center;wire [34:0] median_meta;
 median_3x3 #(.W(W),.H(H),.HT(HT),.COMPACT_META(1)) filter(
 .clk(clk),.rst(rst),.din(gray),.meta(gray_meta),.dout(median_gray),
 .m_meta(median_meta),.center_gray(median_center));
 reg median_vs_q,filter_on;reg [10:0] filter_limit;
 always @(posedge clk)begin
 if(rst)begin median_vs_q<=1;filter_on<=0;filter_limit<=128;end
 else begin median_vs_q<=median_meta[34];
 if(median_meta[34]&&!median_vs_q)begin filter_on<=median_enable;filter_limit<=limit;end
 end end
 wire interior=median_meta[32] && median_meta[15:0]>0 && median_meta[15:0]<W-1 && median_meta[31:16]>0 && median_meta[31:16]<H-1;
 wire [7:0] filtered=filter_on&&interior?median_gray:median_center;
 // A light binomial Gaussian removes low-amplitude noise left by median.
 wire [71:0] smooth_window;wire [34:0] smooth_center_meta,smooth_meta;
 window_3x3 #(8,HT,1) smooth_win(clk,rst,filtered,median_meta,smooth_window,smooth_center_meta);
 wire [11:0] smooth_sum={4'd0,smooth_window[0+:8]}+({4'd0,smooth_window[8+:8]}<<1)+{4'd0,smooth_window[16+:8]}
  +({4'd0,smooth_window[24+:8]}<<1)+({4'd0,smooth_window[32+:8]}<<2)+({4'd0,smooth_window[40+:8]}<<1)
  +{4'd0,smooth_window[48+:8]}+({4'd0,smooth_window[56+:8]}<<1)+{4'd0,smooth_window[64+:8]}+12'd8;
 reg [7:0] smooth_gray,smooth_bypass;
 always @(posedge clk)begin
  if(rst)begin smooth_gray<=0;smooth_bypass<=0;end
  else begin smooth_gray<=smooth_sum[11:4];smooth_bypass<=smooth_window[32+:8];end
 end
 raster_meta_delay #(1,1) smooth_md(clk,rst,smooth_center_meta,smooth_meta);
 reg smooth_vs_q,smooth_on;reg [10:0] smooth_limit;
 always @(posedge clk)begin
  if(rst)begin smooth_vs_q<=1;smooth_on<=0;smooth_limit<=128;end
  else begin smooth_vs_q<=smooth_meta[34];
   if(smooth_meta[34]&&!smooth_vs_q)begin smooth_on<=filter_on;smooth_limit<=filter_limit;end
  end
 end
 wire smooth_interior=smooth_meta[32] && smooth_meta[15:0]>0 && smooth_meta[15:0]<W-1 && smooth_meta[31:16]>0 && smooth_meta[31:16]<H-1;
 // Blend equally with the median center to retain fine detail.
 wire [8:0] gentle_sum={1'b0,smooth_gray}+{1'b0,smooth_bypass}+9'd1;
 wire [7:0] denoised=smooth_on&&smooth_interior?gentle_sum[8:1]:smooth_bypass;
 wire edge_bit;wire [10:0] magnitude;wire [34:0] meta;
 sobel_top #(.W(W),.H(H),.HT(HT),.COMPACT_META(1),.COMPUTE_DIRECTION(0)) sobel(
 .clk(clk),.rst(rst),.din(denoised),.meta(smooth_meta),.threshold(smooth_limit),
 .edge_out(edge_bit),.mag(magnitude),.dir(),.m_meta(meta));
 wire [7:0] aligned_gray;wire [23:0] aligned_rgb;
 stream_delay #(24,3*HT+20) rd(clk,rst,rgb,aligned_rgb);
 // Reconstruct the original grayscale from the already aligned RGB stream.
 // This is byte-exact to the earlier gray stage and saves eight RAM blocks
 // at 1080p without changing the median, Gaussian or Sobel filters.
 wire [15:0] aligned_luminance=({8'd0,aligned_rgb[23:16]}*16'd77)
  +({8'd0,aligned_rgb[15:8]}*16'd150)+({8'd0,aligned_rgb[7:0]}*16'd29);
 assign aligned_gray=aligned_luminance[15:8];
 reg output_vs_q;reg [2:0] output_view;
 always @(posedge clk)begin
 if(rst)begin output_vs_q<=1;output_view<=0;end
 else begin output_vs_q<=meta[34];if(meta[34]&&!output_vs_q)output_view<=selected;end end
 always @(posedge clk)begin
 if(rst)begin out_rgb<=0;out_hs<=1;out_vs<=1;out_de<=0;end
 else begin
 out_hs<=meta[33];out_vs<=meta[34];out_de<=meta[32];
 if(!meta[32])out_rgb<=0;
 else case(output_view)
 1:out_rgb<={3{aligned_gray}};
 2:out_rgb<={24{edge_bit}};
 3:out_rgb<=meta[15:0]<W/2?{3{aligned_gray}}:{24{edge_bit}};
 4:out_rgb<=meta[31:16]<H/2?{3{aligned_gray}}:{24{edge_bit}};
 5:out_rgb<=edge_bit?24'hff4040:aligned_rgb;
 default:out_rgb<=aligned_rgb;
 endcase
 end
 end
endmodule
`default_nettype wire
