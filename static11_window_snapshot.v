`timescale 1ns/1ps
`default_nettype none
// One sparse immutable bank, full raster validation, exact half-pixel taps.
module static11_window_snapshot(
 input wire clk,rst,request,cancel,release_bank,
 input wire [31:0] epoch,input wire [6:0] window_id,
 input wire frame_start,frame_end,de,frame_quality,
 input wire [15:0] x,y,input wire [31:0] pixel_rgb565,
 output wire request_ready,output reg done,locked,quality,
 output reg [31:0] snapshot_epoch,frame_id,
 output reg [6:0] snapshot_window,output reg [2:0] reason,
 input wire read_enable,input wire [15:0] read_address,
 output reg [15:0] read_data,output reg read_valid
);
 localparam IDLE=0,WAIT_FRAME=1,CAPTURE=2,LOCKED=3;
 reg [1:0] state;
 wire [15:0] wx,wy,ww,wh;wire [5:0] ws;
 wire [6:0] wp;wire [7:0] wc;wire window_valid;
 static11_window_schedule schedule(window_id,wx,wy,ww,wh,ws,wp,wc,window_valid);
 reg [15:0] origin_x,origin_y,next_x,next_y,first_x;
 reg [5:0] step;
 reg [6:0] col,pad_rows;
 reg [7:0] row;
 reg [7:0] content_rows;
 reg [14:0] stored_count;
 reg [20:0] count;
 reg [15:0] expected_x,expected_y;
 reg [31:0] saved_epoch,source_id;
 reg bad;
 reg [7:0] bank[0:4095];
 reg [31:0] top_row[0:63];
 reg [15:0] read_gray;
 always @* read_data=read_gray;
 reg [31:0] top_pair,bottom_pair;
 reg v1=0,v2=0,v3=0;
 reg [11:0] a1,a2,a3;
 reg [7:0] red_q,green_q,blue_q;
 reg [22:0] pr,pg,pb;
 wire [6:0] sr={2'd0,top_pair[15:11]}+{2'd0,top_pair[31:27]}+{2'd0,bottom_pair[15:11]}+{2'd0,bottom_pair[31:27]};
 wire [7:0] sg={2'd0,top_pair[10:5]}+{2'd0,top_pair[26:21]}+{2'd0,bottom_pair[10:5]}+{2'd0,bottom_pair[26:21]};
 wire [6:0] sb={2'd0,top_pair[4:0]}+{2'd0,top_pair[20:16]}+{2'd0,bottom_pair[4:0]}+{2'd0,bottom_pair[20:16]};
 wire [7:0] red={sr,1'b0},green=sg,blue={sb,1'b0};
 wire [22:0] gray_sum=pr+pg+pb+23'd16384;
 wire live=!rst&&!cancel&&epoch==saved_epoch;
 wire take=state==CAPTURE&&de&&live;
 wire selected=take&&x==next_x&&y==next_y&&row<{1'b0,pad_rows}+content_rows;
 wire padding=read_address[13:7]<pad_rows||{1'b0,read_address[13:7]}>={1'b0,pad_rows}+content_rows;
 assign request_ready=state==IDLE&&!rst&&!cancel;
 always @(posedge clk)begin
  if(rst||cancel||!live)begin v1<=0;v2<=0;v3<=0;end
  else begin
   v1<=selected&&stored_count<16384&&row[0];v2<=v1;v3<=v2;
   if(v1)begin red_q<=red;green_q<=green;blue_q<=blue;a2<=a1;end
   if(v2)begin pr<=red_q*15'd9798;pg<=green_q*15'd19235;pb<=blue_q*15'd3735;a3<=a2;end
   if(v3)bank[a3]<=gray_sum[22:15];
  end
  if(selected&&stored_count<16384)begin
   if(!row[0])top_row[col[6:1]]<=pixel_rgb565;
   else begin top_pair<=top_row[col[6:1]];bottom_pair<=pixel_rgb565;a1<={row[6:1],col[6:1]};end
  end
  if(read_enable&&locked&&live&&!release_bank&&read_address<4096)
   read_gray<={8'd0,bank[read_address[11:0]]};
  read_valid<=read_enable&&locked&&live&&!release_bank&&read_address<4096;
 end
 always @(posedge clk)begin
  done<=0;
  if(rst)begin
   state<=IDLE;done<=0;locked<=0;quality<=0;reason<=0;
   snapshot_epoch<=0;frame_id<=0;source_id<=0;saved_epoch<=0;snapshot_window<=0;
   count<=0;stored_count<=0;bad<=0;expected_x<=0;expected_y<=0;
   origin_x<=0;origin_y<=0;next_x<=0;next_y<=0;first_x<=0;
   step<=0;col<=0;row<=0;pad_rows<=0;content_rows<=0;
  end else begin
   if(frame_start)source_id<=source_id+1'b1;
   if(cancel||(state!=IDLE&&epoch!=saved_epoch))begin state<=IDLE;locked<=0;quality<=0;end
   else case(state)
    IDLE:if(request&&request_ready)begin
     saved_epoch<=epoch;snapshot_window<=window_id;state<=WAIT_FRAME;
     quality<=0;reason<=0;bad<=!window_valid;
     origin_x<=wx;origin_y<=wy;step<=ws;pad_rows<=wp;content_rows<=wc;
     // Align the 2-pixel tap to an even raster pair (step8 center straddles pairs).
     first_x<=(wx+{11'd0,ws[5:1]}-1'b1)&16'hfffe;
    end
    WAIT_FRAME:if(frame_start)begin
     state<=CAPTURE;count<=0;stored_count<=0;bad<=bad||de;
     expected_x<=0;expected_y<=0;frame_id<=source_id+1'b1;
     col<=0;row<=pad_rows;next_x<=first_x;
     next_y<=origin_y+{11'd0,step[5:1]}-1'b1;
    end
    CAPTURE:begin
     if(take)begin
      if(count>=2073600||x!=expected_x||y!=expected_y||x>=1920||y>=1080)bad<=1;
      if(count<2073601)count<=count+21'd2;
      if(expected_x==1918)begin expected_x<=0;expected_y<=expected_y+1'b1;end
      else expected_x<=expected_x+16'd2;
      if(selected&&stored_count<16384)begin
       stored_count<=stored_count+15'd2;
       if(col==126)begin
        col<=0;row<=row+1'b1;next_x<=first_x;
        next_y<=next_y+(row[0]?{10'd0,step}-1'b1:16'd1);
       end else begin col<=col+7'd2;next_x<=next_x+{10'd0,step};end
      end
     end
     if(frame_end||frame_start)begin
      state<=LOCKED;locked<=1;done<=1;snapshot_epoch<=saved_epoch;
      quality<=frame_quality&&!bad&&count==2073600&&stored_count=={content_rows,7'd0}&&!de&&!frame_start;
      reason<=frame_start?3:(!frame_quality?1:((bad||count!=2073600||stored_count!={content_rows,7'd0}||de)?2:0));
     end
    end
    LOCKED:if(release_bank)begin state<=IDLE;locked<=0;quality<=0;end
   endcase
  end
 end
endmodule
`default_nettype wire

