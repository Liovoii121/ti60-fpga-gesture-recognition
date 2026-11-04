`timescale 1ns/1ps
// Composition of model-bound job scheduler and arithmetic engines.
// External memory clients still supply cached reads and real-B stores.
module nn_compute_core(input wire clk,nn_reset,cancel,weights_ready,memory_idle,
 input wire frame_request,sequence_request,input wire[8:0] requested_frame_index,requested_sequence_frames,
 output wire frame_ready,sequence_ready,busy,frame_done,sequence_done,fault,cache_invalidate,client_cancel,parameter_is_activation,
 output wire activation_request,output wire[31:0] activation_address,
 input wire activation_ready,activation_response,input wire[31:0] activation_data,
 input wire activation_fault,output wire activation_response_ready,
 output wire parameter_request,output wire[31:0] parameter_address,
 input wire parameter_ready,parameter_response,input wire[31:0] parameter_data,
 input wire parameter_fault,output wire parameter_response_ready,
 output wire store_request,output wire[31:0] store_address,store_data,
 input wire store_ready,store_response,store_fault);
 wire[4:0] layer_index;wire[8:0] sequence_frames;
 wire conv_start,res_start,conv_done,res_done,conv_fault,res_fault,core_cancel;
 wire conv_cancel,res_cancel;
 wire use_res=layer_index==5'd7||layer_index==5'd10||layer_index==5'd13||layer_index==5'd16||layer_index==5'd19;
wire [31:0] cfg_input_base;
wire [31:0] cfg_input_b_base;
wire [31:0] cfg_weight_base;
wire [31:0] cfg_bias_base;
wire [31:0] cfg_output_base;
wire [8:0] cfg_in_width;
wire [8:0] cfg_in_height;
wire [8:0] cfg_out_width;
wire [8:0] cfg_out_height;
wire [8:0] cfg_channels;
wire [8:0] cfg_out_channels;
wire [23:0] cfg_input_plane_words;
wire [23:0] cfg_output_plane_words;
wire [15:0] cfg_input_row_words;
wire [15:0] cfg_output_row_words;
wire [2:0] cfg_kernel_width;
wire [2:0] cfg_kernel_height;
wire [4:0] cfg_dilation_x;
wire [5:0] cfg_pad_x;
wire [5:0] cfg_pad_y;
wire cfg_stride_two;
wire cfg_depthwise;
wire cfg_pool_two;
wire cfg_relu_enable;
wire cfg_relu6_enable;
nn_job_scheduler scheduler(.clk(clk),.nn_reset(nn_reset),.cancel(cancel),.weights_ready(weights_ready),.memory_idle(memory_idle),
 .frame_request(frame_request),.sequence_request(sequence_request),.requested_frame_index(requested_frame_index),.requested_sequence_frames(requested_sequence_frames),
 .frame_ready(frame_ready),.sequence_ready(sequence_ready),.busy(busy),.core_cancel(core_cancel),.cache_invalidate(cache_invalidate),
 .convolution_done(conv_done),.convolution_fault(conv_fault),.residual_done(res_done),.residual_fault(res_fault),.convolution_start(conv_start),.residual_start(res_start),
 .frame_done(frame_done),.sequence_done(sequence_done),.fault(fault),.layer_index(layer_index),.sequence_frames(sequence_frames),
 .cfg_input_base(cfg_input_base),
 .cfg_input_b_base(cfg_input_b_base),
 .cfg_weight_base(cfg_weight_base),
 .cfg_bias_base(cfg_bias_base),
 .cfg_output_base(cfg_output_base),
 .cfg_in_width(cfg_in_width),
 .cfg_in_height(cfg_in_height),
 .cfg_out_width(cfg_out_width),
 .cfg_out_height(cfg_out_height),
 .cfg_channels(cfg_channels),
 .cfg_out_channels(cfg_out_channels),
 .cfg_input_plane_words(cfg_input_plane_words),
 .cfg_output_plane_words(cfg_output_plane_words),
 .cfg_input_row_words(cfg_input_row_words),
 .cfg_output_row_words(cfg_output_row_words),
 .cfg_kernel_width(cfg_kernel_width),
 .cfg_kernel_height(cfg_kernel_height),
 .cfg_dilation_x(cfg_dilation_x),
 .cfg_pad_x(cfg_pad_x),
 .cfg_pad_y(cfg_pad_y),
 .cfg_stride_two(cfg_stride_two),
 .cfg_depthwise(cfg_depthwise),
 .cfg_pool_two(cfg_pool_two),
 .cfg_relu_enable(cfg_relu_enable),
 .cfg_relu6_enable(cfg_relu6_enable));
wire car,cpr,csr,carr,cprr;wire[31:0] caa,cpa,csa,csd;
wire rar,rpr,rsr,rarr,rprr;wire[31:0] raa,rpa,rsa,rsd;
assign parameter_is_activation=use_res;
 assign client_cancel=core_cancel||(use_res?res_cancel:conv_cancel);
 assign activation_request=use_res?rar:car;assign activation_address=use_res?raa:caa;
 assign activation_response_ready=use_res?rarr:carr;
 assign parameter_request=use_res?rpr:cpr;assign parameter_address=use_res?rpa:cpa;
 assign parameter_response_ready=use_res?rprr:cprr;
 assign store_request=use_res?rsr:csr;assign store_address=use_res?rsa:csa;assign store_data=use_res?rsd:csd;
nn_layer_engine #(.MODEL_ADDRESSING(1),.WEIGHT_BITS(18)) convolution(.clk(clk),.rst(nn_reset),.cancel(cancel),.start(conv_start),.memory_idle(memory_idle),
 .done(conv_done),.fault(conv_fault),.memory_cancel(conv_cancel),
 .input_base(cfg_input_base),
 .weight_base(cfg_weight_base),
 .bias_base(cfg_bias_base),
 .output_base(cfg_output_base),
 .in_width(cfg_in_width),
 .in_height(cfg_in_height),
 .out_width(cfg_out_width),
 .out_height(cfg_out_height),
 .channels(cfg_channels),
 .out_channels(cfg_out_channels),
 .input_plane_words(cfg_input_plane_words),
 .output_plane_words(cfg_output_plane_words),
 .input_row_words(cfg_input_row_words),
 .output_row_words(cfg_output_row_words),
 .kernel_width(cfg_kernel_width),
 .kernel_height(cfg_kernel_height),
 .dilation_x(cfg_dilation_x),
 .pad_x(cfg_pad_x),
 .pad_y(cfg_pad_y),
 .stride_two(cfg_stride_two),
 .depthwise(cfg_depthwise),
 .pool_two(cfg_pool_two),
 .relu_enable(cfg_relu_enable),
 .relu6_enable(cfg_relu6_enable),
 .activation_request(car),.activation_address(caa),.activation_ready(activation_ready),.activation_response(activation_response&&!use_res),.activation_data(activation_data),.activation_fault(activation_fault),.activation_response_ready(carr),
 .parameter_request(cpr),.parameter_address(cpa),.parameter_ready(parameter_ready),.parameter_response(parameter_response&&!use_res),.parameter_data(parameter_data),.parameter_fault(parameter_fault),.parameter_response_ready(cprr),
 .store_request(csr),.store_address(csa),.store_data(csd),.store_ready(store_ready),.store_response(store_response&&!use_res),.store_fault(store_fault));
nn_residual_engine #(.MODEL_ADDRESSING(1)) residual(.clk(clk),.rst(nn_reset),.cancel(cancel),.start(res_start),.memory_idle(memory_idle),
 .input_a_base(cfg_input_base),.input_b_base(cfg_input_b_base),.output_base(cfg_output_base),.frames(sequence_frames),.channels(cfg_out_channels),.plane_words(cfg_output_plane_words[15:0]),
 .done(res_done),.fault(res_fault),.memory_cancel(res_cancel),
 
 .activation_request(rar),.activation_address(raa),.activation_ready(activation_ready),.activation_response(activation_response&&use_res),.activation_data(activation_data),.activation_fault(activation_fault),.activation_response_ready(rarr),
 .parameter_request(rpr),.parameter_address(rpa),.parameter_ready(parameter_ready),.parameter_response(parameter_response&&use_res),.parameter_data(parameter_data),.parameter_fault(parameter_fault),.parameter_response_ready(rprr),
 .store_request(rsr),.store_address(rsa),.store_data(rsd),.store_ready(store_ready),.store_response(store_response&&use_res),.store_fault(store_fault));
endmodule
