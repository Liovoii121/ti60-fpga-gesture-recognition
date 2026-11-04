// SC2210 register-table writer. 16-bit register, 8-bit value, 8-bit wire address.
// SDA and the top-level SCL pad must be open drain. Single master, no stretching.
// Three attempts per register; failure is sticky until reset.
`timescale 1ns/1ns
module i2c_timing_ctrl_reg16_dat8_wronly #(
    parameter CLK_FREQ=96000000,
    parameter I2C_FREQ=50000
)(
    input clk, input rst_n,
    output reg i2c_sclk,
    input i2c_sdat_IN,
    output i2c_sdat_OUT, output i2c_sdat_OE,
    input [8:0] i2c_config_size,
    output reg [8:0] i2c_config_index,
    input [31:0] i2c_config_data,
    output reg i2c_config_failed,
    output reg i2c_config_done
);
localparam QUARTER = CLK_FREQ/(4*I2C_FREQ);
localparam QW = QUARTER<2 ? 1 : $clog2(QUARTER);
localparam STARTUP = CLK_FREQ/100; // 10 ms; also used after software reset.
localparam DW = STARTUP<2 ? 1 : $clog2(STARTUP+1);
localparam WAIT=0, START=1, DATA=2, ACK=3, STOP0=4,
           STOP1=5, STOP2=6, GAP=7, HALT=8;
reg [3:0] state;
reg [QW-1:0] divider;
reg [DW-1:0] delay_count;
reg [1:0] phase, byte_index, retries;
reg [2:0] bit_index;
reg [31:0] word_latch;
reg sda_low,nack;
(* async_reg="true" *) reg [1:0] sda_sync;
assign i2c_sdat_OUT=1'b0;
assign i2c_sdat_OE=rst_n && sda_low;
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) sda_sync<=2'b11;
 else sda_sync<={sda_sync[0],i2c_sdat_IN};
end
always @(posedge clk or negedge rst_n) begin
 if(!rst_n) begin
  state<=WAIT;divider<=0;delay_count<=0;phase<=0;
  byte_index<=0;bit_index<=7;word_latch<=0;retries<=0;
  sda_low<=0;i2c_sclk<=1;nack<=0;
  i2c_config_index<=0;i2c_config_failed<=0;i2c_config_done<=0;
 end else if(state==WAIT) begin
  divider<=0;
  if(delay_count<STARTUP) delay_count<=delay_count+1'b1;
  else if(i2c_config_index==i2c_config_size) begin
   i2c_config_done<=1;state<=HALT;
  end else if(i2c_config_index==0 && !sda_sync[1]) begin
   i2c_config_failed<=1;state<=HALT; // A stuck-low bus is not an ACK.
  end else begin
   word_latch<=i2c_config_data;byte_index<=0;bit_index<=7;
   phase<=0;nack<=0;sda_low<=1;state<=START;
  end
 end else if(divider==QUARTER-1) begin
  divider<=0;
  case(state)
   START: begin i2c_sclk<=0;state<=DATA;phase<=0;end
   DATA: begin
    case(phase)
     0: begin i2c_sclk<=0;sda_low<=~word_latch[31];phase<=1;end
     1: begin i2c_sclk<=1;phase<=2;end
     2: phase<=3;
     3: begin
      i2c_sclk<=0;word_latch<={word_latch[30:0],1'b0};phase<=0;
      if(bit_index==0) state<=ACK;
      else bit_index<=bit_index-1'b1;
     end
    endcase
   end
   ACK: begin
    case(phase)
     0: begin sda_low<=0;phase<=1;end
     1: begin i2c_sclk<=1;phase<=2;end
     2: begin nack<=nack|sda_sync[1];phase<=3;end
     3: begin
      i2c_sclk<=0;phase<=0;bit_index<=7;
      if(byte_index==3) state<=STOP0;
      else begin byte_index<=byte_index+1'b1;state<=DATA;end
     end
    endcase
   end
   STOP0: begin i2c_sclk<=0;sda_low<=1;state<=STOP1;end
   STOP1: begin i2c_sclk<=1;state<=STOP2;end
   STOP2: begin sda_low<=0;state<=GAP;end
   GAP: begin
    if(nack) begin
     if(retries==2) begin i2c_config_failed<=1;state<=HALT;end
     else begin retries<=retries+1'b1;state<=WAIT;end
    end else begin
     retries<=0;i2c_config_index<=i2c_config_index+1'b1;
     // The table starts with software reset (0x0103=1).
     if(i2c_config_index==0) delay_count<=0;
     state<=WAIT;
    end
   end
   HALT: begin i2c_sclk<=1;sda_low<=0;end
   default: begin i2c_config_failed<=1;state<=HALT;end
  endcase
 end else divider<=divider+1'b1;
end
endmodule
