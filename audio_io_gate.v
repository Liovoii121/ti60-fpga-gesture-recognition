`timescale 1ns/1ps
`default_nettype none
// mode0: quiet when idle; mode1: force isolation; mode2: original continuous clock.
// Change gate only at a falling LRCLK edge while BCLK is low, keeping every
// transmitted I2S frame complete. The internal transmitter is never gated.
module audio_io_gate(input wire clk,rst,input wire[1:0]mode,input wire busy,
 input wire bclk_in,lrclk_in,din_in,output reg gate=0,output wire bclk,lrclk,din);
 reg lq=0;
 always @(posedge clk)begin
  if(rst)begin lq<=0;gate<=0;end
  else begin
   lq<=lrclk_in;
   if(lq&&!lrclk_in&&!bclk_in)gate<=mode==2||(mode==0&&busy);
  end
 end
 assign bclk=gate&&bclk_in;
 assign lrclk=gate&&lrclk_in;
 assign din=gate&&din_in;
endmodule
`default_nettype wire
