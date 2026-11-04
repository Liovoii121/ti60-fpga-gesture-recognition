`timescale 1ns/1ps
`default_nettype none
// DDR-bus-clock domain. bus_reset MUST also reset/flush the DDR transaction path.
// A job cancellation is NOT a bus reset. Accepted writes drain through real B.
// Input byte0 is stream_data[7:0], the lowest DDR address byte (Q16 little-endian).
// CRC32 is IEEE reflected, init/final XOR ffffffff, over ALL padded input bytes.
// Integrity scope: input-stream CRC + DDR BRESP, NOT read-back DDR CRC.
module ddr_weight_stream_loader #(
 parameter [31:0] BASE_ADDRESS=32'h00800000,
 parameter [31:0] MAX_BYTES=32'd131072,
 // Startup-only bus budget: release DDR between buffered bursts for video.
 parameter integer BUS_GAP_CYCLES=2048,
 // Experimental FF-buffered loader; burst must be 1,2,4,8 or16.
 parameter integer BURST_BEATS=2
)(
 input wire clk,bus_reset,ddr_ready,start,cancel,
 input wire [31:0] byte_length,expected_crc32,
 output wire start_ready,busy,
 input wire stream_valid,stream_last,input wire [127:0] stream_data,
 output wire stream_ready,
 output wire req_valid,req_write,input wire req_ready,
 output wire [31:0] req_address,output wire [7:0] req_length,
 output wire wvalid,wlast,input wire wready,
 output wire [127:0] wdata,output wire [15:0] wstrb,
 input wire bvalid,input wire [1:0] bresp,output wire bready,
 output reg weights_ready,done,aborted,fault,
 output reg [2:0] error_code,
 output reg [31:0] bytes_received,bytes_written,
 output wire [31:0] observed_crc32
);
 localparam IDLE=0,FILL=1,CRC=2,COMMAND=3,WRITE=4,RESPONSE=5,GATHER=6,GAP=7;
 reg [2:0] state;reg [15:0] gap_count;
 localparam integer INDEX_BITS=BURST_BEATS<2 ? 1 : $clog2(BURST_BEATS);
 localparam integer BURST_BYTES=BURST_BEATS*16;
 (* syn_ramstyle="registers" *)reg [31:0] buffer[0:BURST_BEATS*4-1];
 reg [127:0] packed_word;
 reg [1:0] gather_part;
 reg [127:0] crc_word;
 reg [31:0] crc,total_bytes,expected;
 reg [INDEX_BITS-1:0] fill_index,write_index;reg [3:0]crc_byte;
 reg discard;
 function [31:0] crc8;
  input [31:0] crc_in;input [7:0] data;
  reg [31:0] c;integer k;
  begin c=crc_in^{24'd0,data};for(k=0;k<8;k=k+1)c=c[0]?(c>>1)^32'hedb88320:c>>1;crc8=c;end
 endfunction
 wire [31:0] next_crc=crc8(crc,crc_word[crc_byte*8+:8]);
 assign start_ready=state==IDLE&&ddr_ready&&!bus_reset&&!cancel;
 assign busy=state!=IDLE;
 assign stream_ready=state==FILL&&!bus_reset&&!cancel;
 assign req_valid=state==COMMAND&&ddr_ready&&!bus_reset&&!cancel;
 assign req_write=1'b1;
 assign req_address=BASE_ADDRESS+bytes_written;
 assign req_length=BURST_BEATS-1;
 assign wvalid=state==WRITE&&!bus_reset;
 assign wdata=packed_word;
 assign wstrb=16'hffff;
 assign wlast=write_index==BURST_BEATS-1;
 assign bready=state==RESPONSE&&!bus_reset;
 assign observed_crc32=crc^32'hffffffff;
 always @(posedge clk)begin
  if(state==CRC&&crc_byte[1:0]==0)buffer[{fill_index,crc_byte[3:2]}]<=crc_word[crc_byte[3:2]*32+:32];
  if(state==GATHER)packed_word[gather_part*32+:32]<=buffer[{write_index,gather_part}];
 end
 always @(posedge clk)begin
  done<=0;aborted<=0;
  if(bus_reset)begin
   state<=IDLE;weights_ready<=0;done<=0;aborted<=0;fault<=0;error_code<=0;
   bytes_received<=0;bytes_written<=0;crc<=32'hffffffff;total_bytes<=0;expected<=0;
   fill_index<=0;write_index<=0;crc_byte<=0;crc_word<=0;discard<=0;gather_part<=0;gap_count<=0;
  end else if(cancel&&(state==FILL||state==CRC||state==COMMAND||state==GAP))begin
   state<=IDLE;weights_ready<=0;aborted<=1;
  end else begin
   if(cancel&&state!=IDLE)begin discard<=1;weights_ready<=0;end
   case(state)
    IDLE:if(start&&start_ready)begin
     weights_ready<=0;fault<=0;error_code<=0;discard<=0;
     bytes_received<=0;bytes_written<=0;crc<=32'hffffffff;fill_index<=0;
     total_bytes<=byte_length;expected<=expected_crc32;
     if(byte_length==0||byte_length[7:0]!=0||byte_length>MAX_BYTES||BASE_ADDRESS[7:0]!=0)begin fault<=1;error_code<=1;end
     else state<=FILL;
    end
    FILL:if(stream_valid&&stream_ready)begin
     if(stream_last!=(bytes_received+32'd16==total_bytes))begin fault<=1;error_code<=4;state<=IDLE;end
     else begin
      crc_word<=stream_data;crc_byte<=0;
      bytes_received<=bytes_received+32'd16;state<=CRC;
     end
    end
    CRC:begin
     crc<=next_crc;
     if(crc_byte==15)begin
      if(fill_index==BURST_BEATS-1)state<=COMMAND;
      else begin fill_index<=fill_index+1'b1;state<=FILL;end
     end else crc_byte<=crc_byte+1'b1;
    end
    COMMAND:if(req_valid&&req_ready)begin write_index<=0;gather_part<=0;state<=GATHER;end
    GATHER:if(gather_part==3)state<=WRITE;else gather_part<=gather_part+1'b1;
    WRITE:if(wvalid&&wready)begin
     if(write_index==BURST_BEATS-1)state<=RESPONSE;
     else begin write_index<=write_index+1'b1;gather_part<=0;state<=GATHER;end
    end
    RESPONSE:if(bvalid&&bready)begin
     if(bresp!=0)begin fault<=1;error_code<=3;state<=IDLE;end
     else begin
      bytes_written<=bytes_written+BURST_BYTES;
      if(discard||cancel)begin aborted<=1;state<=IDLE;end
      else if(bytes_written+BURST_BYTES==total_bytes)begin
       state<=IDLE;
       if(observed_crc32!=expected)begin fault<=1;error_code<=2;end
       else begin weights_ready<=1;done<=1;end
      end else begin fill_index<=0;gap_count<=BUS_GAP_CYCLES;state<=BUS_GAP_CYCLES==0?FILL:GAP;end
     end
    end
    GAP:if(gap_count==0)state<=FILL;else gap_count<=gap_count-1'b1;
    default:begin state<=IDLE;weights_ready<=0;fault<=1;error_code<=5;end
   endcase
  end
 end
endmodule
`default_nettype wire
