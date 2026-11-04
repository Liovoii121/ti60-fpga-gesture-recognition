// GT911 register transactions: open-drain I2C, 16-bit register address,
// repeated START, ACK checking, final-byte NACK and clock-stretch timeout.
module gt911_i2c #(parameter TICK_DIV=306, parameter STRETCH_TICKS=4000)(
 input wire clk, reset_n, start, reading,alternate_address,
 input wire [15:0] address, input wire [3:0] length,
 input wire [7:0] write_data,
 input wire scl_i,sda_i,
 output reg scl_low,sda_low, busy,done,error,
 output reg [63:0] read_data,
 output reg [7:0] fault
);
 reg [1:0] scl_sync,sda_sync;
 always @(posedge clk or negedge reset_n)
   if(!reset_n) begin scl_sync<=3;sda_sync<=3;end
   else begin scl_sync<={scl_sync[0],scl_i};sda_sync<={sda_sync[0],sda_i};end
 reg [15:0] divider,stall;
 reg [4:0] state;
 reg [1:0] phase;
 reg [3:0] bit_no,byte_no,rx_no,nbytes;
 reg [7:0] tx,rx,wr;
 reg [15:0] addr;
 reg rd,alt;
 localparam IDLE=0,START_A=1,START_B=2,SEND=3,RESTART_A=4,
 RESTART_B=5,RESTART_C=6,RECEIVE=7,STOP_A=8,STOP_B=9,STOP_C=10;
 always @(posedge clk or negedge reset_n) begin
   if(!reset_n) begin
     divider<=0;stall<=0;state<=IDLE;phase<=0;bit_no<=0;byte_no<=0;rx_no<=0;
     tx<=0;rx<=0;wr<=0;addr<=0;rd<=0;alt<=0;nbytes<=0;fault<=0;
     scl_low<=0;sda_low<=0;busy<=0;done<=0;error<=0;read_data<=0;
   end else begin
     done<=0;
     if(state==IDLE) begin
       divider<=0;stall<=0;
       if(start) begin
         busy<=1;error<=0;read_data<=0;rd<=reading;addr<=address;wr<=write_data;
         nbytes<=length;rx_no<=0;byte_no<=0;alt<=alternate_address;
         tx<=alternate_address?8'h28:8'hba;fault<=0;
         scl_low<=0;sda_low<=0;state<=START_A;
       end
     end else if(divider==TICK_DIV-1) begin
       divider<=0;
       if(!scl_low && !scl_sync[1]) begin
         if(stall==STRETCH_TICKS-1) begin
           error<=1;fault<=2;busy<=0;done<=1;scl_low<=0;sda_low<=0;state<=IDLE;stall<=0;
         end else stall<=stall+1'b1;
       end else begin
         stall<=0;
         case(state)
           START_A: if(sda_sync[1]) begin sda_low<=1;state<=START_B;end
                    else begin error<=1;fault<=1;state<=STOP_A;end
           START_B: begin scl_low<=1;phase<=0;bit_no<=7;state<=SEND;end
           SEND: case(phase)
             0:begin sda_low<=(bit_no==8)?0:!tx[bit_no];phase<=1;end
             1:begin
               if(scl_sync[1]) begin error<=1;fault<=11;state<=STOP_A;end
               else if(bit_no!=8 && sda_sync[1]!=tx[bit_no]) begin error<=1;fault<=12;state<=STOP_A;end
               else begin scl_low<=0;phase<=2;end
             end
             2:begin if(bit_no==8 && sda_sync[1]) begin error<=1;fault<=byte_no+3;end phase<=3;end
             3:begin
               scl_low<=1;phase<=0;
               if(bit_no==8) begin
                 if(error) state<=STOP_A;
                 else case(byte_no)
                   0:begin tx<=addr[15:8];byte_no<=1;bit_no<=7;end
                   1:begin tx<=addr[7:0];byte_no<=2;bit_no<=7;end
                   2:if(rd) state<=RESTART_A;
                     else begin tx<=wr;byte_no<=3;bit_no<=7;end
                   3:state<=STOP_A;
                   4:begin state<=RECEIVE;bit_no<=7;rx<=0;end
                 endcase
               end else if(bit_no==0) bit_no<=8;
               else bit_no<=bit_no-1'b1;
             end
           endcase
           RESTART_A:begin sda_low<=0;state<=RESTART_B;end
           RESTART_B:begin scl_low<=0;state<=RESTART_C;end
           RESTART_C:begin sda_low<=1;state<=START_B;tx<=alt?8'h29:8'hbb;byte_no<=4;end
           RECEIVE:case(phase)
             0:begin sda_low<=(bit_no==8 && rx_no<nbytes-1);phase<=1;end
             1:begin scl_low<=0;phase<=2;end
             2:begin if(bit_no!=8) rx<={rx[6:0],sda_sync[1]};phase<=3;end
             3:begin
               scl_low<=1;phase<=0;
               if(bit_no==8) begin
                 read_data[rx_no*8+:8]<=rx;
                 if(rx_no==nbytes-1) state<=STOP_A;
                 else begin rx_no<=rx_no+1'b1;bit_no<=7;rx<=0;end
               end else if(bit_no==0) bit_no<=8;
               else bit_no<=bit_no-1'b1;
             end
           endcase
           STOP_A:begin scl_low<=1;sda_low<=1;state<=STOP_B;end
           STOP_B:begin scl_low<=0;state<=STOP_C;end
           STOP_C:begin sda_low<=0;busy<=0;done<=1;state<=IDLE;end
           default:state<=STOP_A;
         endcase
       end
     end else divider<=divider+1'b1;
   end
 end
