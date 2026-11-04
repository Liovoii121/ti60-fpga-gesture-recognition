`timescale 1ns/1ps
// Six signed Q16 logits -> argmax and approximate softmax peak in unsigned Q16.
// exp(-x) uses ln2 range reduction and a fifth-degree polynomial, all integer.
// One shared multiplier; restoring divider. No floating-point or large exp ROM.
module logit_peak_probability(input wire clk,rst,cancel,start,
 input wire[191:0] logits_packed,output wire start_ready,busy,
 output wire result_valid,input wire result_ready,
 output reg[2:0] class_id,output reg[16:0] peak_q,output reg fault);
 localparam IDLE=0,MAXIMUM=1,EXP_INIT=2,REDUCE=3,MULT=4,ACCUM=5,EXP_ADD=6,DIV_INIT=7,DIVIDE=8,DIV_DONE=9,OUTPUT=10;
 reg[3:0] state;reg signed[31:0] logits[0:5],maximum,poly;
 reg[2:0] index,max_index,term;reg[4:0] halves;reg[20:0] reduced;
 reg signed[63:0] product;reg[19:0] sum;
 reg[32:0] numerator,quotient;reg[20:0] remainder;reg[5:0] bit_index;
 wire signed[32:0] difference=$signed({maximum[31],maximum})-$signed({logits[index][31],logits[index]});
 wire[31:0] clipped_exp=poly<=0?32'd0:(poly>=65536?32'd65536:poly[31:0]);
 wire[16:0] scaled_exp=clipped_exp>>halves;
 wire[20:0] shifted_remainder={remainder[19:0],numerator[32]};
 function signed[31:0] coefficient(input[2:0] n);
  begin case(n)0:coefficient=2731;1:coefficient=-10923;2:coefficient=32768;3:coefficient=-65536;default:coefficient=65536;endcase end
 endfunction
 integer j;
 assign start_ready=state==IDLE&&!rst&&!cancel;
 assign busy=state!=IDLE;
 assign result_valid=state==OUTPUT&&!rst&&!cancel;
 always @(posedge clk)begin
  if(rst||cancel)begin state<=IDLE;class_id<=0;peak_q<=0;fault<=0;end
  else case(state)
   IDLE:if(start)begin
    for(j=0;j<6;j=j+1)logits[j]<=logits_packed[j*32+:32];
    maximum<=$signed(logits_packed[31:0]);max_index<=0;index<=1;sum<=0;fault<=0;state<=MAXIMUM;
   end
   MAXIMUM:begin
    if($signed(logits[index])>maximum)begin maximum<=logits[index];max_index<=index;end
    if(index==5)begin index<=0;state<=EXP_INIT;end else index<=index+1'b1;
   end
   EXP_INIT:begin
    halves<=0;reduced<=difference[20:0];poly<=-546;term<=0;
    if(difference>=33'sd1048576)begin poly<=0;state<=EXP_ADD;end else state<=REDUCE;
   end
   REDUCE:begin
    if(halves>=17)begin poly<=0;state<=EXP_ADD;end
    else if(reduced>=45426)begin reduced<=reduced-45426;halves<=halves+1'b1;end
    else state<=MULT;
   end
   MULT:begin product<=$signed(poly)*$signed({1'b0,reduced});state<=ACCUM;end
   ACCUM:begin
    poly<=((product+64'sd32768)>>>16)+coefficient(term);
    if(term==4)state<=EXP_ADD;else begin term<=term+1'b1;state<=MULT;end
   end
   EXP_ADD:begin
    sum<=sum+scaled_exp;
    if(index==5)state<=DIV_INIT;else begin index<=index+1'b1;state<=EXP_INIT;end
   end
   DIV_INIT:begin
    if(sum==0)begin fault<=1;peak_q<=0;class_id<=max_index;state<=OUTPUT;end
    else begin numerator<=33'h100000000;quotient<=0;remainder<=0;bit_index<=32;state<=DIVIDE;end
   end
   DIVIDE:begin
    numerator<=numerator<<1;
    if(shifted_remainder>=sum)begin remainder<=shifted_remainder-sum;quotient<={quotient[31:0],1'b1};end
    else begin remainder<=shifted_remainder;quotient<={quotient[31:0],1'b0};end
    if(bit_index==0)state<=DIV_DONE;else bit_index<=bit_index-1'b1;
   end
   DIV_DONE:begin peak_q<=quotient[16:0];class_id<=max_index;state<=OUTPUT;end
   OUTPUT:if(result_ready)state<=IDLE;
   default:state<=IDLE;
  endcase
 end
endmodule
