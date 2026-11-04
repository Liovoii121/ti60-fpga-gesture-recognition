`timescale 1ns/1ps
// Serial shared-MAC layer engine for CNN, FC, temporal depthwise/pointwise
// convolution and 2x2 average pool. Memory layout is signed Q16 NCHW.
// Physical plane strides may exceed logical dimensions (temporal capacity310).
// A store response MUST mean real DDR B completion, not local FIFO acceptance.
// Reset/cancel stop this engine; memory_cancel must connect to caches/clients
// which drain accepted DDR transactions. Start only after memory_idle.
module nn_layer_engine #(parameter MODEL_ADDRESSING=0,parameter WEIGHT_BITS=32)(input wire clk,rst,cancel,start,memory_idle,
 input wire [31:0] input_base,weight_base,bias_base,output_base,
 input wire [8:0] in_width,in_height,out_width,out_height,channels,out_channels,
 input wire [23:0] input_plane_words,output_plane_words,
 input wire [15:0] input_row_words,output_row_words,
 input wire [2:0] kernel_width,kernel_height,
 input wire [4:0] dilation_x,input wire [5:0] pad_x,pad_y,
 input wire stride_two,depthwise,pool_two,relu_enable,relu6_enable,
 output wire busy,output reg done,fault,aborted,output wire memory_cancel,
 output wire activation_request,output wire [31:0] activation_address,
 input wire activation_ready,activation_response,input wire [31:0] activation_data,
 input wire activation_fault,output wire activation_response_ready,
 output wire parameter_request,output wire [31:0] parameter_address,
 input wire parameter_ready,parameter_response,input wire [31:0] parameter_data,
 input wire parameter_fault,output wire parameter_response_ready,
 output wire store_request,output wire [31:0] store_address,
 output reg [31:0] store_data,input wire store_ready,store_response,store_fault);
 localparam IDLE=0,INIT=1,BIAS_REQ=2,BIAS_WAIT=3,DOT_START=4,TAP_WAIT=5,
  WEIGHT_REQ=6,WEIGHT_WAIT=7,ACT_REQ=8,ACT_WAIT=9,FEED=10,DOT_WAIT=11,
  STORE_REQ=12,STORE_WAIT=13,FINISH=14,ERROR=15;
 reg[3:0] state;
 reg[31:0] src,weights,biases,dst;
 reg[8:0] iw,ih,ow,oh,cin,cout,ox,oy,oc,ic;
 reg[23:0] ip,op;reg[15:0] ir,orr;
 reg[2:0] kw,kh,kx,ky;reg[4:0] dil;reg[5:0] padx,pady;
 reg str2,dw,pool,relu,relu6;
 reg[15:0] tap;
 reg signed[31:0] dot_bias,operand_a,operand_w;
 wire[15:0] area=kw*kh;
 wire[15:0] taps=(dw||pool)?area:(area*cin);
 wire[8:0] input_channel=(dw||pool)?oc:ic;
 // Geometry is bounded by9-bit coordinates,3-bit kernels and5-bit dilation:
 // -63 <= ix <=1239; -63 <= iy <=1029. Twelve signed bits are exact.
 wire[7:0] kx_dil=kx*dil;
 wire signed[11:0] ix=(str2?$signed({2'b0,ox,1'b0}):$signed({3'b0,ox}))+$signed({4'b0,kx_dil})-$signed({6'b0,padx});
 wire signed[11:0] iy=(str2?$signed({2'b0,oy,1'b0}):$signed({3'b0,oy}))+$signed({9'b0,ky})-$signed({6'b0,pady});
 // Only the model-bound scheduler enables bank addressing. Its21 descriptors
 // have <16384 words per activation/weight view; see address_bounds.json.
 wire[13:0] model_in_word=input_channel*ip[13:0]+$unsigned(iy)*ir[13:0]+$unsigned(ix);
 wire[13:0] model_out_word=oc*op[13:0]+oy*orr[13:0]+ox;
 wire[13:0] model_weight_word=oc*taps+tap;
 wire[15:0] model_out_low=dst[15:0]+{model_out_word,2'b00};
 wire padding=(ix<0||iy<0||ix>=iw||iy>=ih);
 assign busy=state!=IDLE;
 assign memory_cancel=rst||cancel||fault;
 assign activation_request=state==ACT_REQ&&!memory_cancel;
 assign activation_address=MODEL_ADDRESSING?{src[31:16],model_in_word,2'b00}:(src+((input_channel*ip+iy*ir+ix)<<2));
 assign activation_response_ready=state==ACT_WAIT;
 assign parameter_request=(state==BIAS_REQ||state==WEIGHT_REQ)&&!memory_cancel;
 assign parameter_address=(state==BIAS_REQ)?(biases+(oc<<2)):(MODEL_ADDRESSING?(weights+{16'd0,model_weight_word,2'b00}):(weights+((oc*taps+tap)<<2)));
 assign parameter_response_ready=state==BIAS_WAIT||state==WEIGHT_WAIT;
 assign store_request=state==STORE_REQ&&!memory_cancel;
 assign store_address=MODEL_ADDRESSING?{dst[31:16],model_out_low}:(dst+((oc*op+oy*orr+ox)<<2));
 wire dot_req,dot_done,dot_overflow;wire signed[31:0] dot_result;
 fixed_dot_product #(.WEIGHT_BITS(WEIGHT_BITS)) mac(.clk(clk),.rst(rst),.cancel(cancel||state==ERROR),
  .start(state==DOT_START),.length(taps),.bias(dot_bias),.relu_enable(relu),.relu6_enable(relu6),
  .operand_req(dot_req),.operand_index(),.operand_valid(state==FEED),
  .activation(operand_a),.weight(operand_w),.busy(),.done(dot_done),.overflow(dot_overflow),.result(dot_result));
 always @(posedge clk)begin
  done<=0;
  if(rst)begin state<=IDLE;fault<=0;aborted<=0;ox<=0;oy<=0;oc<=0;ic<=0;kx<=0;ky<=0;tap<=0;store_data<=0;end
  else if(cancel)begin state<=IDLE;aborted<=1;done<=busy;end
  else case(state)
   IDLE:if(start&&memory_idle)begin
    fault<=0;aborted<=0;src<=input_base;weights<=weight_base;biases<=bias_base;dst<=output_base;
    iw<=in_width;ih<=in_height;ow<=out_width;oh<=out_height;cin<=channels;cout<=out_channels;
    ip<=input_plane_words;op<=output_plane_words;ir<=input_row_words;orr<=output_row_words;
    kw<=kernel_width;kh<=kernel_height;dil<=dilation_x;padx<=pad_x;pady<=pad_y;
    str2<=stride_two;dw<=depthwise;pool<=pool_two;relu<=relu_enable;relu6<=relu6_enable;
    ox<=0;oy<=0;oc<=0;
    if(channels==0||out_channels==0||out_width==0||out_height==0||kernel_width==0||kernel_height==0||dilation_x==0)state<=ERROR;
    else state<=INIT;
   end
   INIT:begin ic<=0;kx<=0;ky<=0;tap<=0;if(pool)begin dot_bias<=0;state<=DOT_START;end else state<=BIAS_REQ;end
   BIAS_REQ:if(parameter_ready)state<=BIAS_WAIT;
   BIAS_WAIT:if(parameter_response)begin if(parameter_fault)state<=ERROR;else begin dot_bias<=parameter_data;state<=DOT_START;end end
   DOT_START:state<=TAP_WAIT;
   TAP_WAIT:if(dot_req)begin
    if(padding)begin operand_a<=0;operand_w<=0;state<=FEED;end
    else if(pool)begin operand_w<=32'sd16384;state<=ACT_REQ;end
    else state<=WEIGHT_REQ;
   end
   WEIGHT_REQ:if(parameter_ready)state<=WEIGHT_WAIT;
   WEIGHT_WAIT:if(parameter_response)begin if(parameter_fault)state<=ERROR;else begin operand_w<=parameter_data;state<=ACT_REQ;end end
   ACT_REQ:if(activation_ready)state<=ACT_WAIT;
   ACT_WAIT:if(activation_response)begin if(activation_fault)state<=ERROR;else begin operand_a<=activation_data;state<=FEED;end end
   FEED:begin
    tap<=tap+1'b1;
    if(kx+1==kw)begin kx<=0;if(ky+1==kh)begin ky<=0;ic<=ic+1'b1;end else ky<=ky+1'b1;end
    else kx<=kx+1'b1;
    state<=(tap+1==taps)?DOT_WAIT:TAP_WAIT;
   end
   DOT_WAIT:if(dot_done)begin if(dot_overflow)state<=ERROR;else begin store_data<=dot_result;state<=STORE_REQ;end end
   STORE_REQ:if(store_ready)state<=STORE_WAIT;
   STORE_WAIT:if(store_response)begin
    if(store_fault)state<=ERROR;
    else if(ox+1<ow)begin ox<=ox+1'b1;state<=INIT;end
    else begin ox<=0;if(oy+1<oh)begin oy<=oy+1'b1;state<=INIT;end
     else begin oy<=0;if(oc+1<cout)begin oc<=oc+1'b1;state<=INIT;end else state<=FINISH;end
    end
   end
   FINISH:begin done<=1;state<=IDLE;end
   ERROR:begin fault<=1;done<=1;state<=IDLE;end
   default:state<=ERROR;
  endcase
 end
endmodule
