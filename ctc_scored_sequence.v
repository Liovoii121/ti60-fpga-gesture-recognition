`timescale 1ns/1ps
// Greedy CTC, matching Python collapse-before-blank removal and run-peak score.
// Buffer is published only at sequence completion; low confidence/overflow reject.
module ctc_scored_sequence(input wire clk,rst,cancel,sequence_start,
 input wire[16:0] threshold_q,input wire frame_valid,sequence_end,
 input wire[2:0] frame_class,input wire[16:0] frame_peak_q,
 output wire start_ready,frame_ready,result_valid,input wire result_ready,
 output reg accepted,overflow,fault,output reg[4:0] token_count,
 output reg[47:0] token_words,output reg[16:0] minimum_score_q);
 localparam IDLE=0,ACTIVE=1,FLUSH=2,OUTPUT=3;
 reg[1:0] state;reg[2:0] previous;reg[16:0] run_peak,minimum,threshold;
 wire[16:0] final_minimum=(previous!=0&&run_peak<minimum)?run_peak:minimum;
 assign start_ready=state==IDLE&&!rst&&!cancel;
 assign frame_ready=state==ACTIVE&&!rst&&!cancel;
 assign result_valid=state==OUTPUT&&!rst&&!cancel;
 always @(posedge clk)begin
  if(rst||cancel)begin state<=IDLE;accepted<=0;overflow<=0;fault<=0;token_count<=0;token_words<=0;minimum_score_q<=0;previous<=0;run_peak<=0;minimum<=17'd65536;threshold<=0;end
  else case(state)
   IDLE:if(sequence_start)begin
    accepted<=0;overflow<=0;fault<=0;token_count<=0;token_words<=0;
    minimum_score_q<=0;previous<=0;run_peak<=0;minimum<=17'd65536;threshold<=threshold_q;state<=ACTIVE;
   end
   ACTIVE:begin
    if(frame_valid)begin
     if(frame_class>5||frame_peak_q>65536)fault<=1;
     if(frame_class==previous)begin if(frame_class!=0&&frame_peak_q>run_peak)run_peak<=frame_peak_q;end
     else begin
      if(previous!=0&&run_peak<minimum)minimum<=run_peak;
      previous<=frame_class;run_peak<=frame_class==0?17'd0:frame_peak_q;
      if(frame_class!=0&&frame_class<=5)begin
       if(token_count==16)overflow<=1;
       else begin token_words[token_count*3+:3]<=frame_class;token_count<=token_count+1'b1;end
      end
     end
    end
    if(sequence_end)state<=FLUSH;
   end
   FLUSH:begin
    minimum_score_q<=token_count==0?17'd0:final_minimum;
    accepted<=token_count!=0&&!overflow&&!fault&&final_minimum>=threshold;
    state<=OUTPUT;
   end
   OUTPUT:if(result_ready)state<=IDLE;
  endcase
 end
endmodule
