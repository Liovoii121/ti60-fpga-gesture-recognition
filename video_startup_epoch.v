`default_nettype none
// Startup only. Begin both pixel writer and identity stream at a full frame.
module video_startup_epoch(input wire camera_clk,resetn,ddr_ready,config_done,vsync,de,
 output wire accepted_vsync,accepted_de,output reg started=0);
 (* async_reg="true" *) reg [1:0] ready_sync=0;
 reg vs_q=0;
 always @(posedge camera_clk or negedge resetn)begin
  if(!resetn)begin ready_sync<=0;vs_q<=0;started<=0;end
  else begin
   ready_sync<={ready_sync[0],ddr_ready&&config_done};vs_q<=vsync;
   // A trailing DE at EOF is not a clean frame boundary. Wait for the next EOF.
   if(ready_sync[1]&&vs_q&&!vsync&&!de)started<=1;
  end
 end
 assign accepted_vsync=vsync&&started;
 assign accepted_de=de&&started;
endmodule
`default_nettype wire
