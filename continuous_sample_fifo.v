`timescale 1ns/1ps
// Global reset only. Session cancellation drains samples; it never resets one
// side of a live asynchronous FIFO independently.
module continuous_sample_fifo(input wire pixel_clk,bus_clk,bus_reset,pixel_reset,
 input wire sample_valid,input wire[19:0] sample_data,
 output wire sample_ready,output reg overflow_pixel,
 output wire valid,output reg[19:0] data,input wire ready);
 reg[19:0] mem[0:127];
 reg[7:0] wp,wg,rp,rg;
 (* async_reg="true" *)reg[7:0] rg1,rg2,wg1,wg2;
 reg occupied;
 wire[7:0] wn=wp+1'b1;
 wire full=wg=={~rg2[7:6],rg2[5:0]};
 wire empty=rg==wg2;
 assign sample_ready=!full&&!pixel_reset;
 assign valid=occupied&&!bus_reset;
 always @(posedge pixel_clk or posedge pixel_reset)begin
  if(pixel_reset)begin wp<=0;wg<=0;rg1<=0;rg2<=0;overflow_pixel<=0;end
  else begin
   rg1<=rg;rg2<=rg1;
   if(sample_valid)begin
    if(full)overflow_pixel<=1;
    else begin mem[wp[6:0]]<=sample_data;wp<=wn;wg<=(wn>>1)^wn;end
   end
  end
 end
 wire[7:0] rn=rp+1'b1;
 always @(posedge bus_clk or posedge bus_reset)begin
  if(bus_reset)begin rp<=0;rg<=0;wg1<=0;wg2<=0;occupied<=0;data<=0;end
  else begin
   wg1<=wg;wg2<=wg1;
   if(!occupied||ready)begin
    if(!empty)begin data<=mem[rp[6:0]];rp<=rn;rg<=(rn>>1)^rn;occupied<=1;end
    else occupied<=0;
   end
  end
 end
endmodule
