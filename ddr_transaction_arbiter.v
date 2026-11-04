`timescale 1ns/1ps
// Two clients of the Efinity combined AW/AR interface, one transaction in flight.
// Client 0 is video; client 1 is inference. Packed slice 0 belongs to video.
// Requests accepted into this module are buffered until DDR accepts the address.
// Owner remains locked through RLAST or the REAL B response, never a BVALID stub.
module ddr_transaction_arbiter(input wire clk,rst,ddr_ready,
 input wire [1:0] req_valid,req_write,output wire [1:0] req_ready,
 input wire [63:0] req_addr,input wire [15:0] req_len,req_id,
 input wire [255:0] client_wdata,input wire [31:0] client_wstrb,
 input wire [1:0] client_wvalid,client_wlast,output wire [1:0] client_wready,
 output wire [127:0] client_rdata,output wire [1:0] client_rvalid,
 output wire [1:0] client_rlast,input wire [1:0] client_rready,
 output wire [3:0] client_rresp,client_bresp,
 output wire [1:0] client_bvalid,input wire [1:0] client_bready,
 output reg [31:0] ddr_addr,output reg [7:0] ddr_len,ddr_id,
 output reg ddr_write,output wire ddr_avalid,input wire ddr_aready,
 output wire [127:0] ddr_wdata,output wire [15:0] ddr_wstrb,
 output wire ddr_wvalid,ddr_wlast,input wire ddr_wready,
 input wire [127:0] ddr_rdata,input wire ddr_rvalid,ddr_rlast,
 input wire [1:0] ddr_rresp,ddr_bresp,input wire ddr_bvalid,
 output wire ddr_rready,ddr_bready,
 output reg video_write_committed,output wire transaction_active);
 localparam IDLE=0,ADDRESS=1,WRITE_DATA=2,WRITE_RESPONSE=3,READ_DATA=4;
 reg [2:0] state;reg owner,prefer_neural;
 wire selected=(req_valid==2'b11)?prefer_neural:req_valid[1];
 wire accepting=state==IDLE&&ddr_ready&&(|req_valid)&&!rst;
 assign req_ready=accepting?(selected?2'b10:2'b01):2'b00;
 assign transaction_active=state!=IDLE;
 assign ddr_avalid=state==ADDRESS&&!rst;
 assign ddr_wvalid=state==WRITE_DATA&&client_wvalid[owner]&&!rst;
 assign ddr_wlast=client_wlast[owner];
 assign ddr_wdata=owner?client_wdata[255:128]:client_wdata[127:0];
 assign ddr_wstrb=owner?client_wstrb[31:16]:client_wstrb[15:0];
 assign client_wready=(state==WRITE_DATA&&ddr_wready&&!rst)?(owner?2'b10:2'b01):2'b00;
 // Shared data is qualified ONLY by the routed valid bit; each client must
 // ignore it when its valid is low. No neural response enters the video FIFO.
 assign client_rdata=ddr_rdata;
 assign client_rvalid=(state==READ_DATA&&ddr_rvalid&&!rst)?(owner?2'b10:2'b01):2'b00;
 assign client_rlast=(state==READ_DATA&&ddr_rlast)?(owner?2'b10:2'b01):2'b00;
 assign client_rresp=owner?{ddr_rresp,2'b00}:{2'b00,ddr_rresp};
 assign ddr_rready=state==READ_DATA&&client_rready[owner]&&!rst;
 assign client_bvalid=(state==WRITE_RESPONSE&&ddr_bvalid&&!rst)?(owner?2'b10:2'b01):2'b00;
 assign client_bresp=owner?{ddr_bresp,2'b00}:{2'b00,ddr_bresp};
 assign ddr_bready=state==WRITE_RESPONSE&&client_bready[owner]&&!rst;
 always @(posedge clk) begin
  video_write_committed<=0;
  if(rst)begin state<=IDLE;owner<=0;prefer_neural<=0;ddr_addr<=0;ddr_len<=0;ddr_id<=0;ddr_write<=0;end
  else case(state)
   IDLE:if(accepting)begin
    owner<=selected;ddr_addr<=selected?req_addr[63:32]:req_addr[31:0];
    ddr_len<=selected?req_len[15:8]:req_len[7:0];
    ddr_id<=selected?req_id[15:8]:req_id[7:0];
    ddr_write<=req_write[selected];state<=ADDRESS;
   end
   ADDRESS:if(ddr_aready)state<=ddr_write?WRITE_DATA:READ_DATA;
   WRITE_DATA:if(ddr_wvalid&&ddr_wready&&ddr_wlast)state<=WRITE_RESPONSE;
   WRITE_RESPONSE:if(ddr_bvalid&&ddr_bready)begin
    video_write_committed<=!owner&&ddr_bresp==0;
    prefer_neural<=!owner;state<=IDLE;
   end
   READ_DATA:if(ddr_rvalid&&ddr_rready&&ddr_rlast)begin prefer_neural<=!owner;state<=IDLE;end
   default:state<=IDLE;
  endcase
 end
endmodule
