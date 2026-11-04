`timescale 1ns/1ps
// Shared Q16.16 dot-product datapath. Operand memories are external.
// req -> operand_valid is an explicit handshake, allowing BRAM or DDR clients.
module fixed_dot_product #(parameter WEIGHT_BITS=32)(input wire clk,rst,cancel,start,
 input wire [15:0] length,input wire signed [31:0] bias,
 input wire relu_enable,relu6_enable,
 output reg operand_req,output reg [15:0] operand_index,
 input wire operand_valid,input wire signed [31:0] activation,weight,
 output reg busy,done,overflow,output reg signed [31:0] result);
 reg [1:0] state;reg [15:0] count,total;
 reg signed [63:0] accumulator,product;
 reg use_relu,use_relu6;
 wire signed[WEIGHT_BITS-1:0] exact_weight=weight[WEIGHT_BITS-1:0];
 wire signed[WEIGHT_BITS+31:0] exact_product=$signed(activation)*exact_weight;
 // Guard incompatible parameters; do not silently truncate a replacement model.
 wire weight_out_of_range=weight!=$signed(exact_weight);
 wire signed [63:0] rounded=(accumulator+64'sd32768)>>>16;
 always @(posedge clk) begin
  done<=0;operand_req<=0;
  if(rst||cancel)begin state<=0;busy<=0;overflow<=0;operand_index<=0;result<=0;accumulator<=0;end
  else case(state)
   0:if(start)begin
    accumulator<=$signed(bias)*64'sd65536;
    total<=length;count<=0;operand_index<=0;use_relu<=relu_enable;use_relu6<=relu6_enable;overflow<=0;busy<=1;
    if(length==0)state<=3;else begin operand_req<=1;state<=1;end
   end
   1:if(operand_valid)begin product<=$signed(exact_product);if(weight_out_of_range)overflow<=1;state<=2;end
   2:begin
    accumulator<=accumulator+product;
    if(count+1==total)state<=3;
    else begin count<=count+1'b1;operand_index<=count+1'b1;operand_req<=1;state<=1;end
   end
   3:begin
    if((use_relu||use_relu6)&&rounded<0)result<=0;
    else if(use_relu6&&rounded>64'sd393216)result<=32'sd393216;
    else if(rounded>64'sh7fffffff)begin result<=32'sh7fffffff;overflow<=1;end
    else if(rounded< -64'sh80000000)begin result<=32'sh80000000;overflow<=1;end
    else result<=rounded[31:0];
    done<=1;busy<=0;state<=0;
   end
  endcase
 end
endmodule
