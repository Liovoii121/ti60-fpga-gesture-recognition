`timescale 1ns/1ps
`default_nettype none
// Pinned SDK common.h/gemmlowp arithmetic, NOT NNgen rshift_out rounding.
// Defined finite domain: shift -31..30 and INT32 left product must fit INT32.
module static5_sdk_requantize(
 input wire clk,rst,cancel,request,
 input wire signed [31:0] accumulator,multiplier,
 input wire signed [7:0] shift,
 output wire ready,output reg done,fault,
 output reg signed [31:0] value
);
 localparam IDLE=0,MULT=1,HIGH=2,RIGHT=3;
 reg [1:0] state;
 reg signed [31:0] left_q,multiplier_q,high_q;
 reg signed [63:0] product_q;
 reg [5:0] right_q;
 wire [5:0] left_amount=shift>0?shift[5:0]:6'd0;
 wire signed [63:0] left_wide=$signed({{32{accumulator[31]}},accumulator})<<<left_amount;
 wire signed [63:0] nudged=product_q+64'sd1073741824;
 // For a negative product SDK adds(1-2^30) then divides with trunc toward0.
 // Adding(2^31-1) converts that trunc to arithmetic floor: p+2^30 >>>31.
 wire [31:0] mask=right_q==0?0:(32'h1<<right_q)-1'b1;
 wire [31:0] threshold=(mask>>1)+{31'd0,high_q[31]};
 // Keep the arithmetic shift in a signed expression before adding the unsigned
 // remainder comparison; mixed-sign addition otherwise turns >>> into >>.
 wire signed [31:0] quotient=high_q>>>right_q;
 wire signed [31:0] increment=(high_q&mask)>threshold ? 32'sd1 : 32'sd0;
 wire signed [31:0] rounded_right=quotient+increment;
 assign ready=state==IDLE&&!rst&&!cancel;
 always @(posedge clk)begin
  done<=0;
  if(rst||cancel)begin state<=IDLE;done<=0;fault<=0;value<=0;left_q<=0;multiplier_q<=0;high_q<=0;product_q<=0;right_q<=0;end
  else case(state)
   IDLE:if(request&&ready)begin
    fault<=0;
    if(shift < -8'sd31||shift>8'sd30||left_wide>64'sd2147483647||left_wide < -64'sd2147483648)begin fault<=1;done<=1;end
    else begin left_q<=left_wide[31:0];multiplier_q<=multiplier;right_q<=shift<0?-shift:0;state<=MULT;end
   end
   MULT:begin product_q<=left_q*multiplier_q;state<=HIGH;end
   HIGH:begin high_q<=(left_q==32'sh80000000&&multiplier_q==32'sh80000000)?32'sh7fffffff:(nudged>>>31);state<=RIGHT;end
   RIGHT:begin value<=right_q==0?high_q:rounded_right;done<=1;state<=IDLE;end
   default:begin state<=IDLE;fault<=1;done<=1;end
  endcase
 end
endmodule
`default_nettype wire
