`timescale 1ns/1ps
`default_nettype none
// 2PPC HDMI-only OSD; one-cycle video/DE/HS/VS matched latency.
// Width/height come from active DE, published only after a nonempty frame.
module continuous_hdmi_osd(input wire clk,rst,input wire[47:0]rgb,
 input wire hs,vs,de,input wire[2:0]state,input wire[4:0]count,
 input wire[47:0]words,input wire accepted,input wire continuous_mode,
 output wire[47:0]out_rgb,output reg out_hs,out_vs,out_de,
 output reg[15:0]active_width,active_height);
 initial begin active_width=0;active_height=0;end
 reg vq=0,dq=0;reg[15:0]x=0,y=0,max_width=0;
 reg[2:0]state_s=0;reg[4:0]count_s=0;reg[47:0]words_s=0;reg accepted_s=0;
 // Frame-atomic mode switch: static mode keeps only the resolution label.
 reg continuous_mode_s=0;
 reg[15:0]width_bcd=0,height_bcd=0;
 reg[15:0]wb=0,hb=0,ws=0,hh=0;reg[4:0]convert=0;
 function[15:0]add3(input[15:0]q);reg[15:0]z;begin
 z=q;if(q[3:0]>=5)z[3:0]=q[3:0]+3;if(q[7:4]>=5)z[7:4]=q[7:4]+3;
 if(q[11:8]>=5)z[11:8]=q[11:8]+3;if(q[15:12]>=5)z[15:12]=q[15:12]+3;add3=z;end endfunction
 wire[15:0]wa=add3(wb),ha=add3(hb);
 always @(posedge clk)begin
 if(rst)begin vq<=0;dq<=0;x<=0;y<=0;max_width<=0;active_width<=0;active_height<=0;
 state_s<=0;count_s<=0;words_s<=0;accepted_s<=0;continuous_mode_s<=0;width_bcd<=0;height_bcd<=0;wb<=0;hb<=0;ws<=0;hh<=0;convert<=0;end
 else begin
 vq<=vs;dq<=de;
 if(convert!=0)begin
 wb<={wa[14:0],ws[15]};hb<={ha[14:0],hh[15]};ws<=ws<<1;hh<=hh<<1;convert<=convert-1'b1;
 if(convert==1)begin width_bcd<={wa[14:0],ws[15]};height_bcd<={ha[14:0],hh[15]};end end

 if(de)x<=x+2;else x<=0;
 if(dq&&!de)begin y<=y+1'b1;if(x>max_width)max_width<=x;end
 if(vs&&!vq)begin
 if(y!=0&&max_width!=0)begin active_width<=max_width;active_height<=y;ws<=max_width;hh<=y;wb<=0;hb<=0;convert<=16;end
 x<=0;y<=0;max_width<=0;state_s<=state;count_s<=count;words_s<=words;accepted_s<=accepted;continuous_mode_s<=continuous_mode;
 end end end
 // 56 glyphs x 16 rows x 16 bits = 14,336 bits; nearest-neighbour x3
 // preserves the 48x48 screen cells without storing the enlarged bitmap.
 (* syn_romstyle="block_rom" *)reg[15:0]font[0:895];
 initial $readmemh("continuous_osd_font16.mem",font);
 reg[7:0]glyph;reg area;reg[5:0]gy;reg[4:0]slot;reg[2:0]token;
 wire[15:0]lx=x-16;wire[3:0]column=lx/48;wire[5:0]gx=lx%48;
 wire[5:0]state_index=column+((y>=64)?10:0);
 wire[5:0]word_index=((y-136)/48)*10+column;
 function[7:0]digit(input[3:0]n);begin case(n)
4'd0:digit=8'd45;
4'd1:digit=8'd47;
4'd2:digit=8'd48;
4'd3:digit=8'd49;
4'd4:digit=8'd50;
4'd5:digit=8'd51;
4'd6:digit=8'd52;
4'd7:digit=8'd53;
4'd8:digit=8'd54;
4'd9:digit=8'd55;
default:digit=0;endcase end endfunction
 always @*begin glyph=0;area=0;gy=0;slot=0;token=0;
 if(continuous_mode_s&&de&&x>=16&&x<496&&y>=16&&y<112)begin
 area=1;gy=(y-16)%48;case(state_s)
