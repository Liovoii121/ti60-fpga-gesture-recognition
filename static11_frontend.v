`timescale 1ns/1ps
`default_nettype none
// All ports are clk_pixel74.4MHz. D connects static11_cnn_core at gray boundary.
module static11_frontend #(
 parameter integer READ_TIMEOUT_CYCLES=1024,MIN_SCORE=-128,MIN_MARGIN=256
)(
 input wire clk,rst,model_ready,key_valid,input wire [3:0] key_code,
 input wire vs,de,frame_quality,input wire [15:0] x,y,input wire [31:0] pixel_rgb565,
 output wire [13:0] ui_control,output wire fault,busy,
 output wire [31:0] epoch,output wire [6:0] window_id,best_window,
 output wire snapshot_locked,snapshot_quality,output wire [31:0] snapshot_frame,
 output wire engine_start,engine_cancel,input wire engine_ready,engine_idle,engine_fault,
 output wire gray_valid,gray_last,output wire [7:0] gray_data,
 output wire [31:0] gray_epoch,input wire gray_ready,
 input wire result_valid,input wire [31:0] result_epoch,input wire [223:0] result_scores,
 output wire result_ready,scan_done,output wire [4:0] candidate,
 output wire signed [7:0] best_score,output wire signed [8:0] margin
);
 reg vs_q;
 always @(posedge clk)if(rst)vs_q<=1;else vs_q<=vs;
 wire frame_start=vs&&!vs_q&&!de,frame_end=!vs&&vs_q&&!de;
 wire snapshot_request,snapshot_cancel,snapshot_release,snapshot_ready,snapshot_done;
 wire [31:0] snapshot_epoch;
 wire pre_ready,pre_busy,pre_error;
 wire job_cancel,job_start,pre_gray_valid;
 wire cancel_now=key_valid&&key_code==12;
 assign engine_cancel=job_cancel||fault||cancel_now;
 assign engine_start=job_start&&!rst&&!engine_cancel&&!fault;
 assign gray_valid=pre_gray_valid&&!rst&&!engine_cancel&&!fault&&gray_epoch==epoch;
 wire read_request,read_ready,read_valid,response_ready;
 wire [15:0] read_address,read_data;
 wire [31:0] read_epoch;
 wire bank_read,bank_valid;wire [15:0] bank_data;
 reg read_pending,response_valid,reader_fault,fatal_fault;
 reg [15:0] response_data;reg [31:0] response_epoch;
 // Core cancel clears its fault; the job's fatal state requires common reset.
 // Preserve immediate combinational gates and keep diagnostics aligned with it.
 assign fault=fatal_fault||engine_fault||pre_error||reader_fault;
 always @(posedge clk)begin
  if(rst)fatal_fault<=0;
  else if(engine_fault||pre_error||reader_fault)fatal_fault<=1;
 end
 assign read_ready=snapshot_locked&&snapshot_quality&&!read_pending&&!response_valid&&!rst&&!engine_cancel;
 assign bank_read=read_request&&read_ready;
 assign read_valid=response_valid&&!rst;
 assign read_data=response_data;
 always @(posedge clk)begin
  if(rst)begin read_pending<=0;response_valid<=0;reader_fault<=0;response_data<=0;response_epoch<=0;end
  else begin
   if(bank_read)begin read_pending<=1;response_epoch<=read_epoch;end
   if(bank_valid)begin
    if(!read_pending||response_valid)reader_fault<=1;
    else begin response_valid<=1;response_data<=bank_data;read_pending<=0;end
   end
   if(response_valid&&response_ready)response_valid<=0;
  end
 end
 static11_window_snapshot snapshot(
  .clk(clk),.rst(rst),.request(snapshot_request),.cancel(snapshot_cancel),.release_bank(snapshot_release),
  .epoch(epoch),.window_id(window_id),.frame_start(frame_start),.frame_end(frame_end),.de(de),
  .frame_quality(frame_quality),.x(x),.y(y),.pixel_rgb565(pixel_rgb565),.request_ready(snapshot_ready),
  .done(snapshot_done),.locked(snapshot_locked),.quality(snapshot_quality),.snapshot_epoch(snapshot_epoch),
  .frame_id(snapshot_frame),.snapshot_window(),.reason(),.read_enable(bank_read),
  .read_address(read_address),.read_data(bank_data),.read_valid(bank_valid));
 static5_rgb565_gray64 #(.READ_TIMEOUT_CYCLES(READ_TIMEOUT_CYCLES)) preprocess(
  .clk(clk),.rst(rst),.start(engine_start),.cancel(engine_cancel),.epoch(epoch),
  .source_width(9'd128),.source_height(9'd128),.start_ready(pre_ready),.busy(pre_busy),
  .source_read_request(read_request),.source_read_ready(read_ready),.source_read_address(read_address),
  .source_read_epoch(read_epoch),.source_read_valid(read_valid),.source_read_data(read_data),
  .source_response_epoch(response_epoch),.source_response_ready(response_ready),
  .gray_valid(pre_gray_valid),.gray_last(gray_last),.gray_data(gray_data),.gray_epoch(gray_epoch),
  .gray_ready(gray_ready),.done(),.aborted(),.error(pre_error),.error_code());
 static11_job_control #(.MIN_SCORE(MIN_SCORE),.MIN_MARGIN(MIN_MARGIN)) job(
  .clk(clk),.rst(rst),.model_ready(model_ready),.fault(fault),.key_valid(key_valid),.key_code(key_code),
  .snapshot_ready(snapshot_ready&&!read_pending&&!response_valid),.snapshot_done(snapshot_done),
  .snapshot_quality(snapshot_quality),.snapshot_epoch(snapshot_epoch),
  .engine_ready(engine_ready&&pre_ready),.engine_idle(engine_idle&&pre_ready&&!pre_busy&&!read_pending&&!response_valid),
  .engine_result_valid(result_valid),.engine_result_epoch(result_epoch),.engine_result_scores(result_scores),
  .snapshot_request(snapshot_request),.snapshot_cancel(snapshot_cancel),.snapshot_release(snapshot_release),
  .engine_start(job_start),.engine_cancel(job_cancel),.engine_result_ready(result_ready),
  .epoch(epoch),.snapshot_window_id(window_id),.busy(busy),.ui_control(ui_control),.candidate(candidate),
  .best_score(best_score),.margin(margin),.best_window(best_window),.scan_done(scan_done));
endmodule
`default_nettype wire
