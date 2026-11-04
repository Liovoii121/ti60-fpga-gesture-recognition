`timescale 1ns/1ps
`default_nettype none
// Camera and display snapshots are independent held-data publishers.
// Never sample camera data on a display event. Normalize each own count/time.
module frame_rate_window #(parameter REF_HZ=96000000)(
 input wire clk,rst,input wire[31:0]snapshot_seq,camera_good,output_good,
 input wire camera_snapshot_valid,
 input wire[31:0]camera_snapshot_seq,
 input wire[63:0]camera_reference_cycles,output_reference_cycles,
 output reg[15:0]camera_fps=0,output_hz=0,output reg valid=0,toggle=0);
 reg[31:0]camera_seen=0,output_seen=0,camera_previous=0,output_previous=0;
 reg[63:0]camera_time=0,output_time=0;
 reg camera_primed=0,output_primed=0;
 reg[31:0]camera_watchdog=0,output_watchdog=0;
 reg camera_pending=0,output_pending=0;
 reg[31:0]camera_job_delta=0,output_job_delta=0;
 reg[63:0]camera_job_time=0,output_job_time=0;
 reg[15:0]camera_calculated=0,output_calculated=0;
 reg camera_valid=0,output_valid=0;
 wire camera_event=camera_snapshot_seq!=camera_seen;
 wire output_event=snapshot_seq!=output_seen;
 localparam IDLE=0,MULTIPLY=1,ROUND=2,DIVIDE=3;
 reg[1:0]state=IDLE;reg target_camera=0;
 reg[31:0]job_delta=0,divisor=0;
 reg[63:0]product=0,dividend=0,quotient=0;
 reg[32:0]remainder=0;reg[5:0]bit_index=0;
 wire[32:0]shifted_remainder={remainder[31:0],dividend[63]};
 wire subtract=shifted_remainder>={1'b0,divisor};
 wire[63:0]next_quotient={quotient[62:0],subtract};
 function time_valid(input[63:0]elapsed);
 begin time_valid=elapsed>=REF_HZ/4&&elapsed<=64'd8*REF_HZ&&elapsed[63:32]==0;end
 endfunction
 // Wait after the last calculation change, then publish one stable mailbox.
 // This prevents two close publisher events from cancelling a CDC toggle.
 wire[32:0]calculated={camera_valid&&output_valid,camera_calculated,output_calculated};
 reg[32:0]observed=0;reg[3:0]publish_wait=0;
 always @(posedge clk)begin
  if(rst)begin
   camera_seen<=0;output_seen<=0;camera_previous<=0;output_previous<=0;camera_time<=0;output_time<=0;
   camera_primed<=0;output_primed<=0;camera_watchdog<=0;output_watchdog<=0;
   camera_pending<=0;output_pending<=0;camera_job_delta<=0;output_job_delta<=0;camera_job_time<=0;output_job_time<=0;
   camera_calculated<=0;output_calculated<=0;camera_valid<=0;output_valid<=0;
   state<=IDLE;target_camera<=0;job_delta<=0;divisor<=0;product<=0;dividend<=0;quotient<=0;remainder<=0;bit_index<=0;
   camera_fps<=0;output_hz<=0;valid<=0;toggle<=0;observed<=0;publish_wait<=0;
  end else begin
   if(camera_watchdog<2*REF_HZ)camera_watchdog<=camera_watchdog+1'b1;
   if(output_watchdog<2*REF_HZ)output_watchdog<=output_watchdog+1'b1;
   if(camera_watchdog==2*REF_HZ-1)camera_valid<=0;
   if(output_watchdog==2*REF_HZ-1)output_valid<=0;
   if(!camera_snapshot_valid)begin camera_valid<=0;camera_primed<=0;camera_pending<=0;end
   if(camera_event)begin
    camera_seen<=camera_snapshot_seq;camera_watchdog<=0;
    camera_job_delta<=camera_good-camera_previous;camera_job_time<=camera_reference_cycles-camera_time;
    camera_previous<=camera_good;camera_time<=camera_reference_cycles;
    if(camera_primed&&camera_snapshot_valid)camera_pending<=1;
    else camera_valid<=0;
    camera_primed<=camera_snapshot_valid;
   end
   if(output_event)begin
    output_seen<=snapshot_seq;output_watchdog<=0;
    output_job_delta<=output_good-output_previous;output_job_time<=output_reference_cycles-output_time;
    output_previous<=output_good;output_time<=output_reference_cycles;
    if(output_primed)output_pending<=1;else output_valid<=0;
    output_primed<=1;
   end
   case(state)
    IDLE:begin
     if(camera_pending&&!camera_event)begin
      camera_pending<=0;
      if(time_valid(camera_job_time)&&camera_snapshot_valid)begin job_delta<=camera_job_delta;divisor<=camera_job_time[31:0];target_camera<=1;state<=MULTIPLY;end
      else camera_valid<=0;
     end else if(output_pending&&!output_event)begin
      output_pending<=0;
      if(time_valid(output_job_time))begin job_delta<=output_job_delta;divisor<=output_job_time[31:0];target_camera<=0;state<=MULTIPLY;end
      else output_valid<=0;
     end
    end
    MULTIPLY:begin product<={32'd0,job_delta}*REF_HZ;state<=ROUND;end
    ROUND:begin dividend<=product+(divisor>>1);quotient<=0;remainder<=0;bit_index<=63;state<=DIVIDE;end
    DIVIDE:begin
     dividend<=dividend<<1;quotient<=next_quotient;
     remainder<=subtract?shifted_remainder-{1'b0,divisor}:shifted_remainder;
     if(bit_index==0)begin
      if(target_camera)begin camera_calculated<=next_quotient<=9999?next_quotient[15:0]:16'd0;camera_valid<=camera_snapshot_valid&&next_quotient<=9999;end
      else begin output_calculated<=next_quotient<=9999?next_quotient[15:0]:16'd0;output_valid<=next_quotient<=9999;end
      state<=IDLE;
     end else bit_index<=bit_index-1'b1;
    end
   endcase
   if(calculated!=observed)begin observed<=calculated;publish_wait<=8;end
   else if(publish_wait!=0)begin
    publish_wait<=publish_wait-1'b1;
    if(publish_wait==1)begin valid<=calculated[32];camera_fps<=calculated[31:16];output_hz<=calculated[15:0];toggle<=!toggle;end
   end
  end
 end
endmodule
`default_nettype wire
