`timescale 1ns/1ps
`default_nettype none
// Count complete 4PPC RAW frames. HS closes a physical line; DE may have gaps.
// hs/vs/de MUST share the same crop-register latency.
// Effective counters include a line/frame closing on the current clock.
module camera_input_monitor #(parameter W=1280,H=720,REF_HZ=96000000)(
 input wire clk,resetn,vs,hs,de,sys_clk,sys_resetn,output wire[191:0]status,output reg[31:0]snapshot_sequence=0,output reg[63:0]snapshot_reference_cycles=0);
 reg vq=0,hq=0,primed=0,bad_frame=0;
 reg[31:0]good=0,bad=0,last_groups=0,last_lines=0,last_minmax=0;
 reg[19:0]groups=0;reg[11:0]lines=0,line_groups=0;
 reg[15:0]min_groups=16'hffff,max_groups=0;
 reg request=0,ack=0,seen=0;reg[31:0]timer=0;
 (* async_reg="true" *)reg[1:0]req_sync=0,ack_sync=0;
 reg[191:0]held=0,published=0;
 reg[63:0]reference_cycles=0;
 wire frame_end=vq&&!vs;
 wire close_line=hq&&!hs&&(vs||vq);
 // A final DE on the HS/VS falling edge belongs to the just-closing line.
 wire sample=de&&(vs||vq)&&(hs||hq);
 wire invalid_sample=de&&(!(vs||vq)||!(hs||hq));
 wire[20:0]next_groups={1'b0,groups}+sample;
 wire[12:0]next_line_groups={1'b0,line_groups}+sample;
 wire[12:0]next_lines={1'b0,lines}+close_line;
 wire line_bad=close_line&&(next_line_groups!=W/4);
 wire effective_bad=bad_frame||invalid_sample||line_bad||next_groups>W*H/4||next_line_groups>W/4||next_lines>H;
 wire[15:0]line_width={3'd0,next_line_groups};
 wire[15:0]next_min=close_line&&line_width<min_groups?line_width:min_groups;
 wire[15:0]next_max=close_line&&line_width>max_groups?line_width:max_groups;
 wire complete=next_groups==W*H/4&&next_lines==H&&!effective_bad&&(close_line||next_line_groups==0);
 always @(posedge clk)begin
  if(!resetn)begin
   vq<=0;hq<=0;primed<=0;bad_frame<=0;good<=0;bad<=0;
   groups<=0;lines<=0;line_groups<=0;min_groups<=16'hffff;max_groups<=0;
   last_groups<=0;last_lines<=0;last_minmax<=0;req_sync<=0;ack<=0;held<=0;
  end else begin
   vq<=vs;hq<=hs;req_sync<={req_sync[0],request};
   groups<=next_groups[19:0];lines<=next_lines[11:0];
   line_groups<=close_line?12'd0:next_line_groups[11:0];
   min_groups<=next_min;max_groups<=next_max;bad_frame<=effective_bad;
   if(frame_end)begin
    if(primed)begin if(complete)good<=good+1'b1;else bad<=bad+1'b1;end
    primed<=1;last_groups<={11'd0,next_groups};last_lines<={19'd0,next_lines};
    last_minmax<=next_lines==0?32'd0:{next_min,next_max};
    groups<=0;lines<=0;line_groups<=0;min_groups<=16'hffff;max_groups<=0;bad_frame<=0;
   end
   if(req_sync[1]!=ack)begin held<={32'h43414d31,last_minmax,last_lines,last_groups,bad,good};ack<=req_sync[1];end
  end
 end
 always @(posedge sys_clk)begin
  if(!sys_resetn)begin request<=0;ack_sync<=0;seen<=0;timer<=0;published<=0;snapshot_sequence<=0;snapshot_reference_cycles<=0;reference_cycles<=0;end
  else begin
   reference_cycles<=reference_cycles+1'b1;
   ack_sync<={ack_sync[0],ack};
   if(timer==REF_HZ-1)begin timer<=0;if(request==ack_sync[1])request<=!request;end
   else timer<=timer+1'b1;
   if(ack_sync[1]!=seen)begin published<=held;seen<=ack_sync[1];snapshot_sequence<=snapshot_sequence+1'b1;snapshot_reference_cycles<=reference_cycles;end
  end
 end
 assign status=published;
endmodule
`default_nettype wire