endmodule

module gt911_touch #(parameter MS_CYCLES=122182, parameter I2C_DIV=6110)(
 input wire clk,reset_n,scl_i,sda_i,
 output wire scl_low,sda_low,int_low,
 output wire touch_rst,
 output reg [1:0] status,
 output reg active,seen,
 output reg [9:0] x,y,
 output reg [3:0] fingers,
 output reg [15:0] taps,
 output reg [4:0] targets,
 output wire [127:0] diagnostic
);
 localparam MS_BITS=(MS_CYCLES<2)?1:$clog2(MS_CYCLES);
 reg [MS_BITS-1:0] ms_div;
 reg [10:0] wait_ms;
 reg [4:0] state;
 reg start,reading;
 reg [15:0] address;
 reg [3:0] length;
 wire done,error,busy;
 wire [63:0] data;
 reg [63:0] packet;
 wire [15:0] px=packet[31:16],py=packet[47:32];
 reg [15:0] max_x,max_y;
 // Older RGB070M1 modules report 1024x600 touch coordinates. Match the
 // vendor's coordinate conversion without changing the controller config.
 wire [14:0] legacy_x=(px[9:0]<<4)+(px[9:0]<<3)+px[9:0];
 wire [11:0] legacy_y=py[9:0]<<2;
 wire [15:0] screen_x=(max_x==1024)?(legacy_x>>5):px;
 wire [15:0] screen_y=(max_y==600)?(legacy_y/12'd5):py;
 reg [1:0] ready;
 reg alternate_address;
 wire [7:0] bus_fault;
 reg [7:0] last_fault,fault_5d,fault_14,attempts;
 reg [31:0] id_data,config_data;
 assign diagnostic={8'h02,8'h00,fault_5d,fault_14,config_data,id_data,attempts,last_fault,
                    alternate_address,state,status,seen,active,sda_low,scl_low,int_low,touch_rst,sda_i,scl_i};
 always @(posedge clk or negedge reset_n)
   if(!reset_n) ready<=0;else ready<={ready[0],1'b1};
 localparam RESET_LOW=0,RESET_HIGH=1,BOOT_WAIT=2,ID_START=3,ID_WAIT=4,
 CONFIG_START=5,CONFIG_WAIT=6,POLL_DELAY=7,POLL_START=8,POLL_WAIT=9,
 CLEAR_START=10,CLEAR_WAIT=11,RETRY=12;
 assign touch_rst=ready[1] && state!=RESET_LOW;
 // INT low during reset selects 7-bit slave address 0x5D, then release it.
 assign int_low=(state==RESET_LOW || state==RESET_HIGH);
 gt911_i2c #(.TICK_DIV(I2C_DIV)) bus(.clk(clk),.reset_n(ready[1]),
 .start(start),.reading(reading),.alternate_address(alternate_address),.address(address),.length(length),.write_data(8'h00),
 .scl_i(scl_i),.sda_i(sda_i),.scl_low(scl_low),.sda_low(sda_low),
 .busy(busy),.done(done),.error(error),.read_data(data),.fault(bus_fault));
 always @(posedge clk or negedge ready[1]) begin
   if(!ready[1]) begin
     ms_div<=0;wait_ms<=30;state<=RESET_LOW;start<=0;reading<=1;address<=0;length<=0;
     status<=0;active<=0;seen<=0;x<=400;y<=240;fingers<=0;taps<=0;targets<=0;
     packet<=0;max_x<=800;max_y<=480;
     alternate_address<=0;last_fault<=0;fault_5d<=0;fault_14<=0;attempts<=0;id_data<=0;config_data<=0;
   end else begin
     start<=0;
     if(ms_div==MS_CYCLES-1) begin
       ms_div<=0;
       if(wait_ms!=0) wait_ms<=wait_ms-1'b1;
     end else ms_div<=ms_div+1'b1;
     case(state)
       RESET_LOW:if(wait_ms==0) begin wait_ms<=50;state<=RESET_HIGH;end
       RESET_HIGH:if(wait_ms==0) begin wait_ms<=100;state<=BOOT_WAIT;end
       BOOT_WAIT:if(wait_ms==0) state<=ID_START;
       ID_START:begin reading<=1;address<=16'h8140;length<=4;start<=1;state<=ID_WAIT;attempts<=attempts+1'b1;end
       ID_WAIT:if(done) begin
         id_data<=data[31:0];
         last_fault<=error?bus_fault:((data[23:0]==24'h313139)?0:8);
         if(alternate_address) fault_14<=error?bus_fault:((data[23:0]==24'h313139)?0:8);
         else fault_5d<=error?bus_fault:((data[23:0]==24'h313139)?0:8);
         if(!error && data[23:0]==24'h313139) state<=CONFIG_START;
         else begin
           status<=2;active<=0;
           if(!alternate_address) begin alternate_address<=1;state<=ID_START;end
           else begin wait_ms<=1000;state<=RETRY;end
         end
       end
       CONFIG_START:begin reading<=1;address<=16'h8048;length<=4;start<=1;state<=CONFIG_WAIT;end
       CONFIG_WAIT:if(done) begin
         config_data<=data[31:0];last_fault<=error?bus_fault:9;
         if(!error && ((data[15:0]==800 && data[31:16]==480) ||
                     (data[15:0]==1024 && data[31:16]==600))) begin
           max_x<=data[15:0];max_y<=data[31:16];status<=1;last_fault<=0;wait_ms<=10;state<=POLL_DELAY;
         end else begin status<=3;wait_ms<=1000;state<=RETRY;end
       end
       POLL_DELAY:if(wait_ms==0) state<=POLL_START;
       POLL_START:begin reading<=1;address<=16'h814e;length<=8;start<=1;state<=POLL_WAIT;end
       POLL_WAIT:if(done) begin
         last_fault<=error?bus_fault:0;
         if(error) begin status<=2;active<=0;wait_ms<=1000;state<=RETRY;end
         else if(data[7]) begin packet<=data;state<=CLEAR_START;end
         else begin wait_ms<=10;state<=POLL_DELAY;end
       end
       CLEAR_START:begin reading<=0;address<=16'h814e;length<=1;start<=1;state<=CLEAR_WAIT;end
       CLEAR_WAIT:if(done) begin
         last_fault<=error?bus_fault:0;
         if(error) begin status<=2;active<=0;wait_ms<=1000;state<=RETRY;end
         else begin
           fingers<=packet[3:0];
           if(packet[3:0]==0) active<=0;
           else if(packet[3:0]<=5 && px<max_x && py<max_y) begin
             if(!active) taps<=taps+1'b1;
             active<=1;seen<=1;x<=screen_x[9:0];y<=screen_y[9:0];status<=1;
             if(screen_x<120 && screen_y<120) targets[0]<=1;
             if(screen_x>679 && screen_y<120) targets[1]<=1;
             if(screen_x>340 && screen_x<460 && screen_y>180 && screen_y<300) targets[2]<=1;
             if(screen_x<120 && screen_y>359) targets[3]<=1;
             if(screen_x>679 && screen_y>359) targets[4]<=1;
           end else begin status<=3;active<=0;last_fault<=10;end
           wait_ms<=10;state<=POLL_DELAY;
         end
       end
       RETRY:if(wait_ms==0) begin alternate_address<=0;wait_ms<=30;state<=RESET_LOW;end
       default:state<=RESET_LOW;
     endcase
   end
 end
endmodule
