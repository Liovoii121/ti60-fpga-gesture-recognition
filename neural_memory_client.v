`timescale 1ns/1ps
`default_nettype none
// Bus-domain NN memory client. LOAD is exclusive; RUN has separate P/A caches.
// All arbiters share the real bus_reset; job cancel/invalidate only drain clients.
// memory_idle is a STATE observation, deliberately independent of cancel/invalidate.
module neural_memory_client(
 input wire clk,bus_reset,ddr_ready,cancel,invalidate,
 input wire load_start,input wire [31:0] load_byte_length,load_expected_crc32,
 output wire load_start_ready,load_active,load_stream_ready,
 input wire load_stream_valid,load_stream_last,input wire [127:0] load_stream_data,
 output wire weights_ready,load_done,load_aborted,load_fault,
 output wire [2:0] load_error_code,output wire [31:0] load_bytes_written,load_observed_crc32,
 input wire param_request,param_activation_mode,input wire [31:0] param_address,
 output wire param_ready,param_response_valid,param_response_fault,
 output wire [31:0] param_response_data,input wire param_response_ready,
 input wire activation_request,input wire [31:0] activation_address,
 output wire activation_ready,activation_response_valid,activation_response_fault,
 output wire [31:0] activation_response_data,input wire activation_response_ready,
 input wire store_request,input wire [31:0] store_address,store_data,
 output wire store_ready,store_done,store_fault,store_aborted,memory_idle,
 output wire command_valid,command_write,input wire command_ready,
 output wire [31:0] command_address,output wire [7:0] command_length,
 output wire wvalid,wlast,input wire wready,output wire [127:0] wdata,
 output wire [15:0] wstrb,
 input wire [127:0] read_data,input wire read_valid,read_last,
 input wire [1:0] read_response,output wire read_ready,
 input wire bvalid,input wire [1:0] bresp,output wire bready
);
 reg loading;
 reg param_bad,activation_bad,param_holds_activation;
 wire p_idle,a_idle,s_idle,l_busy,l_ready,l_loaded;
 wire arb_reads_active,arb_run_active;
 wire p_word_ready,a_word_ready,s_word_ready,s_done,s_fault,s_aborted;
 wire load_accept;
 wire p_valid,a_valid,p_fault,a_fault;wire [31:0]p_data,a_data;
 wire p_cmd,a_cmd,s_cmd;wire[31:0]p_addr,a_addr,s_addr;wire[7:0]p_len,a_len,s_len;
 wire [1:0] pair_ready,pair_rvalid,pair_rlast;wire[3:0]pair_rresp;
 wire p_rready,a_rready;
 wire pair_cmd,pair_write,pair_wvalid,pair_wlast,pair_rready,pair_bready;
 wire [31:0]pair_addr;wire[7:0]pair_len;wire[127:0]pair_wdata;wire[15:0]pair_wstrb;
 wire run_cmd,run_write,run_wvalid,run_wlast,run_rready,run_bready;
 wire [31:0]run_addr;wire[7:0]run_len;wire[127:0]run_wdata;wire[15:0]run_wstrb;
 wire [1:0] run_qready,run_wready,run_rvalid,run_rlast,run_bvalid;
 wire [3:0] run_rresp,run_bresp;
 wire s_wvalid,s_wlast,s_bready;wire[127:0]s_wdata;wire[15:0]s_wstrb;
 wire l_cmd,l_wvalid,l_wlast,l_bready;wire[31:0]l_addr;wire[7:0]l_len;wire[127:0]l_wdata;wire[15:0]l_wstrb;
 wire loader_done;
 wire p_range=param_address[1:0]==0&&(param_activation_mode?
 (param_address>=32'h00820000&&param_address<32'h00880000):
 (param_address>=32'h00800000&&param_address<32'h00820000));
 wire a_range=activation_address>=32'h00820000&&activation_address<32'h00880000&&activation_address[1:0]==0;
 wire p_act_context=param_activation_mode||param_holds_activation;
 wire p_invalidate=invalidate||loading||(s_done&&p_act_context);
 wire a_invalidate=invalidate||loading||s_done;
 wire responses_allowed=!loading&&!cancel&&!invalidate&&!bus_reset;
 // Holding load_start while RUN drains must NOT suppress old responses.
 wire new_run_allowed=responses_allowed&&l_loaded&&!l_busy&&!load_start;
 assign memory_idle=!loading&&!l_busy&&p_idle&&a_idle&&s_idle&&!arb_reads_active&&!arb_run_active&&!param_bad&&!activation_bad&&!s_done;
 assign load_start_ready=memory_idle&&l_ready&&ddr_ready&&!cancel&&!invalidate&&!bus_reset;
 assign load_accept=load_start&&load_start_ready;
 assign load_active=loading;
 assign weights_ready=l_loaded&&!loading;
 assign load_done=loader_done;
 assign param_ready=new_run_allowed&&p_word_ready&&!param_bad&&
 (!param_activation_mode||(s_idle&&!s_done&&!store_request));
 assign activation_ready=new_run_allowed&&a_word_ready&&!activation_bad&&s_idle&&!s_done&&!store_request;
 assign param_response_valid=responses_allowed&&(param_bad||p_valid);
 assign activation_response_valid=responses_allowed&&(activation_bad||a_valid);
 assign param_response_data=param_bad?32'd0:p_data;
 assign activation_response_data=activation_bad?32'd0:a_data;
 assign param_response_fault=param_bad||p_fault;
 assign activation_response_fault=activation_bad||a_fault;
 // Wait until prior activation response is consumed before accepting a store.
 assign store_ready=new_run_allowed&&s_word_ready&&a_idle&&!activation_bad&&!s_done&&
 (!p_act_context||(p_idle&&!param_bad));
 assign store_done=s_done&&!loading&&!bus_reset;
 assign store_fault=s_fault;
 assign store_aborted=s_aborted;
 always @(posedge clk)begin
  if(bus_reset)begin loading<=0;param_bad<=0;activation_bad<=0;param_holds_activation<=0;end
  else begin
   if(load_accept)loading<=1;
   else if(loading&&!l_busy)loading<=0;
   if(cancel||invalidate||loading)begin param_bad<=0;activation_bad<=0;param_holds_activation<=0;end
   else begin
    if(param_bad&&param_response_ready)param_bad<=0;
    if(activation_bad&&activation_response_ready)activation_bad<=0;
    if(param_request&&param_ready&&!p_range)param_bad<=1;
    if(param_request&&param_ready&&p_range)param_holds_activation<=param_activation_mode;
    if(activation_request&&activation_ready&&!a_range)activation_bad<=1;
   end
  end
 end
 nn_compact_word_cache param_cache(.clk(clk),.bus_reset(bus_reset),.cancel(cancel),.invalidate(p_invalidate),
 .word_request(param_request&&param_ready&&p_range),.word_address(param_address),.word_ready(p_word_ready),.idle(p_idle),
 .response_valid(p_valid),.response_ready(param_response_ready&&responses_allowed&&!param_bad),.response_data(p_data),.response_fault(p_fault),
 .command_valid(p_cmd),.command_ready(pair_ready[0]),.command_address(p_addr),.command_length(p_len),
 .read_data(read_data),.read_valid(pair_rvalid[0]),.read_last(pair_rlast[0]),.read_response(pair_rresp[1:0]),.read_ready(p_rready));
 nn_compact_word_cache activation_cache(.clk(clk),.bus_reset(bus_reset),.cancel(cancel),.invalidate(a_invalidate),
 .word_request(activation_request&&activation_ready&&a_range),.word_address(activation_address),.word_ready(a_word_ready),.idle(a_idle),
 .response_valid(a_valid),.response_ready(activation_response_ready&&responses_allowed&&!activation_bad),.response_data(a_data),.response_fault(a_fault),
 .command_valid(a_cmd),.command_ready(pair_ready[1]),.command_address(a_addr),.command_length(a_len),
 .read_data(read_data),.read_valid(pair_rvalid[1]),.read_last(pair_rlast[1]),.read_response(pair_rresp[3:2]),.read_ready(a_rready));
 ddr_word_writer writer(.clk(clk),.bus_reset(bus_reset),.cancel(cancel),
 .word_request(store_request&&store_ready),.word_address(store_address),.word_data(store_data),.word_ready(s_word_ready),.idle(s_idle),.done(s_done),.fault(s_fault),.aborted(s_aborted),
 .command_valid(s_cmd),.command_ready(run_qready[1]),.command_address(s_addr),.command_length(s_len),.command_write(),
 .wvalid(s_wvalid),.wlast(s_wlast),.wready(run_wready[1]),.wdata(s_wdata),.wstrb(s_wstrb),
 .bvalid(run_bvalid[1]),.bresp(run_bresp[3:2]),.bready(s_bready));
 ddr_transaction_arbiter read_pair(.clk(clk),.rst(bus_reset),.ddr_ready(ddr_ready&&!loading),
 .req_valid({a_cmd,p_cmd}),.req_write(2'b00),.req_ready(pair_ready),.req_addr({a_addr,p_addr}),.req_len({a_len,p_len}),.req_id(16'd0),
 .client_wdata(256'd0),.client_wstrb(32'd0),.client_wvalid(2'b00),.client_wlast(2'b00),.client_wready(),
 .client_rdata(),.client_rvalid(pair_rvalid),.client_rlast(pair_rlast),.client_rready({a_rready,p_rready}),.client_rresp(pair_rresp),.client_bresp(),.client_bvalid(),.client_bready(2'b00),
 .ddr_addr(pair_addr),.ddr_len(pair_len),.ddr_id(),.ddr_write(pair_write),.ddr_avalid(pair_cmd),.ddr_aready(run_qready[0]),
 .ddr_wdata(pair_wdata),.ddr_wstrb(pair_wstrb),.ddr_wvalid(pair_wvalid),.ddr_wlast(pair_wlast),.ddr_wready(run_wready[0]),
 .ddr_rdata(read_data),.ddr_rvalid(run_rvalid[0]),.ddr_rlast(run_rlast[0]),.ddr_rresp(run_rresp[1:0]),.ddr_bresp(run_bresp[1:0]),.ddr_bvalid(run_bvalid[0]),.ddr_rready(pair_rready),.ddr_bready(pair_bready),.transaction_active(arb_reads_active));
 ddr_transaction_arbiter run_mux(.clk(clk),.rst(bus_reset),.ddr_ready(ddr_ready&&!loading),
 .req_valid({s_cmd,pair_cmd}),.req_write({1'b1,pair_write}),.req_ready(run_qready),.req_addr({s_addr,pair_addr}),.req_len({s_len,pair_len}),.req_id(16'd0),
 .client_wdata({s_wdata,pair_wdata}),.client_wstrb({s_wstrb,pair_wstrb}),.client_wvalid({s_wvalid,pair_wvalid}),.client_wlast({s_wlast,pair_wlast}),.client_wready(run_wready),
 .client_rdata(),.client_rvalid(run_rvalid),.client_rlast(run_rlast),.client_rready({1'b0,pair_rready}),.client_rresp(run_rresp),.client_bresp(run_bresp),.client_bvalid(run_bvalid),.client_bready({s_bready,pair_bready}),
 .ddr_addr(run_addr),.ddr_len(run_len),.ddr_id(),.ddr_write(run_write),.ddr_avalid(run_cmd),.ddr_aready(command_ready&&!loading),
 .ddr_wdata(run_wdata),.ddr_wstrb(run_wstrb),.ddr_wvalid(run_wvalid),.ddr_wlast(run_wlast),.ddr_wready(wready&&!loading),
 .ddr_rdata(read_data),.ddr_rvalid(read_valid&&!loading),.ddr_rlast(read_last),.ddr_rresp(read_response),.ddr_bresp(bresp),.ddr_bvalid(bvalid&&!loading),.ddr_rready(run_rready),.ddr_bready(run_bready),.transaction_active(arb_run_active));
 ddr_weight_stream_loader loader(.clk(clk),.bus_reset(bus_reset),.ddr_ready(ddr_ready),.start(load_accept),.cancel(cancel),
 .byte_length(load_byte_length),.expected_crc32(load_expected_crc32),.start_ready(l_ready),.busy(l_busy),
 .stream_valid(load_stream_valid&&loading),.stream_last(load_stream_last),.stream_data(load_stream_data),.stream_ready(load_stream_ready),
 .req_valid(l_cmd),.req_write(),.req_ready(command_ready&&loading),.req_address(l_addr),.req_length(l_len),
 .wvalid(l_wvalid),.wlast(l_wlast),.wready(wready&&loading),.wdata(l_wdata),.wstrb(l_wstrb),
 .bvalid(bvalid&&loading),.bresp(bresp),.bready(l_bready),.weights_ready(l_loaded),.done(loader_done),.aborted(load_aborted),.fault(load_fault),.error_code(load_error_code),.bytes_received(),.bytes_written(load_bytes_written),.observed_crc32(load_observed_crc32));
 assign command_valid=loading?l_cmd:run_cmd;
 assign command_write=loading?1'b1:run_write;
 assign command_address=loading?l_addr:run_addr;
 assign command_length=loading?l_len:run_len;
 assign wvalid=loading?l_wvalid:run_wvalid;
 assign wlast=loading?l_wlast:run_wlast;
 assign wdata=loading?l_wdata:run_wdata;
 assign wstrb=loading?l_wstrb:run_wstrb;
 assign read_ready=!loading&&run_rready;
 assign bready=loading?l_bready:run_bready;
endmodule
`default_nettype wire
