`timescale 1ns/1ps
// Q16 elementwise ReLU6(A+B), temporal NCHW with physical plane padding.
// Same memory-client contract as nn_layer_engine: real write completion,
// memory_idle before start, cancel drains in external memory clients.
module nn_residual_engine #(parameter MODEL_ADDRESSING=0)(input wire clk,rst,cancel,start,memory_idle,
 input wire [31:0] input_a_base,input_b_base,output_base,
 input wire [8:0] frames,channels,input wire [15:0] plane_words,
 output wire busy,memory_cancel,output reg done,fault,
 output wire activation_request,output wire [31:0] activation_address,
 input wire activation_ready,activation_response,input wire [31:0] activation_data,
 input wire activation_fault,output wire activation_response_ready,
 output wire parameter_request,output wire [31:0] parameter_address,
 input wire parameter_ready,parameter_response,input wire [31:0] parameter_data,
 input wire parameter_fault,output wire parameter_response_ready,
 output wire store_request,output wire [31:0] store_address,
 output reg [31:0] store_data,input wire store_ready,store_response,store_fault);
 localparam IDLE=0,A_REQ=1,A_WAIT=2,B_REQ=3,B_WAIT=4,ADD=5,W_REQ=6,W_WAIT=7,FINISH=8,ERROR=9;
 reg[3:0] state;reg[31:0] src_a,src_b,dst;
 reg[8:0] n,c,t,channel;reg[15:0] stride;
 reg signed[31:0] a,b;
 wire signed[32:0] sum=$signed({a[31],a})+$signed({b[31],b});
 wire[13:0] model_word=channel*stride+t;
 wire[31:0] offset=MODEL_ADDRESSING?{16'd0,model_word,2'd0}:((channel*stride+t)<<2);
 assign busy=state!=IDLE;
 assign memory_cancel=rst||cancel||fault;
 assign activation_request=state==A_REQ&&!memory_cancel;
 assign activation_address=MODEL_ADDRESSING?{src_a[31:16],model_word,2'd0}:(src_a+offset);
 assign activation_response_ready=state==A_WAIT;
 assign parameter_request=state==B_REQ&&!memory_cancel;
 assign parameter_address=MODEL_ADDRESSING?{src_b[31:16],model_word,2'd0}:(src_b+offset);
 assign parameter_response_ready=state==B_WAIT;
 assign store_request=state==W_REQ&&!memory_cancel;
 assign store_address=MODEL_ADDRESSING?{dst[31:16],model_word,2'd0}:(dst+offset);
 always @(posedge clk)begin
  done<=0;
  if(rst)begin state<=IDLE;fault<=0;t<=0;channel<=0;store_data<=0;end
  else if(cancel)begin done<=busy;state<=IDLE;end
  else case(state)
   IDLE:if(start&&memory_idle)begin
    src_a<=input_a_base;src_b<=input_b_base;dst<=output_base;n<=frames;c<=channels;stride<=plane_words;
    t<=0;channel<=0;fault<=0;
    state<=(frames==0||channels==0||plane_words<frames)?ERROR:A_REQ;
   end
   A_REQ:if(activation_ready)state<=A_WAIT;
   A_WAIT:if(activation_response)begin if(activation_fault)state<=ERROR;else begin a<=activation_data;state<=B_REQ;end end
   B_REQ:if(parameter_ready)state<=B_WAIT;
   B_WAIT:if(parameter_response)begin if(parameter_fault)state<=ERROR;else begin b<=parameter_data;state<=ADD;end end
   ADD:begin store_data<=(sum<0)?32'd0:((sum>33'sd393216)?32'd393216:sum[31:0]);state<=W_REQ;end
   W_REQ:if(store_ready)state<=W_WAIT;
   W_WAIT:if(store_response)begin
    if(store_fault)state<=ERROR;
    else if(t+1<n)begin t<=t+1'b1;state<=A_REQ;end
    else begin t<=0;if(channel+1<c)begin channel<=channel+1'b1;state<=A_REQ;end else state<=FINISH;end
   end
   FINISH:begin done<=1;state<=IDLE;end
   ERROR:begin done<=1;fault<=1;state<=IDLE;end
   default:state<=ERROR;
  endcase
 end
endmodule
