`timescale 1ns/1ps
// Bus-clock NN subsystem. No PC computes scores: LOAD only transports parameters.
// session_active must span capture through sequence result, preventing model
// replacement between frame encoding and temporal inference.
module nn_backend(input wire clk,bus_reset,nn_reset,cancel,ddr_ready,session_active,
 input wire load_start,input wire[31:0] load_byte_length,load_expected_crc32,
 output wire load_start_ready,load_active,load_stream_ready,
 input wire load_stream_valid,load_stream_last,input wire[127:0] load_stream_data,
 output wire weights_ready,load_done,load_aborted,load_fault,
 output wire[2:0] load_error_code,output wire[31:0] load_bytes_written,load_observed_crc32,
 input wire ingest_request,input wire[31:0] ingest_address,ingest_data,
 output wire ingest_ready,ingest_done,ingest_fault,ingest_aborted,
 input wire frame_request,sequence_request,input wire[8:0] frame_index,sequence_frames,
 output wire frame_ready,sequence_ready,frame_done,frame_fault,busy,memory_idle,
 output wire result_valid,input wire result_ready,
 output wire accepted,overflow,result_fault,output wire[4:0] token_count,
 output wire[47:0] token_words,output wire[16:0] minimum_score_q,
 output wire command_valid,command_write,input wire command_ready,
 output wire[31:0] command_address,output wire[7:0] command_length,
 output wire wvalid,wlast,input wire wready,output wire[127:0] wdata,output wire[15:0] wstrb,
 input wire[127:0] read_data,input wire read_valid,read_last,input wire[1:0] read_response,
 output wire read_ready,input wire bvalid,input wire[1:0] bresp,output wire bready);
 wire core_busy,core_fd,core_sd,core_fault,core_fr,core_sq,core_inv,core_cancel,core_p_act;
 wire reader_busy,reader_sr,reader_inv,reader_cancel,reader_valid,reader_accepted,reader_overflow,reader_fault;
 wire[4:0] reader_count;wire[47:0] reader_words;wire[16:0] reader_score;
 reg reader_pending,sequence_error,store_owner_ingest,ingest_pending,bad_ingest;
 reg[8:0] accepted_sequence_frames;
 wire reader_selected=reader_pending||reader_busy||core_sd;
 wire load_eligible=!session_active&&!core_busy&&!reader_selected&&!sequence_error&&!ingest_pending&&!bad_ingest;
 wire block_new=reader_selected||sequence_error||load_active||(load_start&&!session_active)||bad_ingest;
 wire allow_jobs=!block_new&&!ingest_pending&&!ingest_request;
 wire allow_ingest=!core_busy&&!block_new&&weights_ready;
 wire m_load_ready,m_store_ready,m_store_done,m_store_fault,m_store_aborted;
 wire m_cancel=nn_reset||cancel||(core_busy&&core_cancel)||(reader_busy&&reader_cancel);
 wire m_invalidate=core_inv||reader_inv;
 wire car,cpr,csr,carr,cprr,rar,rarr;wire[31:0] caa,cpa,csa,csd,raa;
 wire m_ar=reader_selected?rar:car;wire[31:0] m_aa=reader_selected?raa:caa;
 wire m_arr=reader_selected?rarr:carr;
 wire m_a_ready,m_a_valid,m_a_fault;wire[31:0] m_a_data;
 wire m_p_ready,m_p_valid,m_p_fault;wire[31:0] m_p_data;
 wire ingest_range=ingest_address>=32'h00840000&&ingest_address<32'h00844000&&ingest_address[1:0]==0;
 wire m_store_request=core_busy?csr:(allow_ingest&&ingest_request&&ingest_range&&!bad_ingest);
 wire[31:0] m_store_address=core_busy?csa:ingest_address;
 wire[31:0] m_store_data=core_busy?csd:ingest_data;
 assign load_start_ready=load_eligible&&m_load_ready;
 assign frame_ready=allow_jobs&&core_fr;
 assign sequence_ready=allow_jobs&&core_sq;
 assign frame_done=core_fd;
 assign frame_fault=core_fd&&core_fault;
 assign busy=core_busy||reader_selected||sequence_error||ingest_pending||load_active;
 assign ingest_ready=allow_ingest&&m_store_ready&&!bad_ingest;
 assign ingest_done=(m_store_done&&store_owner_ingest)||bad_ingest;
 assign ingest_fault=bad_ingest||(m_store_done&&m_store_fault&&store_owner_ingest);
 assign ingest_aborted=m_store_done&&m_store_aborted&&store_owner_ingest;
 assign result_valid=reader_valid||sequence_error;
 assign accepted=reader_valid&&reader_accepted&&!sequence_error;
 assign overflow=reader_overflow&&!sequence_error;
 assign result_fault=sequence_error||(reader_valid&&reader_fault);
 assign token_count=sequence_error?5'd0:reader_count;
 assign token_words=sequence_error?48'd0:reader_words;
 assign minimum_score_q=sequence_error?17'd0:reader_score;
 always @(posedge clk)begin
  if(bus_reset||nn_reset)begin reader_pending<=0;sequence_error<=0;store_owner_ingest<=0;ingest_pending<=0;bad_ingest<=0;accepted_sequence_frames<=0;end
  else begin
   bad_ingest<=0;
   if(sequence_request&&sequence_ready)accepted_sequence_frames<=sequence_frames;
   if(m_store_request&&m_store_ready)begin store_owner_ingest<=!core_busy;if(!core_busy)ingest_pending<=1;end
   if(m_store_done)ingest_pending<=0;
   if(ingest_request&&ingest_ready&&!ingest_range)bad_ingest<=1;
   if(cancel)begin reader_pending<=0;sequence_error<=0;end
   else begin
    if(core_sd)begin if(core_fault)sequence_error<=1;else reader_pending<=1;end
    if(reader_pending&&reader_sr)reader_pending<=0;
    if(sequence_error&&result_ready)sequence_error<=0;
   end
  end
 end
 nn_compute_core compute(.clk(clk),.nn_reset(nn_reset||bus_reset),.cancel(cancel),.weights_ready(weights_ready),.memory_idle(memory_idle),
 .frame_request(frame_request&&allow_jobs),.sequence_request(sequence_request&&allow_jobs),.requested_frame_index(frame_index),.requested_sequence_frames(sequence_frames),
 .frame_ready(core_fr),.sequence_ready(core_sq),.busy(core_busy),.frame_done(core_fd),.sequence_done(core_sd),.fault(core_fault),.cache_invalidate(core_inv),.client_cancel(core_cancel),.parameter_is_activation(core_p_act),
 .activation_request(car),.activation_address(caa),.activation_ready(m_a_ready&&!reader_selected),.activation_response(m_a_valid&&!reader_selected),.activation_data(m_a_data),.activation_fault(m_a_fault),.activation_response_ready(carr),
 .parameter_request(cpr),.parameter_address(cpa),.parameter_ready(m_p_ready&&!reader_selected),.parameter_response(m_p_valid&&!reader_selected),.parameter_data(m_p_data),.parameter_fault(m_p_fault),.parameter_response_ready(cprr),
 .store_request(csr),.store_address(csa),.store_data(csd),.store_ready(m_store_ready&&core_busy),.store_response(m_store_done&&!store_owner_ingest),.store_fault(m_store_fault));
 nn_sequence_reader reader(.clk(clk),.rst(nn_reset||bus_reset),.cancel(cancel),.start(reader_pending&&reader_sr),.memory_idle(memory_idle),.frames(accepted_sequence_frames),.threshold_q(17'd43910),
 .start_ready(reader_sr),.busy(reader_busy),.cache_invalidate(reader_inv),.client_cancel(reader_cancel),
 .activation_request(rar),.activation_address(raa),.activation_ready(m_a_ready&&reader_selected),.activation_response(m_a_valid&&reader_selected),.activation_data(m_a_data),.activation_fault(m_a_fault),.activation_response_ready(rarr),
 .result_valid(reader_valid),.result_ready(result_ready&&!sequence_error),.accepted(reader_accepted),.overflow(reader_overflow),.fault(reader_fault),.token_count(reader_count),.token_words(reader_words),.minimum_score_q(reader_score));
 neural_memory_client memory(.clk(clk),.bus_reset(bus_reset),.ddr_ready(ddr_ready),.cancel(m_cancel),.invalidate(m_invalidate),
 .load_start(load_start&&load_eligible),.load_byte_length(load_byte_length),.load_expected_crc32(load_expected_crc32),.load_start_ready(m_load_ready),.load_active(load_active),.load_stream_ready(load_stream_ready),
 .load_stream_valid(load_stream_valid),.load_stream_last(load_stream_last),.load_stream_data(load_stream_data),.weights_ready(weights_ready),.load_done(load_done),.load_aborted(load_aborted),.load_fault(load_fault),
 .load_error_code(load_error_code),.load_bytes_written(load_bytes_written),.load_observed_crc32(load_observed_crc32),
 .param_request(cpr&&!reader_selected),.param_activation_mode(core_p_act&&!reader_selected),.param_address(cpa),.param_ready(m_p_ready),.param_response_valid(m_p_valid),.param_response_fault(m_p_fault),.param_response_data(m_p_data),.param_response_ready(cprr&&!reader_selected),
 .activation_request(m_ar),.activation_address(m_aa),.activation_ready(m_a_ready),.activation_response_valid(m_a_valid),.activation_response_fault(m_a_fault),.activation_response_data(m_a_data),.activation_response_ready(m_arr),
 .store_request(m_store_request),.store_address(m_store_address),.store_data(m_store_data),.store_ready(m_store_ready),.store_done(m_store_done),.store_fault(m_store_fault),.store_aborted(m_store_aborted),.memory_idle(memory_idle),
 .command_valid(command_valid),.command_write(command_write),.command_ready(command_ready),.command_address(command_address),.command_length(command_length),
 .wvalid(wvalid),.wlast(wlast),.wready(wready),.wdata(wdata),.wstrb(wstrb),.read_data(read_data),.read_valid(read_valid),.read_last(read_last),.read_response(read_response),.read_ready(read_ready),.bvalid(bvalid),.bresp(bresp),.bready(bready));
endmodule
