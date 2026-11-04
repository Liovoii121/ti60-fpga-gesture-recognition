`timescale 1ns/1ps
`default_nettype none
// BT.709 limited range. Horizontal and vertical box chroma anti-aliasing.
// Each output symbol contains {Yodd, Yeven, Cb/Cr}; even active rows carry Cb.
module rgb_to_y420 #(parameter HT=800)(input wire clk,rst,input wire [47:0] rgb,
 input wire hs,vs,de,output reg [23:0] data,output reg ohs,ovs,ode);
 wire [23:0] ycc0,ycc1;wire [34:0] meta,previous_meta;
 rgb_ycc_pixel c0(clk,rst,rgb[23:0],ycc0);
 rgb_ycc_pixel c1(clk,rst,rgb[47:24],ycc1);
 wire [8:0] cb_sum={1'b0,ycc0[15:8]}+{1'b0,ycc1[15:8]}+9'd1;
 wire [8:0] cr_sum={1'b0,ycc0[7:0]}+{1'b0,ycc1[7:0]}+9'd1;
 reg [31:0] row_data;
 always @(posedge clk)if(rst)row_data<=0;else row_data<={ycc1[23:16],ycc0[23:16],cb_sum[8:1],cr_sum[8:1]};
 raster_meta_delay #(3,1) m0(clk,rst,{vs,hs,de,32'd0},meta);
 wire [31:0] previous_row;
 stream_delay #(32,HT) line_delay(clk,rst,row_data,previous_row);
 raster_meta_delay #(HT,1) m1(clk,rst,meta,previous_meta);
 wire [8:0] cb_vertical={1'b0,row_data[15:8]}+{1'b0,previous_row[15:8]}+9'd1;
 wire [8:0] cr_vertical={1'b0,row_data[7:0]}+{1'b0,previous_row[7:0]}+9'd1;
 wire [7:0] cr_previous;
 stream_delay #(8,HT) cr_line(clk,rst,cr_vertical[8:1],cr_previous);
 always @(posedge clk)begin
 if(rst)begin data<=0;ohs<=1;ovs<=1;ode<=0;end
 else begin
 {ovs,ohs,ode}<=previous_meta[34:32];
 data<={previous_row[31:16],previous_meta[16]?cr_previous:cb_vertical[8:1]};
 end end
endmodule
module rgb_ycc_pixel(input wire clk,rst,input wire [23:0] rgb,output reg [23:0] ycc);
 reg signed [17:0] ys,cbs,crs;
 wire signed [8:0] r={1'b0,rgb[23:16]},g={1'b0,rgb[15:8]},b={1'b0,rgb[7:0]};
 function [7:0] clip;
 input signed [17:0] s;input signed [17:0] lo,hi;
 begin if(s<lo)clip=lo[7:0];else if(s>hi)clip=hi[7:0];else clip=s[7:0];end endfunction
 always @(posedge clk)begin
 if(rst)begin ys<=0;cbs<=0;crs<=0;ycc<=24'h108080;end
 else begin
 ys<=r*18'sd47+g*18'sd157+b*18'sd16+18'sd128;
 cbs<=-r*18'sd26-g*18'sd86+b*18'sd112+18'sd128;
 crs<=r*18'sd112-g*18'sd102-b*18'sd10+18'sd128;
 ycc<={clip((ys>>>8)+18'sd16,18'sd16,18'sd235),clip((cbs>>>8)+18'sd128,18'sd16,18'sd240),clip((crs>>>8)+18'sd128,18'sd16,18'sd240)};
 end end
endmodule
`default_nettype wire
