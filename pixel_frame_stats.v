`default_nettype none
module pixel_frame_stats #(parameter LANES=4)(
 input wire clk,resetn,vs,de,input wire[31:0]data,
 input wire sys_clk,sys_resetn,output wire[191:0]status);
 reg vq=0,have=0,toggle=0;
 reg[31:0]sum=0,changes=0,first=0,last=0,frames=0;
 reg[7:0]lo=255,hi=0;
 reg[191:0]held=0,published=0;
 reg[10:0]add;reg[7:0]clo,chi;integer i;
 always @*begin
 add=0;clo=255;chi=0;
 for(i=0;i<LANES;i=i+1)begin
 add=add+{3'd0,data[i*8+:8]};
 if(data[i*8+:8]<clo)clo=data[i*8+:8];
 if(data[i*8+:8]>chi)chi=data[i*8+:8];
 end end
 always @(posedge clk)begin
 if(!resetn)begin vq<=0;have<=0;toggle<=0;sum<=0;changes<=0;first<=0;last<=0;frames<=0;lo<=255;hi<=0;held<=0;end
 else begin
 vq<=vs;
 if(de)begin
 sum<=sum+add;last<=data;
 if(!have)begin first<=data;have<=1;end
 else if(data!=last)changes<=changes+1'b1;
 if(clo<lo)lo<=clo;if(chi>hi)hi<=chi;
 end
 if(vq&&!vs)begin
 held<={last,first,16'd0,lo,hi,changes,sum,frames};toggle<=!toggle;
 frames<=frames+1'b1;sum<=0;changes<=0;have<=0;lo<=255;hi<=0;
 end
 end end
 (* async_reg="true" *)reg[1:0]sync=0;reg seen=0;
 always @(posedge sys_clk)begin
 if(!sys_resetn)begin sync<=0;seen<=0;published<=0;end
 else begin sync<={sync[0],toggle};
 // The producer holds a completed frame record for milliseconds. Capture
 // only after the bundled-data toggle has crossed two synchronizer stages.
 if(sync[1]!=seen)begin published<=held;seen<=sync[1];end
 end end
 assign status=published;
endmodule
`default_nettype wire
