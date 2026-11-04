`timescale 1ns/1ps
`default_nettype none
// Monitor the final active-video stream immediately before TMDS encoding.
// Each DE clock carries TWO pixels. Raster integrity is not image quality.
// A held-data request/acknowledge mailbox transfers coherent counter snapshots.
module video_frame_monitor #(
 parameter W=1280,H=720,REF_HZ=96000000
)(input wire pixel_clk,pixel_rst,sys_clk,sys_resetn,
 input wire vs_n,de,input wire [15:0] source_id,
 input wire source_valid,live_mode,camera_vs,
 output wire [511:0] status);
 reg request=0;
 (* async_reg="true" *) reg [1:0] req_sync=0,ack_sync=0;
 (* async_reg="true" *) reg [2:0] camera_sync=0;
 (* async_reg="true" *) reg [15:0] id_meta=0,id_sync=0;
 reg ack=0,ack_seen=0;
 reg [319:0] pixel_snapshot=0,published=0;
 reg vs_q=1,de_q=0,primed=0,bad_line=0,vs_high_seen=0;
 reg [31:0] pixels=0,boundary_cycle=0,period=0;
 reg [31:0] sync_total=0,valid_total=0,bad_total=0;
 reg [31:0] fresh_total=0,repeat_total=0;
 reg [19:0] pairs=0,last_pairs=0;
 reg [11:0] line_pairs=0,lines=0,last_lines=0;
 reg [15:0] frame_id=0,last_fresh_id=0;
 reg frame_valid=0,frame_live=0,have_fresh=0;
 wire boundary=vs_high_seen&&vs_q&&!vs_n;
 wire complete_frame=(pairs==W*H/2)&&(lines==H)&&!bad_line&&!de_q&&!de;
 always @(posedge pixel_clk) begin
  if(pixel_rst) begin
   req_sync<=0;ack<=0;pixel_snapshot<=0;id_meta<=0;id_sync<=0;
   vs_q<=1;de_q<=0;primed<=0;bad_line<=0;vs_high_seen<=0;
   pixels<=0;boundary_cycle<=0;period<=0;
   sync_total<=0;valid_total<=0;bad_total<=0;fresh_total<=0;repeat_total<=0;
   pairs<=0;last_pairs<=0;line_pairs<=0;lines<=0;last_lines<=0;
   frame_id<=0;last_fresh_id<=0;frame_valid<=0;frame_live<=0;have_fresh<=0;
  end else begin
   req_sync<={req_sync[0],request};id_meta<=source_id;id_sync<=id_meta;
   pixels<=pixels+1'b1;vs_q<=vs_n;de_q<=de;
   if(vs_n)vs_high_seen<=1;
   if(de) begin
    pairs<=pairs+1'b1;line_pairs<=line_pairs+1'b1;
    if(pairs==0)begin frame_id<=id_sync;frame_valid<=source_valid;frame_live<=live_mode;end
    // Exclude a frame if UI changes out of live mode during active video.
    else begin frame_valid<=frame_valid&&source_valid;frame_live<=frame_live&&live_mode;end
   end
   if(de_q&&!de)begin
    lines<=lines+1'b1;line_pairs<=0;
    if(line_pairs!=W/2)bad_line<=1;
   end
   if(boundary)begin
    sync_total<=sync_total+1'b1;primed<=1;
    period<=pixels-boundary_cycle;boundary_cycle<=pixels;
    last_pairs<=pairs;last_lines<=lines;
    if(primed)begin
     if(complete_frame)begin
      valid_total<=valid_total+1'b1;
      if(frame_valid&&frame_live)begin
       if(!have_fresh||frame_id!=last_fresh_id)begin
        fresh_total<=fresh_total+1'b1;last_fresh_id<=frame_id;have_fresh<=1;
       end else repeat_total<=repeat_total+1'b1;
      end
     end else bad_total<=bad_total+1'b1;
    end
    pairs<=0;lines<=0;line_pairs<=0;bad_line<=0;frame_valid<=0;frame_live<=0;
   end
   if(req_sync[1]!=ack)begin
    pixel_snapshot<={{14'd0,frame_live,frame_valid,frame_id},pixels,period,
      {20'd0,last_lines},{12'd0,last_pairs},repeat_total,fresh_total,bad_total,valid_total,sync_total};
    ack<=req_sync[1];
   end
  end
 end
 reg [63:0] ref_cycles=0,published_ref=0;
 reg [31:0] second_counter=0,camera_total=0,published_camera=0,snapshot_seq=0;
 always @(posedge sys_clk)begin
  if(!sys_resetn)begin
   request<=0;ack_sync<=0;ack_seen<=0;camera_sync<=0;
   ref_cycles<=0;published_ref<=0;second_counter<=0;
   camera_total<=0;published_camera<=0;snapshot_seq<=0;published<=0;
  end else begin
   ref_cycles<=ref_cycles+1'b1;
   ack_sync<={ack_sync[0],ack};camera_sync<={camera_sync[1:0],camera_vs};
   if(camera_sync[2]&&!camera_sync[1])camera_total<=camera_total+1'b1;
   if(second_counter==REF_HZ-1)begin
    second_counter<=0;
    if(request==ack_sync[1])request<=!request;
   end else second_counter<=second_counter+1'b1;
   if(ack_sync[1]!=ack_seen)begin
    published<=pixel_snapshot;published_ref<=ref_cycles;
    published_camera<=camera_total;snapshot_seq<=snapshot_seq+1'b1;ack_seen<=ack_sync[1];
   end
  end
 end
 assign status={published,published_camera,snapshot_seq,published_ref,32'h00010001,32'h46505331};
endmodule
`default_nettype wire

