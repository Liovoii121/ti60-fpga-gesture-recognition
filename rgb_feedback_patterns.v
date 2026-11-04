// 122.181818 MHz parent, 12 ticks per pixel (10.181818 MHz), P4 translator groups staggered. RGB bits settle sequentially before DCLK falls.
// Constant RGB is maintained through blanking for the solid tests.
module rgb_feedback_patterns #(
 parameter HS=48, HB=40, HF=40, VS=3, VB=29, VF=13,
 parameter CHANGE_FRAMES=82
) (
 input wire pixel_clk, locked,pause,
 input wire [1:0] touch_status,
 input wire touch_active,touch_seen,
 input wire [9:0] touch_x,touch_y,
 input wire [3:0] touch_fingers,
 input wire [15:0] touch_taps,
 input wire [4:0] touch_targets,
 output reg lcd_dclk,
 output reg [7:0] lcd_r,lcd_g,lcd_b,
 output reg lcd_hs,lcd_vs,lcd_de,
 output wire [3:0] diag_mode,
 output wire lcd_bl,touch_rst
);
 localparam HT=HS+HB+800+HF, VT=VS+VB+480+VF;
 reg [1:0] ready;
 reg [10:0] h;
 reg [9:0] v;
 reg [7:0] frames;
 reg [3:0] mode;
 reg [23:0] color; reg [23:0] pending; reg [4:0] phase;

 wire active=h>=HS+HB && h<HS+HB+800 && v>=VS+VB && v<VS+VB+480;
 wire [10:0] x=h-(HS+HB);
 wire [9:0] y=v-(VS+VB);
 function [23:0] palette(input [2:0] i);
   case(i)
     0:palette=24'hff0000;1:palette=24'h00ff00;2:palette=24'h0000ff;
     3:palette=24'hffffff;4:palette=24'h000000;5:palette=24'hffff00;
     6:palette=24'h00ffff;7:palette=24'hff00ff;
   endcase
 endfunction
 function [23:0] gray_palette(input [2:0] i, input full);
   reg [2:0] gr;
   begin
     gr=i^(i>>1);
     if(full) gray_palette={{8{gr[2]}},{8{gr[1]}},{8{gr[0]}}};
     else gray_palette={gr[2],7'b0,gr[1],7'b0,gr[0],7'b0};
   end
 endfunction
 reg [1:0] ui_status;
 reg ui_active,ui_seen;
 reg [9:0] ui_x,ui_y;
 reg [3:0] ui_fingers;
 reg [15:0] ui_taps;
 reg [4:0] ui_targets;
 wire [10:0] dx=(x>=ui_x)?x-ui_x:ui_x-x;
 wire [10:0] dy=(y>=ui_y)?y-ui_y:ui_y-y;
 reg [4:0] target_hit;
 always @* begin
   target_hit=0;
   if(x>=40 && x<120 && y>=40 && y<120) target_hit=5'b00001;
   if(x>=680 && x<760 && y>=40 && y<120) target_hit=5'b00010;
   if(x>=360 && x<440 && y>=200 && y<280) target_hit=5'b00100;
   if(x>=40 && x<120 && y>=360 && y<440) target_hit=5'b01000;
   if(x>=680 && x<760 && y>=360 && y<440) target_hit=5'b10000;
   color=24'h000020;
   if(x==0 || x==799 || y==0 || y==479) color=24'hffffff;
   if(target_hit!=0) color=(target_hit & ui_targets)!=0?24'h00ff00:24'h404040;
   if(y<24) case(ui_status)
     0:color=24'hffff00; // reset / boot
     1:color=24'h00ff00; // GT911 ID and 800x480 configuration verified
     2:color=24'hff0000; // missing device, NACK or bus timeout
     3:color=24'hff00ff; // incompatible configuration / invalid coordinates
   endcase
   // Up to five white blocks indicate current contact count.
   if(y>=28 && y<36 && x>=280 && x<520)
     color=((x-280)/48<ui_fingers && ((x-280)%48)<40)?24'hffffff:24'h000000;
   // Binary tap counter along bottom; marker stays at last valid point on release.
   if(y>=460 && y<475 && x>=16 && x<272)
     color=ui_taps[15-((x-16)/16)]?24'h00ffff:24'h202020;
   if(ui_seen && ((dx<=2 && dy<=18)||(dy<=2 && dx<=18)))
     color=ui_active?24'hffff00:24'h00ffff;
 end
 always @(posedge pixel_clk or negedge ready[1])
   if(!ready[1]) begin
     ui_status<=0;ui_active<=0;ui_seen<=0;ui_x<=400;ui_y<=240;
     ui_fingers<=0;ui_taps<=0;ui_targets<=0;
   end else if(phase==0 && h==HT-1 && v==VT-1) begin
     ui_status<=touch_status;ui_active<=touch_active;ui_seen<=touch_seen;
     ui_x<=touch_x;ui_y<=touch_y;ui_fingers<=touch_fingers;ui_taps<=touch_taps;
     ui_targets<=touch_targets;
   end
 always @(posedge pixel_clk or negedge locked)
   if (!locked) ready<=0; else ready<={ready[0],1'b1};
 always @(posedge pixel_clk or negedge ready[1]) begin
   if (!ready[1]) begin
     h<=0;v<=0;frames<=0;mode<=0;lcd_dclk<=0;phase<=0;pending<=0;
     lcd_r<=0;lcd_g<=0;lcd_b<=0;lcd_hs<=1;lcd_vs<=1;lcd_de<=0;
   end else if(pause && phase==11) begin
     // Diagnostic quiet interval: finish the current pixel then hold all RGB
     // signals and DCLK steady while the first GT911 registers are probed.
     lcd_dclk<=0;
   end else begin
          phase<=(phase==11)?0:phase+1'b1;
     if(phase==11) lcd_dclk<=0; if(phase==9) lcd_dclk<=1;
     // Spread updates across the P4 TXS groups; clock shares its group with R1..R5.
     if(phase==1) begin
       lcd_r[2]<=pending[18];
       lcd_b[0]<=pending[0];
       lcd_b[1]<=pending[1];
       lcd_g[0]<=pending[8];
     end
     if(phase==2) begin
       lcd_b[2]<=pending[2];
       lcd_r[0]<=pending[16];
     end
     if(phase==3) begin
       lcd_r[3]<=pending[19];
       lcd_b[3]<=pending[3];
       lcd_g[3]<=pending[11];
     end
     if(phase==4) begin
       lcd_b[6]<=pending[6];
       lcd_b[4]<=pending[4];
       lcd_r[6]<=pending[22];
     end
     if(phase==5) begin
       lcd_r[4]<=pending[20];
       lcd_b[5]<=pending[5];
       lcd_g[4]<=pending[12];
     end
     if(phase==6) begin
       lcd_g[1]<=pending[9];
       lcd_r[7]<=pending[23];
     end
     if(phase==7) begin
       lcd_r[5]<=pending[21];
       lcd_b[7]<=pending[7];
       lcd_g[6]<=pending[14];
       lcd_g[5]<=pending[13];
     end
     if(phase==8) begin
       lcd_g[7]<=pending[15]; lcd_g[2]<=pending[10];
     end
     if(phase==0) begin
     if(h==HT-1) begin
       h<=0;
       if(v==VT-1) begin
         v<=0;
         if(frames==CHANGE_FRAMES-1) begin frames<=0;mode<=mode+1'b1;end
         else frames<=frames+1'b1;
       end else v<=v+1'b1;
     end else h<=h+1'b1;
     if(active) begin pending<=color; lcd_r[1]<=color[17]; end
     lcd_hs<=h>=HS;lcd_vs<=v>=VS;lcd_de<=active;
     end
   end
 end
 assign diag_mode=mode;
 assign lcd_bl=ready[1];
 assign touch_rst=ready[1];
endmodule









