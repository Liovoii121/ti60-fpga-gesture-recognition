`timescale 1ns/1ps
`default_nettype none
// Fixed640 capture/inference. Display current-mode candidates; all other active classes still compete as rejection evidence.
module static11_job_control #(
 parameter integer MIN_SCORE=-128,MIN_MARGIN=256
)(
 input wire clk,rst,model_ready,fault,key_valid,input wire [3:0] key_code,
 input wire snapshot_ready,snapshot_done,snapshot_quality,
 input wire [31:0] snapshot_epoch,
 input wire engine_ready,engine_idle,engine_result_valid,
 input wire [31:0] engine_result_epoch,input wire [223:0] engine_result_scores,
 output reg snapshot_request,snapshot_cancel,snapshot_release,engine_start,engine_cancel,
 output wire engine_result_ready,output reg [31:0] epoch,
 output reg [6:0] snapshot_window_id,output wire busy,
 output wire [13:0] ui_control,output reg [4:0] candidate,
 output reg signed [8:0] margin,output reg signed [7:0] best_score,
 output reg [6:0] best_window,output reg scan_done
);
 localparam IDLE=0,NEXT=1,SNAPSHOT=2,START_ENGINE=3,INFER=4,DRAIN=5,FAULT=6,REDUCE=7,COMMIT=8;
 reg [3:0] state;
 reg [4:0] target,sweep_class;
 reg searching,seen,quality,accepted,finish,have_result;
 reg signed [8:0] sweep_margin;
 reg signed [7:0] sweep_score;
 reg [6:0] sweep_window;
 // Consume one class per clock. The former eleven-comparator chain is
 // too long for 148.8 MHz; ranking and tie behavior remain identical.
 reg signed [8:0] best,second,outside_best;
 reg [4:0] winner;
 reg [223:0] pending_scores;
 reg [4:0] reduce_index;
 wire signed [8:0] s=$signed(pending_scores[7:0]);
 wire class_in_mode=(target==0&&reduce_index<10)||
                       (target==1&&reduce_index>=10&&reduce_index<20)||
                       (target==2&&reduce_index>=20&&reduce_index<24);
 wire signed [8:0] competitor=second>outside_best?second:outside_best;
 wire signed [8:0] result_margin=best-competitor;
 wire improves=!have_result||result_margin>sweep_margin||
                (result_margin==sweep_margin&&best>sweep_score);
 assign busy=searching;
 assign engine_result_ready=state==INFER||state==DRAIN||state==FAULT;
 assign ui_control={busy,accepted,quality,seen,candidate,target};
 always @(posedge clk)begin
  snapshot_request<=0;snapshot_cancel<=0;snapshot_release<=0;engine_start<=0;engine_cancel<=0;scan_done<=0;
  if(rst)begin
   best<=-256;second<=-256;outside_best<=-256;winner<=31;pending_scores<=0;reduce_index<=0;
   state<=IDLE;target<=0;candidate<=31;seen<=0;quality<=0;accepted<=0;epoch<=0;
   snapshot_window_id<=0;searching<=0;finish<=0;margin<=0;best_score<=0;best_window<=0;
   have_result<=0;sweep_class<=31;sweep_margin<=-256;sweep_score<=-128;sweep_window<=0;
  end else if(fault)begin
   if(state!=FAULT)begin epoch<=epoch+1'b1;engine_cancel<=1;snapshot_cancel<=1;end
   state<=FAULT;searching<=0;candidate<=31;seen<=0;quality<=0;accepted<=0;
   margin<=0;best_score<=0;best_window<=0;
   have_result<=0;sweep_class<=31;sweep_margin<=-256;sweep_score<=-128;sweep_window<=0;
  end else if(key_valid&&key_code==12&&state!=FAULT)begin
   epoch<=epoch+1'b1;engine_cancel<=1;snapshot_cancel<=1;
   candidate<=31;seen<=0;quality<=0;accepted<=0;searching<=0;have_result<=0;finish<=1;state<=DRAIN;
   sweep_class<=31;sweep_margin<=-256;sweep_score<=-128;sweep_window<=0;
   margin<=0;best_score<=0;best_window<=0;
  end else case(state)
   IDLE:if(key_valid&&model_ready)case(key_code)
    7:begin target<=target==0?2:target-1'b1;candidate<=31;seen<=0;accepted<=0;end
    11:begin target<=target==2?0:target+1'b1;candidate<=31;seen<=0;accepted<=0;end
    3:begin
     snapshot_window_id<=0;searching<=1;seen<=0;quality<=0;accepted<=0;candidate<=31;
     margin<=0;best_score<=0;best_window<=0;
     have_result<=0;sweep_class<=31;sweep_margin<=-256;sweep_score<=-128;sweep_window<=0;finish<=0;state<=NEXT;
    end
   endcase
   NEXT:if(snapshot_ready&&engine_idle&&model_ready)begin
    epoch<=epoch+1'b1;snapshot_request<=1;state<=SNAPSHOT;
   end
   SNAPSHOT:if(snapshot_done&&snapshot_epoch==epoch)begin
    if(snapshot_quality)state<=START_ENGINE;
    else begin
     state<=DRAIN;finish<=1;searching<=0;have_result<=0;
     seen<=1;quality<=0;accepted<=0;candidate<=31;scan_done<=1;
     sweep_class<=31;sweep_margin<=-256;sweep_score<=-128;sweep_window<=0;
     margin<=0;best_score<=0;best_window<=0;
    end
   end
   START_ENGINE:if(engine_ready)begin engine_start<=1;state<=INFER;end
   INFER:if(engine_result_valid&&engine_result_epoch==epoch)begin
    pending_scores<=engine_result_scores;
    best<=-256;second<=-256;outside_best<=-256;winner<=31;reduce_index<=0;state<=REDUCE;
   end
   REDUCE:begin
    if(class_in_mode)begin
     if(s>best)begin second<=best;best<=s;winner<=reduce_index;end
     else if(s>second)second<=s;
    end else if(s>outside_best)outside_best<=s;
    pending_scores<=pending_scores>>8;
    if(reduce_index==27)state<=COMMIT;
    else reduce_index<=reduce_index+1'b1;
   end
   COMMIT:begin
    if(improves)begin
     sweep_score<=best[7:0];sweep_margin<=result_margin;sweep_class<=winner;sweep_window<=snapshot_window_id;
    end
    have_result<=1;state<=DRAIN;finish<=1'b1;
   end
   DRAIN:if(engine_idle)begin
    // The bank release is delayed until the engine and responder are idle.
    if(!snapshot_ready)snapshot_release<=1;
    else if(!searching)state<=IDLE;
    else if(finish)begin
     best_score<=sweep_score;margin<=sweep_margin;best_window<=sweep_window;
     quality<=have_result;seen<=1;searching<=0;state<=IDLE;scan_done<=1;
     accepted<=have_result&&((target==0&&sweep_class<10)||(target==1&&sweep_class>=10&&sweep_class<20)||(target==2&&sweep_class>=20&&sweep_class<24))&&sweep_margin>0&&sweep_margin>=(target==0?MIN_MARGIN:4)&&sweep_score>=MIN_SCORE;
     // Display top target for a valid result; accepted retains the formal gate.
     candidate<=have_result?sweep_class:31;
    end else begin snapshot_window_id<=snapshot_window_id+1'b1;state<=NEXT;end
   end
   FAULT:begin end
   default:state<=FAULT;
  endcase
 end
endmodule
`default_nettype wire
