`default_nettype none
// Four adjacent RAW8 pixels per beat. Even x/y offsets preserve Bayer phase.
module raw_center_crop #(parameter SW=1920,SH=1080,W=1280,H=720)(
 input wire clk,resetn,vs,hs,de,input wire [31:0] data,
 output reg ovs=0,output reg ode=0,output reg [31:0] odata=0);
 reg [11:0] x=0,y=0;reg hsq=0;
 localparam X0=(SW-W)/8,Y0=(SH-H)/2;
 always @(posedge clk)begin
 if(!resetn)begin x<=0;y<=0;hsq<=0;ovs<=0;ode<=0;odata<=0;end
 else begin
 hsq<=hs;ovs<=vs;odata<=data;
 if(!vs)begin x<=0;y<=0;end
 else begin
 if(!hs)x<=0;else if(de)x<=x+1'b1;
 if(hsq&&!hs)y<=y+1'b1;
 end
 ode<=vs&&hs&&de&&x>=X0&&x<X0+W/4&&y>=Y0&&y<Y0+H;
 end end
endmodule
`default_nettype wire
