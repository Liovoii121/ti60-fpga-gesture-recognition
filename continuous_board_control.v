`timescale 1ns/1ps
// Board-level continuous recognizer. Host JTAG transports weights only.
module continuous_board_control(input wire clk,pixel_clk,bus_reset,ddr_ready,
 input wire key_valid,input wire[3:0]key_code,input wire frame_tick,pixel_valid,video_ready,live_video,
 input wire[15:0]source_frame_id,input wire[10:0]x,y,input wire[47:0]rgb,
 input wire diag_tck,input wire[1023:0]packet_hold_tck,input wire packet_toggle_tck,
 output wire packet_busy_tck,packet_ack_toggle_tck,output wire[255:0]status_tck,
 output wire weights_ready,session_active,recording,done,fault,
 output wire[8:0]recorded_frames,output wire result_valid,accepted,result_fault,
 output wire[4:0]token_count,output wire[47:0]token_words,output wire[16:0]minimum_score_q,
 output wire command_valid,command_write,input wire command_ready,
 output wire[31:0]command_address,output wire[7:0]command_length,
 output wire wvalid,wlast,input wire wready,output wire[127:0]wdata,output wire[15:0]wstrb,
 input wire[127:0]read_data,input wire read_valid,read_last,input wire[1:0]read_response,
 output wire read_ready,input wire bvalid,input wire[1:0]bresp,output wire bready);
 (* async_reg="true" *)reg[1:0]pixel_reset_sync;
 always @(posedge pixel_clk or posedge bus_reset)
  if(bus_reset)pixel_reset_sync<=2'b11;
  else pixel_reset_sync<={pixel_reset_sync[0],1'b0};
 wire pixel_reset=pixel_reset_sync[1];
 reg key_toggle,cancel_toggle;
 (* async_reg="true" *)reg[2:0] key_sync,cancel_sync;
 reg key_seen,cancel_seen;
 wire command_event=key_sync[2]!=key_seen;
 wire user_cancel=cancel_sync[2]!=cancel_seen;
 wire start=command_event&&!session_active;
 wire stop=command_event&&session_active;
 always @(posedge pixel_clk or posedge pixel_reset)begin
  if(pixel_reset)begin key_toggle<=0;cancel_toggle<=0;end
  else if(key_valid)begin
   if(key_code==13)key_toggle<=!key_toggle;
   if(key_code==12||key_code==15)cancel_toggle<=!cancel_toggle;
  end
 end
 always @(posedge clk or posedge bus_reset)begin
  if(bus_reset)begin key_sync<=0;cancel_sync<=0;key_seen<=0;cancel_seen<=0;end
  else begin key_sync<={key_sync[1:0],key_toggle};cancel_sync<={cancel_sync[1:0],cancel_toggle};key_seen<=key_sync[2];cancel_seen<=cancel_sync[2];end
 end
 (* async_reg="true" *)reg[1:0] record_sync,stopped_sync;
 (* async_reg="true" *)reg[2:0] error_sync;
 reg error_toggle,error_seen,error_latched;
 wire pixel_error=error_sync[2]!=error_seen;
 wire sample_active,sample_valid,sample_ready,sample_done,sample_drop;
 wire[11:0]sample_index;wire[7:0]sample_gray;wire[31:0]sample_id;
 // Video-bank identity belongs to the DDR clock domain. It is held for the
 // complete read frame. Synchronize it during blanking, then sample at first
 // active pixel, after video prefetch has selected this frame's bank.
 (* async_reg="true" *)reg[15:0]source_meta,source_sync;
 wire sample_frame_start=pixel_valid&&x==0&&y==0;
 reg[15:0]last_source;reg[31:0]extended_source;wire[15:0]source_delta=source_sync-last_source;
 wire[31:0]actual_frame_id=extended_source+{16'd0,source_delta};
 wire run_pixel=(record_sync[1]||sample_active)&&video_ready&&live_video;
 wire fifo_ready,fifo_overflow,fifo_valid,fifo_take;wire[19:0]fifo_data;
 wire pixel_stopped=!record_sync[1]&&!sample_active;
 always @(posedge pixel_clk or posedge pixel_reset)begin
  if(pixel_reset)begin record_sync<=0;last_source<=0;extended_source<=0;error_toggle<=0;error_latched<=0;source_meta<=0;source_sync<=0;end
  else begin record_sync<={record_sync[0],recording};
   source_meta<=source_frame_id;source_sync<=source_meta;
   if(!run_pixel)error_latched<=0;
   else if((sample_drop||(sample_valid&&!fifo_ready))&&!error_latched)begin error_latched<=1;error_toggle<=!error_toggle;end
   if(sample_frame_start)begin last_source<=source_sync;extended_source<=actual_frame_id;end
  end
 end
 always @(posedge clk or posedge bus_reset)begin
  if(bus_reset)begin stopped_sync<=3;error_sync<=0;error_seen<=0;end
  else begin stopped_sync<={stopped_sync[0],pixel_stopped};error_sync<={error_sync[1:0],error_toggle};error_seen<=error_sync[2];end
 end
 continuous_roi_sampler sampler(.clk(pixel_clk),.rst(pixel_reset),.enable(run_pixel),.cancel(1'b0),
 .frame_start(sample_frame_start),.pixel_valid(pixel_valid),.frame_store_ready(fifo_ready),.frame_id(actual_frame_id),.x(x),.y(y),.rgb_pair(rgb),
 .sample_valid(sample_valid),.frame_done(sample_done),.dropped_frame(sample_drop),.sample_address(sample_index),.gray(sample_gray),.sampled_frame_id(sample_id),.frame_active(sample_active));
 continuous_sample_fifo fifo(.pixel_clk(pixel_clk),.bus_clk(clk),.bus_reset(bus_reset),.pixel_reset(pixel_reset),.sample_valid(sample_valid),.sample_data({sample_index,sample_gray}),
 .sample_ready(fifo_ready),.overflow_pixel(fifo_overflow),.valid(fifo_valid),.data(fifo_data),.ready(fifo_take));
 wire ingest_q,ingest_r,ingest_d,ingest_f,ingest_a;wire[31:0]ingest_addr,ingest_value;
 wire fq,sq,fr,sr,fd,ff,backend_busy,mem_idle;wire[8:0]fi,sn;
 wire load_start,load_cancel,load_ready,load_active,load_stream_valid,load_stream_last,load_stream_ready,load_done,load_aborted,load_fault;
 wire[31:0]load_length,load_crc,load_bytes,load_observed;wire[2:0]load_code;wire[127:0]load_data;
 jtag_weight_transport_bridge transport(.clk(clk),.diag_tck(diag_tck),.bus_reset(bus_reset),.cancel(user_cancel),
 .packet_hold_tck(packet_hold_tck),.packet_toggle_tck(packet_toggle_tck),.packet_busy_tck(packet_busy_tck),.packet_ack_toggle_tck(packet_ack_toggle_tck),.status_tck(status_tck),
 .load_start(load_start),.load_cancel(load_cancel),.load_byte_length(load_length),.load_expected_crc32(load_crc),
 .load_start_ready(load_ready),.load_active(load_active),.weights_ready(weights_ready),.load_fault(load_fault),.load_error_code(load_code),.load_bytes_written(load_bytes),.load_observed_crc32(load_observed),.memory_idle(mem_idle),
 .stream_valid(load_stream_valid),.stream_last(load_stream_last),.stream_data(load_data),.stream_ready(load_stream_ready));
 wire[1:0]cv,cw,cr,wv,wl,wr,rv,rl,rr,bv,br;wire[63:0]ca;wire[15:0]cl;wire[255:0]wd;wire[31:0]ws;wire[127:0]rd;wire[3:0]rp,bp;
 continuous_clip_engine clip(.clk(clk),.bus_reset(bus_reset),.cancel(user_cancel),.start(start),.stop(stop),.weights_ready(weights_ready),
 .pixel_stopped(stopped_sync[1]),.pixel_fault(pixel_error),.recording(recording),.session_active(session_active),.done(done),.fault(fault),.recorded_frames(recorded_frames),
 .sample_valid(fifo_valid),.sample_data(fifo_data),.sample_ready(fifo_take),
 .ingest_request(ingest_q),.ingest_address(ingest_addr),.ingest_data(ingest_value),.ingest_ready(ingest_r),.ingest_done(ingest_d),.ingest_fault(ingest_f),.ingest_aborted(ingest_a),
 .frame_request(fq),.sequence_request(sq),.frame_index(fi),.sequence_frames(sn),.frame_ready(fr),.sequence_ready(sr),.frame_done(fd),.frame_fault(ff),.result_valid(result_valid),
 .command_valid(cv[0]),.command_write(cw[0]),.command_ready(cr[0]),.command_address(ca[0+:32]),.command_length(cl[0+:8]),
 .wvalid(wv[0]),.wlast(wl[0]),.wready(wr[0]),.wdata(wd[0+:128]),.wstrb(ws[0+:16]),
 .read_data(rd),.read_valid(rv[0]),.read_last(rl[0]),.read_response(rp[0+:2]),.read_ready(rr[0]),.bvalid(bv[0]),.bresp(bp[0+:2]),.bready(br[0]));
 wire overflow;
 nn_backend backend(.clk(clk),.bus_reset(bus_reset),.nn_reset(1'b0),.cancel(user_cancel||load_cancel),.ddr_ready(ddr_ready),.session_active(session_active),
 .load_start(load_start),.load_byte_length(load_length),.load_expected_crc32(load_crc),.load_start_ready(load_ready),.load_active(load_active),.load_stream_ready(load_stream_ready),.load_stream_valid(load_stream_valid),.load_stream_last(load_stream_last),.load_stream_data(load_data),
 .weights_ready(weights_ready),.load_done(load_done),.load_aborted(load_aborted),.load_fault(load_fault),.load_error_code(load_code),.load_bytes_written(load_bytes),.load_observed_crc32(load_observed),
 .ingest_request(ingest_q),.ingest_address(ingest_addr),.ingest_data(ingest_value),.ingest_ready(ingest_r),.ingest_done(ingest_d),.ingest_fault(ingest_f),.ingest_aborted(ingest_a),
 .frame_request(fq),.sequence_request(sq),.frame_index(fi),.sequence_frames(sn),.frame_ready(fr),.sequence_ready(sr),.frame_done(fd),.frame_fault(ff),.busy(backend_busy),.memory_idle(mem_idle),
 .result_valid(result_valid),.result_ready(1'b1),.accepted(accepted),.overflow(overflow),.result_fault(result_fault),.token_count(token_count),.token_words(token_words),.minimum_score_q(minimum_score_q),
 .command_valid(cv[1]),.command_write(cw[1]),.command_ready(cr[1]),.command_address(ca[32+:32]),.command_length(cl[8+:8]),
 .wvalid(wv[1]),.wlast(wl[1]),.wready(wr[1]),.wdata(wd[128+:128]),.wstrb(ws[16+:16]),
 .read_data(rd),.read_valid(rv[1]),.read_last(rl[1]),.read_response(rp[2+:2]),.read_ready(rr[1]),.bvalid(bv[1]),.bresp(bp[2+:2]),.bready(br[1]));
 wire[7:0]unused_id;
 ddr_transaction_arbiter local_bus(.clk(clk),.rst(bus_reset),.ddr_ready(ddr_ready),.req_valid(cv),.req_write(cw),.req_ready(cr),.req_addr(ca),.req_len(cl),.req_id(16'd0),
 .client_wdata(wd),.client_wstrb(ws),.client_wvalid(wv),.client_wlast(wl),.client_wready(wr),.client_rdata(rd),.client_rvalid(rv),.client_rlast(rl),.client_rready(rr),.client_rresp(rp),.client_bresp(bp),.client_bvalid(bv),.client_bready(br),
 .ddr_addr(command_address),.ddr_len(command_length),.ddr_id(unused_id),.ddr_write(command_write),.ddr_avalid(command_valid),.ddr_aready(command_ready),
 .ddr_wdata(wdata),.ddr_wstrb(wstrb),.ddr_wvalid(wvalid),.ddr_wlast(wlast),.ddr_wready(wready),
 .ddr_rdata(read_data),.ddr_rvalid(read_valid),.ddr_rlast(read_last),.ddr_rresp(read_response),.ddr_bresp(bresp),.ddr_bvalid(bvalid),.ddr_rready(read_ready),.ddr_bready(bready),.video_write_committed(),.transaction_active());
endmodule
