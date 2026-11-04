// Source/adaptation: Efinix-Inc/evsoc; raster-stream adaptation, no CPU common_true_dual_port_ram READ_FIRST ring delay
// See docs/SOURCES.md for pinned revision, license and changes.
`timescale 1ns/1ps
`default_nettype none

// D register stages. Every raster clock advances, including blanking.
// RAM is not reset; warm-up masks stale samples, preserving RAM inference.
module stream_delay #(parameter BITS=8, D=1)(
 input wire clk,rst, input wire [BITS-1:0] din, output wire [BITS-1:0] dout);
 generate if(D==0) begin: bypass
  assign dout=din;
 end else if(D==1) begin: single
  reg [BITS-1:0] q;
  always @(posedge clk) if(rst) q<=0; else q<=din;
  assign dout=q;
 end else if(D<=32 || (BITS<=4 && D<=128))begin: register_delay
  reg [BITS-1:0] pipe[0:D-1];integer i;
  always @(posedge clk)begin
   if(rst)for(i=0;i<D;i=i+1)pipe[i]<=0;
   else begin pipe[0]<=din;for(i=1;i<D;i=i+1)pipe[i]<=pipe[i-1];end
  end
  assign dout=pipe[D-1];
 end else if(D>1024)begin: segmented_delay
  wire [BITS-1:0] middle;
  stream_delay #(BITS,1024) first(clk,rst,din,middle);
  stream_delay #(BITS,D-1024) rest(clk,rst,middle,dout);
 end else begin: ring
  localparam N=D-1, AW=(N<2)?1:$clog2(N);
  reg [BITS-1:0] mem[0:N-1];
  reg [BITS-1:0] q;
  reg [AW-1:0] ptr;
  reg [$clog2(D+1)-1:0] fill;
  always @(posedge clk) begin
   if(!rst) begin mem[ptr]<=din; q<=mem[ptr]; end
   if(rst) begin ptr<=0;fill<=0;end
   else begin
    ptr <= (ptr==N-1)?0:ptr+1'b1;
    if(fill<D) fill<=fill+1'b1;
   end
  end
  assign dout=(fill==D)?q:{BITS{1'b0}};
 end endgenerate
endmodule

// Compact metadata for a full origin-based raster. The only deep storage is
// {vs,hs,de}; coordinates are reconstructed from its delayed valid cadence.
// Use COMPACT=0 for cropped/offset coordinates or non-raster streams.
module raster_meta_delay #(parameter D=1, COMPACT=1)(
 input wire clk,rst,input wire [34:0] din,output wire [34:0] dout);
 generate if(!COMPACT) begin: full_metadata
  stream_delay #(35,D) delay_i(clk,rst,din,dout);
 end else begin: compact_metadata
  wire [2:0] sync;
  reg [15:0] x,y;
  reg de_q,vs_q;
  stream_delay #(3,D) delay_i(clk,rst,din[34:32],sync);
  always @(posedge clk) begin
   if(rst) begin x<=0;y<=0;de_q<=0;vs_q<=1;end
   else begin
    de_q<=sync[0];vs_q<=sync[2];
    if(sync[0]) x<=x+1'b1; else x<=0;
    if(sync[2] && !vs_q) y<=0;
    else if(de_q && !sync[0]) y<=y+1'b1;
   end
  end
  assign dout={sync,sync[0]?y:16'hffff,sync[0]?x:16'hffff};
 end endgenerate
endmodule

`default_nettype wire
