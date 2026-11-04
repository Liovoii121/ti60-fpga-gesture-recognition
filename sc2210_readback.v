// Read selected sensor registers after initialization. Single-master I2C, no stretching.
module sc2210_readback #(parameter CLK_FREQ=96000000, I2C_FREQ=50000, REG_COUNT=24, EXPOSURE_ONLY=0, TIMING_ONLY=0)(
 input [6:0] slave_address, input clk,resetn,enable,sda_in,output reg scl_release,
 output sda_low,output reg done,failed,output reg [191:0] values);
localparam Q=CLK_FREQ/(4*I2C_FREQ),QW=$clog2(Q);
localparam IDLE=0,START=1,TX=2,ACK=3,RS0=4,RS1=5,RS2=6,
 RX=7,NACK=8,STOP0=9,STOP1=10,STOP2=11,GAP=12,HALT=13;
reg [3:0] state=IDLE;
reg [QW-1:0] divider=0;
reg [1:0] phase=0,byte_no=0;
reg [2:0] bit_no=7;
reg [4:0] index=0;
reg [7:0] tx=0,rx=0;
reg low=0,reading=0,nack_seen=0;
(* async_reg="true" *) reg [1:0] sda_sync=3;
assign sda_low=resetn&&low;
function [15:0] address(input [4:0] i);
if(TIMING_ONLY)case(i)
0:address=16'h320c;1:address=16'h320d;2:address=16'h320e;3:address=16'h320f;
4:address=16'h3e00;5:address=16'h3e01;6:address=16'h3e02;default:address=0;
endcase
else if(EXPOSURE_ONLY)case(i)
0:address=16'h3e00;1:address=16'h3e01;2:address=16'h3e02;default:address=0;
endcase
else case(i)
0:address=16'h3107;
1:address=16'h3108;
2:address=16'h0100;
3:address=16'h3031;
4:address=16'h3200;
5:address=16'h3201;
6:address=16'h3202;
7:address=16'h3203;
8:address=16'h3204;
9:address=16'h3205;
10:address=16'h3206;
11:address=16'h3207;
12:address=16'h3208;
13:address=16'h3209;
14:address=16'h320a;
15:address=16'h320b;
16:address=16'h320c;
17:address=16'h320d;
18:address=16'h320e;
19:address=16'h320f;
20:address=16'h3211;
21:address=16'h3213;
22:address=16'h3e01;
23:address=16'h3e02;
default:address=0;
endcase
endfunction
wire [15:0] reg_address=address(index);
always @(posedge clk or negedge resetn)
 if(!resetn)sda_sync<=3;else sda_sync<={sda_sync[0],sda_in};
always @(posedge clk or negedge resetn) begin
 if(!resetn)begin
  state<=IDLE;divider<=0;phase<=0;byte_no<=0;bit_no<=7;index<=0;
  low<=0;scl_release<=1;reading<=0;nack_seen<=0;tx<=0;rx<=0;
  done<=0;failed<=0;values<=0;
 end else if(state==IDLE)begin
  if(enable)begin
   low<=1;tx<={slave_address,1'b0};byte_no<=0;bit_no<=7;phase<=0;
   reading<=0;nack_seen<=0;divider<=0;state<=START;
  end
 end else if(divider==Q-1)begin
  divider<=0;
  case(state)
   START:begin scl_release<=0;phase<=0;state<=TX;end
   TX:case(phase)
    0:begin low<=~tx[7];scl_release<=0;phase<=1;end
    1:begin scl_release<=1;phase<=2;end
    2:phase<=3;
    3:begin
     scl_release<=0;tx<={tx[6:0],1'b0};phase<=0;
     if(bit_no==0)state<=ACK;else bit_no<=bit_no-1'b1;
    end
   endcase
   ACK:case(phase)
    0:begin low<=0;phase<=1;end
    1:begin scl_release<=1;phase<=2;end
    2:begin nack_seen<=nack_seen|sda_sync[1];phase<=3;end
    3:begin
     scl_release<=0;phase<=0;bit_no<=7;
     if(nack_seen)state<=STOP0;
     else if(reading)state<=RX;
     else if(byte_no==2)state<=RS0;
     else begin
      tx<=byte_no==0?reg_address[15:8]:reg_address[7:0];
      byte_no<=byte_no+1'b1;state<=TX;
     end
    end
   endcase
   RS0:begin low<=0;scl_release<=0;state<=RS1;end
   RS1:begin scl_release<=1;state<=RS2;end
   RS2:begin low<=1;tx<={slave_address,1'b1};reading<=1;state<=START;end
   RX:case(phase)
    0:begin low<=0;phase<=1;end
    1:begin scl_release<=1;phase<=2;end
    2:begin rx<={rx[6:0],sda_sync[1]};phase<=3;end
    3:begin
     scl_release<=0;phase<=0;
     if(bit_no==0)state<=NACK;else bit_no<=bit_no-1'b1;
    end
   endcase
   NACK:case(phase)
    0:begin low<=0;phase<=1;end
    1:begin scl_release<=1;phase<=2;end
    2:phase<=3;
    3:begin scl_release<=0;phase<=0;state<=STOP0;end
   endcase
   STOP0:begin low<=1;scl_release<=0;state<=STOP1;end
   STOP1:begin scl_release<=1;state<=STOP2;end
   STOP2:begin low<=0;state<=GAP;end
   GAP:begin
    if(nack_seen)begin failed<=1;state<=HALT;end
    else begin
     values[index*8+:8]<=rx;
     if(index==REG_COUNT-1)begin done<=1;state<=HALT;end
     else begin index<=index+1'b1;state<=IDLE;end
    end
   end
   HALT:begin low<=0;scl_release<=1;end
   default:begin failed<=1;state<=HALT;end
  endcase
 end else divider<=divider+1'b1;
end
endmodule
