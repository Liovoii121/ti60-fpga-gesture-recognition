`timescale 1ns/1ps
// Pixel-clock module; frame_id MUST tag the actual sensor frame being read.
// Repeated 120Hz display frames do not advance the 60Hz sensor sampling cadence.
module continuous_roi_sampler #(parameter SENSOR_FRAME_STRIDE=6)(
 input wire clk,rst,enable,cancel,frame_start,pixel_valid,frame_store_ready,
 input wire [31:0] frame_id,input wire [10:0] x,y,
 input wire [47:0] rgb_pair,
 output reg sample_valid,frame_done,dropped_frame,
 output reg [11:0] sample_address,output reg [7:0] gray,
 output reg [31:0] sampled_frame_id,output wire frame_active);
 reg capturing,have_frame;reg [31:0] last_frame;
 assign frame_active=capturing;
 reg [5:0] column,row;
 wire [10:0] target_x=11'd384+column*11'd18;
 // int(1080*.9444444444)-int(1080*.0555555556)=959.
 wire [10:0] target_y=(row==0)?11'd60:(11'd59+row*11'd15);
 wire [23:0] pixel=(target_x==x)?rgb_pair[23:0]:rgb_pair[47:24];
 wire [17:0] weighted=pixel[23:16]*18'd77+pixel[15:8]*18'd150+pixel[7:0]*18'd29;
 always @(posedge clk) begin
  sample_valid<=0;frame_done<=0;dropped_frame<=0;
  if(rst||cancel||!enable)begin capturing<=0;have_frame<=0;last_frame<=0;column<=0;row<=0;sample_address<=0;gray<=0;sampled_frame_id<=0;end
  else if(frame_start)begin
   if(capturing)dropped_frame<=1;
   capturing<=0;column<=0;row<=0;
   if(!have_frame||(frame_id-last_frame)>=SENSOR_FRAME_STRIDE)begin
    if(frame_store_ready)begin capturing<=1;have_frame<=1;last_frame<=frame_id;sampled_frame_id<=frame_id;end
    else dropped_frame<=1;
   end
  end else if(capturing&&pixel_valid&&y==target_y&&(x==target_x||x+1'b1==target_x))begin
   sample_valid<=1;sample_address<={row,column};gray<=weighted[15:8];
   if(column==63)begin
    column<=0;
    if(row==63)begin capturing<=0;frame_done<=1;end
    else row<=row+1'b1;
   end else column<=column+1'b1;
  end
 end
endmodule
