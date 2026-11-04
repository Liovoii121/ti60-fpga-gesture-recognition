`timescale 1ns/1ps
`default_nettype none
// Bundled-data CDC contract: producer holds packet_hold_tck unchanged until
// packet_busy_tck goes low. It must NOT be the shifting USER DR register.
// All mailbox source flops and this bridge share bus_reset. No BRAM is used.
// QUERY snapshots loader status and does not advance the DATA sequence.
module jtag_weight_transport_bridge(
 input wire clk,diag_tck,bus_reset,cancel,
 input wire [1023:0] packet_hold_tck,input wire packet_toggle_tck,
 output wire packet_busy_tck,output wire packet_ack_toggle_tck,
 output reg [255:0] status_tck,
 output wire load_start,output wire load_cancel,
 output reg [31:0] load_byte_length,load_expected_crc32,
 input wire load_start_ready,load_active,weights_ready,load_fault,
 input wire [2:0] load_error_code,
 input wire [31:0] load_bytes_written,load_observed_crc32,
 input wire memory_idle,
 output wire stream_valid,stream_last,output wire [127:0] stream_data,
 input wire stream_ready
);
 localparam [31:0] START=32'h4e4c5354,DATA=32'h4e4c4454,
 QUERY=32'h4e4c5153,ABORT=32'h4e4c4142,SIGNATURE=32'h4e4c5353;
 localparam IDLE=0,DECODE=1,SEND=2,CANCELLING=3,STARTING=4,PUBLISH=5;
 localparam OK=0,BAD_FORMAT=1,BAD_SEQUENCE=2,BAD_OFFSET=3,NOT_LOADING=4,
 BUSY=5,LOADER_FAILED=6,CANCELLED=7;
 reg [2:0] state;reg publish_ack;
 (* async_reg="true" *) reg [2:0] request_sync;
 (* async_reg="true" *) reg [2:0] ack_sync,publish_sync;
 reg request_seen,ack_toggle,publish_toggle,publish_seen;
 reg [255:0] status_hold;
 reg [31:0] pending_seq,expected_seq,accepted_bytes,last_ack,last_kind,last_offset;
 reg [7:0] last_error,last_count;
 reg last_image,session_active,packet_last,cancel_has_packet;
 reg [2:0] packet_count,word_index;
 wire [31:0] opcode=packet_hold_tck[31:0];
 wire [31:0] seq=packet_hold_tck[63:32];
 wire [7:0] count=packet_hold_tck[71:64];
 wire [31:0] offset=packet_hold_tck[127:96];
 wire image_last=packet_hold_tck[72];
 wire [31:0] packet_bytes={20'd0,count,4'd0};
 wire [31:0] live_flags={28'd0,session_active,load_fault,weights_ready,load_active};
 assign packet_ack_toggle_tck=ack_sync[2];
 assign packet_busy_tck=bus_reset||(packet_toggle_tck!=ack_sync[2]);
 assign load_cancel=cancel||state==CANCELLING;
 assign load_start=state==STARTING&&!cancel&&!bus_reset;
 assign stream_valid=state==SEND&&session_active&&load_active&&!load_fault&&!cancel&&!bus_reset;
 assign stream_last=packet_last&&word_index==packet_count-1'b1;
 assign stream_data=word_index==0?packet_hold_tck[255:128]:packet_hold_tck[383:256];
 task publish;
  begin publish_ack<=1;state<=PUBLISH;end
 endtask
 task reject_packet;
  input [7:0] reason;
  begin
   last_ack<=pending_seq;last_error<=reason;last_kind<=0;
   publish();
   
  end
 endtask
 always @(posedge diag_tck or posedge bus_reset)begin
  if(bus_reset)begin ack_sync<=0;publish_sync<=0;publish_seen<=0;status_tck<={224'd0,SIGNATURE};end
  else begin
   ack_sync<={ack_sync[1:0],ack_toggle};publish_sync<={publish_sync[1:0],publish_toggle};
   if(publish_sync[2]!=publish_seen)begin status_tck<=status_hold;publish_seen<=publish_sync[2];end
  end
 end
 always @(posedge clk)begin
  if(bus_reset)begin
   state<=IDLE;publish_ack<=0;request_sync<=0;request_seen<=0;ack_toggle<=0;publish_toggle<=0;
   status_hold<={224'd0,SIGNATURE};load_byte_length<=0;load_expected_crc32<=0;
   pending_seq<=0;expected_seq<=0;accepted_bytes<=0;last_ack<=32'hffffffff;last_kind<=0;
   last_offset<=0;last_error<=0;last_count<=0;last_image<=0;session_active<=0;
   packet_last<=0;packet_count<=0;word_index<=0;cancel_has_packet<=0;
  end else begin
   request_sync<={request_sync[1:0],packet_toggle_tck};
   if(cancel&&(session_active||state==DECODE||state==SEND||state==STARTING))begin
    cancel_has_packet<=state!=IDLE;session_active<=0;state<=CANCELLING;
   end else case(state)
    IDLE:if(!cancel&&request_sync[2]!=request_seen)begin
     request_seen<=request_sync[2];pending_seq<=seq;state<=DECODE;
    end
    DECODE:case(opcode)
     QUERY:begin
      publish();
      
     end
     START:begin
      if(pending_seq!=0||packet_hold_tck[95:64]==0||packet_hold_tck[71:64]!=0||packet_hold_tck[95:64]>131072)reject_packet(BAD_FORMAT);
      else if(last_kind==START&&last_ack==0&&last_error==0&&session_active&&
              load_byte_length==packet_hold_tck[95:64]&&load_expected_crc32==packet_hold_tck[127:96])begin
       publish();
      end else if(!load_start_ready||!memory_idle)reject_packet(BUSY);
      else begin
       load_byte_length<=packet_hold_tck[95:64];load_expected_crc32<=packet_hold_tck[127:96];state<=STARTING;
      end
     end
     DATA:begin
      if(count==0||count>2||packet_hold_tck[95:73]!=0)reject_packet(BAD_FORMAT);
      else if(last_kind==DATA&&last_error==0&&pending_seq==last_ack&&offset==last_offset&&count==last_count&&image_last==last_image)begin
       publish();
      end else if(!session_active||!load_active||load_fault)reject_packet(load_fault?LOADER_FAILED:NOT_LOADING);
      else if(pending_seq!=expected_seq)reject_packet(BAD_SEQUENCE);
      else if(offset!=accepted_bytes||accepted_bytes+packet_bytes>load_byte_length||
              image_last!=(accepted_bytes+packet_bytes==load_byte_length))reject_packet(BAD_OFFSET);
      else begin packet_count<=count[2:0];packet_last<=image_last;word_index<=0;state<=SEND;end
     end
     ABORT:begin session_active<=0;cancel_has_packet<=1;state<=CANCELLING;end
     default:reject_packet(BAD_FORMAT);
    endcase
    STARTING:if(load_start_ready)begin
     expected_seq<=1;accepted_bytes<=0;last_ack<=0;last_error<=0;last_kind<=START;session_active<=1;
     publish();
    end
    SEND:begin
     if(load_fault||!load_active)begin session_active<=0;reject_packet(LOADER_FAILED);end
     else if(stream_valid&&stream_ready)begin
      accepted_bytes<=accepted_bytes+16;
      if(word_index==packet_count-1'b1)begin
       last_ack<=pending_seq;last_error<=0;last_kind<=DATA;last_offset<=offset;last_count<={5'd0,packet_count};last_image<=packet_last;
       expected_seq<=expected_seq+1'b1;
       publish();
       
      end else word_index<=word_index+1'b1;
     end
    end
    CANCELLING:if(!load_active&&memory_idle)begin
     session_active<=0;last_error<=CANCELLED;last_kind<=ABORT;
     if(cancel_has_packet)last_ack<=pending_seq;
     publish_ack<=cancel_has_packet;state<=PUBLISH;
    end
    PUBLISH:begin
     status_hold<={expected_seq,load_observed_crc32,load_bytes_written,accepted_bytes,live_flags,
                   16'd0,5'd0,load_error_code,last_error,last_ack,SIGNATURE};
     publish_toggle<=!publish_toggle;
     if(publish_ack)ack_toggle<=request_seen;
     state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
`default_nettype wire
