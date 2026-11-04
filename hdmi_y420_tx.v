`timescale 1ns/1ps
`default_nettype none
// Experimental reduced-blanking 1920x1080 120.2424 Hz YCbCr420, AVI VIC=0.
// NOT advertised as CTA VIC 4 (720p60). A compatible custom-mode sink is required.
// Uses existing Sameer Puri TMDS/TERC4 channel encoder with explicit CN values.
module hdmi_y420_tx #(parameter HT=800)(
 input wire clk,rst,input wire [23:0] data,input wire hs_n,vs_n,de,
 output wire [9:0] txc,tx0,tx1,tx2,output wire monitor_vs_n,monitor_de);
 wire [26:0] delayed;
 wire de8;
 assign monitor_vs_n=delayed[26];
 assign monitor_de=delayed[24];
 stream_delay #(27,10) align(clk,rst,{vs_n,hs_n,de,data},delayed);
 stream_delay #(1,8) advance(clk,rst,de,de8);
 wire vp=de&&!de8;
 wire vg=de8&&!delayed[24];
 reg deq,vsq,pending;reg [5:0] phase;
 reg [15:0] blank_cycles;
 always @(posedge clk)begin
 if(rst)begin deq<=0;vsq<=1;pending<=0;phase<=0;blank_cycles<=0;end
 else begin
 deq<=de;vsq<=vs_n;
 if(de)blank_cycles<=0;
 else if(blank_cycles!=16'hffff)blank_cycles<=blank_cycles+1'b1;
 if(vsq&&!vs_n)pending<=1;
 if(phase!=0)phase<=phase==59?0:phase+1'b1;
 // Horizontal blank is only 160 clocks: place the 60-clock AVI sequence in
 // vertical blank, after a complete line has passed without active video.
 // Current mode guarantees >=9 blank lines, including 4 back-porch lines.
 else if(pending&&!de&&blank_cycles>=HT+32)begin phase<=1;pending<=0;end
 end end
 wire dip=phase>=16&&phase<24;
 wire dig=(phase>=24&&phase<26)||(phase>=58&&phase<60);
 wire di=phase>=26&&phase<58;
 wire [4:0] index=phase-6'd26;
 // Static AVI payload + BCH are generated/rechecked by tools/test_720p240.py.
 // PB1=0x60: YCbCr420; PB2=0x88: BT.709,aspect unspecified; PB4=0: custom timing.
 localparam [31:0] HEADER=32'he40d0282; // generated parity patched below
 localparam [63:0] SUB0=64'h3600000000886087;
 localparam [63:0] SUB1=64'h0000000000000000,SUB2=64'h0000000000000000,SUB3=64'h0000000000000000;
 wire [5:0] bit0={index,1'b0},bit1={index,1'b1};
 wire [8:0] packet={SUB3[bit1],SUB2[bit1],SUB1[bit1],SUB0[bit1],SUB3[bit0],SUB2[bit0],SUB1[bit0],SUB0[bit0],HEADER[index]};
 wire [1:0] sync={~delayed[26],~delayed[25]}; // positive HS/VS on link
 wire [2:0] mode=rst?3'd0:delayed[24]?3'd1:vg?3'd2:dig?3'd4:di?3'd3:3'd0;
 tmds_channel #(.CN(0)) ch0(clk,delayed[7:0],{1'b1,packet[0],sync},sync,mode,tx0);
 tmds_channel #(.CN(1)) ch1(clk,delayed[15:8],packet[4:1],{1'b0,vp||dip},mode,tx1);
 tmds_channel #(.CN(2)) ch2(clk,delayed[23:16],packet[8:5],{1'b0,dip},mode,tx2);
 assign txc=10'b1111100000;
endmodule
`default_nettype wire
