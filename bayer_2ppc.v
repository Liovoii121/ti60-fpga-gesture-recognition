`timescale 1ns/1ps
`default_nettype none
module bayer_2ppc #(parameter HT=800,W=1280,H=720)(
 input wire clk,rst,input wire [1:0] mirror,input wire [15:0] raw,
 input wire vs,hs,de,output wire [47:0] rgb,output wire ovs,ohs,ode);
 wire [71:0] a,b;wire [34:0] meta,cm,om;
 raster_meta_delay #(0,1) coords(clk,rst,{vs,hs,de,32'd0},meta);
 pair_window #(HT) win(clk,rst,raw,meta,a,b,cm);
 raster_meta_delay #(2,1) md(clk,rst,cm,om);
 assign {ovs,ohs,ode}=om[34:32];
 bayer_pixel_2stage p0(clk,rst,a,{cm[16]^mirror[1],~mirror[0]},rgb[23:0]);
 bayer_pixel_2stage p1(clk,rst,b,{cm[16]^mirror[1],mirror[0]},rgb[47:24]);
endmodule
module bayer_pixel_2stage(input wire clk,rst,input wire [71:0] w,input wire [1:0] phase,
 output reg [23:0] rgb);
 reg [9:0] cross_sum,diag_sum;reg [8:0] horiz_sum,vert_sum;
 reg [7:0] center;reg [1:0] p;
 always @(posedge clk)begin
 if(rst)begin cross_sum<=0;diag_sum<=0;horiz_sum<=0;vert_sum<=0;center<=0;p<=0;rgb<=0;end
 else begin
 cross_sum<={2'd0,w[8+:8]}+{2'd0,w[24+:8]}+{2'd0,w[40+:8]}+{2'd0,w[56+:8]};
 diag_sum<={2'd0,w[0+:8]}+{2'd0,w[16+:8]}+{2'd0,w[48+:8]}+{2'd0,w[64+:8]};
 horiz_sum<={1'b0,w[24+:8]}+{1'b0,w[40+:8]};
 vert_sum<={1'b0,w[8+:8]}+{1'b0,w[56+:8]};center<=w[32+:8];p<=phase;
 case(p)
 0:rgb<={center,cross_sum[9:2],diag_sum[9:2]};
 1:rgb<={horiz_sum[8:1],center,vert_sum[8:1]};
 2:rgb<={vert_sum[8:1],center,horiz_sum[8:1]};
 3:rgb<={diag_sum[9:2],cross_sum[9:2],center};
 endcase
 end end
endmodule
`default_nettype wire
