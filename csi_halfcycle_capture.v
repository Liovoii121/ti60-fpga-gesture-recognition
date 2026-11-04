`timescale 1ns/1ps
`default_nettype none
// PHY parallel bytes change after the rising byte-clock edge. Sample halfway
// through the byte period so the soft receiver consumes the same bytes at the
// following rising edge, with a half-cycle boundary instead of near-zero hold.
module csi_halfcycle_capture(input wire clk,input wire[31:0] phy_data,output wire[31:0] data);
 (* syn_preserve="true",syn_keep="true" *)reg[31:0] held=0;
 always @(negedge clk)held<=phy_data;
 assign data=held;
endmodule
`default_nettype wire
