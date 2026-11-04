`timescale 1ns/1ps
`default_nettype none
// One IMA-ADPCM decoder; bank 0 = original static words, bank 1 = five tokens.
// sample_req is already at the source ADPCM rate (one half of I2S LRCLK).
module unified_adpcm_player(input wire clk,rst_n,play_start,sample_req,
 input wire clip_bank,input wire[4:0] clip_id,input wire[3:0] rom_data,
 output reg[16:0] rom_address,output reg rom_bank,
 output reg[15:0] pcm_sample,output reg busy,done);
 `include "unified_audio_lookup.vh"
 wire[5:0] metadata_index={clip_bank,clip_id};
 wire[16:0] clip_begin=clip_starts[metadata_index],clip_length=clip_lengths[metadata_index];
 reg signed[16:0] predictor;
 reg[6:0] index;reg[15:0] step;
 reg[16:0] end_address;
 reg[3:0] code;reg[1:0] phase,prefetch;reg draining;
 reg signed[17:0] delta,next_predictor;reg signed[8:0] next_index;
 always @*begin
  delta=$signed({2'b0,step})>>>3;
  if(code[2])delta=delta+$signed({2'b0,step});
  if(code[1])delta=delta+($signed({2'b0,step})>>>1);
  if(code[0])delta=delta+($signed({2'b0,step})>>>2);
  next_predictor=code[3]?predictor-delta:predictor+delta;
  if(next_predictor>32767)next_predictor=32767;
  if(next_predictor< -32768)next_predictor=-32768;
  case(code[2:0])
   0,1,2,3:next_index=$signed({2'b0,index})-9'sd1;
   4:next_index=$signed({2'b0,index})+9'sd2;
   5:next_index=$signed({2'b0,index})+9'sd4;
   6:next_index=$signed({2'b0,index})+9'sd6;
   default:next_index=$signed({2'b0,index})+9'sd8;
  endcase
  if(next_index<0)next_index=0;
  if(next_index>88)next_index=88;
 end
 always @(posedge clk)begin
  if(!rst_n)begin
   predictor<=0;index<=0;step<=7;end_address<=0;rom_address<=0;rom_bank<=0;
   pcm_sample<=0;busy<=0;done<=0;phase<=0;prefetch<=0;draining<=0;code<=0;
  end else begin
   done<=0;
   if(prefetch!=0)prefetch<=prefetch-1'b1;
   if(play_start&&!busy&&clip_length!=0)begin
    busy<=1;phase<=0;prefetch<=2;draining<=0;predictor<=0;index<=0;step<=7;
    pcm_sample<=0;rom_bank<=clip_bank;rom_address<=clip_begin;end_address<=clip_begin+clip_length;
   end else if(phase==1)begin
    predictor<=next_predictor[16:0];pcm_sample<=next_predictor[15:0];index<=next_index[6:0];phase<=2;
   end else if(phase==2)begin
    step<=ima_steps[index];phase<=0;
    if(rom_address+17'd1>=end_address)draining<=1;
    else rom_address<=rom_address+1'b1;
   end else if(sample_req)begin
    if(busy&&!draining&&prefetch==0)begin code<=rom_data;phase<=1;end
    else if(!busy||draining)begin
     pcm_sample<=0;
     if(busy&&draining)begin busy<=0;done<=1;draining<=0;end
    end
   end
  end
 end
endmodule
`default_nettype wire
