`timescale 1ns/1ps
// A 32-bit Q16 store becomes one aligned 128-bit beat with exactly four strobes.
// Never write the video region or immutable weight window. Accepted transactions
// drain through W/B on cancel; bus_reset must be shared with DDR/arbiter reset.
module ddr_word_writer #(parameter [31:0] MIN_ADDRESS=32'h00820000,MAX_ADDRESS_EXCLUSIVE=32'h00880000)(
 input wire clk,bus_reset,cancel,word_request,input wire [31:0] word_address,word_data,
 output wire word_ready,idle,output reg done,fault,aborted,
 output wire command_valid,input wire command_ready,
 output reg[31:0] command_address,output wire command_write,output wire[7:0] command_length,
 output wire wvalid,wlast,input wire wready,
 output reg[127:0] wdata,output reg[15:0] wstrb,
 input wire bvalid,input wire[1:0] bresp,output wire bready);
 localparam IDLE=0,COMMAND=1,DATA=2,RESPONSE=3;
 reg[1:0] state;reg discard;
 assign word_ready=state==IDLE&&!cancel&&!bus_reset;
 assign idle=state==IDLE;
 assign command_valid=state==COMMAND&&!cancel&&!bus_reset;
 assign command_write=1;
 assign command_length=0;
 assign wvalid=state==DATA&&!bus_reset;
 assign wlast=1;
 assign bready=state==RESPONSE&&!bus_reset;
 always @(posedge clk)begin
  done<=0;aborted<=0;
  if(bus_reset)begin state<=IDLE;discard<=0;fault<=0;command_address<=0;wdata<=0;wstrb<=0;end
  else begin
   if(cancel&&(state==DATA||state==RESPONSE))discard<=1;
   case(state)
    IDLE:if(word_request&&word_ready)begin
     fault<=0;discard<=0;
     if(word_address[1:0]!=0||word_address<MIN_ADDRESS||word_address>=MAX_ADDRESS_EXCLUSIVE)begin fault<=1;done<=1;end
     else begin
      command_address<={word_address[31:4],4'b0};
      wdata<={4{word_data}};wstrb<=16'h000f<<(word_address[3:2]*4);state<=COMMAND;
     end
    end
    COMMAND:if(cancel)begin aborted<=1;done<=1;state<=IDLE;end else if(command_ready)state<=DATA;
    DATA:if(wready)state<=RESPONSE;
    RESPONSE:if(bvalid)begin
     done<=1;fault<=bresp!=0;aborted<=discard||cancel;state<=IDLE;
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
