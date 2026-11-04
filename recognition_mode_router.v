`timescale 1ns/1ps
`default_nettype none
// Runtime selection. Neither switching nor cancellation resets the shared DDR
// controller; the continuous engine drains every issued memory transaction.
module recognition_mode_router(
 input wire clk,rst,key_valid,input wire[3:0]key_code,
 output reg continuous_mode=0,
 output wire mode_change,static_reset,
 output wire static_key_valid,continuous_key_valid,
 output wire[3:0]static_key_code,continuous_key_code);
 assign mode_change=key_valid&&key_code==4'd14&&!rst;
 always @(posedge clk)begin
  if(rst)continuous_mode<=0;
  else if(mode_change)continuous_mode<=!continuous_mode;
 end
 assign static_key_valid=key_valid&&!continuous_mode&&!mode_change&&!rst;
 assign static_key_code=key_code;
 assign static_reset=rst||continuous_mode||mode_change||
                     (static_key_valid&&key_code==4'd15);
 assign continuous_key_valid=!rst&&continuous_mode&&key_valid&&
     (key_code==4'd13||key_code==4'd12||key_code==4'd15||mode_change);
 assign continuous_key_code=mode_change?4'd12:key_code;
endmodule
`default_nettype wire
