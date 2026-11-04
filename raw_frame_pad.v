`timescale 1ns/1ps
`default_nettype none
// Pad immediately after the last cropped pixel, using the unused source lines.
// Input VS can be low for one cycle: never extend padding into the next frame.
module raw_frame_pad #(parameter integer PAD_BEATS=256,FRAME_BEATS=518400)(
 input wire clk,resetn,vs,de,input wire [31:0] data,
 output reg overlap,output reg ovs,ode,output reg [31:0] odata,
 output reg [19:0] last_input_beats,last_output_beats);
 reg vs_q,ending,closed,out_vs_q;
 reg [15:0] left;
 reg [19:0] in_count,out_count;
 always @(posedge clk)begin
  if(!resetn)begin
   overlap<=0;ending<=0;closed<=0;vs_q<=0;left<=0;ovs<=0;ode<=0;odata<=0;
   in_count<=0;out_count<=0;out_vs_q<=0;last_input_beats<=0;last_output_beats<=0;
  end else begin
   vs_q<=vs;out_vs_q<=ovs;ode<=0;odata<=data;
   if(de&&vs)in_count<=in_count+1'b1;
   if(vs_q&&!vs)begin last_input_beats<=in_count;in_count<=0;closed<=0;end
   if(ovs&&ode)out_count<=out_count+1'b1;
   if(out_vs_q&&!ovs)begin last_output_beats<=out_count;out_count<=0;end
   if((left!=0||ending)&&de&&vs)overlap<=1;
   if(ending)begin ovs<=0;ode<=0;ending<=0;end
   else if(left!=0)begin
    ovs<=1;ode<=1;odata<=0;left<=left-1'b1;if(left==1)ending<=1;
   end else if(de&&vs&&in_count==FRAME_BEATS-1)begin
    ovs<=1;ode<=1;left<=PAD_BEATS;closed<=1;
    if(PAD_BEATS==0)ending<=1;
   end else if(vs_q&&!vs&&in_count!=FRAME_BEATS&&PAD_BEATS!=0)begin
    ovs<=1;ode<=1;odata<=0;left<=PAD_BEATS-1;
   end else begin ovs<=vs&&!closed;ode<=de&&vs&&!closed;end
  end
 end
endmodule
`default_nettype wire
