// 122.181818 MHz parent, 12 ticks per pixel (10.181818 MHz), P4 translator groups staggered. RGB bits settle sequentially before DCLK falls.
// Constant RGB is maintained through blanking for the solid tests.
module touch_edge_panel #(
 parameter HS=48, HB=40, HF=40, VS=3, VB=29, VF=13,
 parameter CHANGE_FRAMES=82
) (
 input wire pixel_clk, locked,pause,
 input wire continuous_mode,
 input wire[2:0]continuous_state,input wire[4:0]continuous_count,input wire[47:0]continuous_words,input wire continuous_accepted,
 input wire [2:0] control_view,
 input wire [7:0] control_threshold,
 input wire control_median,input wire[4:0] feature_state,
 input wire [10:0] gesture_state,
 input wire [6:0] advanced_state,
 input wire [31:0] history_ids,
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
 wire [23:0] ui_color;reg[4:0] feature_frame=0;
 (* async_reg="true", syn_srlstyle="registers" *)reg[1:0]mode_sync=0;
 reg mode_frame=0;
 always @(posedge pixel_clk)begin
  if(!ready[1])begin mode_sync<=0;mode_frame<=0;end
  else begin mode_sync<={mode_sync[0],continuous_mode};
   if(phase==0&&h==HT-1&&v==VT-1)mode_frame<=mode_sync[1];
  end
 end
 always@(posedge pixel_clk)if(!ready[1])feature_frame<=0;else if(phase==0&&h==HT-1&&v==VT-1)feature_frame<=feature_state;
 touch_edge_pixel ui(.clk(pixel_clk),.x(x),.y(y),.view(control_view),
 .feature_state(feature_frame),.threshold(control_threshold),.median(control_median),.gesture_state(mode_frame?{(continuous_state!=0),(continuous_state==6),(continuous_state==2||continuous_state==3),8'd0}:gesture_state),.advanced_state(advanced_state),.history_ids(history_ids),.status(ui_status),
 .active(ui_active),.tx(ui_x),.ty(ui_y),.color(ui_color));
 wire continuous_enable;wire[23:0]continuous_color;
 continuous_lcd_overlay continuous_overlay(.clk(pixel_clk),.x(x),.y(y),.continuous_mode(mode_frame),.advanced_page(advanced_state[6]),.state(continuous_state),.token_count(continuous_count),.token_words(continuous_words),.result_accepted(continuous_accepted),.enabled(continuous_enable),.color(continuous_color));
 // Retain the existing explicit 8-second-demo message as one unbroken area.
 wire demo_top=feature_frame[2:0]!=0&&x>=24&&x<610&&y>=68&&y<110;
 always @* color=continuous_enable&&!demo_top?continuous_color:ui_color;
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









