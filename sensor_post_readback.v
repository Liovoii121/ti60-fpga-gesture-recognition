`default_nettype none
// Serialize initialization -> full readback -> runtime exposure ownership.
// The initial address probe must not be mistaken for post-configuration proof.
module sensor_post_readback(input wire clk,resetn,init_done,init_failed,rb_done,rb_failed,
 output reg select_read=0,output reg reset_read=0,output wire runtime_ready);
 localparam WAIT_INIT=0,RESET_READ=1,READ=2,DONE=3;
 reg [1:0] state=WAIT_INIT;
 assign runtime_ready=state==DONE;
 always @(posedge clk or negedge resetn)begin
  if(!resetn)begin state<=WAIT_INIT;select_read<=0;reset_read<=0;end
  else case(state)
   WAIT_INIT:if(init_done&&!init_failed)begin
    select_read<=1;reset_read<=1;state<=RESET_READ;
   end
   RESET_READ:begin reset_read<=0;state<=READ;end
   READ:if(rb_done||rb_failed)begin select_read<=0;state<=DONE;end
   DONE:begin end
  endcase
 end
endmodule
`default_nettype wire
