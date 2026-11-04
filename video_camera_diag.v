`default_nettype none
module video_camera_diag(input wire camera_clk,sys_clk,resetn,raw_vsync,raw_de,accepted_vsync,accepted_de,
 output wire [31:0] raw_counts,accepted_counts);
 reg rv=0,av=0;reg [15:0] rf=0,rd=0,af=0,ad=0;
 reg [63:0] counts_gray=0;
 (* async_reg="true" *) reg [63:0] gray_meta=0,gray_sync=0;
 function [15:0] decode;input [15:0] g;integer i;begin decode[15]=g[15];for(i=14;i>=0;i=i-1)decode[i]=decode[i+1]^g[i];end endfunction
 always @(posedge camera_clk)begin
  if(!resetn)begin rv<=0;av<=0;rf<=0;rd<=0;af<=0;ad<=0;counts_gray<=0;end
  else begin
   rv<=raw_vsync;av<=accepted_vsync;
   if(raw_vsync&&!rv)rf<=rf+1'b1;if(raw_de)rd<=rd+1'b1;
   if(accepted_vsync&&!av)af<=af+1'b1;if(accepted_de)ad<=ad+1'b1;
   counts_gray<={rf^(rf>>1),rd^(rd>>1),af^(af>>1),ad^(ad>>1)};
  end
 end
 always @(posedge sys_clk)begin
  if(!resetn)begin gray_meta<=0;gray_sync<=0;end
  else begin gray_meta<=counts_gray;gray_sync<=gray_meta;end
 end
 assign raw_counts={decode(gray_sync[63:48]),decode(gray_sync[47:32])};
 assign accepted_counts={decode(gray_sync[31:16]),decode(gray_sync[15:0])};
endmodule
`default_nettype wire
