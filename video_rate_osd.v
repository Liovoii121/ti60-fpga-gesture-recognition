`timescale 1ns/1ps
`default_nettype none
// 16px ASCII glyphs scaled3x to48px; both2PPC lane bits are selected independently.
module video_rate_osd #(parameter CAM_Y=456,OUT_Y=512)(input wire clk,rst,input wire[47:0]rgb,
 input wire hs,vs,de,input wire[15:0]camera_fps,output_hz,input wire rate_valid,
 output wire[47:0]out_rgb,output reg out_hs,out_vs,out_de);
 reg vs_q=0,de_q=0;reg[15:0]x=0,y=0;
 reg[15:0]camera_bcd=0,output_bcd=0,cb=0,ob=0,cs=0,os=0;reg[4:0]convert=0;reg valid_s=0;
 function[15:0]add3(input[15:0]q);reg[15:0]z;begin z=q;
 if(q[3:0]>=5)z[3:0]=q[3:0]+3;if(q[7:4]>=5)z[7:4]=q[7:4]+3;
 if(q[11:8]>=5)z[11:8]=q[11:8]+3;if(q[15:12]>=5)z[15:12]=q[15:12]+3;add3=z;end endfunction
 wire[15:0]ca=add3(cb),oa=add3(ob);
 always @(posedge clk)begin
 if(rst)begin vs_q<=0;de_q<=0;x<=0;y<=0;camera_bcd<=0;output_bcd<=0;cb<=0;ob<=0;cs<=0;os<=0;convert<=0;valid_s<=0;end
 else begin vs_q<=vs;de_q<=de;if(de)x<=x+2;else x<=0;if(de_q&&!de)y<=y+1'b1;
 if(convert!=0)begin cb<={ca[14:0],cs[15]};ob<={oa[14:0],os[15]};cs<=cs<<1;os<=os<<1;convert<=convert-1'b1;
 if(convert==1)begin camera_bcd<={ca[14:0],cs[15]};output_bcd<={oa[14:0],os[15]};end end
 if(vs&&!vs_q)begin x<=0;y<=0;cs<=camera_fps;os<=output_hz;cb<=0;ob<=0;convert<=16;valid_s<=rate_valid;end
 end end
 (* syn_romstyle="block_rom" *)reg[15:0]font[0:383];initial $readmemh("rate_font.mem",font);
 function[7:0]digit_glyph(input[3:0]d);begin case(d)
4'd0:digit_glyph=8'd13;
4'd1:digit_glyph=8'd14;
4'd2:digit_glyph=8'd15;
4'd3:digit_glyph=8'd16;
4'd4:digit_glyph=8'd17;
4'd5:digit_glyph=8'd18;
4'd6:digit_glyph=8'd19;
4'd7:digit_glyph=8'd20;
4'd8:digit_glyph=8'd21;
4'd9:digit_glyph=8'd22;
 default:digit_glyph=0;endcase end endfunction
 wire[15:0]lx=x-16;wire[3:0]column=lx/48;
 wire output_line=y>=OUT_Y;reg[7:0]glyph;
 always @*begin glyph=0;if(!output_line)case(column)
4'd0:glyph=8'd1;
4'd1:glyph=8'd2;
4'd2:glyph=8'd3;
4'd3:glyph=valid_s?digit_glyph(camera_bcd[12+:4]):8'd23;
4'd4:glyph=valid_s?digit_glyph(camera_bcd[8+:4]):8'd23;
4'd5:glyph=valid_s?digit_glyph(camera_bcd[4+:4]):8'd23;
4'd6:glyph=valid_s?digit_glyph(camera_bcd[0+:4]):8'd23;
4'd7:glyph=8'd5;
4'd8:glyph=8'd6;
4'd9:glyph=8'd7;
default:glyph=0;endcase
if(output_line)case(column)
4'd0:glyph=8'd8;
4'd1:glyph=8'd9;
4'd2:glyph=8'd10;
4'd3:glyph=valid_s?digit_glyph(output_bcd[12+:4]):8'd23;
4'd4:glyph=valid_s?digit_glyph(output_bcd[8+:4]):8'd23;
4'd5:glyph=valid_s?digit_glyph(output_bcd[4+:4]):8'd23;
4'd6:glyph=valid_s?digit_glyph(output_bcd[0+:4]):8'd23;
4'd7:glyph=8'd11;
4'd8:glyph=8'd12;
default:glyph=0;endcase
 end
 wire area=de&&x>=16&&((x<496&&y>=CAM_Y&&y<CAM_Y+48)||(x<448&&y>=OUT_Y&&y<OUT_Y+48));
 wire[5:0]ly=output_line?y-OUT_Y:y-CAM_Y;wire[5:0]local_x=lx%48;reg[15:0]bits;reg[3:0]gx,gx1;reg area_q;reg[47:0]rgb_q;
 always @(posedge clk)begin bits<=font[{glyph,4'd0}+ly/3];gx<=local_x/3;gx1<=(local_x+1'b1)/3;area_q<=area;rgb_q<=rgb;out_hs<=hs;out_vs<=vs;out_de<=de;
 if(rst)begin area_q<=0;rgb_q<=0;out_hs<=1;out_vs<=1;out_de<=0;end end
 wire[23:0]c=bits[15-gx]?24'hffffff:24'h102438;
 wire[23:0]c1=bits[15-gx1]?24'hffffff:24'h102438;
 assign out_rgb=area_q?{c1,c}:rgb_q;
endmodule
`default_nettype wire
