// Proposed single-outstanding write bridge, not vendor-qualified IP.
// m_aw* connects to the existing AWARMux; probe_* observes actual DDR A pins.
// That mux returns AWREADY a cycle after actual A acceptance: ACK is essential.
// Sole write-address owner, stable AXI upstream payload, common fabric reset required.
module ddr_wid_bridge(
 input wire clk,rst,
 input wire [3:0] s_awid,input wire [31:0] s_awaddr,input wire [7:0] s_awlen,input wire s_awvalid,output wire s_awready,
 input wire [127:0] s_wdata,input wire [15:0] s_wstrb,input wire s_wlast,s_wvalid,output wire s_wready,
 output wire [3:0] s_bid,output wire [1:0] s_bresp,output wire s_bvalid,input wire s_bready,
 output wire [3:0] m_awid,output wire [31:0] m_awaddr,output wire [7:0] m_awlen,output wire m_awvalid,input wire m_awready,
 output wire [3:0] m_wid,output wire [127:0] m_wdata,output wire [15:0] m_wstrb,output wire m_wlast,m_wvalid,input wire m_wready,
 input wire [3:0] m_bid,input wire [1:0] m_bresp,input wire m_bvalid,output wire m_bready,
 input wire [3:0] probe_aid,input wire [7:0] probe_alen,input wire probe_atype,probe_avalid,probe_aready,
 output wire busy,output reg protocol_error=0
);
 localparam IDLE=0,ADDRESS_ACK=1,DATA=2,RESPONSE=3;
 reg [1:0] state=IDLE;reg [3:0] accepted_id=0;reg [8:0] beats_left=0;
 wire allow_aw=!rst&&(state==IDLE||state==ADDRESS_ACK);
 wire actual_write_accept=!rst&&probe_avalid&&probe_aready&&probe_atype;
 wire upstream_aw_accept=s_awvalid&&s_awready;
 assign m_awid=s_awid;assign m_awaddr=s_awaddr;assign m_awlen=s_awlen;
 assign m_awvalid=allow_aw&&s_awvalid;assign s_awready=allow_aw&&m_awready;
 assign m_wid=accepted_id;assign m_wdata=s_wdata;assign m_wstrb=s_wstrb;
 assign m_wvalid=!rst&&state==DATA&&s_wvalid;assign s_wready=!rst&&state==DATA&&m_wready;
 // Explicit length enforcement; malformed upstream WLAST sets sticky error.
 assign m_wlast=beats_left==1;
 assign s_bid=m_bid;assign s_bresp=m_bresp;assign s_bvalid=!rst&&state==RESPONSE&&m_bvalid;
 assign m_bready=!rst&&state==RESPONSE&&s_bready;
 assign busy=!rst&&state!=IDLE;
 always @(posedge clk) begin
  if(rst)begin state<=IDLE;accepted_id<=0;beats_left<=0;protocol_error<=0;end
  else begin
   if(actual_write_accept)begin
    if(state!=IDLE)protocol_error<=1;
    else begin
     if(!m_awvalid||probe_aid!=s_awid||probe_alen!=s_awlen)protocol_error<=1;
     accepted_id<=probe_aid;beats_left<={1'b0,probe_alen}+1;
     state<=upstream_aw_accept?DATA:ADDRESS_ACK;
    end
   end else if(state==IDLE&&upstream_aw_accept)protocol_error<=1;
   if(state==ADDRESS_ACK&&upstream_aw_accept)begin
    if(s_awid!=accepted_id||{1'b0,s_awlen}+1!=beats_left)protocol_error<=1;
    state<=DATA;
   end
   if(state==DATA&&m_wvalid&&m_wready)begin
    if(s_wlast!=m_wlast)protocol_error<=1;
    if(beats_left==1)begin beats_left<=0;state<=RESPONSE;end
    else beats_left<=beats_left-1;
   end
   if(state==RESPONSE&&s_bvalid&&s_bready)begin
    if(m_bid!=accepted_id)protocol_error<=1;
    state<=IDLE;
   end
  end
 end
endmodule
