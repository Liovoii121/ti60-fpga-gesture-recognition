// Manual exposure plus bounded diagnostic HTS/VTS changes; no PLL writes.
module sensor_exposure_control #(parameter CLK_FREQ=96000000,I2C_FREQ=50000,MAX_LINES=2220)(
 input clk,resetn,ready,frame_signal,input[6:0]slave_address,
 input[31:0]mailbox,input toggle,sda_in,
 output bus_active,scl,sda_low,output[31:0]status,
 output reg[31:0]confirmed_lines=0,output reg[31:0]confirmed_timing=0);
 localparam IDLE=0,FRAME=1,WRITE=2,READ_RESET=3,READ=4;
 reg[2:0]state=IDLE;
 (* async_reg="true" *)reg[2:0]toggle_sync=0,frame_sync=0;
 reg seen=0,initial_read=0,valid=0,error=0,timing_mode=0;
 reg[3:0]reason=0;
 reg[15:0]pending_lines=0,pending_hts=0,pending_vts=0,active_max=MAX_LINES;
 reg[15:0]command_seq=0,ack_sequence=0;
 reg[26:0]watchdog=0;
 wire wr_done,wr_failed,wr_scl,wr_sda,rb_done,rb_failed,rb_scl,rb_sda;
 wire[8:0]wr_index;wire[191:0]rb_values;
 wire[15:0]read_hts={rb_values[7:0],rb_values[15:8]};
 wire[15:0]read_vts={rb_values[23:16],rb_values[31:24]};
 wire[15:0]read_lines={rb_values[35:32],rb_values[47:40],rb_values[55:52]};
 reg[23:0]wr_data;
 always @*begin
 if(timing_mode)case(wr_index)
 0:wr_data={16'h0100,8'h00};
 1:wr_data={16'h320c,pending_hts[15:8]};
 2:wr_data={16'h320d,pending_hts[7:0]};
 3:wr_data={16'h320e,pending_vts[15:8]};
 4:wr_data={16'h320f,pending_vts[7:0]};
 5:wr_data={16'h3e03,8'h0b};
 6:wr_data={16'h3e00,4'd0,pending_lines[15:12]};
 7:wr_data={16'h3e01,pending_lines[11:4]};
 8:wr_data={16'h3e02,pending_lines[3:0],4'd0};
 default:wr_data={16'h0100,8'h01};
 endcase
 else case(wr_index)
 0:wr_data={16'h3e03,8'h0b};
 1:wr_data={16'h3e00,4'd0,pending_lines[15:12]};
 2:wr_data={16'h3e01,pending_lines[11:4]};
 default:wr_data={16'h3e02,pending_lines[3:0],4'd0};
 endcase
 end
 assign bus_active=state!=IDLE;
 assign scl=state==WRITE?wr_scl:state==READ?rb_scl:1'b1;
 assign sda_low=state==WRITE?wr_sda:state==READ?rb_sda:1'b0;
 assign status={ack_sequence,8'd0,reason,1'b0,valid,error,bus_active};
 i2c_timing_ctrl_reg16_dat8_wronly #(.CLK_FREQ(CLK_FREQ),.I2C_FREQ(I2C_FREQ)) writer(
 .clk(clk),.rst_n(resetn&&state==WRITE),.i2c_sclk(wr_scl),.i2c_sdat_IN(sda_in),
 .i2c_sdat_OUT(),.i2c_sdat_OE(wr_sda),.i2c_config_size(timing_mode?9'd10:9'd4),
 .i2c_config_index(wr_index),.i2c_config_data({slave_address,1'b0,wr_data}),.i2c_config_failed(wr_failed),.i2c_config_done(wr_done));
 sc2210_readback #(.CLK_FREQ(CLK_FREQ),.I2C_FREQ(I2C_FREQ),.REG_COUNT(7),.TIMING_ONLY(1)) reader(
 .slave_address(slave_address),.clk(clk),.resetn(resetn&&state==READ),.enable(1'b1),
 .sda_in(sda_in),.scl_release(rb_scl),.sda_low(rb_sda),.done(rb_done),.failed(rb_failed),.values(rb_values));
 always @(posedge clk or negedge resetn)begin
 if(!resetn)begin
 state<=IDLE;toggle_sync<=0;frame_sync<=0;seen<=0;initial_read<=0;valid<=0;error<=0;reason<=0;
 confirmed_lines<=0;confirmed_timing<=0;watchdog<=0;pending_lines<=0;pending_hts<=0;pending_vts<=0;
 active_max<=MAX_LINES;command_seq<=0;ack_sequence<=0;timing_mode<=0;
 end else begin
 toggle_sync<={toggle_sync[1:0],toggle};frame_sync<={frame_sync[1:0],frame_signal};
 if(state!=IDLE)watchdog<=watchdog+1'b1;else watchdog<=0;
 if(state!=IDLE&&watchdog>=CLK_FREQ)begin state<=IDLE;error<=1;reason<=4;valid<=0;ack_sequence<=command_seq;end
 else case(state)
 IDLE:begin
 if(ready&&!initial_read)begin initial_read<=1;state<=READ_RESET;end
 else if(toggle_sync[2]!=seen)begin
 seen<=toggle_sync[2];command_seq<=mailbox[31:16];error<=0;reason<=0;timing_mode<=mailbox[31];
 if(!ready)begin error<=1;reason<=1;ack_sequence<=mailbox[31:16];end
 else if(mailbox[31])begin
 // Fixed 1280x720 ROI: timing may change only within these conservative bounds.
 if(mailbox[30:16]<640||mailbox[30:16]>2048||mailbox[15:0]<736||mailbox[15:0]>4095)begin error<=1;reason<=1;ack_sequence<=mailbox[31:16];end
 else begin pending_hts<={1'b0,mailbox[30:16]};pending_vts<=mailbox[15:0];pending_lines<=mailbox[15:0]-16'd4;state<=WRITE;end
 end else if(mailbox[15:0]==0||mailbox[15:0]>active_max)begin error<=1;reason<=1;ack_sequence<=mailbox[31:16];end
 else begin pending_lines<=mailbox[15:0];state<=FRAME;end
 end
 end
 FRAME:if(frame_sync[1]&&!frame_sync[2])state<=WRITE;
 WRITE:if(wr_failed)begin state<=IDLE;error<=1;valid<=0;reason<=2;ack_sequence<=command_seq;end else if(wr_done)state<=READ_RESET;
 READ_RESET:state<=READ;
 READ:if(rb_failed)begin state<=IDLE;error<=1;valid<=0;reason<=3;ack_sequence<=command_seq;end
 else if(rb_done)begin
 state<=IDLE;confirmed_lines<={16'd0,read_lines};confirmed_timing<={read_hts,read_vts};ack_sequence<=command_seq;
 if(command_seq!=0&&(read_lines!=pending_lines||(timing_mode&&(read_hts!=pending_hts||read_vts!=pending_vts))))begin error<=1;reason<=5;valid<=0;end
 else begin valid<=1;error<=0;reason<=0;if(read_vts>=4)active_max<=read_vts-16'd4;end
 end
 default:state<=IDLE;
 endcase
 end end
endmodule
