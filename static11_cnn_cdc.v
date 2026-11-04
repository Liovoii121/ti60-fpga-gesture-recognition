`timescale 1ns/1ps
`default_nettype none
// Bundled-data mailboxes: payload stays immutable until the returned toggle.
// Backpressure is intentional: 4096 input bytes take less than one video frame.
// CNN arithmetic retains the validated 74.4 MHz clock at 1080p output rates.
module static11_cnn_cdc(
 input wire clk,core_clk,rst,start,cancel,input wire [31:0] epoch,
 output wire start_ready,busy,
 input wire gray_valid,gray_last,input wire [7:0] gray_data,
 input wire [31:0] gray_epoch,output wire gray_ready,
 output wire result_valid,input wire result_ready,
 output reg [31:0] result_epoch,output reg [223:0] result_scores,
 output wire fault);
 reg start_req,cancel_req,gray_req,result_ack;
 reg [31:0] start_payload;
 reg [40:0] gray_payload;
 reg cancel_q,active,result_seen,result_full;
 reg start_ack,cancel_ack,gray_ack,result_req;
 reg [255:0] result_payload;
 (* async_reg="true",syn_preserve=1 *) reg [1:0] sa,ca,ga,rr,nr,nf;
 (* async_reg="true",syn_preserve=1 *) reg [1:0] sr,cr,gr,ra;
 (* async_reg="true",syn_preserve=1 *) reg [1:0] reset_core;
 wire core_rst=reset_core[1];
 always @(posedge core_clk or posedge rst)
  if(rst)reset_core<=2'b11;else reset_core<={reset_core[0],1'b0};
 wire n_ready,n_busy,n_gray_ready,n_result_valid,n_fault;
 wire [31:0] n_result_epoch;
 wire [223:0] n_result_scores;
 reg n_start,n_cancel,n_result_ready,start_wait;
 reg [31:0] n_epoch;
 reg result_pending,result_hold;
 reg [1:0] cancel_wait;
 assign busy=active||!nr[1]||start_req!=sa[1]||cancel_req!=ca[1];
 assign start_ready=!rst&&!cancel&&!active&&nr[1]&&!nf[1]&&
  start_req==sa[1]&&cancel_req==ca[1]&&gray_req==ga[1]&&!result_full;
 assign gray_ready=!rst&&!cancel&&active&&gray_req==ga[1];
 assign result_valid=result_full&&!rst&&!cancel;
 assign fault=nf[1]&&!rst;
 always @(posedge clk)begin
  if(rst)begin
   sa<=0;ca<=0;ga<=0;rr<=0;nr<=0;nf<=0;
   start_req<=0;cancel_req<=0;gray_req<=0;result_ack<=0;
   start_payload<=0;gray_payload<=0;cancel_q<=0;active<=0;
   result_seen<=0;result_full<=0;result_epoch<=0;result_scores<=0;
  end else begin
   sa<={sa[0],start_ack};ca<={ca[0],cancel_ack};ga<={ga[0],gray_ack};
   rr<={rr[0],result_req};nr<={nr[0],n_ready};nf<={nf[0],n_fault};cancel_q<=cancel;
   if(start&&start_ready)begin start_payload<=epoch;start_req<=!start_req;active<=1;end
   if(gray_valid&&gray_ready)begin gray_payload<={gray_epoch,gray_last,gray_data};gray_req<=!gray_req;end
   if(rr[1]!=result_seen)begin
    result_epoch<=result_payload[255:224];result_scores<=result_payload[223:0];
    result_seen<=rr[1];result_full<=1;
   end
   if(result_full&&(result_ready||cancel||result_epoch!=epoch))begin
    result_full<=0;result_ack<=result_seen;
    if(result_epoch==epoch)active<=0;
   end
   if(cancel&&!cancel_q)begin cancel_req<=!cancel_req;active<=0;end
  end
 end
 // Old mailbox entries are consumed without reaching the core after cancel.
 wire gray_match=gray_payload[40:9]==n_epoch;
 wire n_gray_valid=gr[1]!=gray_ack&&gray_match&&n_busy&&cancel_wait==0&&cr[1]==cancel_ack;
 always @(posedge core_clk)begin
  if(core_rst)begin
   sr<=0;cr<=0;gr<=0;ra<=0;start_ack<=0;cancel_ack<=0;gray_ack<=0;result_req<=0;
   n_start<=0;n_cancel<=0;n_result_ready<=0;n_epoch<=0;start_wait<=0;cancel_wait<=0;
   result_payload<=0;result_pending<=0;result_hold<=0;
  end else begin
   sr<={sr[0],start_req};cr<={cr[0],cancel_req};gr<={gr[0],gray_req};ra<={ra[0],result_ack};
   n_start<=0;n_cancel<=0;n_result_ready<=0;
   if(cr[1]!=cancel_ack&&cancel_wait==0)begin n_cancel<=1;cancel_wait<=2;end
   else if(cancel_wait!=0)begin
    cancel_wait<=cancel_wait-1'b1;
    if(cancel_wait==1)begin cancel_ack<=cr[1];start_ack<=sr[1];start_wait<=0;end
   end else if(sr[1]!=start_ack&&!start_wait&&n_ready)begin
    n_epoch<=start_payload;n_start<=1;start_wait<=1;
   end
   if(start_wait&&n_busy)begin start_ack<=sr[1];start_wait<=0;end
   if(gr[1]!=gray_ack&&((n_gray_valid&&n_gray_ready)||
      ((!gray_match||!n_busy)&&!start_wait&&!n_start&&sr[1]==start_ack)||
      cancel_wait!=0))gray_ack<=gr[1];
   if(n_result_valid&&!result_pending&&!result_hold&&cancel_wait==0)begin
    result_payload<={n_result_epoch,n_result_scores};result_req<=!result_req;
    result_pending<=1;result_hold<=1;
   end
   if(result_pending&&ra[1]==result_req)begin
    n_result_ready<=1;result_pending<=0;
   end
   if(!n_result_valid)result_hold<=0;
  end
 end
 static11_cnn_core cnn(.clk(core_clk),.rst(core_rst),.start(n_start),.cancel(n_cancel),.epoch(n_epoch),
  .start_ready(n_ready),.busy(n_busy),.gray_valid(n_gray_valid),.gray_last(gray_payload[8]),
  .gray_data(gray_payload[7:0]),.gray_epoch(gray_payload[40:9]),.gray_ready(n_gray_ready),
  .result_valid(n_result_valid),.result_ready(n_result_ready),.result_epoch(n_result_epoch),
  .result_scores(n_result_scores),.fault(n_fault),.score_valid(),.score_class(),.score_value(),.aborted(),.error_code());
endmodule
`default_nettype wire
