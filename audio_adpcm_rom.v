`timescale 1ns/1ps
module audio_adpcm_rom(input wire clk,input wire[16:0] address,output reg[3:0] data);
 (* syn_romstyle="logic" *)reg[3:0]mem[0:65535];
 initial $readmemh("audio_adpcm.mem",mem);
 always @(posedge clk)data<=mem[address[15:0]];
endmodule
