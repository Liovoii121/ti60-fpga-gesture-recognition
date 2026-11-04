`timescale 1ns/1ps
module touch_edge_control(input wire clk,rst,input wire [1:0] status,
 input wire active,input wire [3:0] fingers,input wire [9:0] x,y,
 output reg [2:0] view,output reg [7:0] threshold,output reg median,
 input wire recognition_ready,recognition_busy,recognition_fault,
 input wire continuous_mode,continuous_recording,
 output reg gesture_key_valid,output reg [3:0] gesture_key_code,
 input wire frame_tick,frozen_ready,
 output reg canny_enable,output reg audition,demo_start,audio_stop,
 output reg advanced_page,freeze,compare,playback,output reg [1:0] history_offset);
 reg [4:0] play_count;
 reg held,armed;reg [4:0] pending;reg [15:0] event_count;
 reg [4:0] hit;
 always @* begin
 hit=0;
 if(!advanced_page && y>=124 && y<188) begin
 if(x>=24 && x<200)hit=1;
 else if(x>=216 && x<392)hit=2;
 else if(x>=408 && x<584)hit=3;
 else if(x>=600 && x<776)hit=4;
 end
 if(!advanced_page && y>=267 && y<332 && x>=44 && x<107)hit=5;
 if(!advanced_page && y>=267 && y<332 && x>=410 && x<473)hit=6;
 if(!advanced_page && y>=255 && y<309 && x>=513 && x<776)hit=7;
 if(y>=68 && y<110 && x>=408 && x<584)hit=24;
 if(y>=68 && y<110 && x>=620 && x<777)hit=11;
 if(advanced_page)begin
  if(y>=124 && y<188)begin
   if(x>=24 && x<200)hit=12;else if(x>=216 && x<392)hit=13;else if(x>=408&&x<584)hit=20;else if(x>=600&&x<776)hit=21;
  end
  if(y>=220 && y<284)begin
   if(x>=24 && x<200)hit=14;else if(x>=216 && x<392)hit=15;else if(x>=408&&x<584)hit=22;else if(x>=600&&x<776)hit=23;
  end
  if(y>=316 && y<366)begin
   if(x>=24 && x<200)hit=16;else if(x>=216 && x<392)hit=17;
   else if(x>=408 && x<584)hit=18;else if(x>=600 && x<776)hit=19;
  end
 end
 if(y>=440 && y<476 && x>=24 && x<777)hit=25;
 if(y>=379 && y<436)begin
 if(x>=24 && x<266)hit=8;
 else if(x>=282 && x<520)hit=9;
 else if(x>=536 && x<777)hit=10;
 end
 end
 always @(posedge clk) begin
 gesture_key_valid<=0;audition<=0;demo_start<=0;audio_stop<=0;
 if(!rst && frame_tick && playback && frozen_ready)begin
  if(play_count==11)begin play_count<=0;history_offset<=history_offset==0?2:history_offset-1'b1;end
  else play_count<=play_count+1'b1;
 end
 if(rst)begin canny_enable<=0;audition<=0;demo_start<=0;audio_stop<=0;view<=0;threshold<=48;median<=1;advanced_page<=0;freeze<=0;compare<=0;playback<=0;history_offset<=0;play_count<=0;gesture_key_valid<=0;gesture_key_code<=0;held<=0;armed<=0;pending<=0;event_count<=0;end
 else if(status!=1)begin held<=0;armed<=0;pending<=0;end
 else if(active && fingers!=1)begin armed<=0;pending<=0;held<=1;end
 else if(active && !held)begin held<=1;pending<=hit;armed<=hit!=0;end
 else if(active && hit!=pending)armed<=0;
 else if(!active && held)begin
 held<=0;armed<=0;pending<=0;
 if(armed)begin
 event_count<=event_count+1'b1;
 case(pending)
 25:begin gesture_key_valid<=1;gesture_key_code<=14;audio_stop<=1;view<=0;freeze<=0;playback<=0;compare<=0;history_offset<=0;end
 1:view<=0;2:view<=1;3:view<=2;4:view<=5;
 5:threshold<=threshold<4?0:threshold-4;
 6:threshold<=threshold>251?255:threshold+4;
 7:median<=!median;
 8:begin canny_enable<=0;view<=0;threshold<=48;median<=1;freeze<=0;compare<=0;playback<=0;history_offset<=0;gesture_key_valid<=1;gesture_key_code<=15;end
 9:if((continuous_mode&&continuous_recording)||
 (recognition_ready&&!recognition_busy&&!recognition_fault))begin
 gesture_key_valid<=1;gesture_key_code<=continuous_mode?13:3;view<=0;
 freeze<=0;playback<=0;compare<=0;history_offset<=0;end
 10:begin gesture_key_valid<=1;gesture_key_code<=12;end
 11:advanced_page<=!advanced_page;
 12:view<=3;13:view<=4;
 14:begin freeze<=!freeze;history_offset<=0;compare<=0;playback<=0;play_count<=0;end
 15:begin freeze<=0;history_offset<=0;compare<=0;playback<=0;end
 16:if(freeze && frozen_ready)begin history_offset<=history_offset==2?0:history_offset+1'b1;playback<=0;end
 17:if(freeze && frozen_ready)begin history_offset<=history_offset==0?2:history_offset-1'b1;playback<=0;end
 18:if(freeze && frozen_ready)begin compare<=!compare;if(!compare)view<=0;end
 19:if(freeze && frozen_ready)begin playback<=!playback;play_count<=0;compare<=0;end
 20:audition<=1;
 21:canny_enable<=!canny_enable;
 22:demo_start<=1;
 23:audio_stop<=1;
 24:if(!continuous_mode&&recognition_ready&&!recognition_busy&&!recognition_fault)begin gesture_key_valid<=1;gesture_key_code<=11;end
 endcase
 end
 end
 end
endmodule
