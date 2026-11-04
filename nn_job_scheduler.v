`timescale 1ns/1ps
// Online CNN frame jobs (five layers), then offline temporal sequence jobs.
// A frame may be offered only after its Q16 input has been stored to0x00840000.
// Cache invalidation happens between layers AFTER real writes have completed.
// nn_reset/cancel cancel clients, never reset the DDR transaction ownership.
module nn_job_scheduler(input wire clk,nn_reset,cancel,weights_ready,memory_idle,
 input wire frame_request,sequence_request,input wire[8:0] requested_frame_index,requested_sequence_frames,
 output wire frame_ready,sequence_ready,busy,core_cancel,cache_invalidate,
 input wire convolution_done,convolution_fault,residual_done,residual_fault,
 output wire convolution_start,residual_start,
 output reg frame_done,sequence_done,fault,
 output wire[4:0] layer_index,output wire[8:0] sequence_frames,
 output reg [31:0] cfg_input_base,
 output reg [31:0] cfg_input_b_base,
 output reg [31:0] cfg_weight_base,
 output reg [31:0] cfg_bias_base,
 output reg [31:0] cfg_output_base,
 output reg [8:0] cfg_in_width,
 output reg [8:0] cfg_in_height,
 output reg [8:0] cfg_out_width,
 output reg [8:0] cfg_out_height,
 output reg [8:0] cfg_channels,
 output reg [8:0] cfg_out_channels,
 output reg [23:0] cfg_input_plane_words,
 output reg [23:0] cfg_output_plane_words,
 output reg [15:0] cfg_input_row_words,
 output reg [15:0] cfg_output_row_words,
 output reg [2:0] cfg_kernel_width,
 output reg [2:0] cfg_kernel_height,
 output reg [4:0] cfg_dilation_x,
 output reg [5:0] cfg_pad_x,
 output reg [5:0] cfg_pad_y,
 output reg cfg_stride_two,
 output reg cfg_depthwise,
 output reg cfg_pool_two,
 output reg cfg_relu_enable,
 output reg cfg_relu6_enable);
 localparam IDLE=0,INVALIDATE=1,WAIT_IDLE=2,LAUNCH=3,WAIT_LAYER=4,COMPLETE=5,ERROR=6;
 reg[2:0] state;reg[4:0] step;
 reg[8:0] frame_index,nframes;reg sequence_active,residual_operation;
 assign layer_index=step;assign sequence_frames=nframes;
 assign busy=state!=IDLE;assign core_cancel=nn_reset||cancel||fault;
 assign sequence_ready=state==IDLE&&weights_ready&&memory_idle&&!nn_reset&&!cancel;
 assign frame_ready=sequence_ready&&!sequence_request;
 assign cache_invalidate=state==INVALIDATE;
 assign convolution_start=state==LAUNCH&&!residual_operation&&!core_cancel;
 assign residual_start=state==LAUNCH&&residual_operation&&!core_cancel;
 always @*begin
 cfg_input_base=({32{(step==5'd0 || step==5'd2 || step==5'd4)}} & (32'd8650752)) | ({32{(step==5'd1 || step==5'd3)}} & (32'd8716288)) | ({32{(step==5'd5 || step==5'd7 || step==5'd9 || step==5'd11 || step==5'd13 || step==5'd15 || step==5'd17 || step==5'd19)}} & (32'd8519680)) | ({32{(step==5'd6 || step==5'd8 || step==5'd10 || step==5'd12 || step==5'd14 || step==5'd16 || step==5'd18 || step==5'd20)}} & (32'd8585216));
 cfg_input_b_base=({32{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd3 || step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (32'd8781824));
 cfg_weight_base=({32{(step==5'd0)}} & (32'd8388608)) | ({32{(step==5'd1)}} & (32'd8388928)) | ({32{(step==5'd2)}} & (32'd8392432)) | ({32{(step==5'd4)}} & (32'd8399408)) | ({32{(step==5'd5)}} & (32'd8448752)) | ({32{(step==5'd6)}} & (32'd8449520)) | ({32{(step==5'd8)}} & (32'd8458928)) | ({32{(step==5'd9)}} & (32'd8459696)) | ({32{(step==5'd11)}} & (32'd8469104)) | ({32{(step==5'd12)}} & (32'd8469872)) | ({32{(step==5'd14)}} & (32'd8479280)) | ({32{(step==5'd15)}} & (32'd8480048)) | ({32{(step==5'd17)}} & (32'd8489456)) | ({32{(step==5'd18)}} & (32'd8490224)) | ({32{(step==5'd20)}} & (32'd8499632));
 cfg_bias_base=({32{(step==5'd0)}} & (32'd8388896)) | ({32{(step==5'd1)}} & (32'd8392384)) | ({32{(step==5'd2)}} & (32'd8399344)) | ({32{(step==5'd4)}} & (32'd8448560)) | ({32{(step==5'd5)}} & (32'd8449328)) | ({32{(step==5'd6)}} & (32'd8458736)) | ({32{(step==5'd8)}} & (32'd8459504)) | ({32{(step==5'd9)}} & (32'd8468912)) | ({32{(step==5'd11)}} & (32'd8469680)) | ({32{(step==5'd12)}} & (32'd8479088)) | ({32{(step==5'd14)}} & (32'd8479856)) | ({32{(step==5'd15)}} & (32'd8489264)) | ({32{(step==5'd17)}} & (32'd8490032)) | ({32{(step==5'd18)}} & (32'd8499440)) | ({32{(step==5'd20)}} & (32'd8500784));
 cfg_output_base=({32{(step==5'd0 || step==5'd2)}} & (32'd8716288)) | ({32{(step==5'd1 || step==5'd3)}} & (32'd8650752)) | ({32{(step==5'd4)}} & (32'h00820000+({23'd0,frame_index}<<2))) | ({32{(step==5'd5 || step==5'd7 || step==5'd11 || step==5'd13 || step==5'd17 || step==5'd19)}} & (32'd8585216)) | ({32{(step==5'd6 || step==5'd9 || step==5'd12 || step==5'd15 || step==5'd18 || step==5'd20)}} & (32'd8781824)) | ({32{(step==5'd8 || step==5'd10 || step==5'd14 || step==5'd16)}} & (32'd8519680));
 cfg_in_width=({9{(step==5'd0)}} & (9'd64)) | ({9{(step==5'd1)}} & (9'd32)) | ({9{(step==5'd2)}} & (9'd16)) | ({9{(step==5'd3)}} & (9'd8)) | ({9{(step==5'd4)}} & (9'd1)) | ({9{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (nframes));
 cfg_in_height=({9{(step==5'd0)}} & (9'd64)) | ({9{(step==5'd1)}} & (9'd32)) | ({9{(step==5'd2)}} & (9'd16)) | ({9{(step==5'd3)}} & (9'd8)) | ({9{(step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (9'd1));
 cfg_out_width=({9{(step==5'd0)}} & (9'd32)) | ({9{(step==5'd1)}} & (9'd16)) | ({9{(step==5'd2)}} & (9'd8)) | ({9{(step==5'd3)}} & (9'd4)) | ({9{(step==5'd4)}} & (9'd1)) | ({9{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (nframes));
 cfg_out_height=({9{(step==5'd0)}} & (9'd32)) | ({9{(step==5'd1)}} & (9'd16)) | ({9{(step==5'd2)}} & (9'd8)) | ({9{(step==5'd3)}} & (9'd4)) | ({9{(step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (9'd1));
 cfg_channels=({9{(step==5'd0)}} & (9'd1)) | ({9{(step==5'd1)}} & (9'd8)) | ({9{(step==5'd2)}} & (9'd12)) | ({9{(step==5'd3)}} & (9'd16)) | ({9{(step==5'd4)}} & (9'd256)) | ({9{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (9'd48));
 cfg_out_channels=({9{(step==5'd0)}} & (9'd8)) | ({9{(step==5'd1)}} & (9'd12)) | ({9{(step==5'd2 || step==5'd3)}} & (9'd16)) | ({9{(step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19)}} & (9'd48)) | ({9{(step==5'd20)}} & (9'd6));
 cfg_input_plane_words=({24{(step==5'd0)}} & (24'd4096)) | ({24{(step==5'd1)}} & (24'd1024)) | ({24{(step==5'd2)}} & (24'd256)) | ({24{(step==5'd3)}} & (24'd64)) | ({24{(step==5'd4)}} & (24'd1)) | ({24{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (24'd310));
 cfg_output_plane_words=({24{(step==5'd0)}} & (24'd1024)) | ({24{(step==5'd1)}} & (24'd256)) | ({24{(step==5'd2)}} & (24'd64)) | ({24{(step==5'd3)}} & (24'd16)) | ({24{(step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (24'd310));
 cfg_input_row_words=({16{(step==5'd0)}} & (16'd64)) | ({16{(step==5'd1)}} & (16'd32)) | ({16{(step==5'd2)}} & (16'd16)) | ({16{(step==5'd3)}} & (16'd8)) | ({16{(step==5'd4)}} & (16'd1)) | ({16{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (16'd310));
 cfg_output_row_words=({16{(step==5'd0)}} & (16'd32)) | ({16{(step==5'd1)}} & (16'd16)) | ({16{(step==5'd2)}} & (16'd8)) | ({16{(step==5'd3)}} & (16'd4)) | ({16{(step==5'd4)}} & (16'd1)) | ({16{(step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (16'd310));
 cfg_kernel_width=({3{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd5 || step==5'd8 || step==5'd11 || step==5'd14 || step==5'd17)}} & (3'd3)) | ({3{(step==5'd3)}} & (3'd2)) | ({3{(step==5'd4 || step==5'd6 || step==5'd7 || step==5'd9 || step==5'd10 || step==5'd12 || step==5'd13 || step==5'd15 || step==5'd16 || step==5'd18 || step==5'd19 || step==5'd20)}} & (3'd1));
 cfg_kernel_height=({3{(step==5'd0 || step==5'd1 || step==5'd2)}} & (3'd3)) | ({3{(step==5'd3)}} & (3'd2)) | ({3{(step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd8 || step==5'd9 || step==5'd10 || step==5'd11 || step==5'd12 || step==5'd13 || step==5'd14 || step==5'd15 || step==5'd16 || step==5'd17 || step==5'd18 || step==5'd19 || step==5'd20)}} & (3'd1));
 cfg_dilation_x=({5{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd3 || step==5'd4 || step==5'd5 || step==5'd6 || step==5'd7 || step==5'd9 || step==5'd10 || step==5'd12 || step==5'd13 || step==5'd15 || step==5'd16 || step==5'd18 || step==5'd19 || step==5'd20)}} & (5'd1)) | ({5{(step==5'd8)}} & (5'd2)) | ({5{(step==5'd11)}} & (5'd4)) | ({5{(step==5'd14)}} & (5'd8)) | ({5{(step==5'd17)}} & (5'd16));
 cfg_pad_x=({6{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd5)}} & (6'd1)) | ({6{(step==5'd8)}} & (6'd2)) | ({6{(step==5'd11)}} & (6'd4)) | ({6{(step==5'd14)}} & (6'd8)) | ({6{(step==5'd17)}} & (6'd16));
 cfg_pad_y=({6{(step==5'd0 || step==5'd1 || step==5'd2)}} & (6'd1));
 cfg_stride_two=({1{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd3)}} & (1'd1));
 cfg_depthwise=({1{(step==5'd3 || step==5'd5 || step==5'd8 || step==5'd11 || step==5'd14 || step==5'd17)}} & (1'd1));
 cfg_pool_two=({1{(step==5'd3)}} & (1'd1));
 cfg_relu_enable=({1{(step==5'd0 || step==5'd1 || step==5'd2 || step==5'd4)}} & (1'd1));
 cfg_relu6_enable=({1{(step==5'd6 || step==5'd9 || step==5'd12 || step==5'd15 || step==5'd18)}} & (1'd1));
 residual_operation=({1{(step==5'd7 || step==5'd10 || step==5'd13 || step==5'd16 || step==5'd19)}} & (1'd1));
 end

 always @(posedge clk)begin
 frame_done<=0;sequence_done<=0;
 if(nn_reset)begin state<=IDLE;fault<=0;step<=0;frame_index<=0;nframes<=0;sequence_active<=0;end
 else if(cancel)begin state<=IDLE;end
 else case(state)
  IDLE:begin
   if(sequence_request&&sequence_ready)begin
    fault<=0;sequence_active<=1;nframes<=requested_sequence_frames;step<=5;
    state<=(requested_sequence_frames==0||requested_sequence_frames>310)?ERROR:INVALIDATE;
   end else if(frame_request&&frame_ready)begin
    fault<=0;sequence_active<=0;frame_index<=requested_frame_index;step<=0;
    state<=requested_frame_index>=310?ERROR:INVALIDATE;
   end
  end
  INVALIDATE:state<=WAIT_IDLE;
  WAIT_IDLE:if(memory_idle)state<=LAUNCH;
  LAUNCH:state<=WAIT_LAYER;
  WAIT_LAYER:if(residual_operation?residual_done:convolution_done)begin
   if(residual_operation?residual_fault:convolution_fault)state<=ERROR;
   else if((!sequence_active&&step==4)||(sequence_active&&step==20))state<=COMPLETE;
   else begin step<=step+1'b1;state<=INVALIDATE;end
  end
  COMPLETE:begin if(sequence_active)sequence_done<=1;else frame_done<=1;state<=IDLE;end
  ERROR:begin fault<=1;if(sequence_active)sequence_done<=1;else frame_done<=1;state<=IDLE;end
  default:state<=ERROR;
 endcase
 end
endmodule
