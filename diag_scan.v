`default_nettype none
// UPDATE requests a sys-clock snapshot; CAPTURE reads the previous settled snapshot.
// Only a magic-tagged command writes the stable color-settings mailbox.
module diag_scan(input wire bus_reset,
 input wire packet_busy_tck,packet_ack_tck,input wire[255:0]neural_status_tck,
 output reg[1023:0]packet_hold_tck=0,output reg packet_toggle_tck=0,
 input wire sys_clk,input wire [1023:0] live_state,input wire [1023:0] fps_state,
 input wire tck,capture,shift,update,sel,tdi,output wire tdo, output reg [63:0] color_mailbox=0, output reg color_toggle=0,output reg [1:0] audio_io_mode=0, output reg [31:0] exposure_mailbox=0, output reg exposure_toggle=0,input wire[1023:0]pixel_state);
 reg request=0;
 reg fps_page=0;reg neural_page=0;
 reg pixel_page=0;
 (* async_reg="true" *) reg [1:0] page_sync=0;
 (* async_reg="true" *) reg [1:0] pixel_page_sync=0;
 (* async_reg="true" *) reg [1:0] request_sync=0;
 reg request_seen=0;
 reg [1023:0] snapshot=0,scan=0;
 always @(posedge tck or posedge bus_reset)begin
  if(bus_reset)begin packet_hold_tck<=0;packet_toggle_tck<=0;neural_page<=0;request<=0;fps_page<=0;pixel_page<=0;scan<=0;end else begin
  if(sel&&update)begin
   request<=!request;
   if(scan[31:0]==32'h4e4c5354||scan[31:0]==32'h4e4c4454||scan[31:0]==32'h4e4c5153||scan[31:0]==32'h4e4c4142)begin
    if(!packet_busy_tck)begin packet_hold_tck<=scan;packet_toggle_tck<=!packet_toggle_tck;end
    if(scan[31:0]==32'h4e4c5153)neural_page<=1;
   end
   if(scan[31:0]==32'h46505350)begin fps_page<=scan[32];pixel_page<=0;neural_page<=0;end
   if(scan[31:0]==32'h50495850)begin pixel_page<=scan[32];neural_page<=0;end
   if(scan[31:0]==32'h5343544d)begin exposure_mailbox<=scan[63:32]|32'h80000000;exposure_toggle<=!exposure_toggle;end
   if(scan[31:0]==32'h53434558)begin exposure_mailbox<=scan[63:32];exposure_toggle<=!exposure_toggle;end
   if(scan[31:0]==32'h53434155)audio_io_mode<=scan[33:32];
   if(scan[31:0]==32'h53434346)begin color_mailbox<=scan[95:32];color_toggle<=!color_toggle;end
  end
  if(sel&&capture)scan<=neural_page?{766'd0,packet_ack_tck,packet_busy_tck,neural_status_tck}:snapshot;
  else if(sel&&shift)scan<={tdi,scan[1023:1]};
 end
 end
 always @(posedge sys_clk)begin
  page_sync<={page_sync[0],fps_page};
  pixel_page_sync<={pixel_page_sync[0],pixel_page};
  request_sync<={request_sync[0],request};
  if(request_sync[1]!=request_seen)begin
   snapshot<=pixel_page_sync[1]?pixel_state:(page_sync[1]?fps_state:live_state);request_seen<=request_sync[1];
  end
 end
 assign tdo=scan[0];
endmodule
`default_nettype wire
