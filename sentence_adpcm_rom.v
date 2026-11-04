module sentence_adpcm_rom(input wire clk,input wire[15:0]address,output wire[3:0]data);
reg[2:0]bank;
(* syn_romstyle="block_rom" *)reg[3:0]mem0[0:2047];reg[3:0]q0;initial $readmemh("speech_bank0.mem",mem0);
(* syn_romstyle="block_rom" *)reg[3:0]mem1[0:2047];reg[3:0]q1;initial $readmemh("speech_bank1.mem",mem1);
(* syn_romstyle="block_rom" *)reg[3:0]mem2[0:2047];reg[3:0]q2;initial $readmemh("speech_bank2.mem",mem2);
(* syn_romstyle="block_rom" *)reg[3:0]mem3[0:2047];reg[3:0]q3;initial $readmemh("speech_bank3.mem",mem3);
(* syn_romstyle="block_rom" *)reg[3:0]mem4[0:2047];reg[3:0]q4;initial $readmemh("speech_bank4.mem",mem4);
(* syn_romstyle="logic" *)reg[3:0]mem5[0:2047];reg[3:0]q5;initial $readmemh("speech_bank5.mem",mem5);
(* syn_romstyle="logic" *)reg[3:0]mem6[0:2047];reg[3:0]q6;initial $readmemh("speech_bank6.mem",mem6);
(* syn_romstyle="logic" *)reg[3:0]mem7[0:2047];reg[3:0]q7;initial $readmemh("speech_bank7.mem",mem7);
always @(posedge clk)begin bank<=address[13:11];
q0<=mem0[address[10:0]];
q1<=mem1[address[10:0]];
q2<=mem2[address[10:0]];
q3<=mem3[address[10:0]];
q4<=mem4[address[10:0]];
q5<=mem5[address[10:0]];
q6<=mem6[address[10:0]];
q7<=mem7[address[10:0]];
end
assign data=bank==3'd0 ? q0:bank==3'd1 ? q1:bank==3'd2 ? q2:bank==3'd3 ? q3:bank==3'd4 ? q4:bank==3'd5 ? q5:bank==3'd6 ? q6 : q7;
endmodule
