`timescale 1ns/1ps
// Capture first, infer afterwards: CNN latency cannot alter the trained 10Hz
// sampling cadence. 310 packed gray frames occupy 0x880000..0x9b5fff.
// Pixel-side stopped must acknowledge the final entire sampled frame; all
// buffered samples and real DDR B responses drain before inference begins.
module continuous_clip_engine(input wire clk,bus_reset,cancel,start,stop,
 input wire weights_ready,pixel_stopped,pixel_fault,
 output wire recording,session_active,output reg done,fault,
 output reg[8:0] recorded_frames,
 input wire sample_valid,input wire[19:0] sample_data,output wire sample_ready,
 output wire ingest_request,output wire[31:0] ingest_address,ingest_data,
 input wire ingest_ready,ingest_done,ingest_fault,ingest_aborted,
 output wire frame_request,sequence_request,output wire[8:0] frame_index,sequence_frames,
 input wire frame_ready,sequence_ready,frame_done,frame_fault,
 input wire result_valid,
 output wire command_valid,command_write,input wire command_ready,
 output wire[31:0] command_address,output wire[7:0] command_length,
 output wire wvalid,wlast,input wire wready,output wire[127:0]wdata,output wire[15:0]wstrb,
 input wire[127:0]read_data,input wire read_valid,read_last,input wire[1:0]read_response,
 output wire read_ready,input wire bvalid,input wire[1:0]bresp,output wire bready);
 localparam IDLE=0,RECORD=1,STORE=2,DRAIN=3,READ_CMD=4,READ_BEAT=5,
  INGEST=6,INGEST_WAIT=7,FRAME=8,FRAME_WAIT=9,SEQUENCE=10,RESULT=11,FAILED=12;
 reg[3:0] state;
 reg[3:0] quiet_cycles;
 reg stop_pending,read_pending,store_issued;reg[11:0] expected_sample,replay_pixel;
 reg[8:0] replay_frame;
 reg[31:0] packed_word,store_word,store_address;
 reg[127:0] replay_word;
 reg[3:0] replay_lane;
 wire writer_ready,writer_idle,writer_done,writer_fault,writer_aborted;
 wire writer_cv,writer_cw;wire[31:0]writer_ca;wire[7:0]writer_cl;
 wire take_sample=sample_valid&&sample_ready;
 wire[7:0] pixel=replay_word[replay_lane*8+:8];
 assign recording=state==RECORD||state==STORE ? !stop_pending&&!fault : 1'b0;
 assign session_active=state!=IDLE;
 assign sample_ready=(state==RECORD&&!fault)||(state==IDLE)||(state==FAILED&&writer_idle);
 assign frame_index=replay_frame;assign sequence_frames=recorded_frames;
 assign ingest_request=state==INGEST&&!cancel;
 assign ingest_address=32'h00840000+{18'd0,replay_pixel,2'd0};
 // round(gray*65536/255) == gray*257 + (gray>=128), exact for all256.
 assign ingest_data={16'd0,pixel,pixel}+{31'd0,pixel[7]};
 assign frame_request=state==FRAME&&!cancel;
 assign sequence_request=state==SEQUENCE&&!cancel;
 assign command_valid=state==READ_CMD ? !cancel : writer_cv;
 assign command_write=state==READ_CMD ? 1'b0 : writer_cw;
 assign command_address=state==READ_CMD ? 32'h00880000+{11'd0,replay_frame,12'd0}+{20'd0,replay_pixel} : writer_ca;
 assign command_length=state==READ_CMD ? 8'd0 : writer_cl;
 assign read_ready=read_pending;
 ddr_word_writer #(.MIN_ADDRESS(32'h00880000),.MAX_ADDRESS_EXCLUSIVE(32'h009b6000)) writer(
 .clk(clk),.bus_reset(bus_reset),.cancel(cancel||fault),
 .word_request(state==STORE&&!store_issued&&!fault),.word_address(store_address),.word_data(store_word),
 .word_ready(writer_ready),.idle(writer_idle),.done(writer_done),.fault(writer_fault),.aborted(writer_aborted),
 .command_valid(writer_cv),.command_ready(command_ready&&state!=READ_CMD),.command_address(writer_ca),.command_write(writer_cw),.command_length(writer_cl),
 .wvalid(wvalid),.wlast(wlast),.wready(wready),.wdata(wdata),.wstrb(wstrb),.bvalid(bvalid),.bresp(bresp),.bready(bready));
 always @(posedge clk)begin
  done<=0;
  if(bus_reset)begin state<=IDLE;fault<=0;recorded_frames<=0;stop_pending<=0;expected_sample<=0;
   packed_word<=0;store_word<=0;store_address<=0;replay_frame<=0;replay_pixel<=0;replay_lane<=0;replay_word<=0;store_issued<=0;read_pending<=0;quiet_cycles<=0;
  end else begin
   if(state==READ_CMD&&command_valid&&command_ready)read_pending<=1;
   if(read_pending&&read_valid&&read_last)read_pending<=0;
   if(stop)stop_pending<=1;
   if(cancel||((state==RECORD||state==STORE)&&pixel_fault))begin fault<=1;state<=FAILED;end
   else case(state)
    IDLE:if(start&&weights_ready&&pixel_stopped&&!sample_valid&&writer_idle)begin
     state<=RECORD;recorded_frames<=0;expected_sample<=0;stop_pending<=0;fault<=0;
    end
    RECORD:begin
     if(take_sample)begin
      if(sample_data[19:8]!=expected_sample||recorded_frames>=310)begin fault<=1;state<=FAILED;end
      else begin
       packed_word[expected_sample[1:0]*8+:8]<=sample_data[7:0];
       expected_sample<=expected_sample+1'b1;
       if(expected_sample[1:0]==3)begin
        store_word<={sample_data[7:0],packed_word[23:0]};
        store_address<=32'h00880000+{11'd0,recorded_frames,12'd0}+{20'd0,expected_sample[11:2],2'd0};
        store_issued<=0;state<=STORE;
       end
      end
     end else if(stop_pending&&pixel_stopped&&!sample_valid)begin quiet_cycles<=0;state<=DRAIN;end
    end
    DRAIN:begin
     if(sample_valid||!pixel_stopped)state<=RECORD;
     else if(quiet_cycles==8)begin
      if(expected_sample!=0||recorded_frames==0)begin fault<=1;state<=FAILED;end
      else begin replay_frame<=0;replay_pixel<=0;state<=READ_CMD;end
     end else quiet_cycles<=quiet_cycles+1'b1;
    end
    STORE:begin
     if(writer_ready&&!store_issued)store_issued<=1;
     if(writer_done)begin
      if(writer_fault||writer_aborted)begin fault<=1;state<=FAILED;end
      else begin
       if(expected_sample==0)begin recorded_frames<=recorded_frames+1'b1;if(recorded_frames==309)stop_pending<=1;end
       state<=RECORD;
      end
     end
    end
    READ_CMD:if(command_ready)state<=READ_BEAT;
    READ_BEAT:if(read_valid)begin
     if(!read_last||read_response!=0)begin fault<=1;state<=FAILED;end
     else begin replay_word<=read_data;replay_lane<=0;state<=INGEST;end
    end
    INGEST:if(ingest_ready)state<=INGEST_WAIT;
    INGEST_WAIT:if(ingest_done)begin
     if(ingest_fault||ingest_aborted)begin fault<=1;state<=FAILED;end
     else if(replay_pixel==4095)state<=FRAME;
     else begin replay_pixel<=replay_pixel+1'b1;replay_lane<=replay_lane+1'b1;
      state<=replay_lane==15?READ_CMD:INGEST;end
    end
    FRAME:if(frame_ready)state<=FRAME_WAIT;
    FRAME_WAIT:if(frame_done)begin
     if(frame_fault)begin fault<=1;state<=FAILED;end
     else if(replay_frame+1'b1==recorded_frames)state<=SEQUENCE;
     else begin replay_frame<=replay_frame+1'b1;replay_pixel<=0;state<=READ_CMD;end
    end
    SEQUENCE:if(sequence_ready)state<=RESULT;
    RESULT:if(result_valid)begin done<=1;state<=IDLE;end
    FAILED:if(writer_idle&&!read_pending&&pixel_stopped&&!sample_valid)begin done<=1;state<=IDLE;end
    default:begin fault<=1;state<=FAILED;end
   endcase
  end
 end
endmodule
