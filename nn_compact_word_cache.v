`timescale 1ns/1ps
`default_nettype none
// Four-word / one-beat cache in registers: no physical RAM or beat-unpack stall.
// Separate P/A instances retain weights/activations independently. Accepted reads
// always drain to actual RLAST on invalidate/cancel, including malformed bursts.
module nn_compact_word_cache(input wire clk,bus_reset,cancel,invalidate,
 input wire word_request,input wire[31:0]word_address,
 output wire word_ready,idle,response_valid,input wire response_ready,
 output reg[31:0]response_data,output reg response_fault,
 output wire command_valid,input wire command_ready,
 output reg[31:0]command_address,output wire[7:0]command_length,
 input wire[127:0]read_data,input wire read_valid,read_last,
 input wire[1:0]read_response,output wire read_ready);
 localparam IDLE=0,COMMAND=1,FILL=2,RESPONSE=3;
 reg[1:0]state,wanted;reg[127:0]line_data;reg[27:0]tag;
 reg cache_valid,discard,fill_fault;
 assign idle=state==IDLE;
 assign word_ready=idle&&!cancel&&!invalidate&&!bus_reset;
 assign response_valid=state==RESPONSE&&!cancel&&!invalidate&&!bus_reset;
 assign command_valid=state==COMMAND&&!cancel&&!invalidate&&!bus_reset;
 assign command_length=0;
 assign read_ready=state==FILL&&!bus_reset;
 always @(posedge clk)begin
  if(bus_reset)begin state<=IDLE;wanted<=0;line_data<=0;tag<=0;cache_valid<=0;discard<=0;fill_fault<=0;command_address<=0;response_data<=0;response_fault<=0;end
  else begin
   if(cancel||invalidate)begin cache_valid<=0;if(state==FILL)discard<=1;end
   case(state)
    IDLE:if(word_request&&word_ready)begin
     wanted<=word_address[3:2];response_fault<=0;
     if(word_address[1:0]!=0)begin response_fault<=1;response_data<=0;state<=RESPONSE;end
     else if(cache_valid&&tag==word_address[31:4])begin response_data<=line_data[word_address[3:2]*32+:32];state<=RESPONSE;end
     else begin command_address<={word_address[31:4],4'd0};cache_valid<=0;state<=COMMAND;end
    end
    COMMAND:if(cancel||invalidate)state<=IDLE;
     else if(command_ready)begin discard<=0;fill_fault<=0;state<=FILL;end
    FILL:if(read_valid)begin
     if(!read_last)fill_fault<=1;
     else if(discard||cancel||invalidate)begin cache_valid<=0;state<=IDLE;end
     else begin
      response_fault<=fill_fault||read_response!=0;
      cache_valid<=!fill_fault&&read_response==0;
      if(!fill_fault&&read_response==0)begin line_data<=read_data;tag<=command_address[31:4];response_data<=read_data[wanted*32+:32];end
      else response_data<=0;
      state<=RESPONSE;
     end
    end
    RESPONSE:if(response_ready||cancel||invalidate)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
`default_nettype wire
