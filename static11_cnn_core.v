`timescale 1ns/1ps
`default_nettype none
// Fixed frozen CNN; four output channels share one activation and ROM read.
// ponytail: three cycles/tap prioritizes a short, verifiable schedule; pipeline
// only if the measured candidate latency exceeds the full-frame scan budget.
module static11_cnn_core #(
 parameter WEIGHTS_FILE="weight4.mem", BIAS_FILE="bias.mem",
 parameter MULTIPLIER_FILE="multiplier.mem", SHIFT_FILE="shift.mem",
 parameter INPUT_ZP_FILE="input_zp.mem", OUTPUT_ZP_FILE="output_zp.mem",
 parameter INPUT_LUT_FILE="input_quant.mem"
)(
 input wire clk,rst,start,cancel,
 input wire [31:0] epoch,
 output wire start_ready,busy,
 input wire gray_valid,gray_last,
 input wire [7:0] gray_data,
 input wire [31:0] gray_epoch,
 output wire gray_ready,
 output wire result_valid,
 input wire result_ready,
 output reg [31:0] result_epoch,
 output reg [223:0] result_scores,
 output wire score_valid,
 output reg [4:0] score_class,
 output reg signed [7:0] score_value,
 output reg fault,aborted,
 output reg [2:0] error_code
);
 localparam IDLE=0,CAPTURE=1,LUT_WRITE=2,BIAS_READ=3,BIAS_LOAD=4,
  TAP_READ=5,TAP_MULT=6,TAP_ACCUM=7,Q_READ=8,Q_LOAD=9,Q_START=10,
  Q_WAIT=11,Q_WRITE=12,NEXT_GROUP=13,HOLD=14;
 reg [3:0] state;
 reg [2:0] layer;
 reg [4:0] ox,oy;
 reg [2:0] group;
 reg [1:0] lane;
 reg [11:0] tap,input_index;
 reg [2:0] ky,kx;
 reg [4:0] ic;
 reg [31:0] saved_epoch;
 reg raw_result_valid,raw_score_valid;
 reg signed [7:0] bank_a[0:8191],bank_b[0:4095];
 reg [31:0] weights[0:18097];
 reg signed [31:0] biases[0:115],multipliers[0:115];
 reg signed [7:0] shifts[0:115],input_zp[0:4],output_zp[0:4];
 // A tiny immutable lookup uses logic to leave block RAM for 1080p lines.
 (* syn_romstyle="logic" *) reg signed [7:0] input_lut[0:255];
 reg signed [7:0] bank_a_q,bank_b_q,lut_q;
 reg [31:0] weight_q;
 reg padding_q;
 reg signed [31:0] bias_q,multiplier_q;
 reg signed [7:0] shift_q;
 reg signed [31:0] accum[0:3];
 reg signed [16:0] product[0:3];
 reg signed [7:0] quant_byte;
 integer j;
 initial begin
  $readmemh(WEIGHTS_FILE,weights);$readmemh(BIAS_FILE,biases);
  $readmemh(MULTIPLIER_FILE,multipliers);$readmemh(SHIFT_FILE,shifts);
  $readmemh(INPUT_ZP_FILE,input_zp);$readmemh(OUTPUT_ZP_FILE,output_zp);
  $readmemh(INPUT_LUT_FILE,input_lut);
 end
 wire live=!rst&&!cancel&&(state==IDLE||epoch==saved_epoch);
 assign start_ready=state==IDLE&&!rst&&!cancel;
 assign busy=state!=IDLE;
 assign gray_ready=state==CAPTURE&&live;
 assign result_valid=raw_result_valid&&live&&!fault;
 assign score_valid=raw_score_valid&&live&&!fault;

 reg [11:0] taps;
 reg [5:0] out_dim;
 reg [6:0] in_dim;
 reg [2:0] groups,kernel;
 reg [5:0] channels;
 reg [14:0] weight_base;
 reg [6:0] param_base;
 reg signed [7:0] pad;
 always @* begin
  taps=25;out_dim=32;in_dim=64;groups=2;kernel=5;channels=1;
  weight_base=0;param_base=0;pad=1;
  case(layer)
   1:begin taps=72;out_dim=16;in_dim=32;groups=4;kernel=3;channels=8;weight_base=50;param_base=8;pad=0;end
   2:begin taps=144;out_dim=8;in_dim=16;groups=8;kernel=3;channels=16;weight_base=338;param_base=24;pad=0;end
   3:begin taps=2048;out_dim=1;in_dim=1;groups=8;kernel=1;channels=1;weight_base=1490;param_base=56;pad=0;end
   4:begin taps=32;out_dim=1;in_dim=1;groups=7;kernel=1;channels=1;weight_base=17874;param_base=88;pad=0;end
  endcase
 end
 // groups=8 needs a four-bit count; group register itself holds indices0..7.
 wire [3:0] group_count=(layer==2||layer==3)?4'd8:{1'b0,groups};
 wire [6:0] param_address=param_base+{group,2'b00}+lane;
 wire [14:0] weight_address=weight_base+group*taps+tap;
 wire signed [8:0] py=$signed({3'b000,oy,1'b0})+$signed({6'b0,ky})-$signed(pad);
 wire signed [8:0] px=$signed({3'b000,ox,1'b0})+$signed({6'b0,kx})-$signed(pad);
 wire padding=layer<3&&(py<0||px<0||py>=$signed({2'b0,in_dim})||px>=$signed({2'b0,in_dim}));
 reg [12:0] source_address,dest_address;
 always @* begin
  source_address=tap;dest_address={8'b0,group,2'b00}+lane;
  case(layer)
   0:begin source_address=({7'b0,py[5:0]}<<6)+px[5:0];dest_address=({8'b0,oy}<<8)+({8'b0,ox}<<3)+{group,2'b0}+lane;end
   1:begin source_address=({8'b0,py[4:0]}<<8)+({8'b0,px[4:0]}<<3)+ic;dest_address=({8'b0,oy}<<8)+({8'b0,ox}<<4)+{group,2'b0}+lane;end
   2:begin source_address=({9'b0,py[3:0]}<<8)+({9'b0,px[3:0]}<<4)+ic;dest_address=({8'b0,oy}<<8)+({8'b0,ox}<<5)+{group,2'b0}+lane;end
  endcase
 end
 wire signed [7:0] source_q=(layer==0||layer==2||layer==4)?bank_b_q:bank_a_q;
 wire signed [8:0] centered=padding_q?9'sd0:
  $signed({source_q[7],source_q})-$signed({input_zp[layer][7],input_zp[layer]});
 wire signed [32:0] sums[0:3];
 genvar g;
 generate for(g=0;g<4;g=g+1)begin: lanes
  assign sums[g]=$signed({accum[g][31],accum[g]})+$signed({{16{product[g][16]}},product[g]});
 end endgenerate
 wire acc_overflow=(sums[0][32]!=sums[0][31])||(sums[1][32]!=sums[1][31])||
                   (sums[2][32]!=sums[2][31])||(sums[3][32]!=sums[3][31]);
 wire quant_ready,quant_done,quant_fault;
 wire signed [31:0] quant_value;
 static5_sdk_requantize requant(
  .clk(clk),.rst(rst),.cancel(cancel||(state!=IDLE&&epoch!=saved_epoch)),
  .request(state==Q_START&&live),.accumulator(accum[lane]),
  .multiplier(multiplier_q),.shift(shift_q),.ready(quant_ready),
  .done(quant_done),.fault(quant_fault),.value(quant_value));
 wire signed [32:0] shifted_output=$signed({quant_value[31],quant_value})+
  $signed({{25{output_zp[layer][7]}},output_zp[layer]});
 wire signed [32:0] act_min=layer==4?-33'sd128:
  $signed({{25{output_zp[layer][7]}},output_zp[layer]});

 wire bank_b_write=state==LUT_WRITE||(state==Q_WRITE&&(layer==1||layer==3));
 wire [11:0] bank_b_write_address=state==LUT_WRITE?input_index:dest_address[11:0];
 wire signed [7:0] bank_b_write_data=state==LUT_WRITE?lut_q:quant_byte;
 // One explicit write port per RAM; Efinity does not always merge disjoint
 // write statements into a single port. Reads have independent registered q.
 always @(posedge clk)begin
  if(live)begin
   if(gray_valid&&gray_ready&&gray_epoch==saved_epoch)lut_q<=input_lut[gray_data];
   if(bank_b_write)bank_b[bank_b_write_address]<=bank_b_write_data;
   if(state==BIAS_READ)bias_q<=biases[param_address];
   if(state==TAP_READ)begin
    weight_q<=weights[weight_address];padding_q<=padding;
    bank_a_q<=bank_a[source_address];
    bank_b_q<=bank_b[source_address[11:0]];
   end
   if(state==Q_READ)begin multiplier_q<=multipliers[param_address];shift_q<=shifts[param_address];end
   if(state==Q_WRITE&&(layer==0||layer==2))bank_a[dest_address]<=quant_byte;
  end
 end
 always @(posedge clk)begin
  raw_score_valid<=0;aborted<=0;
  if(rst)begin
   state<=IDLE;layer<=0;ox<=0;oy<=0;group<=0;lane<=0;tap<=0;ic<=0;kx<=0;ky<=0;
   input_index<=0;saved_epoch<=0;raw_result_valid<=0;result_epoch<=0;result_scores<=0;
   fault<=0;error_code<=0;score_class<=0;score_value<=0;quant_byte<=0;
   for(j=0;j<4;j=j+1)begin accum[j]<=0;product[j]<=0;end
  end else if(cancel||(state!=IDLE&&epoch!=saved_epoch))begin
   state<=IDLE;raw_result_valid<=0;raw_score_valid<=0;aborted<=state!=IDLE;fault<=0;error_code<=0;
  end else case(state)
   IDLE:if(start&&start_ready)begin
    state<=CAPTURE;input_index<=0;saved_epoch<=epoch;fault<=0;error_code<=0;
    raw_result_valid<=0;result_scores<=0;layer<=0;ox<=0;oy<=0;group<=0;lane<=0;
   end
   CAPTURE:if(gray_valid&&gray_ready)begin
    if(gray_epoch!=saved_epoch||gray_last!=(input_index==4095))begin
     fault<=1;error_code<=gray_epoch!=saved_epoch?3'd2:3'd1;state<=IDLE;
    end else state<=LUT_WRITE;
   end
   LUT_WRITE:if(input_index==4095)begin lane<=0;state<=BIAS_READ;end
             else begin input_index<=input_index+1'b1;state<=CAPTURE;end
   BIAS_READ:state<=BIAS_LOAD;
   BIAS_LOAD:begin
    accum[lane]<=bias_q;
    if(lane==3)begin lane<=0;tap<=0;ic<=0;kx<=0;ky<=0;state<=TAP_READ;end
    else begin lane<=lane+1'b1;state<=BIAS_READ;end
   end
   TAP_READ:state<=TAP_MULT;
   TAP_MULT:begin
    for(j=0;j<4;j=j+1)product[j]<=centered*$signed(weight_q[j*8+:8]);
    state<=TAP_ACCUM;
   end
   TAP_ACCUM:begin
    if(acc_overflow)begin fault<=1;error_code<=3;state<=IDLE;end
    else begin
     for(j=0;j<4;j=j+1)accum[j]<=sums[j][31:0];
     if(tap==taps-1)begin lane<=0;state<=Q_READ;end
     else begin
      tap<=tap+1'b1;state<=TAP_READ;
      if(ic==channels-1)begin
       ic<=0;
       if(kx==kernel-1)begin kx<=0;ky<=ky+1'b1;end else kx<=kx+1'b1;
      end else ic<=ic+1'b1;
     end
    end
   end
   Q_READ:state<=Q_LOAD;
   Q_LOAD:state<=Q_START;
   Q_START:if(quant_ready)state<=Q_WAIT;
   Q_WAIT:if(quant_done)begin
    if(quant_fault)begin fault<=1;error_code<=4;state<=IDLE;end
    else begin
     if(shifted_output>127)quant_byte<=127;
     else if(shifted_output<act_min)quant_byte<=act_min[7:0];
     else quant_byte<=shifted_output[7:0];
     state<=Q_WRITE;
    end
   end
   Q_WRITE:begin
    if(layer==4)begin
     result_scores[({group,2'b00}+lane)*8+:8]<=quant_byte;
     score_class<={group,2'b00}+lane;score_value<=quant_byte;raw_score_valid<=1;
    end
    if(lane==3)begin lane<=0;state<=NEXT_GROUP;end
    else begin lane<=lane+1'b1;state<=Q_READ;end
   end
   NEXT_GROUP:begin
    lane<=0;
    if({1'b0,group}==group_count-1)begin
     group<=0;
     if(ox==out_dim-1)begin
      ox<=0;
      if(oy==out_dim-1)begin
       oy<=0;
       if(layer==4)begin result_epoch<=saved_epoch;raw_result_valid<=1;state<=HOLD;end
       else begin layer<=layer+1'b1;state<=BIAS_READ;end
      end else begin oy<=oy+1'b1;state<=BIAS_READ;end
     end else begin ox<=ox+1'b1;state<=BIAS_READ;end
    end else begin group<=group+1'b1;state<=BIAS_READ;end
   end
   HOLD:if(result_ready)begin raw_result_valid<=0;state<=IDLE;end
   default:begin fault<=1;error_code<=5;state<=IDLE;raw_result_valid<=0;end
  endcase
 end
endmodule
`default_nettype wire
