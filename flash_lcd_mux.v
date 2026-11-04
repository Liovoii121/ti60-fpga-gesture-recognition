`default_nettype none
// Board pins are physically shared. Explicit software release disables Flash
// immediately; two pixel-domain synchronizer cycles provide a high-Z gap before
// LCD ownership. No implicit timer. Only common board reset can reclaim Flash.
module flash_lcd_mux(input wire resetn,pixel_clk,pixel_resetn,flash_release,
 input wire cpu_cs_n,cpu_sclk,input wire [3:0] cpu_data,cpu_oe,
 input wire [7:0] lcd_r,lcd_g,lcd_b,
 output wire flash_cs_n,flash_sclk,output wire [7:0] pin_r,pin_g,
 output wire [3:0] pin_b,output wire [7:0] oe_r,oe_g,output wire [3:0] oe_b);
 (* async_reg="true" *) reg [1:0] released_pixel=0;
 always @(posedge pixel_clk)begin
  if(!pixel_resetn)released_pixel<=0;else released_pixel<={released_pixel[0],flash_release};
 end
 wire flash_owned=resetn&&!flash_release;
 wire lcd_owned=resetn&&pixel_resetn&&flash_release&&released_pixel[1];
 assign flash_cs_n=flash_owned?cpu_cs_n:1'b1;
 assign flash_sclk=flash_owned?cpu_sclk:1'b0;
 assign pin_r=lcd_owned?lcd_r:8'd0;
 assign pin_g=lcd_owned?lcd_g:flash_owned?{6'd0,cpu_data[1:0]}:8'd0;
 assign pin_b=lcd_owned?lcd_b[3:0]:flash_owned?{cpu_data[3:2],2'd0}:4'd0;
 assign oe_r=lcd_owned?8'hff:8'd0;
 assign oe_g=lcd_owned?8'hff:flash_owned?{6'd0,cpu_oe[1:0]}:8'd0;
 assign oe_b=lcd_owned?4'hf:flash_owned?{cpu_oe[3:2],2'd0}:4'd0;
endmodule
`default_nettype wire
