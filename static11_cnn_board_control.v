`timescale 1ns/1ps
`default_nettype none
// B owns fixed640 raster/snapshot/preprocess/drain and one-result aggregation. C owns the CNN.
// This wrapper preserves the validated board tap and diagnostic port widths.
module static11_cnn_board_control #(
 parameter integer MIN_SCORE=-128,MIN_MARGIN=256,USE_CDC=0
)(
 input wire clk,core_clk,rst,model_ready,key_valid,
 input wire [3:0] key_code,
 input wire vs,de,frame_quality,
 input wire [15:0] x,y,input wire [31:0] pixel_rgb565,
 output wire [13:0] ui_control,
 output wire fault,busy,
 output wire [31:0] epoch,
 output wire snapshot_locked,snapshot_quality,
 output wire [31:0] snapshot_frame,
 output wire [4:0] candidate,
 output wire result_valid,
 output reg [31:0] result_epoch,
 output wire signed [63:0] best_score,
 output wire [64:0] margin
);
 wire engine_start,engine_cancel,core_ready,core_busy,core_fault;
 wire gray_valid,gray_last,gray_ready;
 wire [7:0] gray_data;
 wire [31:0] gray_epoch;
 wire raw_result_valid,result_ready,scan_done;
 wire [31:0] core_result_epoch;
 reg final_result_valid;
 wire [223:0] result_scores;
 wire signed [7:0] sweep_score;
 wire signed [8:0] sweep_margin;
 wire cancel_key=key_valid&&key_code==4'd12;
 // These idle keys replace the displayed aggregate on the same edge. Do not
 // register the preceding job's completion against those cleared fields.
 wire replace_result_key=key_valid&&model_ready&&!busy&&
  (key_code==4'd3||key_code==4'd7||key_code==4'd11);
 wire live=!rst&&!cancel_key&&!engine_cancel&&!fault&&core_result_epoch==epoch;
 wire core_result_valid=raw_result_valid&&live;
 // One board result per fixed640 capture/inference, with matching final epoch and aggregate.
 // Invalid-raster completion is represented by candidate31 and quality0.
 assign result_valid=final_result_valid&&!rst&&!cancel_key&&!replace_result_key&&!engine_cancel&&!fault&&result_epoch==epoch;
 always @(posedge clk)begin
  if(rst)begin final_result_valid<=0;result_epoch<=0;end
  else begin
   final_result_valid<=scan_done&&!cancel_key&&!replace_result_key&&!engine_cancel&&!fault;
   if(scan_done&&!cancel_key&&!replace_result_key&&!engine_cancel&&!fault)result_epoch<=epoch;
  end
 end
 assign best_score={{56{sweep_score[7]}},sweep_score};
 // Diagnostic margin remains65 bits; interpret this field as signed two's complement.
 assign margin={{56{sweep_margin[8]}},sweep_margin};
 static11_frontend #(.MIN_SCORE(MIN_SCORE),.MIN_MARGIN(MIN_MARGIN)) frontend(
  .clk(clk),.rst(rst),.model_ready(model_ready),.key_valid(key_valid),.key_code(key_code),
  .vs(vs),.de(de),.frame_quality(frame_quality),.x(x),.y(y),.pixel_rgb565(pixel_rgb565),
  .ui_control(ui_control),.fault(fault),.busy(busy),.epoch(epoch),.window_id(),.best_window(),.scan_done(scan_done),
  .snapshot_locked(snapshot_locked),.snapshot_quality(snapshot_quality),.snapshot_frame(snapshot_frame),
  .engine_start(engine_start),.engine_cancel(engine_cancel),.engine_ready(core_ready&&!core_fault),
  .engine_idle(core_ready&&!core_busy),.engine_fault(core_fault),
  .gray_valid(gray_valid),.gray_last(gray_last),.gray_data(gray_data),.gray_epoch(gray_epoch),.gray_ready(gray_ready),
  .result_valid(core_result_valid),.result_epoch(core_result_epoch),.result_scores(result_scores),.result_ready(result_ready),
  .candidate(candidate),.best_score(sweep_score),.margin(sweep_margin));
 generate if(USE_CDC)begin: dual_clock
 static11_cnn_cdc cnn_bridge(
  .clk(clk),.core_clk(core_clk),.rst(rst),.start(engine_start&&!cancel_key&&!fault),
  .cancel(cancel_key||engine_cancel||fault),.epoch(epoch),.start_ready(core_ready),.busy(core_busy),
  .gray_valid(gray_valid&&!fault&&!engine_cancel),.gray_last(gray_last),.gray_data(gray_data),
  .gray_epoch(gray_epoch),.gray_ready(gray_ready),.result_valid(raw_result_valid),
  .result_ready(result_ready&&live),.result_epoch(core_result_epoch),.result_scores(result_scores),.fault(core_fault));
 end else begin: single_clock
 static11_cnn_core cnn(
  .clk(clk),.rst(rst),.start(engine_start&&!cancel_key&&!fault),.cancel(cancel_key||engine_cancel||fault),.epoch(epoch),
  .start_ready(core_ready),.busy(core_busy),.gray_valid(gray_valid&&!fault&&!engine_cancel),
  .gray_last(gray_last),.gray_data(gray_data),.gray_epoch(gray_epoch),.gray_ready(gray_ready),
  .result_valid(raw_result_valid),.result_ready(result_ready&&live),.result_epoch(core_result_epoch),.result_scores(result_scores),
  .score_valid(),.score_class(),.score_value(),.fault(core_fault),.aborted(),.error_code());
 end endgenerate
endmodule
`default_nettype wire
