`default_nettype none
module color_pipeline #(parameter [63:0] DEFAULT=64'h139494951564b963)(input wire clk,rst_n,input wire [63:0] mailbox,input wire toggle,
 output reg [63:0] active=DEFAULT,
 input wire vs,hs,de,input wire [23:0] rgb,
 output wire ovs,ohs,ode,output reg [23:0] orgb);
 // Q8 gains/contrast/saturation; signed 9-bit brightness; Bayer selector.
 // User confirmed selector2 restores red/yellow/blue on the current native720p ROI.
 // Q8 WB R/G/B=325/250/325; contrast=473; brightness=105; saturation=256.
 // One DEFAULT drives power-up, reset, and staging; mailbox remains adjustable.
 (* async_reg="true" *) reg [2:0] sync_toggle=0;
 reg seen=0,pending=0,vsq=0;
 reg [63:0] staged=DEFAULT;
 reg [3:0] vpipe=0,hpipe=0,dpipe=0;
 reg [17:0] r1=0,g1=0,b1=0;
 reg [7:0] r2=0,g2=0,b2=0;
 reg signed [21:0] r3=0,g3=0,b3=0;
 wire [9:0] lsum={2'b0,r2}+{1'b0,g2,1'b0}+{2'b0,b2};
 wire signed [10:0] lum=$signed({3'b0,lsum[9:2]});
 function [7:0] clamp;
 input signed [31:0] val;
 begin if(val<0)clamp=0;else if(val>255)clamp=255;else clamp=val[7:0];end
 endfunction
 function [7:0] contrast;
 input [17:0] gain_pixel;
 input [9:0] scale;
 input signed [8:0] offset;
 reg signed [31:0] val;
 begin
 val=$signed({1'b0,gain_pixel})>>>8;
 val=(((val-128)*$signed({1'b0,scale}))>>>8)+128+offset;
 contrast=clamp(val);
 end
 endfunction
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin
 active<=DEFAULT;staged<=DEFAULT;sync_toggle<=0;seen<=0;pending<=0;vsq<=0;
 vpipe<=0;hpipe<=0;dpipe<=0;r1<=0;g1<=0;b1<=0;r2<=0;g2<=0;b2<=0;
 r3<=0;g3<=0;b3<=0;orgb<=0;
 end else begin
 sync_toggle<={sync_toggle[1:0],toggle};vsq<=vs;
 if(sync_toggle[2]!=seen)begin staged<=mailbox;pending<=1;seen<=sync_toggle[2];end
 // Atomic frame-boundary update. Host waits for active-register readback.
 if(pending && vs && !vsq)begin active<=staged;pending<=0;end
 vpipe<={vpipe[2:0],vs};hpipe<={hpipe[2:0],hs};dpipe<={dpipe[2:0],de};
 r1<=rgb[23:16]*active[9:0];g1<=rgb[15:8]*active[19:10];b1<=rgb[7:0]*active[29:20];
 r2<=contrast(r1,active[39:30],$signed(active[48:40]));
 g2<=contrast(g1,active[39:30],$signed(active[48:40]));
 b2<=contrast(b1,active[39:30],$signed(active[48:40]));
 r3<=(($signed({3'b0,r2})-lum)*$signed({1'b0,active[58:49]}))+(lum<<<8);
 g3<=(($signed({3'b0,g2})-lum)*$signed({1'b0,active[58:49]}))+(lum<<<8);
 b3<=(($signed({3'b0,b2})-lum)*$signed({1'b0,active[58:49]}))+(lum<<<8);
 orgb<={clamp(r3>>>8),clamp(g3>>>8),clamp(b3>>>8)};
 end end
 assign ovs=vpipe[3];assign ohs=hpipe[3];assign ode=dpipe[3];
endmodule
`default_nettype wire
