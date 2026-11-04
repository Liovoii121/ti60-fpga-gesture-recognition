`timescale 1ns/1ps
`default_nettype none
// Fixed640 compact snapshot: exact gray64 is computed during capture.
// Packed native rectangle only; bank/bbox translation and localization external.
// One read outstanding. Every accepted read must eventually return read_valid,
// including after cancel; release the source bank only once busy deasserts.
// rst must reset requester AND responder together to flush old responses.
module static5_rgb565_gray64 #(
 parameter integer READ_TIMEOUT_CYCLES=1024
)(
 input wire clk,rst,start,cancel,
 input wire [31:0] epoch,
 input wire [8:0] source_width,source_height,
 output wire start_ready,busy,
 output wire source_read_request,
 output wire [15:0] source_read_address,
 output wire [31:0] source_read_epoch,
 input wire source_read_ready,
 input wire source_read_valid,
 input wire [15:0] source_read_data,
 input wire [31:0] source_response_epoch,
 output wire source_response_ready,
 output wire gray_valid,gray_last,
 output reg [7:0] gray_data,
 output wire [31:0] gray_epoch,
 input wire gray_ready,
 output reg done,aborted,error,
 output reg [1:0] error_code
);
 localparam IDLE=0,REQ=1,WAIT_READ=2,EMIT=3,DRAIN=4,FAULT=5;
 reg [2:0] state;
 reg [11:0] address;
 reg [31:0] saved_epoch,wait_count;
 wire stale=epoch!=saved_epoch;
 assign start_ready=state==IDLE&&!rst&&!cancel;
 assign busy=state!=IDLE;
 assign source_read_request=state==REQ&&!rst&&!cancel&&!stale;
 assign source_read_address={4'd0,address};
 assign source_read_epoch=saved_epoch;
 assign source_response_ready=(state==WAIT_READ||state==DRAIN||state==FAULT)&&!rst;
 assign gray_valid=state==EMIT&&!rst&&!cancel&&!stale;
 assign gray_last=address==4095;
 assign gray_epoch=saved_epoch;
 always @(posedge clk)begin
  done<=0;aborted<=0;
  if(rst)begin state<=IDLE;address<=0;saved_epoch<=0;wait_count<=0;gray_data<=0;done<=0;aborted<=0;error<=0;error_code<=0;end
  else if(state!=IDLE&&state!=DRAIN&&state!=FAULT&&(cancel||stale))begin
   aborted<=1;
   if(state==WAIT_READ&&!source_read_valid)state<=DRAIN;
   else if(state==WAIT_READ&&source_response_epoch!=saved_epoch)begin state<=FAULT;error<=1;error_code<=3;end
   else state<=IDLE;
  end else case(state)
   IDLE:if(start&&start_ready)begin
    error<=0;error_code<=0;
    if(source_width!=128||source_height!=128)begin error<=1;error_code<=1;end
    else begin saved_epoch<=epoch;address<=0;wait_count<=0;state<=REQ;end
   end
   REQ:if(source_read_ready)begin state<=WAIT_READ;wait_count<=0;end
    else if(wait_count>=READ_TIMEOUT_CYCLES-1)begin error<=1;error_code<=2;state<=FAULT;end
    else wait_count<=wait_count+1'b1;
   WAIT_READ:if(source_read_valid)begin
    if(source_response_epoch!=saved_epoch)begin state<=FAULT;error<=1;error_code<=3;end
    else begin gray_data<=source_read_data[7:0];state<=EMIT;end
   end else if(wait_count>=READ_TIMEOUT_CYCLES-1)begin error<=1;error_code<=2;state<=FAULT;end
   else wait_count<=wait_count+1'b1;
   EMIT:if(gray_ready)begin
    if(address==4095)begin state<=IDLE;done<=1;end
    else begin address<=address+1'b1;wait_count<=0;state<=REQ;end
   end
   DRAIN:if(source_read_valid)begin
    if(source_response_epoch==saved_epoch)state<=IDLE;
    else begin state<=FAULT;error<=1;error_code<=3;end
   end
   FAULT:begin end
   default:state<=IDLE;
  endcase
 end
endmodule
`default_nettype wire
