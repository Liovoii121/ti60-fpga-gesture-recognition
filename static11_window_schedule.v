`default_nettype none
module static11_window_schedule(input wire [6:0] id,
 output reg [15:0] x,y,width,height,output reg [5:0] step,
 output reg [6:0] pad_rows,output reg [7:0] content_rows,output reg valid);
always @* begin
 x=16'd512;y=16'd92;width=16'd896;height=16'd896;
 step=6'd14;pad_rows=0;content_rows=8'd128;valid=id==0;
end
endmodule
`default_nettype wire