3'd0:case(state_index)
6'd0:glyph=8'd1;
6'd1:glyph=8'd2;
6'd2:glyph=8'd3;
6'd3:glyph=8'd4;
6'd4:glyph=8'd5;
default:glyph=0;endcase
3'd1:case(state_index)
6'd0:glyph=8'd6;
6'd1:glyph=8'd7;
6'd2:glyph=8'd8;
6'd3:glyph=8'd9;
6'd4:glyph=8'd10;
6'd5:glyph=8'd11;
6'd6:glyph=8'd12;
6'd7:glyph=8'd13;
6'd8:glyph=8'd14;
default:glyph=0;endcase
3'd2:case(state_index)
6'd0:glyph=8'd15;
6'd1:glyph=8'd16;
6'd2:glyph=8'd13;
6'd3:glyph=8'd14;
6'd4:glyph=8'd8;
6'd5:glyph=8'd17;
6'd6:glyph=8'd18;
6'd7:glyph=8'd9;
6'd8:glyph=8'd10;
6'd9:glyph=8'd19;
6'd10:glyph=8'd20;
default:glyph=0;endcase
3'd3:case(state_index)
6'd0:glyph=8'd15;
6'd1:glyph=8'd16;
6'd2:glyph=8'd21;
6'd3:glyph=8'd22;
6'd4:glyph=8'd23;
6'd5:glyph=8'd24;
6'd6:glyph=8'd25;
6'd7:glyph=8'd26;
default:glyph=0;endcase
3'd4:case(state_index)
6'd0:glyph=8'd21;
6'd1:glyph=8'd22;
6'd2:glyph=8'd19;
6'd3:glyph=8'd27;
6'd4:glyph=8'd8;
default:glyph=0;endcase
3'd5:case(state_index)
6'd0:glyph=8'd28;
6'd1:glyph=8'd29;
6'd2:glyph=8'd30;
6'd3:glyph=8'd31;
6'd4:glyph=8'd19;
6'd5:glyph=8'd27;
default:glyph=0;endcase
3'd6:case(state_index)
6'd0:glyph=8'd21;
6'd1:glyph=8'd22;
6'd2:glyph=8'd32;
6'd3:glyph=8'd33;
6'd4:glyph=8'd8;
6'd5:glyph=8'd24;
6'd6:glyph=8'd34;
6'd7:glyph=8'd35;
default:glyph=0;endcase
 default:glyph=0;endcase
 end else if(continuous_mode_s&&de&&x>=16&&x<496&&y>=136&&y<328&&accepted_s)begin
 area=1;gy=(y-136)%48;slot=word_index>>1;
 if(word_index<32&&slot<count_s)begin token=words_s[slot*3+:3];case(token)
3'd1:glyph=word_index[0]?8'd37:8'd36;
3'd2:glyph=word_index[0]?8'd0:8'd38;
3'd3:glyph=word_index[0]?8'd0:8'd39;
3'd4:glyph=word_index[0]?8'd0:8'd40;
3'd5:glyph=word_index[0]?8'd42:8'd41;
 default:glyph=0;endcase end
 end else if(de&&x>=16&&x<160&&y>=352&&y<400)begin
 area=1;gy=y-352;case(column)
4'd0:glyph=8'd43;
4'd1:glyph=8'd44;
4'd2:glyph=8'd8;
 default:glyph=0;endcase
 end else if(de&&x>=16&&x<448&&y>=400&&y<448)begin
 area=1;gy=y-400;case(column)
4'd0:glyph=digit(width_bcd[12+:4]);
4'd1:glyph=digit(width_bcd[8+:4]);
4'd2:glyph=digit(width_bcd[4+:4]);
4'd3:glyph=digit(width_bcd[0+:4]);
4'd4:glyph=8'd46;
4'd5:glyph=digit(height_bcd[12+:4]);
4'd6:glyph=digit(height_bcd[8+:4]);
4'd7:glyph=digit(height_bcd[4+:4]);
4'd8:glyph=digit(height_bcd[0+:4]);
 default:glyph=0;endcase end end
 wire[3:0]font_y=gy/3;
 // Compute both pixels separately: x=2/3, 8/9, ... straddle a scale cell.
 // All text cells start at even x and are 48 pixels wide, so a 2PPC pair
 // never straddles a glyph boundary (last pair is gx=46,47).
 wire[3:0]font_x0=gx/3;
 wire[3:0]font_x1=(gx+6'd1)/3;
 reg[15:0]bits;reg[3:0]font_x0_q,font_x1_q;reg area_q;reg[47:0]rgb_q;reg[23:0]ink_q;
 always @(posedge clk)begin
 bits<=font[{glyph,4'b0000}+font_y];font_x0_q<=font_x0;font_x1_q<=font_x1;area_q<=area;
 rgb_q<=rgb;out_hs<=hs;out_vs<=vs;out_de<=de;
 ink_q<=continuous_mode_s&&state_s==4&&accepted_s?24'h28ff98:continuous_mode_s&&state_s==6?24'hff6060:24'hffffff;
 if(rst)begin area_q<=0;rgb_q<=0;out_hs<=1;out_vs<=1;out_de<=0;end
 end
 wire[23:0]a=bits[15-font_x0_q]?ink_q:24'h102438;
 wire[23:0]b=bits[15-font_x1_q]?ink_q:24'h102438;
 assign out_rgb=area_q?{b,a}:rgb_q;
endmodule
`default_nettype wire
