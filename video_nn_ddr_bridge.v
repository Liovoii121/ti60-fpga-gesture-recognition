`timescale 1ns/1ps
`default_nettype none
// Baseline video AW/AR mux followed by the single-outstanding owner arbiter.
// No NN address clipping: the raw clip extends through 0x009b5fff.
// Consumer must qualify shared RDATA/IDs/address with the matching valid pulse.
module video_nn_ddr_bridge #(parameter integer NN_MIN_GAP_CYCLES=1024)(
 input wire clk,rst,ddr_ready,
 input wire [3:0] video_awid,video_arid,
 input wire [31:0] video_awaddr,video_araddr,
 input wire [7:0] video_awlen,video_arlen,
 input wire video_awvalid,video_arvalid,
 output wire video_awready,video_arready,
 input wire [127:0] video_wdata,input wire [15:0] video_wstrb,
 input wire video_wvalid,video_wlast,output wire video_wready,
 output wire [127:0] video_rdata,output wire [3:0] video_rid,
 output wire video_rvalid,video_rlast,output wire [1:0] video_rresp,
 input wire video_rready,
 output wire video_bvalid,output wire [3:0] video_bid,output wire [1:0] video_bresp,
 input wire video_bready,
 input wire nn_command_valid,nn_command_write,
 input wire [31:0] nn_command_address,input wire [7:0] nn_command_length,nn_command_id,
 output wire nn_command_ready,
 input wire [127:0] nn_wdata,input wire [15:0] nn_wstrb,
 input wire nn_wvalid,nn_wlast,output wire nn_wready,
 output wire [127:0] nn_rdata,output wire [7:0] nn_rid,
 output wire nn_rvalid,nn_rlast,output wire [1:0] nn_rresp,input wire nn_rready,
 output wire nn_bvalid,output wire [7:0] nn_bid,output wire [1:0] nn_bresp,input wire nn_bready,
 output wire [31:0] ddr_address,output wire [7:0] ddr_length,ddr_id,
 output wire ddr_write,ddr_avalid,input wire ddr_aready,
 output wire [127:0] ddr_wdata,output wire [15:0] ddr_wstrb,
 output wire ddr_wvalid,ddr_wlast,input wire ddr_wready,
 input wire [127:0] ddr_rdata,input wire [7:0] ddr_rid,
 input wire ddr_rvalid,ddr_rlast,input wire [1:0] ddr_rresp,output wire ddr_rready,
 input wire ddr_bvalid,input wire [7:0] ddr_bid,input wire [1:0] ddr_bresp,output wire ddr_bready,
 output wire video_write_committed,output wire [31:0] video_write_address,
 output wire [7:0] video_write_length,output wire transaction_active
);
 localparam integer GAP_BITS=NN_MIN_GAP_CYCLES<1 ? 1 : $clog2(NN_MIN_GAP_CYCLES+1);
 reg [GAP_BITS-1:0] neural_cooldown;
 wire neural_may_issue=NN_MIN_GAP_CYCLES==0||neural_cooldown==0;
 wire va_valid,va_ready,va_write,aw_ready,ar_ready;
 wire [31:0] va_address;wire [7:0] va_length;wire [3:0] va_id;
 wire [1:0] requests_ready,w_ready,r_valid,r_last,b_valid;
 wire [3:0] r_resp,b_resp;wire [127:0] shared_rdata;
 AXI4_AWARMux #(.AID_LEN(4),.AADDR_LEN(32)) video_mux(
 .aclk_i(clk),.arst_i(rst),.awid_i(video_awid),.awaddr_i(video_awaddr),.awlen_i(video_awlen),
 .awvalid_i(video_awvalid&&!rst),.awready_o(aw_ready),
 .arid_i(video_arid),.araddr_i(video_araddr),.arlen_i(video_arlen),
 .arvalid_i(video_arvalid&&!rst),.arready_o(ar_ready),
 .aid_o(va_id),.aaddr_o(va_address),.alen_o(va_length),.atype_o(va_write),
 .avalid_o(va_valid),.aready_i(va_ready));
 assign video_awready=aw_ready&&!rst;assign video_arready=ar_ready&&!rst;
 assign va_ready=requests_ready[0];assign nn_command_ready=requests_ready[1];
 assign video_wready=w_ready[0];assign nn_wready=w_ready[1];
 assign video_rdata=shared_rdata;assign nn_rdata=shared_rdata;
 assign video_rvalid=r_valid[0];assign nn_rvalid=r_valid[1];
 assign video_rlast=r_last[0];assign nn_rlast=r_last[1];
 assign video_rresp=r_resp[1:0];assign nn_rresp=r_resp[3:2];
 assign video_bvalid=b_valid[0];assign nn_bvalid=b_valid[1];
 assign video_bresp=b_resp[1:0];assign nn_bresp=b_resp[3:2];
 assign video_rid=ddr_rid[3:0];assign nn_rid=ddr_rid;
 assign video_bid=ddr_bid[3:0];assign nn_bid=ddr_bid;
 // Arbiter retains accepted address/length through the B-completion pulse.
 // Neural writes can NEVER generate this event. Feed frame_available only here.
 assign video_write_address=ddr_address;assign video_write_length=ddr_length;
 // Only admission of NEW neural commands is throttled. Accepted W/R/B drains
 // normally, including cancellation/fault paths. Video is never gated here.
 always @(posedge clk)begin
  if(rst)neural_cooldown<=0;
  else if((b_valid[1]&&nn_bready)||(r_valid[1]&&nn_rready&&r_last[1]))
   neural_cooldown<=NN_MIN_GAP_CYCLES;
  else if(neural_cooldown!=0)neural_cooldown<=neural_cooldown-1'b1;
 end
 ddr_transaction_arbiter owner_arbiter(.clk(clk),.rst(rst),.ddr_ready(ddr_ready),
 .req_valid({nn_command_valid&&neural_may_issue,va_valid}),.req_write({nn_command_write,va_write}),
 .req_ready(requests_ready),.req_addr({nn_command_address,va_address}),
 .req_len({nn_command_length,va_length}),.req_id({nn_command_id,4'b0,va_id}),
 .client_wdata({nn_wdata,video_wdata}),.client_wstrb({nn_wstrb,video_wstrb}),
 .client_wvalid({nn_wvalid,video_wvalid}),.client_wlast({nn_wlast,video_wlast}),.client_wready(w_ready),
 .client_rdata(shared_rdata),.client_rvalid(r_valid),.client_rlast(r_last),
 .client_rready({nn_rready,video_rready}),.client_rresp(r_resp),.client_bresp(b_resp),
 .client_bvalid(b_valid),.client_bready({nn_bready,video_bready}),
 .ddr_addr(ddr_address),.ddr_len(ddr_length),.ddr_id(ddr_id),.ddr_write(ddr_write),
 .ddr_avalid(ddr_avalid),.ddr_aready(ddr_aready),.ddr_wdata(ddr_wdata),.ddr_wstrb(ddr_wstrb),
 .ddr_wvalid(ddr_wvalid),.ddr_wlast(ddr_wlast),.ddr_wready(ddr_wready),
 .ddr_rdata(ddr_rdata),.ddr_rvalid(ddr_rvalid),.ddr_rlast(ddr_rlast),.ddr_rresp(ddr_rresp),
 .ddr_bvalid(ddr_bvalid),.ddr_bresp(ddr_bresp),.ddr_rready(ddr_rready),.ddr_bready(ddr_bready),
 .video_write_committed(video_write_committed),.transaction_active(transaction_active));
endmodule
`default_nettype wire
