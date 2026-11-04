`timescale 1ns/1ps
`include "gesture_thresholds.vh"

//`include "ddr3_controller.vh"


module example_top 
(output amp_bclk,amp_lrclk,amp_din,output lcd_dclk,output [7:0] rgb_lcd_r,rgb_lcd_g,rgb_lcd_b,
output rgb_lcd_de,rgb_lcd_hs,rgb_lcd_vs,rgb_lcd_bl,rgb_touch_rst,
input diag_capture,diag_drck,diag_reset,diag_runtest,diag_sel,diag_shift,
input diag_tck,diag_tdi,diag_tms,diag_update,output diag_tdo,

	////////////////////////////////////////////////////////////////
	//	External Clock & Reset
	//input 			nrst, 			//	Button K2
	input 			clk_24m,			//	24MHz Crystal
	input 			clk_25m,			//	25MHz Crystal 
	
	
	////////////////////////////////////////////////////////////////
	//	System Clock
	output 			sys_pll_rstn_o, 		
	
	input 			clk_sys,			//	Sys PLL 96MHz 
	input 			clk_pixel,			//	Sys PLL 74.25MHz
	input 			clk_nn,		// CNN clock 74.4 MHz
	input 			clk_pixel_10x,		//	Sys PLL 742.5MHz
	
	input 			sys_pll_lock,		//	Sys PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	MIPI-DSI Clock & Reset
	output 			dsi_pll_rstn_o,
	
	input 			dsi_refclk_i,		//	48MHz Reference Clock (for DSI PLL)
	input 			dsi_byteclk_i,		//	DSI Byte Clock (1X)
	input 			dsi_serclk_i,		//	DSI Serial Clock (4X 45)
	input 			dsi_txcclk_i,		//	DSI Serial Clock (4X 135)
	
	input 			dsi_pll_lock,
	
	////////////////////////////////////////////////////////////////
	//	DDR Clock
	output 			ddr_pll_rstn_o, 
	
	input 			tdqss_clk,			
	input 			core_clk,			//	DDR PLL 200MHz
	input 			tac_clk,			
	input 			twd_clk,			
	
	input 			ddr_pll_lock,		//	DDR PLL Lock
	
	////////////////////////////////////////////////////////////////
	//	DDR PLL Phase Shift Interface
	output 	[2:0] 	shift,
	output 	[4:0] 	shift_sel,
	output 			shift_ena,
	
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Clock
	output 			lvds_pll_rstn_o, 
	
	input 			clk_lvds_1x, 
	input 			clk_lvds_7x, 
	input 			clk_27m, 			//	RGB 1X Clock (16MHz)
	input 			clk_54m, 			//	RGB 2X Clock (32MHz, for export control)
	
	input 			lvds_pll_lock, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DDR Interface Ports
	output 	[15:0] 	addr,
	output 	[2:0] 	ba,
	output 			we,
	output 			reset,
	output 			ras,
	output 			cas,
	output 			odt,
	output 			cke,
	output 			cs,
	
	//	DQ I/O
	input 	[15:0] 	i_dq_hi,
	input 	[15:0] 	i_dq_lo,
	
	output 	[15:0] 	o_dq_hi,
	output 	[15:0] 	o_dq_lo,
	output 	[15:0] 	o_dq_oe,
	
	//	DM O
	output 	[1:0] 	o_dm_hi,
	output 	[1:0] 	o_dm_lo,
	
	//	DQS I/O
	input 	[1:0] 	i_dqs_hi,
	input 	[1:0] 	i_dqs_lo,
	
//	input 	[1:0] 	i_dqs_n_hi,
//	input 	[1:0] 	i_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_hi,
	output 	[1:0] 	o_dqs_lo,
	
//	output 	[1:0] 	o_dqs_n_hi,
//	output 	[1:0] 	o_dqs_n_lo,
	
	output 	[1:0] 	o_dqs_oe,
	output 	[1:0] 	o_dqs_n_oe,
	
	//	CK
	output 			clk_p_hi, 
	output 			clk_p_lo, 
	output 			clk_n_hi, 
	output 			clk_n_lo, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Ctl / I2C
	output 			csi_ctl0_o,
	output 			csi_ctl0_oe,
	input 			csi_ctl0_i,
	
	output 			csi_ctl1_o,
	output 			csi_ctl1_oe,
	input 			csi_ctl1_i,
	
	output 			csi_scl_o,
	output 			csi_scl_oe,
	input 			csi_scl_i,
	
	output 			csi_sda_o,
	output 			csi_sda_oe,
	input 			csi_sda_i,
	
	//	MIPI-CSI RXC 
	input 			csi_rxc_lp_p_i,
	input 			csi_rxc_lp_n_i,
	output 			csi_rxc_hs_en_o,
	output 			csi_rxc_hs_term_en_o,
	input 			csi_rxc_i,
	
	//	MIPI-CSI RXD0
	output 			csi_rxd0_rst_o,
	output 			csi_rxd0_hs_en_o,
	output 			csi_rxd0_hs_term_en_o,
	
	input 			csi_rxd0_lp_p_i,
	input 			csi_rxd0_lp_n_i,
	input 	[7:0] 	csi_rxd0_hs_i,
	
	//	MIPI-CSI RXD1
	output 			csi_rxd1_rst_o,
	output 			csi_rxd1_hs_en_o,
	output 			csi_rxd1_hs_term_en_o,
	
	input 			csi_rxd1_lp_n_i,
	input 			csi_rxd1_lp_p_i,
	input 	[7:0] 	csi_rxd1_hs_i,
	
	//	MIPI-CSI RXD2
	output 			csi_rxd2_rst_o,
	output 			csi_rxd2_hs_en_o,
	output 			csi_rxd2_hs_term_en_o,
	
	input 			csi_rxd2_lp_p_i,
	input 			csi_rxd2_lp_n_i,
	input 	[7:0] 	csi_rxd2_hs_i,
	
	//	MIPI-CSI RXD3
	output 			csi_rxd3_rst_o,
	output 			csi_rxd3_hs_en_o,
	output 			csi_rxd3_hs_term_en_o,
	
	input 			csi_rxd3_lp_p_i,
	input 			csi_rxd3_lp_n_i,
	input 	[7:0] 	csi_rxd3_hs_i,
	
	//output 			csi_rxd0_fifo_rd_o, 
	//input 			csi_rxd0_fifo_empty_i, 
	//output 			csi_rxd1_fifo_rd_o, 
	//input 			csi_rxd1_fifo_empty_i, 
	//output 			csi_rxd2_fifo_rd_o, 
	//input 			csi_rxd2_fifo_empty_i, 
	//output 			csi_rxd3_fifo_rd_o, 
	//input 			csi_rxd3_fifo_empty_i, 
	
	
	
	////////////////////////////////////////////////////////////////
	//	DSI PWM & Reset Control 
	output 			dsi_pwm_o,			//	MIPI-DSI LCD PWM
	output 			dsi_resetn_o,		//	MIPI-DSI LCD Reset
	
	//	MIPI-DSI TXC / TXD
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	UART Interface
	
	
	output 	[5:0] 	led_o,			//	
	
	
	////////////////////////////////////////////////////////////////
	//	CMOS Sensor
	output 			cmos_sclk,
	input 			cmos_sdat_IN,
	output 			cmos_sdat_OUT,
	output 			cmos_sdat_OE,
	
	//	CMOS Interface
	input 			cmos_pclk,
	input 			cmos_vsync,
	input 			cmos_href,
	input 	[7:0] 	cmos_data,
	input 			cmos_ctl1,
	output 			cmos_ctl2,
	output 			cmos_ctl3,
	
	
	////////////////////////////////////////////////////////////////
	//	HDMI Interface
	output 			hdmi_txc_oe,
	output 			hdmi_txd0_oe,
	output 			hdmi_txd1_oe,
	output 			hdmi_txd2_oe,
	
	output 			hdmi_txc_rst_o,
	output 			hdmi_txd0_rst_o,
	output 			hdmi_txd1_rst_o,
	output 			hdmi_txd2_rst_o,
	
	output 	[9:0] 	hdmi_txc_o,
	output 	[9:0] 	hdmi_txd0_o,
	output 	[9:0] 	hdmi_txd1_o,
	output 	[9:0] 	hdmi_txd2_o,
	
	
	////////////////////////////////////////////////////////////////
	//	LVDS Interface
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	RGB LCD 5Inch 800x480
	output 			lcd_tp_sda_o,		//	TP SDA
	output 			lcd_tp_sda_oe,
	input 			lcd_tp_sda_i,
	
	output 			lcd_tp_scl_o,		//	TP SCL
	output 			lcd_tp_scl_oe,
	input 			lcd_tp_scl_i,
	
	output 			lcd_tp_int_o,		//	TP INT
	output 			lcd_tp_int_oe,
	input 			lcd_tp_int_i,
	
	output 			lcd_tp_rst_o,		//	TP RST
	
	output 			lcd_pwm_o,			//	Backlight
	output 			lcd_blen_o,
	
	//output 			lcd_pclk_o,			//	PCLK & SCK Mux
	output 			lcd_vs_o,			//	VS & SSN Mux. Fixed to 1. Use DE-Only mode. 
	output 			lcd_hs_o,			//	HS. Fixed to 1. Use DE-Only mode. 
	output 			lcd_de_o,			//	DE. 

	output 	[7:0] 	lcd_b7_0_o,			//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_o,			//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_o,			//	R7:R0. 
	
	output 	[7:0] 	lcd_b7_0_oe,		//	B7:B0. 
	output 	[7:0] 	lcd_g7_0_oe,		//	G7:G0. Must output 8'hFF when access SPI. 
	output 	[7:0] 	lcd_r7_0_oe,		//	R7:R0. 

	input 	[7:0] 	lcd_b7_0_i,			//	B7:B0. 
	input 	[7:0] 	lcd_g7_0_i,			//	G7:G0. Must output 8'hFF when access SPI. 
	input 	[7:0] 	lcd_r7_0_i,			//	R7:R0. 
	
	//	SPI Pins
	output 			spi_sck_o, 
	output 			spi_ssn_o 			
);
	
	wire 			csi_rxd0_fifo_rd_o; 
	wire 			csi_rxd0_fifo_empty_i = 0;  
	wire 			csi_rxd1_fifo_rd_o;  
	wire 			csi_rxd1_fifo_empty_i = 0;  
	wire 			csi_rxd2_fifo_rd_o;  
	wire 			csi_rxd2_fifo_empty_i = 0;  
	wire 			csi_rxd3_fifo_rd_o;  
	wire 			csi_rxd3_fifo_empty_i = 0;  
	
	wire 	[1:0] 	i_dqs_n_hi;
	wire 	[1:0] 	i_dqs_n_lo;
	wire 	[1:0] 	o_dqs_n_hi;
	wire 	[1:0] 	o_dqs_n_lo;
	
	
	parameter 	SIM_DATA 	= 0; 
	
	//	Hardware Configuration
	assign clk_p_hi = 1'b0;	//	DDR3 Clock requires 180 degree shifted. 
	assign clk_p_lo = 1'b1;
	assign clk_n_hi = 1'b1;
	assign clk_n_lo = 1'b0; 
	
	//	System Clock Tree Control
	assign sys_pll_rstn_o = 1'b1; 	//	nrst; 	//	Reset whole system when nrst (K2) is pressed. 
	
	assign dsi_pll_rstn_o = sys_pll_lock; 
	assign ddr_pll_rstn_o = sys_pll_lock; 
	assign lvds_pll_rstn_o = sys_pll_lock; 
	
	wire 			w_pll_lock = sys_pll_lock && dsi_pll_lock && ddr_pll_lock && lvds_pll_lock; 
	
	//	Synchronize System Resets. 
	reg 			rstn_sys = 0, rstn_pixel = 0; 
	wire 			rst_sys = ~rstn_sys, rst_pixel = ~rstn_pixel; 
	
	reg 			rstn_dsi_refclk = 0, rstn_dsi_byteclk = 0; 
	wire 			rst_dsi_refclk = ~rstn_dsi_refclk, rst_dsi_byteclk = ~rstn_dsi_byteclk; 
	
	reg 			rstn_lvds_1x = 0; 
	wire 			rst_lvds_1x = ~rstn_lvds_1x; 
	
	reg 			rstn_27m = 0, rstn_54m = 0; 
	wire 			rst_27m = ~rstn_27m, rst_54m = ~rstn_54m; 
	
	//	Clock Gen
	always @(posedge clk_27m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_27m <= 0; else rstn_27m <= 1; end
	always @(posedge clk_54m or negedge w_pll_lock) begin if(~w_pll_lock) rstn_54m <= 0; else rstn_54m <= 1; end
	always @(posedge clk_sys or negedge w_pll_lock) begin if(~w_pll_lock) rstn_sys <= 0; else rstn_sys <= 1; end
	always @(posedge clk_pixel or negedge w_pll_lock) begin if(~w_pll_lock) rstn_pixel <= 0; else rstn_pixel <= 1; end
	always @(posedge dsi_refclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_refclk <= 0; else rstn_dsi_refclk <= 1; end
	always @(posedge dsi_byteclk_i or negedge w_pll_lock) begin if(~w_pll_lock) rstn_dsi_byteclk <= 0; else rstn_dsi_byteclk <= 1; end
	always @(posedge clk_lvds_1x or negedge w_pll_lock) begin if(~w_pll_lock) rstn_lvds_1x <= 0; else rstn_lvds_1x <= 1; end
	
	
	localparam 	CLOCK_MAIN 	= 96000000; 	//	System clock using 96MHz. 
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	Flash Burner Control
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	wire 			w_ustick, w_mstick; 
	
// Configuration owns Flash until user mode; no runtime Flash transactions.
wire flash_release = rstn_sys;
reg fabric_unlocked=0;
wire [7:0] w_lcd_b_o,w_lcd_g_o,w_lcd_r_o;
flash_lcd_mux boot_pin_owner(.resetn(rstn_sys),.pixel_clk(clk_pixel),.pixel_resetn(rstn_pixel),
 .flash_release(flash_release),.cpu_cs_n(1'b1),.cpu_sclk(1'b0),.cpu_data(4'd0),.cpu_oe(4'd0),
 .lcd_r(w_lcd_r_o),.lcd_g(w_lcd_g_o),.lcd_b(w_lcd_b_o),.flash_cs_n(spi_ssn_o),.flash_sclk(spi_sck_o),
 .pin_r(lcd_r7_0_o),.pin_g(lcd_g7_0_o),.pin_b(lcd_b7_0_o),.oe_r(lcd_r7_0_oe),.oe_g(lcd_g7_0_oe),.oe_b(lcd_b7_0_oe));

	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	DDR3 Controller
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	wire			w_ddr3_ui_clk = clk_sys;
	wire			w_ddr3_ui_rst = rst_sys;
	wire			w_ddr3_ui_areset = rst_sys;
	wire			w_ddr3_ui_aresetn = rstn_sys;
	

	//	General AXI Interface 
	wire	[3:0] 	w_ddr3_awid;
	wire	[31:0]	w_ddr3_awaddr;
	wire	[7:0]		w_ddr3_awlen;
	wire			w_ddr3_awvalid;
	wire			w_ddr3_awready;
	
	wire 	[3:0]  	w_ddr3_wid;
	wire 	[127:0] 	w_ddr3_wdata;
	wire 	[15:0]	w_ddr3_wstrb;
	wire			w_ddr3_wlast;
	wire			w_ddr3_wvalid;
	wire			w_ddr3_wready;
	
	wire 	[3:0] 	w_ddr3_bid;
	wire 	[1:0] 	w_ddr3_bresp;
	wire			w_ddr3_bvalid;
	wire			w_ddr3_bready;
	
	wire	[3:0] 	w_ddr3_arid;
	wire	[31:0]	w_ddr3_araddr;
	wire	[7:0]		w_ddr3_arlen;
	wire			w_ddr3_arvalid;
	wire			w_ddr3_arready;
	
	wire 	[3:0] 	w_ddr3_rid;
	wire 	[127:0] 	w_ddr3_rdata;
	wire			w_ddr3_rlast;
	wire			w_ddr3_rvalid;
	wire			w_ddr3_rready;
	wire 	[1:0] 	w_ddr3_rresp;
	
	
	//	AXI Interface Request
	wire 	[3:0] 	w_ddr3_aid;
	wire 	[31:0] 	w_ddr3_aaddr;
	wire 	[7:0]  	w_ddr3_alen;
	wire 	[2:0]  	w_ddr3_asize;
	wire 	[1:0]  	w_ddr3_aburst;
	wire 	[1:0]  	w_ddr3_alock;
	wire			w_ddr3_avalid;
	wire			w_ddr3_aready;
	wire			w_ddr3_atype;
	
	wire 			w_ddr3_cal_done, w_ddr3_cal_pass; 
	
	//	Do not issue DDR read / write when ~cal_done. 
	reg 			r_ddr_unlock = 0; 
	always @(posedge w_ddr3_ui_clk or negedge w_ddr3_ui_aresetn) begin
		if(~w_ddr3_ui_aresetn)
			r_ddr_unlock <= 0; 
		else
			r_ddr_unlock <= w_ddr3_cal_done && w_ddr3_cal_pass; 
	end
	
	DdrCtrl ddr3_ctl_axi (	
		.core_clk		(core_clk),
		.tac_clk		(tac_clk),
		.twd_clk		(twd_clk),	
		.tdqss_clk		(tdqss_clk),
		
		.reset		(reset),
		.cs			(cs),
		.ras			(ras),
		.cas			(cas),
		.we			(we),
		.cke			(cke),    
		.addr			(addr),
		.ba			(ba),
		.odt			(odt),
		
		.o_dm_hi		(o_dm_hi),
		.o_dm_lo		(o_dm_lo),
		
		.i_dq_hi		(i_dq_hi),
		.i_dq_lo		(i_dq_lo),
		.o_dq_hi		(o_dq_hi),
		.o_dq_lo		(o_dq_lo),
		.o_dq_oe		(o_dq_oe),
		
		.i_dqs_hi		(i_dqs_hi),
		.i_dqs_lo		(i_dqs_lo),
		.i_dqs_n_hi		(i_dqs_n_hi),
		.i_dqs_n_lo		(i_dqs_n_lo),
		.o_dqs_hi		(o_dqs_hi),
		.o_dqs_lo		(o_dqs_lo),
		.o_dqs_n_hi		(o_dqs_n_hi),
		.o_dqs_n_lo		(o_dqs_n_lo),
		.o_dqs_oe		(o_dqs_oe),
		.o_dqs_n_oe		(),				//	o_dqs_n_oe),
		
		.clk			(w_ddr3_ui_clk),
		.reset_n		(w_ddr3_ui_aresetn),
		
		.axi_avalid		(w_ddr3_avalid),		//	Enable command only when unlocked. 
		.axi_aready		(w_ddr3_aready),
		.axi_aaddr		(w_ddr3_aaddr),
		.axi_aid		(w_ddr3_aid),
		.axi_alen		(w_ddr3_alen),
		.axi_asize		(w_ddr3_asize),
		.axi_aburst		(w_ddr3_aburst),
		.axi_alock		(w_ddr3_alock),
		.axi_atype		(w_ddr3_atype),
		
		.axi_wid		(w_ddr3_aid),
		.axi_wvalid		(physical_wvalid),
		.axi_wready		(physical_wready),
		.axi_wdata		(physical_wdata),
		.axi_wstrb		(physical_wstrb),
		.axi_wlast		(physical_wlast),
		
		.axi_bvalid		(physical_bvalid),
		.axi_bready		(physical_bready),
		.axi_bid		(physical_bid),
		.axi_bresp		(physical_bresp),
		
		.axi_rvalid		(physical_rvalid),
		.axi_rready		(physical_rready),
		.axi_rdata		(physical_rdata),
		.axi_rid		(physical_rid),
		.axi_rresp		(physical_rresp),
		.axi_rlast		(physical_rlast),
		
		.shift		(shift),
		.shift_sel		(),
		.shift_ena		(shift_ena),
		
		.cal_ena		(1'b1),
		.cal_done		(w_ddr3_cal_done),
		.cal_pass		(w_ddr3_cal_pass)
	);
	//	The o_dqs_n_oe may not assert at negative edge. 
	assign o_dqs_n_oe = o_dqs_oe; 
	
	assign w_ddr3_bready = 1'b1; 
	assign shift_sel = 5'b00100; 		//	ddr_tac_clk always use PLLOUT[2]. 
	
	

 wire physical_wvalid,physical_wready,physical_wlast,physical_bvalid,physical_bready,physical_rvalid,physical_rready,physical_rlast;
 wire[127:0]physical_wdata,physical_rdata;wire[15:0]physical_wstrb;
 wire[3:0]physical_bid,physical_rid;wire[1:0]physical_bresp,physical_rresp;
 wire nn_cv,nn_cw,nn_cr,nn_wv,nn_wl,nn_wr,nn_rv,nn_rl,nn_rr,nn_bv,nn_br;
 wire[31:0]nn_ca;wire[7:0]nn_cl;wire[127:0]nn_wd,nn_rd;wire[15:0]nn_ws;wire[1:0]nn_rp,nn_bp;
 wire[7:0]nn_rid_unused,nn_bid_unused,global_id;
 assign w_ddr3_aid=global_id[3:0];
 wire video_commit;wire[31:0]video_commit_address;wire[7:0]video_commit_length;
 video_nn_ddr_bridge #(.NN_MIN_GAP_CYCLES(256)) neural_video_bus(.clk(w_ddr3_ui_clk),.rst(w_ddr3_ui_rst),.ddr_ready(r_ddr_unlock),
 .video_awid(w_ddr3_awid),.video_arid(w_ddr3_arid),.video_awaddr(w_ddr3_awaddr),.video_araddr(w_ddr3_araddr),.video_awlen(w_ddr3_awlen),.video_arlen(w_ddr3_arlen),
 .video_awvalid(w_ddr3_awvalid&&r_ddr_unlock),.video_arvalid(w_ddr3_arvalid&&r_ddr_unlock),.video_awready(w_ddr3_awready),.video_arready(w_ddr3_arready),
 .video_wdata(w_ddr3_wdata),.video_wstrb(w_ddr3_wstrb),.video_wvalid(w_ddr3_wvalid),.video_wlast(w_ddr3_wlast),.video_wready(w_ddr3_wready),
 .video_rdata(w_ddr3_rdata),.video_rid(w_ddr3_rid),.video_rvalid(w_ddr3_rvalid),.video_rlast(w_ddr3_rlast),.video_rresp(w_ddr3_rresp),.video_rready(w_ddr3_rready),
 .video_bvalid(w_ddr3_bvalid),.video_bid(w_ddr3_bid),.video_bresp(w_ddr3_bresp),.video_bready(w_ddr3_bready),
 .nn_command_valid(nn_cv),.nn_command_write(nn_cw),.nn_command_address(nn_ca),.nn_command_length(nn_cl),.nn_command_id(8'd0),.nn_command_ready(nn_cr),
 .nn_wdata(nn_wd),.nn_wstrb(nn_ws),.nn_wvalid(nn_wv),.nn_wlast(nn_wl),.nn_wready(nn_wr),.nn_rdata(nn_rd),.nn_rid(nn_rid_unused),.nn_rvalid(nn_rv),.nn_rlast(nn_rl),.nn_rresp(nn_rp),.nn_rready(nn_rr),
 .nn_bvalid(nn_bv),.nn_bid(nn_bid_unused),.nn_bresp(nn_bp),.nn_bready(nn_br),
 .ddr_address(w_ddr3_aaddr),.ddr_length(w_ddr3_alen),.ddr_id(global_id),.ddr_write(w_ddr3_atype),.ddr_avalid(w_ddr3_avalid),.ddr_aready(w_ddr3_aready),
 .ddr_wdata(physical_wdata),.ddr_wstrb(physical_wstrb),.ddr_wvalid(physical_wvalid),.ddr_wlast(physical_wlast),.ddr_wready(physical_wready),
 .ddr_rdata(physical_rdata),.ddr_rid({4'd0,physical_rid}),.ddr_rvalid(physical_rvalid),.ddr_rlast(physical_rlast),.ddr_rresp(physical_rresp),.ddr_rready(physical_rready),
 .ddr_bvalid(physical_bvalid),.ddr_bid({4'd0,physical_bid}),.ddr_bresp(physical_bresp),.ddr_bready(physical_bready),.video_write_committed(video_commit),.video_write_address(video_commit_address),.video_write_length(video_commit_length),.transaction_active());

	assign w_ddr3_asize = 4; 		//	Fixed 128 bits (16 bytes, size = 4)
	assign w_ddr3_aburst = 1; 
	assign w_ddr3_alock = 0; 
	
	assign led_o[1:0] = {w_ddr3_cal_pass, w_ddr3_cal_done}; 
	
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	I2C Config (SC130GS)
	
	//  i2c timing controller module of 16Bit
	wire            [ 8:0]          sc2210_i2c_config_index;
	wire            [23:0]          sc2210_i2c_config_data;
	wire            [ 8:0]          sc2210_i2c_config_size;
	wire                            sc2210_i2c_config_done;
    wire sc2210_i2c_config_failed;
    wire sc2210_scl_release;
 reg [1:0] probe_index=0;
 wire [6:0] probe_address={5'b01100,probe_index}; // 0x30..0x33
 wire [31:0] exposure_mailbox,exposure_status,exposure_lines;
 wire exposure_toggle,exp_bus_active,exp_scl,exp_sda_low;
 wire [31:0] sensor_timing_confirmed;
 sensor_exposure_control #(.MAX_LINES(1108)) exposure_control(.clk(clk_sys),.resetn(rstn_sys),
 .ready(sc2210_i2c_config_done&&!sc2210_i2c_config_failed&&sensor_runtime_ready),.frame_signal(crop_vs),
 .slave_address(probe_address),.mailbox(exposure_mailbox),.toggle(exposure_toggle),
 .sda_in(csi_sda_i),.bus_active(exp_bus_active),.scl(exp_scl),.sda_low(exp_sda_low),
 .status(exposure_status),.confirmed_lines(exposure_lines),.confirmed_timing(sensor_timing_confirmed));
 wire init_sda_oe,rb_scl_release,rb_sda_low,rb_done,rb_failed;
 wire [191:0] rb_values;

reg [26:0] post_timer=0;
 reg [2:0] post_state=0;
 wire post_select,post_reset,sensor_runtime_ready;
 sensor_post_readback post_readback(.clk(clk_sys),.resetn(rstn_sys),
 .init_done(sc2210_i2c_config_done),.init_failed(sc2210_i2c_config_failed),
 .rb_done(rb_done),.rb_failed(rb_failed),.select_read(post_select),
 .reset_read(post_reset),.runtime_ready(sensor_runtime_ready));
 reg [7:0] post_count=0;
 // Startup probe retains the bus until initialization ends; runtime exposure owns it afterwards.
 reg probe_reset=0,probe_found=0,probe_complete=0;
 reg [2:0] probe_state=0;
 reg [20:0] probe_wait=0;
 reg [63:0] probe_ids=0;
 reg [3:0] probe_ack=0;
 sc2210_readback #(.I2C_FREQ(10000),.REG_COUNT(24)) rb(
 probe_address,clk_sys,rstn_sys&&probe_reset&&!post_reset,1'b1,csi_sda_i,
 rb_scl_release,rb_sda_low,rb_done,rb_failed,rb_values);
 assign csi_sda_oe=exp_bus_active ? exp_sda_low : (probe_found&&!post_select ? init_sda_oe : rb_sda_low);
 always @(posedge clk_sys or negedge rstn_sys) begin
  if(!rstn_sys)begin
   probe_index<=0;probe_reset<=0;probe_found<=0;probe_complete<=0;
   probe_state<=0;probe_wait<=0;probe_ids<=0;probe_ack<=0;
  end else case(probe_state)
   0:if(probe_wait<960000)probe_wait<=probe_wait+1'b1;
     else begin probe_wait<=0;probe_state<=1;end
   1:if(probe_wait<960)probe_wait<=probe_wait+1'b1;
     else begin probe_reset<=1;probe_wait<=0;probe_state<=2;end
   2:if(rb_done||rb_failed)begin
    probe_ids[probe_index*16+:16]<=rb_values[15:0];
    probe_ack[probe_index]<=rb_done&&!rb_failed;
    if(rb_done&&!rb_failed&&rb_values[15:0]==16'h1022)begin
     probe_found<=1;probe_complete<=1;probe_state<=3;
    end else if(probe_index==3)begin
     probe_complete<=1;probe_state<=3;
    end else begin
     probe_index<=probe_index+1'b1;probe_reset<=0;probe_state<=1;
    end
   end
   3:begin end
   default:begin probe_complete<=1;probe_state<=3;end
  endcase
 end

	i2c_timing_ctrl_reg16_dat8_wronly
	#(
	    .CLK_FREQ           (CLOCK_MAIN),                              //  100 MHz
	    .I2C_FREQ           (10_000    )                               //  10 KHz(<= 400KHz)
	) u_i2c_timing_ctrl_16bit (
	    //  global clock
	    .clk                (clk_sys                 ),                          //  96MHz
	    .rst_n              (rstn_sys && probe_found                ),                          //  system reset

	    //  i2c interface
	    .i2c_sclk           (sc2210_scl_release               ),                          //  i2c clock
	    .i2c_sdat_IN        (csi_sda_i               ),
	    .i2c_sdat_OUT       (csi_sda_o               ),
	    .i2c_sdat_OE        (init_sda_oe              ),

	    //  i2c config data
	    .i2c_config_index   (sc2210_i2c_config_index        ),                          //  i2c config reg index, read 2 reg and write xx reg
	    .i2c_config_data    ({probe_address,1'b0,sc2210_i2c_config_data}),                     //  i2c config data
	    .i2c_config_size    (sc2210_i2c_config_size         ),                          //  i2c config data counte
	    .i2c_config_failed  (sc2210_i2c_config_failed),
        .i2c_config_done    (sc2210_i2c_config_done         )                          //  i2c config timing complete
	);
	assign csi_scl_o = exp_bus_active ? exp_scl : (probe_found&&!post_select ? sc2210_scl_release : rb_scl_release);
    assign csi_scl_oe = 1'b1; // Same single-master push-pull SCL as the vendor reference. 

	//  I2C Configure Data of SC2210
	I2C_SC2210_19201080_4Lanes_Config u_I2C_SC2210_19201080_4Lanes_Config
	(
	    .LUT_INDEX  (sc2210_i2c_config_index   ),
	    .LUT_DATA   (sc2210_i2c_config_data    ),
	    .LUT_SIZE   (sc2210_i2c_config_size    )
	);
		
	
		
	//	CMOS Interface
	//input 			cmos_pclk,
	//input 			cmos_vsync,
	//input 			cmos_href,
	//input 	[7:0] 	cmos_data,
	//input 			cmos_ctl1,
	//output 			cmos_ctl2,
	//output 			cmos_ctl3,

	
	//	Output LED
	reg 	[3:0]		r_cmos_fv_o = 0; 
	reg 	[1:0] 	r_cmos_rx_vsync0_in = 0; 
	always @(posedge cmos_pclk) begin
		r_cmos_rx_vsync0_in <= {r_cmos_rx_vsync0_in, cmos_vsync}; 
		r_cmos_fv_o <= r_cmos_fv_o + ((r_cmos_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	assign led_o[5] = sc2210_i2c_config_done; 
	
	
	
	
	
	
	
	
	////////////////////////////////////////////////////////////////
	//	System Control. Can be removed for public. 
	
	localparam 	CLK_FREQ 	= 96_000_000; 	//	clk_sys is 96MHz. 
	localparam 	BAUD_RATE 	= 460_800; 		//	Use 460800-8-N-1. 
	
	
	//	SFR I/O Interface
	wire 	[7:0] 	w_sfr_addr_o; 	//	SFR Address (0xFF00 ~ 0xFFFF). 00:Power; 40~5F:Stream0; 60~7F:Stream1. 
	wire 	[7:0] 	w_sfr_wdata_o; 	//	SFR Write Data. 
	wire 			w_sfr_we_o; 		//	SFR WE. 
	reg 	[7:0] 	w_sfr_rdata_i; 	//	Must be valid after sfr_rd_o. 
	wire 			w_sfr_rd_o; 		//	SFR RD. 
	
	
	//	System Control Registers
	reg 			r_dsi_tx_rstn = 0; 	//	DSI TX Reset
	reg 	[7:0] 	r_dsi_pwm = 64; 		//	[6:0]PWM, [7]Pol
	reg 			r_dsi_resetn_o = 0; 	//	DSI Panel Reset
	reg 			r_dsi_data_rstn = 0; 	//	DSI TX Reset
	
	reg 	[3:0] 	r_dsi_lp_p_ovr = 0; 	
	reg 	[3:0] 	r_dsi_lp_n_ovr = 0; 	
	
	
	
	//	AXI-Lite Interface Bridge
	localparam 	CSI_AXILITE_ID 	= 0; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	localparam 	DSI_AXILITE_ID 	= 1; 				//	Select DSI_TX when r_axi_sel = DSI_AXILITE_ID. 
	
	reg 	[7:0] 	r_axi_addr = 8'h18; 		//	0xE0 (RW)
	reg 	[31:0] 	r_axi_wdata = 32'h0000000A; 	//	0xE1~0xE4 (RW)
	wire 	[31:0] 	w_axi_rdata; 			//	0xE5~0xE8 (RO)
	reg 	[0:0] 	r_axi_sel = 1; 			//	0xE9[7:2] (RW)
	reg 			r_axi_r1w0 = 0; 			//	0xE9[1] (RW)
	reg 			r_axi_req = 0; 			//	0xE9[0] (WO, Single Cycle)
	reg 			r_axi_req_o = 0; 			//	Delayed of r_axi_req. 
	
	
	//	Buffered AXI Read Data
	reg 	[31:0] 	r_axi_rdata = 0; 		//	Use state machine
	reg 			r_axi_idle = 0; 		//	AXI Idle 
	
	reg 	[3:0] 	rs_axilite = 0; 		//	AXI Access
	wire 	[3:0] 	ws_axilite_idle = 0; 		
	wire 	[3:0] 	ws_axilite_write = 1; 
	wire 	[3:0] 	ws_axilite_read = 2; 
	wire 	[3:0] 	ws_axilite_endread = 3; 
	
	reg 			r_axi_awvalid = 0, r_axi_wvalid = 0, r_axi_arvalid = 0; 
	wire 			w_axi_awready, w_axi_wready, w_axi_arready, w_axi_rvalid; 
	
	
	reg 	[3:0] 	rc_axi_init = 0; 

	always @(posedge clk_sys or posedge rst_sys) begin
		if(rst_sys) begin
			r_dsi_tx_rstn <= 0; 
			r_dsi_pwm <= 64; 
			r_axi_req <= 0; 
			r_dsi_resetn_o <= 0; 
			r_dsi_data_rstn <= 0; 
			
			rs_axilite <= 0; 
			r_axi_awvalid <= 0; 
			r_axi_wvalid <= 0;
			r_axi_arvalid <= 0; 
			
			r_dsi_lp_p_ovr <= 0; 
			r_dsi_lp_n_ovr <= 0; 
			
			rc_axi_init <= 0; 
			r_axi_idle <= 0; 
			
		end else begin
			r_dsi_tx_rstn <= 1; 
			r_dsi_resetn_o <= 1; 
			r_dsi_data_rstn <= 1; 
			
		end
	end
	
	assign dsi_resetn_o = r_dsi_resetn_o; 
	
	assign csi_ctl0_oe = 0; 
	assign csi_ctl1_oe = 0; 
	
	
	PWMLite dsi_pwm (		//	#(.ENABLE_TICK(0), .PWM_BITS(7)) 
		.clk_i			(clk_sys),
		.rst_i			(rst_sys),
		.pwm_i			(r_dsi_pwm[6:0]),
		.pol_i			(r_dsi_pwm[7]), 
		.pwm_o			(dsi_pwm_o)
	);






	////////////////////////////////////////////////////////////////
	//	MIPI CSI RX
	
	//	The CSI RXC shall not be inverted. Data can be inverted with swapped LP data and flipped HS data. 
	localparam 	CSI_RXD_INV 	= 4'b1111; 
	localparam 	CSI_DATA_WIDTH 	= 32; 			
	localparam 	CSI_STRB_WIDTH 	= CSI_DATA_WIDTH / 8; 

	//	Current implementation supports RAW8 only. 
	wire 			w_csi_rx_clk; 
	wire 			w_csi_rx_vsync0, w_csi_rx_hsync0, w_csi_rx_dvalid; 
	wire 	[63:0] 	w_csi_rx_data; 
	wire 	[47:0] 	w_csi_rx_data_rel_raw; 
	
	//	AXI Interface
	wire 	[31:0] 	w_csi_axi_rdata; 
	wire 			w_csi_axi_awready, w_csi_axi_wready, w_csi_axi_arready, w_csi_axi_rvalid; 
	
	
	
`define PRI_MIPI_IP
	
	
`ifdef PRI_MIPI_IP
    assign csi_rxd0_rst_o = rst_sys;
    assign csi_rxd1_rst_o = rst_sys;
    assign csi_rxd2_rst_o = rst_sys;
    assign csi_rxd3_rst_o = rst_sys;
    wire[31:0] csi_parallel_stable;
    csi_halfcycle_capture csi_capture(.clk(csi_rxc_i),.phy_data({csi_rxd3_hs_i,csi_rxd2_hs_i,csi_rxd1_hs_i,csi_rxd0_hs_i}),.data(csi_parallel_stable));
	wire 	[7:0] 	w_mipi_d0 = (CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_parallel_stable[0+:8]; 
	wire 	[7:0] 	w_mipi_d1 = (CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_parallel_stable[8+:8]; 
	wire 	[7:0] 	w_mipi_d2 = (CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_parallel_stable[16+:8]; 
	wire 	[7:0] 	w_mipi_d3 = (CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_parallel_stable[24+:8]; 
	MIPIRx4LaneFre mipi0_rx (
		.sclk_i			(clk_sys), 
		.srst_i			(rst_sys), 
		
		.mipi_rx_byteclk_i	(csi_rxc_i), 
		.mipi_rx_d0_i		({w_mipi_d0[0], w_mipi_d0[1], w_mipi_d0[2], w_mipi_d0[3], w_mipi_d0[4], w_mipi_d0[5], w_mipi_d0[6], w_mipi_d0[7]}), 
		.mipi_rx_d1_i		({w_mipi_d1[0], w_mipi_d1[1], w_mipi_d1[2], w_mipi_d1[3], w_mipi_d1[4], w_mipi_d1[5], w_mipi_d1[6], w_mipi_d1[7]}), 
		.mipi_rx_d2_i		({w_mipi_d2[0], w_mipi_d2[1], w_mipi_d2[2], w_mipi_d2[3], w_mipi_d2[4], w_mipi_d2[5], w_mipi_d2[6], w_mipi_d2[7]}), 
		.mipi_rx_d3_i		({w_mipi_d3[0], w_mipi_d3[1], w_mipi_d3[2], w_mipi_d3[3], w_mipi_d3[4], w_mipi_d3[5], w_mipi_d3[6], w_mipi_d3[7]}), 
		.mipi_rx_clk_lp_p_i	(csi_rxc_lp_p_i), 
		.mipi_rx_clk_lp_n_i	(csi_rxc_lp_n_i), 
		.mipi_rx_d0_lp_p_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i), 
		.mipi_rx_d0_lp_n_i	(CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i), 
		.mipi_rx_rst_o		(), 
		.mipi_rx_rst_n_o		(), 
		.mipi_rx_clk_hs_en_o	(csi_rxc_hs_en_o), 
		.mipi_rx_dat_hs_en_o	(csi_rxd0_hs_en_o), 
		.mipi_rx_clk_term_en_o	(csi_rxc_hs_term_en_o), 
		.mipi_rx_dat_term_en_o	(csi_rxd0_hs_term_en_o), 
		
		.CLK				(w_csi_rx_clk), 
		.VSYNC			(w_csi_rx_vsync0), 
		.HSYNC			(w_csi_rx_hsync0), 
		.DE				(w_csi_rx_dvalid), 
		.DAT				(w_csi_rx_data_rel_raw)
	);
	assign w_csi_rx_data = {2{w_csi_rx_data_rel_raw[47:40], w_csi_rx_data_rel_raw[35:28], w_csi_rx_data_rel_raw[23:16], w_csi_rx_data_rel_raw[11:4]}}; 
	assign {csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o} = {3{csi_rxd0_hs_en_o}}; 
	assign {csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o} = {3{csi_rxd0_hs_term_en_o}}; 
	
	
`else	
	
	//	Reset pixel 16 cycles after ~vsync. 
	reg 			r_reset_pixen_n = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_i = 0; 
	always @(posedge w_csi_rx_clk or negedge rstn_sys) begin
		if(~rstn_sys) begin
			r_reset_pixen_n <= 0; 
			r_csi_rx_vsync0_i <= 0; 
		end else begin
			r_csi_rx_vsync0_i <= {r_csi_rx_vsync0_i, w_csi_rx_vsync0}; 
			r_reset_pixen_n <= (r_csi_rx_vsync0_i == 2'b10) ? 1'b0 : 1'b1; 
		end
	end
	
	assign w_csi_rx_clk = clk_sys; 
	csi_rx mipi_rx_0(
		.reset_n			(rstn_sys), 
		.clk				(w_csi_rx_clk), 
		.reset_byte_HS_n		(rstn_sys), 
		.clk_byte_HS		(csi_rxc_i), 
		.reset_pixel_n		(r_reset_pixen_n), 	//rstn_sys), 
		.clk_pixel			(w_csi_rx_clk), 
		.Rx_LP_CLK_P		(csi_rxc_lp_p_i), 
		.Rx_LP_CLK_N		(csi_rxc_lp_n_i), 
		
		.Rx_HS_enable_C		(csi_rxc_hs_en_o), 
		.LVDS_termen_C		(csi_rxc_hs_term_en_o), 
		
		//	Lane inversion affects HS & LP data only. 
		.Rx_LP_D_P			({CSI_RXD_INV[3] ? csi_rxd3_lp_n_i : csi_rxd3_lp_p_i, CSI_RXD_INV[2] ? csi_rxd2_lp_n_i : csi_rxd2_lp_p_i, CSI_RXD_INV[1] ? csi_rxd1_lp_n_i : csi_rxd1_lp_p_i, CSI_RXD_INV[0] ? csi_rxd0_lp_n_i : csi_rxd0_lp_p_i}), 
		.Rx_LP_D_N			({CSI_RXD_INV[3] ? csi_rxd3_lp_p_i : csi_rxd3_lp_n_i, CSI_RXD_INV[2] ? csi_rxd2_lp_p_i : csi_rxd2_lp_n_i, CSI_RXD_INV[1] ? csi_rxd1_lp_p_i : csi_rxd1_lp_n_i, CSI_RXD_INV[0] ? csi_rxd0_lp_p_i : csi_rxd0_lp_n_i}), 
		.Rx_HS_D_0			((CSI_RXD_INV[0] ? 8'hFF : 8'h00) ^ csi_rxd0_hs_i), 
		.Rx_HS_D_1			((CSI_RXD_INV[1] ? 8'hFF : 8'h00) ^ csi_rxd1_hs_i), 
		.Rx_HS_D_2			((CSI_RXD_INV[2] ? 8'hFF : 8'h00) ^ csi_rxd2_hs_i), 
		.Rx_HS_D_3			((CSI_RXD_INV[3] ? 8'hFF : 8'h00) ^ csi_rxd3_hs_i), 
		.Rx_HS_D_4			(), 
		.Rx_HS_D_5			(), 
		.Rx_HS_D_6			(), 
		.Rx_HS_D_7			(), 
		
		.Rx_HS_enable_D		({csi_rxd3_hs_en_o, csi_rxd2_hs_en_o, csi_rxd1_hs_en_o, csi_rxd0_hs_en_o}), 
		.LVDS_termen_D		({csi_rxd3_hs_term_en_o, csi_rxd2_hs_term_en_o, csi_rxd1_hs_term_en_o, csi_rxd0_hs_term_en_o}), 
		.fifo_rd_enable		({csi_rxd3_fifo_rd_o, csi_rxd2_fifo_rd_o, csi_rxd1_fifo_rd_o, csi_rxd0_fifo_rd_o}), 
		.fifo_rd_empty		({csi_rxd3_fifo_empty_i, csi_rxd2_fifo_empty_i, csi_rxd1_fifo_empty_i, csi_rxd0_fifo_empty_i}), 
		.DLY_enable_D		(), 
		.DLY_inc_D			(), 
		.u_dly_enable_D		(0), 
		.u_dly_inc_D		(), 
		
		.vsync_vc1			(), 
		.vsync_vc15			(), 
		.vsync_vc12			(), 
		.vsync_vc9			(), 
		.vsync_vc7			(), 
		.vsync_vc14			(), 
		.vsync_vc13			(), 
		.vsync_vc11			(), 
		.vsync_vc10			(), 
		.vsync_vc8			(), 
		.vsync_vc6			(), 
		.vsync_vc4			(), 
		.vsync_vc0			(w_csi_rx_vsync0), 
		.vsync_vc5			(), 
		.vsync_vc3			(), 
		.vsync_vc2			(), 
	
		.irq				(), 
		
		.pixel_data_valid		(w_csi_rx_dvalid), 
		.pixel_data			(w_csi_rx_data), 
		.pixel_per_clk		(), 
		.datatype			(), 
		.shortpkt_data_field	(), 
		.word_count			(), 
		.vcx				(), 
		.vc				(), 
		.hsync_vc3			(), 
		.hsync_vc2			(), 
		.hsync_vc8			(), 
		.hsync_vc12			(), 
		.hsync_vc7			(), 
		.hsync_vc10			(), 
		.hsync_vc1			(), 
		.hsync_vc0			(w_csi_rx_hsync0), 
		.hsync_vc13			(), 
		.hsync_vc4			(), 
		.hsync_vc11			(), 
		.hsync_vc6			(), 
		.hsync_vc9			(), 
		.hsync_vc15			(), 
		.hsync_vc14			(), 
		.hsync_vc5			(), 
		
		.axi_clk			(clk_sys), 
		.axi_reset_n		(rstn_sys), 
		
		.axi_awaddr			(r_axi_addr), 
		.axi_awvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_awvalid), 
		.axi_awready		(w_csi_axi_awready), 
	
		.axi_wvalid			((r_axi_sel == CSI_AXILITE_ID) && r_axi_wvalid), 
		.axi_wdata			(r_axi_wdata), 
		.axi_wready			(w_csi_axi_wready), 
	
		.axi_bvalid			(), 
		.axi_bready			(1), 
		
		.axi_araddr			(r_axi_addr), 
		.axi_arvalid		((r_axi_sel == CSI_AXILITE_ID) && r_axi_arvalid), 
		.axi_arready		(w_csi_axi_arready), 
		
		.axi_rready			(1), 
		.axi_rvalid			(w_csi_axi_rvalid), 
		.axi_rdata			(w_csi_axi_rdata)
		
	);
	
	assign csi_rxd0_rst_o = rst_sys; 
	assign csi_rxd1_rst_o = rst_sys; 
	assign csi_rxd2_rst_o = rst_sys; 
	assign csi_rxd3_rst_o = rst_sys; 
`endif
	
	
	
	//	Output LED
	reg 	[5:0]		r_csi_fv_o = 0; 
	reg 	[1:0] 	r_csi_rx_vsync0_in = 0; 
	always @(posedge w_csi_rx_clk) begin
		r_csi_rx_vsync0_in <= {r_csi_rx_vsync0_in, w_csi_rx_vsync0}; 
		r_csi_fv_o <= r_csi_fv_o + ((r_csi_rx_vsync0_in == 2'b01) ? 1 : 0); 
	end
	assign led_o[4] = r_csi_fv_o[5]; 
	
	
	
	////////////////////////////////////////////////////////////////
	//	MIPI-CSI Crop
	
	wire			XYCrop_frame_vsync; 
	wire			XYCrop_frame_href;
	wire			XYCrop_frame_de;
	wire	[63:0]	XYCrop_frame_Gray;

	//Sensor_Image_XYCrop
	//#(
	//	.IMAGE_HSIZE_SOURCE (1920 / CSI_STRB_WIDTH),
	//	.IMAGE_VSIZE_SOURCE (1080	 ),
	//	.IMAGE_HSIZE_TARGET (1024 / CSI_STRB_WIDTH),
	//	.IMAGE_YSIZE_TARGET (600 	 ),
	//	.PIXEL_DATA_WIDTH	(CSI_DATA_WIDTH) 		//	32		 )
	//)
	//u_Sensor_Image_XYCrop
	//(
	//	//	globel clock
	//	.clk			(w_csi_rx_clk),			//	image pixel clock
	//	.rst_n		(rstn_sys),			//	system reset
	//	
	//	//CMOS Sensor interface
	//	.image_in_vsync (w_csi_rx_vsync0		),			//H : Data Valid; L : Frame Sync(Set it by register)
	//	.image_in_href	(w_csi_rx_hsync0		),			//H : Data vaild, L : Line Sync
	//	.image_in_de	(w_csi_rx_dvalid		), 			//H : Data Enable, L : Line Sync
	//	.image_in_data	({w_csi_rx_data[7:0], w_csi_rx_data[15:8], w_csi_rx_data[23:16], w_csi_rx_data[31:24], w_csi_rx_data[39:32], w_csi_rx_data[47:40], w_csi_rx_data[55:48], w_csi_rx_data[63:56]}),			//8 bits cmos data input
	//	
	//	.image_out_vsync(XYCrop_frame_vsync ),			//H : Data Valid; L : Frame Sync(Set it by register)
	//	.image_out_href (XYCrop_frame_href	),			//H : Data vaild, L : Line Sync
	//	.image_out_de	(XYCrop_frame_de	), 			//H : Data Enable, L : Line Sync
	//	.image_out_data (XYCrop_frame_Gray	)			//8 bits cmos data input	
	//);

	reg			r_XYCrop_frame_vsync = 0; 
	reg			r_XYCrop_frame_href = 0;
	reg			r_XYCrop_frame_de = 0;
	reg	[63:0]	r_XYCrop_frame_Gray = 0;
	
	always @(posedge w_csi_rx_clk) begin
		r_XYCrop_frame_vsync <= XYCrop_frame_vsync; 
		r_XYCrop_frame_href <= XYCrop_frame_href;
		r_XYCrop_frame_de <= XYCrop_frame_de;
		r_XYCrop_frame_Gray <= XYCrop_frame_Gray;
	end
	
	//	Data Write Assignment
	//wire			cmos_frame_vsync = r_XYCrop_frame_vsync;                     //  cmos frame data vsync valid signal
	//wire			cmos_frame_href = r_XYCrop_frame_href && r_XYCrop_frame_de;	 //  cmos frame data href vaild  signal
	//wire	[63:0]	cmos_frame_Gray = r_XYCrop_frame_Gray; 
	wire cmos_frame_vsync; // = w_csi_rx_vsync0;                     //  cmos frame data vsync valid signal
	wire cmos_frame_href; // = w_csi_rx_hsync0 && w_csi_rx_dvalid;	 //  cmos frame data href vaild  signal
    wire sc2210_video_started;
    video_startup_epoch camera_startup(
        .camera_clk(w_csi_rx_clk), .resetn(rstn_sys),
        .ddr_ready(w_ddr3_cal_done && w_ddr3_cal_pass),
        .config_done(sc2210_i2c_config_done),
        .vsync(padded_vs), .de(padded_de),
        .accepted_vsync(cmos_frame_vsync), .accepted_de(cmos_frame_href),
        .started(sc2210_video_started));
wire crop_vs,crop_de;wire [31:0] crop_data;
raw_center_crop #(.SW(1920),.SH(1080),.W(1920),.H(1080)) camera_crop(.clk(w_csi_rx_clk),.resetn(rstn_sys),.vs(w_csi_rx_vsync0),
 .hs(w_csi_rx_hsync0),.de(w_csi_rx_dvalid),
 .data({w_csi_rx_data[7:0],w_csi_rx_data[15:8],w_csi_rx_data[23:16],w_csi_rx_data[31:24]}),
 .ovs(crop_vs),.ode(crop_de),.odata(crop_data));
wire [19:0] crop_frame_beats,pad_frame_beats;wire pad_overlap;wire padded_vs,padded_de;wire [31:0] padded_data;
// Native 1920x1080 RAW8 is exactly divisible by 1024-byte DDR write bursts.
// No camera-clock padding: forward every pixel without extending frame time.
assign padded_vs=crop_vs;assign padded_de=crop_de;assign padded_data=crop_data;
assign pad_overlap=1'b0;
reg crop_vs_q=0;reg [19:0] crop_count=0,crop_last=0;
always @(posedge w_csi_rx_clk)begin
 if(!rstn_sys)begin crop_vs_q<=0;crop_count<=0;crop_last<=0;end
 else begin
  crop_vs_q<=crop_vs;
  if(crop_de)crop_count<=crop_count+1'b1;
  if(crop_vs_q&&!crop_vs)begin crop_last<=crop_count;crop_count<=0;end
 end
end
assign crop_frame_beats=crop_last;assign pad_frame_beats=crop_last;
wire [63:0] cmos_frame_Gray={32'd0,padded_data}; 

	












	////////////////////////////////////////////////////////////////
	//	DDR R/W Control
	

	wire                            lcd_de;
	wire                            lcd_hs;      
	wire                            lcd_vs;
	wire 					  lcd_request; 
	wire            [7:0]           lcd_red, lcd_red2;
	wire            [7:0]           lcd_green, lcd_green2;
	wire            [7:0]           lcd_blue, lcd_blue2;
	wire            [15:0]          lcd_data;


	assign w_ddr3_awid = 0; 
	assign w_ddr3_wid = 0; 
	
	wire 			w_wframe_vsync; 
	wire 	[7:0] 	w_axi_tp; 
	
	wire [31:0] debug_underflows;wire debug_wfull;
wire edge_canny,frame_freeze,frame_playback,frame_compare;
wire capture_busy,capture_request,capture_cancel,frame_frozen;
wire [1:0] frame_history_offset;wire [15:0] history_display_id,history_compare_id;
    axi4_ctrl #(.C_BURST_LEN(64),.C_BUF_SIZE(21),.C_RD_END_ADDR(1920 * 1080), .C_W_WIDTH(CSI_DATA_WIDTH), .C_R_WIDTH(16), .C_ID_LEN(4)) u_axi4_ctrl (

		.axi_clk        (w_ddr3_ui_clk            ),
		.axi_reset      (w_ddr3_ui_rst            ),

		.axi_awaddr     (w_ddr3_awaddr       ),
		.axi_awlen      (w_ddr3_awlen        ),
		.axi_awvalid    (w_ddr3_awvalid      ),
		.axi_awready    (w_ddr3_awready      ),

		.axi_wdata      (w_ddr3_wdata        ),
		.axi_wstrb      (w_ddr3_wstrb        ),
		.axi_wlast      (w_ddr3_wlast        ),
		.axi_wvalid     (w_ddr3_wvalid       ),
		.axi_wready     (w_ddr3_wready       ),

		.axi_bid        (w_ddr3_bid),
		.axi_bresp      (w_ddr3_bresp),
		.axi_bvalid     (w_ddr3_bvalid),

		.axi_arid       (w_ddr3_arid         ),
		.axi_araddr     (w_ddr3_araddr       ),
		.axi_arlen      (w_ddr3_arlen        ),
		.axi_arvalid    (w_ddr3_arvalid      ),
		.axi_arready    (w_ddr3_arready      ),

		.axi_rid        (w_ddr3_rid          ),
		.axi_rdata      (w_ddr3_rdata        ),
		.axi_rresp      (w_ddr3_rresp),
		.axi_rlast      (w_ddr3_rlast        ),
		.axi_rvalid     (w_ddr3_rvalid       ),
		.axi_rready     (w_ddr3_rready       ),

		.wframe_pclk    (w_csi_rx_clk          ),
		.wframe_vsync   (cmos_frame_vsync), //w_wframe_vsync   ),		//	Writter VSync. Flush on rising edge. Connect to EOF. 
		.wframe_data_en (cmos_frame_href   ),
		.wframe_data    (cmos_frame_Gray),
.frame_freeze(frame_freeze),.frame_frozen(frame_frozen),.frame_compare(frame_compare),
.frame_history_offset(frame_history_offset),.history_display_id(history_display_id),.history_compare_id(history_compare_id),
		
		.rframe_pclk    (clk_pixel            ),
		.rframe_vsync   (~lcd_vs             ),		//	Reader VSync. Flush on rising edge. Connect to ~EOF. 
		.rframe_data_en (lcd_request             ),
		.rframe_data    (lcd_data           ),
		
		.debug_underflows(debug_underflows),.debug_wfull(debug_wfull),
        .tp_o 		(w_axi_tp)
	);
	assign led_o[3:2] = {sc2210_i2c_config_failed, sc2210_i2c_config_done}; 
	
	
	
	
	////////////////////////////////////////////////////////////////
	//  LCD Timing Driver
	
	lcd_driver u_lcd_driver
	(
	    //  global clock
	    .clk        (clk_pixel   ),
	    .rst_n      (rstn_pixel), 
	    
	    //  lcd interface
	    .lcd_dclk   (               ),
	    .lcd_blank  (               ),
	    .lcd_sync   (               ),
	    .lcd_request(lcd_request    ), 	//	Request data 1 cycle ahead. 
	    .lcd_hs     (lcd_hs         ),
	    .lcd_vs     (lcd_vs         ),
	    .lcd_en     (lcd_de         ),
	    .lcd_rgb    ({lcd_red2,lcd_green2,lcd_blue2, lcd_red,lcd_green,lcd_blue}),
	    
	    //  user interface
	    .lcd_data   ({{3{lcd_data[15:8]}}, {3{lcd_data[7:0]}}}  )
	);
	
	
	

	wire 			w_rgb_vsync, w_rgb_hsync, w_rgb_href; 
	wire 	[7:0] 	w_rgb_r, w_rgb_g, w_rgb_b; 
	

 wire [63:0] color_mailbox, color_active;
 wire color_toggle;
 wire color_vs,color_hs,color_de;
 wire [23:0] color_rgb;
 wire [23:0] color_rgb1;
 wire [47:0] bayer_pair;
 bayer_2ppc #(.HT(1100),.W(1920),.H(1080)) bayer2rgb(
 .clk(clk_pixel),.rst(rst_pixel),.mirror(color_active[60:59]),
 .raw({lcd_green2,lcd_green}),.vs(lcd_vs),.hs(lcd_hs),.de(lcd_de),
 .rgb(bayer_pair),.ovs(w_rgb_vsync),.ohs(w_rgb_hsync),.ode(w_rgb_href));
 color_pipeline color_adjust(.clk(clk_pixel),.rst_n(rstn_pixel),
 .mailbox(color_mailbox),.toggle(color_toggle),.active(color_active),
 .vs(w_rgb_vsync),.hs(w_rgb_hsync),.de(w_rgb_href),.rgb(bayer_pair[23:0]),
 .ovs(color_vs),.ohs(color_hs),.ode(color_de),.orgb(color_rgb));
 color_pipeline color_adjust1(.clk(clk_pixel),.rst_n(rstn_pixel),
 .mailbox(color_mailbox),.toggle(color_toggle),.active(),
 .vs(w_rgb_vsync),.hs(w_rgb_hsync),.de(w_rgb_href),.rgb(bayer_pair[47:24]),
 .ovs(),.ohs(),.ode(),.orgb(color_rgb1));

	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	LVDS Output 
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//	HDMI requires specific timing, thus is not compatible with LCD & LVDS & DSI. Must implement standalone. 
	
	assign hdmi_txd0_rst_o = rst_pixel; 
	assign hdmi_txd1_rst_o = rst_pixel; 
	assign hdmi_txd2_rst_o = rst_pixel; 
	assign hdmi_txc_rst_o = rst_pixel; 
	
	assign hdmi_txd0_oe = 1'b1; 
	assign hdmi_txd1_oe = 1'b1; 
	assign hdmi_txd2_oe = 1'b1; 
	assign hdmi_txc_oe = 1'b1; 
	
	//-------------------------------------
	//Digilent HDMI-TX IP Modified by CB elec.
    wire compute_error;
    // GT911 touch controller for the RGB070M1 panel.
    // The four panel pins are open-drain through the board's 1.8 V translator:
    // drive data low when *_oe is asserted and release the line otherwise.
    wire [1:0] touch_status;
    wire touch_active, touch_seen;
    wire [9:0] touch_x, touch_y;
    wire [3:0] touch_fingers;
    wire [15:0] touch_taps;
    wire [4:0] touch_targets;
    wire [127:0] touch_diagnostic;
    wire touch_scl_low, touch_sda_low, touch_int_low, touch_rst;
    assign lcd_tp_sda_o = 1'b0;
    assign lcd_tp_scl_o = 1'b0;
    assign lcd_tp_int_o = 1'b0;
    assign lcd_tp_sda_oe = touch_sda_low;
    assign lcd_tp_scl_oe = touch_scl_low;
    assign lcd_tp_int_oe = touch_int_low;
    assign lcd_tp_rst_o = touch_rst;
    assign rgb_touch_rst = touch_rst;
    wire [2:0] edge_ui_view;
    wire [7:0] edge_ui_threshold;
    wire edge_ui_median;
    wire gesture_key_valid;wire [3:0] gesture_key_code;
    wire audio_audition,audio_demo_start,audio_stop,canny_enable,audio_busy;
    wire[1:0] audio_io_mode;
    (* async_reg="true",syn_srlstyle="registers",syn_preserve="true" *)reg[1:0] audio_mode_meta=0,audio_mode_sync=0;
    always @(posedge clk_pixel)begin audio_mode_meta<=audio_io_mode;audio_mode_sync<=audio_mode_meta;end
    wire audio_bclk_raw,audio_lrclk_raw,audio_din_raw;
    wire audio_pin_gate;
    wire[2:0] demo_state;wire[15:0] audio_played_count;
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *)reg[4:0] feature_meta=0,feature_sync=0;
    always @(posedge clk_54m)begin feature_meta<={canny_enable,audio_busy,demo_state};feature_sync<=feature_meta;end
    wire advanced_page,ui_freeze,ui_compare,ui_playback;wire [1:0] ui_history;
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *) reg [1:0] frozen_pixel_sync=0;
    always @(posedge clk_pixel)frozen_pixel_sync<={frozen_pixel_sync[0],frame_frozen};
    touch_edge_control edge_controls(.continuous_mode(continuous_mode),.continuous_recording(nn_flags_sync[0]),.clk(clk_pixel),.rst(rst_pixel),.status(touch_status),
      .active(touch_active),.fingers(touch_fingers),.x(touch_x),.y(touch_y),
      .view(edge_ui_view),.threshold(edge_ui_threshold),.median(edge_ui_median),
      .recognition_ready(key_ready_pixel&&(!continuous_mode||nn_flags_sync[2])),
      .recognition_busy(continuous_mode?nn_flags_sync[1]:job_busy),.recognition_fault(continuous_mode?1'b0:compute_error),
      .gesture_key_valid(gesture_key_valid),.gesture_key_code(gesture_key_code),
      .canny_enable(canny_enable),.audition(audio_audition),.demo_start(audio_demo_start),.audio_stop(audio_stop),
      .frame_tick(edge_frame_tick),.frozen_ready(frozen_pixel_sync[1]),
      .advanced_page(advanced_page),.freeze(ui_freeze),.compare(ui_compare),.playback(ui_playback),.history_offset(ui_history));
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *) reg [31:0] history_ids_meta=0,history_ids_sync=0;
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *) reg [18:0] panel_control_meta=12'd128,panel_control_sync=12'd128;
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *) reg [10:0] gesture_display_meta=0,gesture_display_sync=0;
    always @(posedge clk_54m) begin
      panel_control_meta <= {advanced_page,ui_freeze,frozen_pixel_sync[1],ui_compare,ui_playback,ui_history,edge_ui_view,edge_ui_threshold,edge_ui_median};
      panel_control_sync <= panel_control_meta;
      gesture_display_meta <= {key_ready_pixel,compute_error,job_busy,ui_control[10],ui_control[11],ui_control[12],ui_control[9:5]};
      gesture_display_sync <= gesture_display_meta;
      history_ids_meta<={history_display_id,history_compare_id};history_ids_sync<=history_ids_meta;
    end
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *) reg [48:0] touch_display_meta=0,touch_display_sync=0;
    always @(posedge clk_54m) begin
      touch_display_meta <= {touch_status,touch_active,touch_seen,touch_x,touch_y,touch_fingers,touch_taps,touch_targets};
      touch_display_sync <= touch_display_meta;
    end

 reg nn_audio_toggle=0;
 reg nn_result_seen=0,nn_accepted_hold=0,nn_fault_hold=0,nn_session_q=0,nn_ui_toggle=0;
 reg[4:0]nn_count_hold=0;reg[47:0]nn_words_hold=0;reg[2:0]nn_ui_state=0,nn_ui_previous=0;
 always @(posedge w_ddr3_ui_clk)begin
  if(w_ddr3_ui_rst)begin nn_audio_toggle<=0;nn_result_seen<=0;nn_accepted_hold<=0;nn_fault_hold<=0;nn_session_q<=0;nn_ui_state<=0;nn_ui_previous<=0;nn_ui_toggle<=0;nn_count_hold<=0;nn_words_hold<=0;end
  else begin
   nn_session_q<=nn_session;
   if(nn_session&&!nn_session_q)begin nn_result_seen<=0;nn_accepted_hold<=0;nn_fault_hold<=0;nn_count_hold<=0;nn_words_hold<=0;end
   if(nn_result)begin if(nn_accepted&&!nn_result_fault)nn_audio_toggle<=!nn_audio_toggle;nn_result_seen<=1;nn_accepted_hold<=nn_accepted&&!nn_result_fault;nn_fault_hold<=nn_result_fault;nn_count_hold<=nn_token_count;nn_words_hold<=nn_tokens;end
   if(nn_done&&nn_fault)nn_fault_hold<=1;
   nn_ui_state<=!nn_weights_ready?0:(nn_recording?2:(nn_session?3:(nn_fault_hold?6:(nn_result_seen?(nn_accepted_hold?4:5):1))));
   nn_ui_previous<=nn_ui_state;if(nn_ui_previous!=nn_ui_state)nn_ui_toggle<=!nn_ui_toggle;
  end
 end
 (* async_reg="true" *)reg[2:0]nn_audio_sync=0;reg nn_audio_seen=0;
 wire nn_audio_event=nn_audio_sync[2]!=nn_audio_seen;
 reg nn_audio_pulse=0;reg[4:0]nn_audio_count=0;reg[47:0]nn_audio_words=0;
 always @(posedge clk_pixel)begin
  if(rst_pixel)begin nn_audio_sync<=0;nn_audio_seen<=0;nn_audio_pulse<=0;nn_audio_count<=0;nn_audio_words<=0;end
  else begin nn_audio_sync<={nn_audio_sync[1:0],nn_audio_toggle};nn_audio_seen<=nn_audio_sync[2];nn_audio_pulse<=0;
   if(nn_audio_event)begin nn_audio_count<=nn_count_hold;nn_audio_words<=nn_words_hold;nn_audio_pulse<=1;end
  end
 end
 (* async_reg="true", syn_srlstyle="registers" *)reg[2:0]nn_ui_sync=0;reg nn_ui_seen=0;
 reg[2:0]nn_panel_state=0;reg[4:0]nn_panel_count=0;reg[47:0]nn_panel_words=0;reg nn_panel_accepted=0;
 always @(posedge clk_54m)begin
  nn_ui_sync<={nn_ui_sync[1:0],nn_ui_toggle};
  if(nn_ui_sync[2]!=nn_ui_seen)begin nn_ui_seen<=nn_ui_sync[2];nn_panel_state<=nn_ui_state;nn_panel_count<=nn_count_hold;nn_panel_words<=nn_words_hold;nn_panel_accepted<=nn_accepted_hold;end
 end

    // Bundled UI mailbox is held in clk_sys until its synchronized toggle retires.
    (* async_reg="true", syn_srlstyle="registers", syn_preserve="true" *)reg[2:0]nn_hdmi_sync=0;reg nn_hdmi_seen=0;
    reg[2:0]nn_hdmi_state=0;reg[4:0]nn_hdmi_count=0;reg[47:0]nn_hdmi_words=0;reg nn_hdmi_accepted=0;
    always @(posedge clk_pixel)begin
      if(rst_pixel)begin nn_hdmi_sync<=0;nn_hdmi_seen<=0;nn_hdmi_state<=0;nn_hdmi_count<=0;nn_hdmi_words<=0;nn_hdmi_accepted<=0;end
      else begin nn_hdmi_sync<={nn_hdmi_sync[1:0],nn_ui_toggle};
       if(nn_hdmi_sync[2]!=nn_hdmi_seen)begin nn_hdmi_seen<=nn_hdmi_sync[2];nn_hdmi_state<=nn_ui_state;
        nn_hdmi_count<=nn_count_hold;nn_hdmi_words<=nn_words_hold;nn_hdmi_accepted<=nn_accepted_hold;end end
    end
    touch_edge_panel touch_display(.continuous_mode(continuous_mode),.continuous_state(nn_panel_state),.continuous_count(nn_panel_count),.continuous_words(nn_panel_words),.continuous_accepted(nn_panel_accepted),
      .feature_state(feature_sync),.control_view(panel_control_sync[11:9]),.control_threshold(panel_control_sync[8:1]),
      .control_median(panel_control_sync[0]),.advanced_state(panel_control_sync[18:12]),.history_ids(history_ids_sync),.gesture_state(gesture_display_sync),
      .pixel_clk(clk_54m),.locked(lvds_pll_lock),.pause(1'b0),
      .touch_status(touch_display_sync[48:47]),.touch_active(touch_display_sync[46]),.touch_seen(touch_display_sync[45]),
      .touch_x(touch_display_sync[44:35]),.touch_y(touch_display_sync[34:25]),.touch_fingers(touch_display_sync[24:21]),
      .touch_taps(touch_display_sync[20:5]),.touch_targets(touch_display_sync[4:0]),
      .lcd_dclk(lcd_dclk),.lcd_r(rgb_lcd_r),.lcd_g(rgb_lcd_g),.lcd_b(rgb_lcd_b),
      .lcd_hs(rgb_lcd_hs),.lcd_vs(rgb_lcd_vs),.lcd_de(rgb_lcd_de),
      .lcd_bl(rgb_lcd_bl),.touch_rst(),.diag_mode());
    gt911_touch #(.MS_CYCLES(148800), .I2C_DIV(7440)) u_gt911_touch (
        .clk(clk_pixel), .reset_n(rstn_pixel),
        .scl_i(lcd_tp_scl_i), .sda_i(lcd_tp_sda_i),
        .scl_low(touch_scl_low), .sda_low(touch_sda_low), .int_low(touch_int_low),
        .touch_rst(touch_rst), .status(touch_status), .active(touch_active), .seen(touch_seen),
        .x(touch_x), .y(touch_y), .fingers(touch_fingers), .taps(touch_taps),
        .targets(touch_targets), .diagnostic(touch_diagnostic));


    // Unified static and continuous recognition; one shared camera/DDR/HDMI shell.
    wire [15:0] diag_key_state;
    wire [895:0] diag_compute;
 wire [63:0] diag_video_completion;wire [3:0] diag_source_cause;
    wire kp_valid,key_ready_pixel;
    wire [3:0] kp_code;
    // Touch commands are owned by edge_controls; keep the inference key path separate.
    wire control_key_valid = gesture_key_valid || kp_valid;
    wire [3:0] control_key_code = gesture_key_valid ? gesture_key_code : kp_code;
    wire continuous_mode,mode_change,static_reset;
    wire static_key_valid,continuous_key_valid;
    wire [3:0] static_key_code,continuous_key_code;
    recognition_mode_router mode_router(.clk(clk_pixel),.rst(rst_pixel),
      .key_valid(control_key_valid),.key_code(control_key_code),
      .continuous_mode(continuous_mode),.mode_change(mode_change),.static_reset(static_reset),
      .static_key_valid(static_key_valid),.static_key_code(static_key_code),
      .continuous_key_valid(continuous_key_valid),.continuous_key_code(continuous_key_code));
    (* async_reg="true",syn_srlstyle="registers",syn_preserve="true" *) reg [2:0] nn_flags_meta=0,nn_flags_sync=0;
    always @(posedge clk_pixel)begin
      if(rst_pixel)begin nn_flags_meta<=0;nn_flags_sync<=0;end
      else begin nn_flags_meta<={nn_weights_ready,nn_session,nn_recording};nn_flags_sync<=nn_flags_meta;end
    end
    reg lcd_vs_q=1'b0;
    always @(posedge clk_pixel) lcd_vs_q<=lcd_vs;
    // Touch-only control: physical button movement must not affect recognition.
    assign kp_valid=1'b0;
    assign kp_code=4'd0;
    assign diag_key_state=16'd0;
    wire [47:0] edge_rgb,practice_rgb;
    assign {w_lcd_r_o,w_lcd_g_o,w_lcd_b_o}=practice_rgb[23:0];
    wire edge_hs,edge_vs,edge_de,practice_hs,practice_vs,practice_de;
    wire [15:0] edge_x,edge_y;
    // Continuous camera display: the inference packet cannot stall pixel processing.
    assign frame_freeze=ui_freeze;
    assign frame_playback=ui_playback;
    assign frame_compare=ui_compare;
    assign frame_history_offset=ui_history;
    assign capture_busy=1'b0;
    assign capture_request=1'b0;
    assign capture_cancel=1'b0;
    assign edge_canny=canny_enable;

    wire edge_frame_tick;
    video_rgb_passthrough edge_video(
        .clk(clk_pixel),.rst(rst_pixel),.in_rgb({color_rgb1,color_rgb}),
        .in_hs(color_hs),.in_vs(color_vs),.in_de(color_de),
        .out_rgb(edge_rgb),.out_hs(edge_hs),.out_vs(edge_vs),.out_de(edge_de),
        .out_x(edge_x),.out_y(edge_y),.frame_tick(edge_frame_tick));
    wire [13:0] ui_control;
    
    reg recognition_mode=0;
    always @(posedge clk_pixel)begin
      if(static_reset||compute_error)recognition_mode<=0;
      else if(static_key_valid)case(static_key_code)
        3:recognition_mode<=1;
        12,15:recognition_mode<=0;
        default:begin end
      endcase
    end
wire signed [63:0] result_score;
wire [64:0] result_margin;
    static11_candidate_ui candidate_ui(.enable(!continuous_mode),.clk(clk_pixel),.rst(rst_pixel),.frame_tick(edge_frame_tick),.recognition_mode(recognition_mode),
      .x(edge_x),.y(edge_y),.rgb_in(edge_rgb),.de_in(edge_de),.hs_in(edge_hs),.vs_in(edge_vs),
      .target_id(ui_control[4:0]),.candidate_id(ui_control[9:5]),.result_seen(ui_control[10]),
      .capture_quality(ui_control[11]),.candidate_valid(ui_control[12]),.busy(ui_control[13]),.result_score(result_score[7:0]),.result_margin(result_margin[8:0]),
      .rgb_out(practice_rgb),.de_out(practice_de),.hs_out(practice_hs),.vs_out(practice_vs));


	////////////////////////////////////////////////////////////////
// Frame-latched display modes with Sobel threshold and optional median and Gaussian prefilters.
    wire [47:0] mode_rgb;wire mode_hs,mode_vs,mode_de;
    touch_view_2ppc #(.W(1920),.H(1080),.HT(1100)) mode_stage(.clk(clk_pixel),.rst(rst_pixel),.view(edge_ui_view),.threshold(edge_ui_threshold),.median_enable(edge_ui_median),.canny_enable(canny_enable),
      .rgb(practice_rgb),.hs(practice_hs),.vs(practice_vs),.de(practice_de),
      .out_rgb(mode_rgb),.out_hs(mode_hs),.out_vs(mode_vs),.out_de(mode_de));

 wire[47:0]rate_rgb;wire rate_hs,rate_vs,rate_de;
 video_rate_osd #(.CAM_Y(456),.OUT_Y(512)) fps_text(.clk(clk_pixel),.rst(rst_pixel),.rgb(osd_rgb),.hs(osd_hs),.vs(osd_vs),.de(osd_de),
 .camera_fps(rate_pixel_camera),.output_hz(rate_pixel_output),.rate_valid(rate_pixel_valid),
 .out_rgb(rate_rgb),.out_hs(rate_hs),.out_vs(rate_vs),.out_de(rate_de));
 wire[47:0]osd_rgb;wire osd_hs,osd_vs,osd_de;wire[15:0]osd_width,osd_height;
 continuous_hdmi_osd main_screen_text(.continuous_mode(continuous_mode),.clk(clk_pixel),.rst(rst_pixel),
 .rgb(video_ready_frame?mode_rgb:48'h101020101020),.hs(mode_hs),.vs(mode_vs),.de(mode_de),
 .state(nn_hdmi_state),.count(nn_hdmi_count),.words(nn_hdmi_words),.accepted(nn_hdmi_accepted),
 .out_rgb(osd_rgb),.out_hs(osd_hs),.out_vs(osd_vs),.out_de(osd_de),.active_width(osd_width),.active_height(osd_height));
 wire [23:0] y420_data; wire y420_hs,y420_vs,y420_de;
 rgb_to_y420 #(.HT(1100)) y420(.clk(clk_pixel),.rst(rst_pixel),
 .rgb(rate_rgb),.hs(rate_hs),.vs(rate_vs),.de(rate_de),
 .data(y420_data),.ohs(y420_hs),.ovs(y420_vs),.ode(y420_de));
 wire final_vs_n,final_de;
 wire [511:0] fps_status;
 wire[31:0]camera_snapshot_seq;wire[63:0]camera_snapshot_ref;
 wire[15:0]rate_camera_sys,rate_output_sys;wire rate_valid_sys,rate_toggle_sys;
 frame_rate_window rate_meter(.clk(clk_sys),.rst(!rstn_sys),.snapshot_seq(fps_status[159:128]),.output_reference_cycles(fps_status[127:64]),
 .camera_snapshot_seq(camera_snapshot_seq),.camera_reference_cycles(camera_snapshot_ref),
 .camera_good(camera_input_status[31:0]),.output_good(fps_status[255:224]),
 .camera_snapshot_valid(camera_input_status[191:160]==32'h43414d31),
 .camera_fps(rate_camera_sys),.output_hz(rate_output_sys),.valid(rate_valid_sys),.toggle(rate_toggle_sys));
 (* async_reg="true",syn_srlstyle="registers",syn_preserve="true" *)reg[2:0]rate_sync=0;
 reg rate_seen=0,rate_pixel_valid=0;reg[15:0]rate_pixel_camera=0,rate_pixel_output=0;
 always @(posedge clk_pixel)begin
 if(rst_pixel)begin rate_sync<=0;rate_seen<=0;rate_pixel_valid<=0;rate_pixel_camera<=0;rate_pixel_output<=0;end
 else begin rate_sync<={rate_sync[1:0],rate_toggle_sys};
 if(rate_sync[2]!=rate_seen)begin rate_seen<=rate_sync[2];rate_pixel_camera<=rate_camera_sys;rate_pixel_output<=rate_output_sys;rate_pixel_valid<=rate_valid_sys;end
 end end

 wire [191:0] camera_input_status;
 // Same one-cycle alignment as raw_center_crop ovs/ode.
 reg monitor_crop_hs=0;
 always @(posedge w_csi_rx_clk)if(!rstn_sys)monitor_crop_hs<=0;else monitor_crop_hs<=w_csi_rx_hsync0;
 camera_input_monitor #(.W(1920),.H(1080)) input_monitor(.clk(w_csi_rx_clk),.resetn(rstn_sys),
 .vs(crop_vs),.hs(monitor_crop_hs),.de(crop_de),.sys_clk(clk_sys),.sys_resetn(rstn_sys),.status(camera_input_status),.snapshot_sequence(camera_snapshot_seq),.snapshot_reference_cycles(camera_snapshot_ref));
 video_frame_monitor #(.W(1920),.H(1080)) fps_monitor(.pixel_clk(clk_pixel),.pixel_rst(rst_pixel),
 .sys_clk(clk_sys),.sys_resetn(rstn_sys),.vs_n(final_vs_n),.de(final_de),
 .source_id(history_display_id),.source_valid(video_ready_frame),
 .live_mode(!ui_freeze&&!ui_playback&&!ui_compare),.camera_vs(w_csi_rx_vsync0),.status(fps_status));
 hdmi_y420_tx #(.HT(1100)) u_hdmi_y420(.clk(clk_pixel),.rst(rst_pixel),
 .data(y420_data),.hs_n(y420_hs),.vs_n(y420_vs),.de(y420_de),
 .txc(hdmi_txc_o),.tx0(hdmi_txd0_o),.tx1(hdmi_txd1_o),.tx2(hdmi_txd2_o),
 .monitor_vs_n(final_vs_n),.monitor_de(final_de));

assign key_ready_pixel=video_ready_frame;
wire [31:0] job_epoch,snapshot_frame,result_epoch;
wire snapshot_locked,snapshot_quality,job_busy,result_valid;
wire [4:0] result_candidate;


static11_cnn_board_control #(.MIN_SCORE(`GESTURE_MIN_SCORE),.MIN_MARGIN(`GESTURE_MIN_MARGIN),.USE_CDC(1)) recognition(.core_clk(clk_nn),.clk(clk_pixel),.rst(static_reset),.model_ready(key_ready_pixel),
 .key_valid(static_key_valid),.key_code(static_key_code),.vs(edge_vs),.de(edge_de),.frame_quality(key_ready_pixel),
 .x(edge_x),.y(edge_y),.pixel_rgb565({edge_rgb[47:43],edge_rgb[39:34],edge_rgb[31:27],edge_rgb[23:19],edge_rgb[15:10],edge_rgb[7:3]}),
 .ui_control(ui_control),.fault(compute_error),.busy(job_busy),.epoch(job_epoch),
 .snapshot_locked(snapshot_locked),.snapshot_quality(snapshot_quality),.snapshot_frame(snapshot_frame),
 .candidate(result_candidate),.result_valid(result_valid),.result_epoch(result_epoch),.best_score(result_score),.margin(result_margin));

// The snapshot bank is already released before final result_valid.
// Use the committed result quality AND confidence acceptance, not live bank quality.
combined_audio audio(.continuous_mode(continuous_mode),.sequence_valid(nn_audio_pulse&&continuous_mode),.sequence_count(nn_audio_count),.sequence_words(nn_audio_words),.clk(clk_pixel),.rst(rst_pixel),.result_valid(result_valid),.quality(ui_control[11]&&ui_control[12]),
 .candidate(result_candidate),.cancel(audio_stop||mode_change||(control_key_valid&&(control_key_code==12||control_key_code==15||control_key_code==3))),
 .fault(continuous_mode?1'b0:compute_error),.audition(audio_audition),.demo_start(audio_demo_start),
 .bclk(audio_bclk_raw),.lrclk(audio_lrclk_raw),.din(audio_din_raw),.busy(audio_busy),.demo_state(demo_state),.played_count(audio_played_count));
audio_io_gate audio_gate(.clk(clk_pixel),.rst(rst_pixel),.mode(audio_mode_sync),.busy(audio_busy),
 .bclk_in(audio_bclk_raw),.lrclk_in(audio_lrclk_raw),.din_in(audio_din_raw),
 .gate(audio_pin_gate),.bclk(amp_bclk),.lrclk(amp_lrclk),.din(amp_din));
reg [31:0] sys_cycles=0,aw_count=0,w_count=0,ar_count=0,r_count=0;
always @(posedge clk_sys) begin
 sys_cycles<=sys_cycles+1'b1;
 if(w_ddr3_awvalid&&w_ddr3_awready) aw_count<=aw_count+1'b1;
 if(w_ddr3_wvalid&&w_ddr3_wready) w_count<=w_count+1'b1;
 if(w_ddr3_arvalid&&w_ddr3_arready) ar_count<=ar_count+1'b1;
 if(w_ddr3_rvalid&&w_ddr3_rready) r_count<=r_count+1'b1;
end
reg cam_vs_q=0,cam_de_q=0;
reg [31:0] cam_frames=0,cam_groups=0,last_groups=0,cam_lines=0,last_lines=0;
reg [15:0] line_groups=0,min_line=16'hffff,max_line=0,last_min=0,last_max=0;
reg [31:0] first_pixels=0,cam_cycles=0,write_full_count=0;
always @(posedge w_csi_rx_clk) begin
 cam_cycles<=cam_cycles+1'b1;cam_vs_q<=w_csi_rx_vsync0;cam_de_q<=w_csi_rx_dvalid;
 if(debug_wfull&&cmos_frame_href) write_full_count<=write_full_count+1'b1;
 if(w_csi_rx_dvalid) begin
  cam_groups<=cam_groups+1'b1;line_groups<=line_groups+1'b1;
  if(cam_groups==0)first_pixels<=w_csi_rx_data[31:0];
 end
 if(cam_de_q&&!w_csi_rx_dvalid)begin
  cam_lines<=cam_lines+1'b1;
  if(line_groups<min_line)min_line<=line_groups;
  if(line_groups>max_line)max_line<=line_groups;
  line_groups<=0;
 end
 if(cam_vs_q&&!w_csi_rx_vsync0)begin
  cam_frames<=cam_frames+1'b1;last_groups<=cam_groups;last_lines<=cam_lines;
  last_min<=min_line;last_max<=max_line;
  cam_groups<=0;cam_lines<=0;min_line<=16'hffff;max_line<=0;
 end
end
reg frame_available=0;
always @(posedge w_ddr3_ui_clk)begin
 if(w_ddr3_ui_rst)frame_available<=0;
 else if(video_commit&&video_commit_address[20:0]==(2073600-1024))frame_available<=1;
end
(* async_reg="true" *) reg [1:0] video_ready_sync=0;
always @(posedge clk_pixel or negedge rstn_pixel)
 if(!rstn_pixel)video_ready_sync<=0;
 else video_ready_sync<={video_ready_sync[0],frame_available};
// Reveal the first committed camera frame only at a display frame boundary.
// This prevents readiness arriving halfway through a 240 Hz scan from exposing
// the partially prefetched startup buffer. Normal reads select completed banks.
reg video_ready_frame=0;
always @(posedge clk_pixel or negedge rstn_pixel)
 if(!rstn_pixel)video_ready_frame<=0;
 else if(!video_ready_sync[1])video_ready_frame<=0;
 else if(!mode_vs)video_ready_frame<=1;
wire [191:0] raw_pixel_stats=192'd0,ddr_pixel_stats=192'd0,y_pixel_stats=192'd0;
// PIXP version2: optional raw/DDR/Y pixel histograms disabled to fit Ti60 routing.
 wire [1023:0] pixel_probe_state={192'd0,y_pixel_stats,ddr_pixel_stats,raw_pixel_stats,
 16'd0,history_display_id,20'd0,edge_ui_view,edge_ui_median,edge_ui_threshold,
 29'd0,video_ready_frame,frame_available,video_ready_sync[1],exposure_lines,exposure_status,sensor_timing_confirmed,32'd2,32'h50495831};
wire [31:0] diag_flags={21'd0,pad_overlap,debug_wfull,sc2210_video_started,sc2210_i2c_config_failed,
 sc2210_i2c_config_done,w_ddr3_cal_pass,w_ddr3_cal_done,r_ddr_unlock,rstn_sys,sys_pll_lock,ddr_pll_lock};
wire [1023:0] diag_state={{rb_values,32'd0,24'd0,post_count,25'd0,probe_address,probe_ids,24'd0,probe_ack,2'd0,probe_complete,probe_found},write_full_count,cam_cycles,first_pixels,{20'd0,csi_sda_i,csi_scl_i,rb_done,rb_failed,csi_ctl1_i,csi_ctl0_i,
 csi_rxd0_hs_en_o,csi_rxc_hs_en_o,csi_rxd0_lp_n_i,csi_rxd0_lp_p_i,csi_rxc_lp_n_i,csi_rxc_lp_p_i},
 debug_underflows,r_count,ar_count,w_count,aw_count,w_csi_rx_data[31:0],
 {12'd0,pad_frame_beats},last_lines,{12'd0,crop_frame_beats},cam_frames,{23'd0,sc2210_i2c_config_index},
 diag_flags,sys_cycles,32'h53433244};

 wire[1023:0]nn_packet;wire nn_packet_toggle,nn_packet_busy,nn_packet_ack;
 wire[255:0]nn_status;wire nn_weights_ready,nn_session,nn_recording,nn_done,nn_fault,nn_result,nn_accepted,nn_result_fault;
 wire[8:0]nn_frames;wire[4:0]nn_token_count;wire[47:0]nn_tokens;wire[16:0]nn_score;
 continuous_board_control continuous_recognition(.clk(w_ddr3_ui_clk),.pixel_clk(clk_pixel),.bus_reset(w_ddr3_ui_rst),.ddr_ready(r_ddr_unlock),
 .key_valid(continuous_key_valid),.key_code(continuous_key_code),.frame_tick(edge_frame_tick),.pixel_valid(edge_de),.video_ready(video_ready_frame),.live_video(!ui_freeze&&!ui_playback&&!ui_compare),
 .source_frame_id(history_display_id),.x(edge_x[10:0]),.y(edge_y[10:0]),.rgb(edge_rgb),
 .diag_tck(diag_tck),.packet_hold_tck(nn_packet),.packet_toggle_tck(nn_packet_toggle),.packet_busy_tck(nn_packet_busy),.packet_ack_toggle_tck(nn_packet_ack),.status_tck(nn_status),
 .weights_ready(nn_weights_ready),.session_active(nn_session),.recording(nn_recording),.done(nn_done),.fault(nn_fault),.recorded_frames(nn_frames),
 .result_valid(nn_result),.accepted(nn_accepted),.result_fault(nn_result_fault),.token_count(nn_token_count),.token_words(nn_tokens),.minimum_score_q(nn_score),
 .command_valid(nn_cv),.command_write(nn_cw),.command_ready(nn_cr),.command_address(nn_ca),.command_length(nn_cl),
 .wvalid(nn_wv),.wlast(nn_wl),.wready(nn_wr),.wdata(nn_wd),.wstrb(nn_ws),.read_data(nn_rd),.read_valid(nn_rv),.read_last(nn_rl),.read_response(nn_rp),.read_ready(nn_rr),.bvalid(nn_bv),.bresp(nn_bp),.bready(nn_br));

diag_scan dscan(.bus_reset(w_ddr3_ui_rst),.packet_busy_tck(nn_packet_busy),.packet_ack_tck(nn_packet_ack),.neural_status_tck(nn_status),.packet_hold_tck(nn_packet),.packet_toggle_tck(nn_packet_toggle),.sys_clk(clk_sys),.fps_state({camera_input_status,rb_values,31'd0,rb_done,{last_min,last_max},last_lines,last_groups,fps_status}),.pixel_state(pixel_probe_state),.live_state({color_active,
32'h53435331,result_margin[63:32],result_margin[31:0],result_score[63:32],result_score[31:0],
{canny_enable,demo_state,audio_pin_gate,audio_played_count,audio_busy,compute_error,snapshot_quality,snapshot_locked,job_busy,result_valid,result_candidate},
snapshot_frame,job_epoch,{18'd0,ui_control},{16'd0,touch_taps},
{12'd0,touch_y,touch_x},{26'd0,touch_seen,touch_active,touch_status,probe_complete,probe_found},
diag_state[575:320],exposure_status,exposure_lines,diag_state[255:0]}),.tck(diag_tck),
 .capture(diag_capture),.shift(diag_shift),.update(diag_update),.sel(diag_sel),.tdi(diag_tdi),.tdo(diag_tdo),.color_mailbox(color_mailbox),.color_toggle(color_toggle),.audio_io_mode(audio_io_mode),.exposure_mailbox(exposure_mailbox),.exposure_toggle(exposure_toggle));
endmodule


