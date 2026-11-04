module sentence_ui_overlay(input wire clk,input wire [10:0] x,input wire [9:0] y,
 input wire [2:0] state,output reg enabled,output wire ink,output reg button);
 (* syn_romstyle="logic" *) reg [31:0] words[0:4607];
 initial $readmemh("sentence_text.mem",words);
 reg [31:0] data;reg [4:0] bit_index;reg valid;
 wire bottom=x>=24&&x<777&&y>=440&&y<476;
 wire top=state!=0&&x>=24&&x<610&&y>=68&&y<110;
 wire text_area=x>=144&&x<656&&y>=442&&y<474;
 wire result_area=state!=0&&x>=32&&x<544&&y>=72&&y<104;
 reg [3:0] line;
 always @*begin
  if(bottom)case(state)
   1:line=1;2:line=2;3:line=3;default:line=0;
  endcase
  else case(state)
   1:line=7;2:line=8;3,4:line=4;5:line=5;6:line=6;default:line=0;
  endcase
 end
 wire [10:0] xx=bottom?x-144:x-32;
 wire [9:0] yy=bottom?y-442:y-72;
 wire [12:0] address={line,9'b0}+{yy[4:0],4'b0}+xx[8:5];
 always @(posedge clk)begin
  data<=words[address<4608?address:0];bit_index<=31-xx[4:0];
  enabled<=bottom||top;button<=bottom;valid<=text_area||result_area;
 end
 assign ink=valid&&data[bit_index];
endmodule
