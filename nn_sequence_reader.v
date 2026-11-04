`timescale 1ns/1ps
// Read six class-major logits from DDR after the sequence compute job commits.
// Physical temporal stride310; confidence is calculated on chip, not supplied by PC.
module nn_sequence_reader(input wire clk,rst,cancel,start,memory_idle,
 input wire[8:0] frames,input wire[16:0] threshold_q,
 output wire start_ready,busy,cache_invalidate,client_cancel,
 output wire activation_request,output wire[31:0] activation_address,
 input wire activation_ready,activation_response,input wire[31:0] activation_data,
 input wire activation_fault,output wire activation_response_ready,
 output wire result_valid,input wire result_ready,
 output reg accepted,overflow,fault,output reg[4:0] token_count,
 output reg[47:0] token_words,output reg[16:0] minimum_score_q);
 localparam IDLE=0,BEGIN=1,READ_REQ=2,READ_WAIT=3,PEAK_START=4,PEAK_WAIT=5,CTC_WAIT=6,OUTPUT=7,ERROR=8;
 reg[3:0] state;reg[8:0] n,t;reg[2:0] c;reg[191:0] logits;reg[16:0] threshold;
 wire peak_ready,peak_valid,peak_fault,ctc_ready,ctc_valid,ctc_accepted,ctc_overflow,ctc_fault;
 wire[2:0] cls;wire[16:0] prob,ctc_score;wire[4:0] ctc_count;wire[47:0] ctc_words;
 wire accepting_peak=state==PEAK_WAIT&&peak_valid&&ctc_ready;
 assign client_cancel=rst||cancel||fault||state==ERROR;
 assign start_ready=state==IDLE&&memory_idle&&!rst&&!cancel;
 assign busy=state!=IDLE;
 assign cache_invalidate=state==BEGIN;
 assign activation_request=state==READ_REQ&&!client_cancel;
 assign activation_address=32'h00860000+((c*32'd310+t)<<2);
 assign activation_response_ready=state==READ_WAIT;
 assign result_valid=state==OUTPUT&&!rst&&!cancel;
 logit_peak_probability peak(.clk(clk),.rst(rst),.cancel(client_cancel),.start(state==PEAK_START),.logits_packed(logits),.start_ready(peak_ready),.busy(),.result_valid(peak_valid),.result_ready(state==PEAK_WAIT&&ctc_ready),.class_id(cls),.peak_q(prob),.fault(peak_fault));
 ctc_scored_sequence decoder(.clk(clk),.rst(rst),.cancel(client_cancel),.sequence_start(state==BEGIN),.threshold_q(threshold),
  .frame_valid(accepting_peak),.sequence_end(accepting_peak&&t+1==n),.frame_class(cls),.frame_peak_q(prob),.start_ready(),.frame_ready(ctc_ready),
  .result_valid(ctc_valid),.result_ready(state==CTC_WAIT),.accepted(ctc_accepted),.overflow(ctc_overflow),.fault(ctc_fault),.token_count(ctc_count),.token_words(ctc_words),.minimum_score_q(ctc_score));
 always @(posedge clk)begin
  if(rst||cancel)begin state<=IDLE;accepted<=0;overflow<=0;fault<=0;token_count<=0;token_words<=0;minimum_score_q<=0;n<=0;t<=0;c<=0;logits<=0;threshold<=0;end
  else case(state)
   IDLE:if(start&&memory_idle)begin
    fault<=0;accepted<=0;overflow<=0;token_count<=0;token_words<=0;minimum_score_q<=0;
    n<=frames;t<=0;c<=0;threshold<=threshold_q;state<=(frames==0||frames>310)?ERROR:BEGIN;
   end
   BEGIN:state<=READ_REQ;
   READ_REQ:if(activation_ready)state<=READ_WAIT;
   READ_WAIT:if(activation_response)begin
    if(activation_fault)state<=ERROR;
    else begin logits[c*32+:32]<=activation_data;if(c==5)state<=PEAK_START;else begin c<=c+1'b1;state<=READ_REQ;end end
   end
   PEAK_START:if(peak_ready)state<=PEAK_WAIT;
   PEAK_WAIT:if(accepting_peak)begin
    if(peak_fault)state<=ERROR;
    else if(t+1==n)state<=CTC_WAIT;
    else begin t<=t+1'b1;c<=0;state<=READ_REQ;end
   end
   CTC_WAIT:if(ctc_valid)begin
    accepted<=ctc_accepted;overflow<=ctc_overflow;fault<=ctc_fault;
    token_count<=ctc_count;token_words<=ctc_words;minimum_score_q<=ctc_score;state<=OUTPUT;
   end
   OUTPUT:if(result_ready)state<=IDLE;
   ERROR:begin fault<=1;accepted<=0;token_count<=0;token_words<=0;minimum_score_q<=0;state<=OUTPUT;end
   default:state<=ERROR;
  endcase
 end
endmodule
