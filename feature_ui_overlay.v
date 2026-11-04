module feature_ui_overlay(input wire clk,input wire[10:0]x,input wire[9:0]y,
 input wire[4:0]state,output reg area,output wire ink,output reg selected);
 (* syn_romstyle="logic" *)reg[31:0]words[0:639];
 initial $readmemh("feature_labels.mem",words);
 reg[31:0]data;reg[4:0]bitno;reg valid;
 wire col=x>=600;wire row=y>=220;
 wire box=(x>=408&&x<584||x>=600&&x<776)&&(y>=124&&y<188||y>=220&&y<284);
 wire[10:0]xx=x-(col?608:416);wire[9:0]yy=y-(row?236:140);
 wire text_area=box&&xx<160&&yy<32;
 wire[9:0]address=({row,col}*160)+(yy[4:0]*5)+xx[7:5];
 always @(posedge clk)begin
  data<=words[address<640?address:0];bitno<=31-xx[4:0];valid<=text_area;area<=box;
  selected<=!row?(col?state[4]:state[3]):(!col&&(state[2:0]==1||state[2:0]==3));
 end
 assign ink=valid&&data[bitno];
endmodule
