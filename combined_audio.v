`timescale 1ns/1ps
`default_nettype none
// Static words and continuous token sequences share one ADPCM decoder and I2S.
// Both verified source versions decoded once per TWO I2S sample requests.
module combined_audio #(parameter CLOCK_HZ=148800000, DELAY_SECONDS=8,
 HALF_DIV=144, BOOT_BEEP=0)(
 input wire clk,rst,result_valid,quality,cancel,fault,audition,demo_start,
 input wire[4:0] candidate,
 input wire continuous_mode,sequence_valid,
 input wire[4:0] sequence_count,input wire[47:0] sequence_words,
 output wire bclk,lrclk,din,busy,output reg[2:0] demo_state=0,
 output reg[15:0] played_count=0);
 localparam[1:0] IDLE=0,LAUNCH=1,WAIT_BUSY=2,WAIT_DONE=3;
 localparam integer DELAY_CYCLES=CLOCK_HZ*DELAY_SECONDS;
 localparam[47:0] DEMO_WORDS=48'h0000000058d1; // tokens 1,2,3,4,5, low token first
 reg[1:0] flow=IDLE;
 reg[4:0] word_id=0,audition_index=0,sequence_length=0,sequence_index=0;
 reg[47:0] sequence_buffer=0,last_words=0;
 reg[4:0] last_count=0;
 reg sequence_job=0,player_start=0,player_bank=0;
 reg[4:0] player_clip=0;
 reg result_q=0,sequence_q=0,mode_q=0;
 reg[31:0] demo_ticks=0,boot_ticks=0;
 reg boot_pending=BOOT_BEEP;
 wire player_busy,player_done,sample_req;
 wire mode_changed=continuous_mode!=mode_q;
 wire stop=rst||cancel||fault||mode_changed;
 assign busy=player_busy||(flow!=IDLE);
 function[4:0] mapped(input[4:0] c);
 begin case(c)
 0:mapped=1;1:mapped=2;2:mapped=3;3:mapped=4;4:mapped=5;
 5:mapped=6;6:mapped=9;7:mapped=7;8:mapped=8;9:mapped=10;
 10:mapped=0;11:mapped=1;12:mapped=2;13:mapped=3;14:mapped=4;15:mapped=5;
 16:mapped=16;17:mapped=17;18:mapped=18;19:mapped=19;
 20:mapped=22;21:mapped=23;22:mapped=21;23:mapped=20;
 default:mapped=0;endcase end endfunction
 function valid_words(input[4:0] n,input[47:0] w);
 integer i;begin
 valid_words=n>0&&n<=16;
 for(i=0;i<16;i=i+1)
  if(i<n&&(w[i*3+:3]<1||w[i*3+:3]>5))valid_words=0;
 end endfunction
 always @(posedge clk)begin
  player_start<=0;result_q<=result_valid;sequence_q<=sequence_valid;mode_q<=continuous_mode;
  if(rst)begin
   flow<=IDLE;word_id<=0;audition_index<=0;sequence_length<=0;sequence_index<=0;
   sequence_buffer<=0;last_words<=0;last_count<=0;sequence_job<=0;
   player_bank<=0;player_clip<=0;demo_state<=0;demo_ticks<=0;
   result_q<=0;sequence_q<=0;mode_q<=continuous_mode;
   played_count<=0;boot_ticks<=0;boot_pending<=BOOT_BEEP;
  end else if(stop)begin
   flow<=IDLE;demo_state<=0;demo_ticks<=0;sequence_length<=0;sequence_index<=0;
   sequence_job<=0;boot_pending<=0;
  end else begin
   if(boot_pending&&boot_ticks<CLOCK_HZ-1)boot_ticks<=boot_ticks+1'b1;
   if(demo_state==1)begin
    if(demo_ticks>=DELAY_CYCLES-1)begin
     sequence_buffer<=DEMO_WORDS;sequence_length<=5;sequence_index<=0;
     sequence_job<=1;flow<=LAUNCH;demo_state<=3;
     played_count<=played_count+1'b1;
    end else demo_ticks<=demo_ticks+1'b1;
   end else case(flow)
    IDLE:begin
     if(demo_start)begin demo_state<=1;demo_ticks<=0;end
     else if(continuous_mode&&sequence_valid&&!sequence_q&&valid_words(sequence_count,sequence_words))begin
      sequence_buffer<=sequence_words;sequence_length<=sequence_count;sequence_index<=0;
      last_words<=sequence_words;last_count<=sequence_count;sequence_job<=1;
      flow<=LAUNCH;played_count<=played_count+1'b1;
     end else if(audition)begin
      if(continuous_mode)begin
       if(valid_words(last_count,last_words))begin
        sequence_buffer<=last_words;sequence_length<=last_count;sequence_index<=0;
        sequence_job<=1;flow<=LAUNCH;played_count<=played_count+1'b1;
       end
      end else begin
       word_id<=mapped(audition_index);audition_index<=audition_index==23?0:audition_index+1'b1;
       sequence_job<=0;flow<=LAUNCH;played_count<=played_count+1'b1;
      end
     end else if(!continuous_mode&&result_valid&&!result_q&&quality&&candidate<24)begin
      word_id<=mapped(candidate);sequence_job<=0;flow<=LAUNCH;played_count<=played_count+1'b1;
     end else if(!continuous_mode&&boot_pending&&boot_ticks==CLOCK_HZ-1)begin
      word_id<=15;sequence_job<=0;flow<=LAUNCH;boot_pending<=0;played_count<=played_count+1'b1;
     end
    end
    LAUNCH:if(!player_busy)begin
     player_bank<=sequence_job;
     player_clip<=sequence_job?{2'b00,sequence_buffer[sequence_index*3+:3]}:word_id;
     player_start<=1;flow<=WAIT_BUSY;
    end
    WAIT_BUSY:if(player_busy)flow<=WAIT_DONE;
    WAIT_DONE:if(player_done)begin
     if(sequence_job&&sequence_index+1'b1<sequence_length)begin
      sequence_index<=sequence_index+1'b1;flow<=LAUNCH;
     end else begin
      flow<=IDLE;
      if(demo_state==3)demo_state<=4;
     end
    end
   endcase
  end
 end
 reg sample_half=0;
 always @(posedge clk)if(stop)sample_half<=0;else if(sample_req)sample_half<=!sample_half;
 wire decode_req=sample_req&&sample_half;
 wire[16:0] rom_address;wire rom_bank;
 wire[3:0] word_data,token_data;
 wire[15:0] pcm;
 audio_adpcm_rom word_rom(clk,rom_address,word_data);
 sentence_adpcm_rom token_rom(clk,rom_address[15:0],token_data);
 unified_adpcm_player player(.clk(clk),.rst_n(!stop),.play_start(player_start&&!stop),
  .sample_req(decode_req),.clip_bank(player_bank),.clip_id(player_clip),
  .rom_data(rom_bank?token_data:word_data),.rom_address(rom_address),.rom_bank(rom_bank),
  .pcm_sample(pcm),.busy(player_busy),.done(player_done));
 i2s_tx #(.HALF_DIV(HALF_DIV)) tx(.clk(clk),.rst_n(!rst),
  .pcm_sample(player_busy&&!stop?pcm:16'd0),.sample_req(sample_req),
  .bclk(bclk),.lrclk(lrclk),.din(din));
endmodule
`default_nettype wire
