`timescale 1ns/1ps
`default_nettype none

// Full display raster, II=1 including blanking. Controls change at each stage's
// delayed frame boundary; deep coordinate RAM is replaced by sync + counters.
module ti60_edge_video #(
    parameter integer W = 1280,
    parameter integer H = 720,
    parameter integer HT = 1650,
    parameter integer ENABLE_CANNY = 1,
    parameter integer ENABLE_NUT_OVERLAY = 1,
    parameter integer COMPACT_META = 1,
    // Only set for {R5,3'b0,G6,2'b0,B5,3'b0}, as used by the vendor DVP path.
    parameter integer RGB565_INPUT = 0,
    parameter integer ENABLE_ROI_DUAL = 0,
    parameter integer ROI_W = W/4,
    parameter integer ROI_H = H/3,
    parameter integer ROI_X = (W-ROI_W)/2,
    parameter integer ROI_Y = (H-ROI_H)/2,
    parameter integer ROI_DISPLAY_X = (W-2*ROI_W)/2
)(
    input wire clk, rst,
    input wire [23:0] in_rgb,
    input wire in_hs, in_vs, in_de,
    input wire [2:0] view,
    input wire median_enable,
    input wire canny_enable,
    input wire [10:0] threshold,
    output reg [23:0] out_rgb,
    output reg out_hs, out_vs, out_de,
    // Taps are BEFORE presentation overlays, on the DDR DISPLAY stream.
    // proc_gray is original luminance; median_enable affects proc_edge only.
    output reg [23:0] proc_rgb,
    output reg [7:0] proc_gray,
    output reg proc_edge,
    output reg [15:0] proc_x, proc_y,
    output reg proc_de, proc_hs, proc_vs
);
    localparam integer MEDIAN_DELAY = HT + 11;
    localparam integer SOBEL_DELAY = HT + 5;
    localparam integer GRAY_DELAY = MEDIAN_DELAY + SOBEL_DELAY;
    localparam integer CANNY_DELAY = ENABLE_CANNY ? 2*(HT+2) : 0;
    // Sample captured at edge n appears after edge n+PIPELINE_DELAY-1.
    localparam integer PIPELINE_DELAY = 1+GRAY_DELAY+CANNY_DELAY+1+ENABLE_ROI_DUAL;

    reg [2:0] input_view;
    reg input_median, input_canny;
    reg [10:0] input_threshold;
    reg [15:0] x,y;
    reg de_q,vs_q,frame_seen;
    wire frame_boundary = in_vs && !vs_q;
    always @(posedge clk) begin
        if (rst) begin
            input_view<=3;input_median<=1;input_canny<=0;input_threshold<=128;
            x<=0;y<=0;de_q<=0;vs_q<=1;frame_seen<=0;
        end else begin
            de_q<=in_de;vs_q<=in_vs;
            if(in_de) x<=x+1'b1;else x<=0;
            if(frame_boundary) begin
                y<=0;frame_seen<=1;
                input_view<=view;input_median<=median_enable;
                input_canny<=canny_enable;input_threshold<=threshold;
            end else if(de_q && !in_de) y<=y+1'b1;
        end
    end
    wire valid = in_de && frame_seen;
    wire [34:0] meta = {in_vs,in_hs,valid,valid?y:16'hffff,valid?x:16'hffff};
    wire [7:0] gray,median_value,median_center,sobel_input,delayed_gray;
    wire [34:0] gray_meta,median_meta,sobel_meta;
    wire edge_pixel;
    wire [10:0] magnitude;
    wire [1:0] direction;

    rgb2gray gray_i(clk,rst,in_rgb,meta,gray,gray_meta);
    median_3x3 #(.HT(HT),.W(W),.H(H),.COMPACT_META(COMPACT_META)) median_i(
        .clk(clk),.rst(rst),.din(gray),.meta(gray_meta),.dout(median_value),
        .m_meta(median_meta),.center_gray(median_center)
    );
    reg median_vs_q,active_median;
    reg sobel_vs_q;
    reg [10:0] sobel_threshold;
    always @(posedge clk) begin
        if(rst) begin median_vs_q<=1;active_median<=1;sobel_vs_q<=1;sobel_threshold<=128;end
        else begin
            median_vs_q<=median_meta[34];sobel_vs_q<=sobel_meta[34];
            if(median_meta[34] && !median_vs_q) active_median<=input_median;
            if(sobel_meta[34] && !sobel_vs_q) sobel_threshold<=input_threshold;
        end
    end
    wire median_interior=median_meta[32] && median_meta[15:0]>0 && median_meta[15:0]<W-1
                         && median_meta[31:16]>0 && median_meta[31:16]<H-1;
    assign sobel_input=active_median && median_interior ? median_value : median_center;
    sobel_top #(.HT(HT),.W(W),.H(H),.COMPACT_META(COMPACT_META),
                .COMPUTE_DIRECTION(ENABLE_CANNY)) sobel_i(
        .clk(clk),.rst(rst),.din(sobel_input),.meta(median_meta),.threshold(sobel_threshold),
        .edge_out(edge_pixel),.mag(magnitude),.dir(direction),.m_meta(sobel_meta)
    );
    // Original gray uses the median window's center and only ONE Sobel delay.
    stream_delay #(8,SOBEL_DELAY+CANNY_DELAY) gray_delay_i(clk,rst,median_center,delayed_gray);
    wire [23:0] delayed_rgb;
    generate if(RGB565_INPUT) begin: packed_rgb
        wire [15:0] q;
        stream_delay #(16,1+GRAY_DELAY+CANNY_DELAY) rgb_delay_i(
            clk,rst,{in_rgb[23:19],in_rgb[15:10],in_rgb[7:3]},q);
        assign delayed_rgb={q[15:11],3'b0,q[10:5],2'b0,q[4:0],3'b0};
    end else begin: full_rgb
        stream_delay #(24,1+GRAY_DELAY+CANNY_DELAY) rgb_delay_i(clk,rst,in_rgb,delayed_rgb);
    end endgenerate

    wire selected_edge;
    wire [34:0] process_meta;
    reg output_vs_q,active_canny;
    reg [2:0] active_view;
    generate if(ENABLE_CANNY) begin: with_canny
        wire canny_edge,delayed_sobel_edge;
        canny_stream #(.HT(HT),.W(W),.H(H),.COMPACT_META(COMPACT_META)) canny_i(
            .clk(clk),.rst(rst),.magnitude(magnitude),.direction(direction),
            .meta(sobel_meta),.high_threshold(sobel_threshold),
            .edge_out(canny_edge),.out_meta(process_meta)
        );
        stream_delay #(1,CANNY_DELAY) sobel_align(clk,rst,edge_pixel,delayed_sobel_edge);
        assign selected_edge=active_canny?canny_edge:delayed_sobel_edge;
    end else begin: without_canny
        assign process_meta=sobel_meta;
        assign selected_edge=edge_pixel;
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin output_vs_q<=1;active_view<=3;active_canny<=0;end
        else begin
            output_vs_q<=process_meta[34];
            if(process_meta[34] && !output_vs_q) begin
                active_view<=input_view;active_canny<=input_canny;
            end
        end
    end

    wire [23:0] nut_overlay_rgb;
    wire nut_overlay_valid;
    generate if(ENABLE_NUT_OVERLAY) begin: with_nuts
        wire [1:0] label0,label1,label2;
        nut_recognizer #(.W(W)) nuts(
            .clk(clk),.rst(rst),.vs(process_meta[34]),.de(process_meta[32]),
            .gray(delayed_gray),.x(process_meta[15:0]),.y(process_meta[31:16]),
            .label0(label0),.label1(label1),.label2(label2),
            .overlay_rgb(nut_overlay_rgb),.overlay_valid(nut_overlay_valid)
        );
    end else begin: without_nuts
        assign nut_overlay_rgb=0;assign nut_overlay_valid=0;
    end endgenerate
    reg [23:0] selected_rgb;
    always @* case(active_view)
        0:selected_rgb=delayed_rgb;
        1:selected_rgb={3{delayed_gray}};
        2:selected_rgb={24{selected_edge}};
        3:selected_rgb=process_meta[15:0]<W/2?{3{delayed_gray}}:{24{selected_edge}};
        4:selected_rgb=process_meta[31:16]<H/2?{3{delayed_gray}}:{24{selected_edge}};
        5:selected_rgb=nut_overlay_valid?nut_overlay_rgb:selected_edge?24'hff2020:delayed_rgb;
        default:selected_rgb=delayed_rgb;
    endcase

    wire [23:0] presentation_rgb,tap_rgb;
    wire [7:0] tap_gray;
    wire tap_edge;
    wire [34:0] tap_meta;
    generate if(ENABLE_ROI_DUAL) begin: roi_dual
        // Two ping-pong scanlines, 2*ROI_W*9 bits, NOT a frame store.
        // View 6 shows the complete fixed ROI gray/edge pair without scaling.
        // Source row y is presented at y+1 so both copies read a completed row.
        localparam integer AW=(ROI_W<2)?1:$clog2(ROI_W);
        reg [8:0] line0[0:ROI_W-1],line1[0:ROI_W-1];
        reg [8:0] read0_q,read1_q;
        reg bank0_q;
        wire [8:0] read_q=bank0_q?read0_q:read1_q;
        reg [23:0] base_q,rgb_q;
        reg [7:0] gray_q;
        reg edge_q,roi_valid_q,right_q;
        reg [34:0] meta_q;
        reg [1:0] line_valid;
        reg [15:0] line_y0,line_y1;
        reg roi_vs_q;
        wire [15:0] px=process_meta[15:0],py=process_meta[31:16];
        wire write_roi=process_meta[32] && px>=ROI_X && px<ROI_X+ROI_W
                       && py>=ROI_Y && py<ROI_Y+ROI_H;
        wire read_roi=process_meta[32] && px>=ROI_DISPLAY_X && px<ROI_DISPLAY_X+2*ROI_W
                      && py>ROI_Y && py<=ROI_Y+ROI_H;
        wire right=px>=ROI_DISPLAY_X+ROI_W;
        wire [AW-1:0] wr_addr=px-ROI_X;
        wire [AW-1:0] rd_addr=right?px-ROI_DISPLAY_X-ROI_W:px-ROI_DISPLAY_X;
        wire completed_line=py[0]?(line_valid[0] && line_y0==py-1'b1):
                                             (line_valid[1] && line_y1==py-1'b1);
        // Each bank has its own unconditional synchronous read. Selecting the
        // bank AFTER these registers preserves block-RAM inference and latency.
        always @(posedge clk) begin
            if(!rst && write_roi && !py[0]) line0[wr_addr]<={selected_edge,delayed_gray};
            read0_q<=line0[rd_addr];
        end
        always @(posedge clk) begin
            if(!rst && write_roi && py[0]) line1[wr_addr]<={selected_edge,delayed_gray};
            read1_q<=line1[rd_addr];
        end
        always @(posedge clk) begin
            if(rst) begin
                base_q<=0;rgb_q<=0;gray_q<=0;edge_q<=0;meta_q<=0;
                roi_valid_q<=0;right_q<=0;bank0_q<=0;line_valid<=0;roi_vs_q<=1;
                line_y0<=0;line_y1<=0;
            end else begin
                roi_vs_q<=process_meta[34];
                if(process_meta[34] && !roi_vs_q) line_valid<=0;
                if(write_roi && px==ROI_X+ROI_W-1) begin
                    line_valid[py[0]]<=1;
                    if(py[0]) line_y1<=py;else line_y0<=py;
                end
                base_q<=selected_rgb;rgb_q<=delayed_rgb;gray_q<=delayed_gray;
                edge_q<=selected_edge;meta_q<=process_meta;right_q<=right;bank0_q<=py[0];
                roi_valid_q<=active_view==6 && read_roi && completed_line;
                if(active_view==6) base_q<=0;
            end
        end
        assign presentation_rgb=roi_valid_q?(right_q?{24{read_q[8]}}:{3{read_q[7:0]}}):base_q;
        assign tap_rgb=rgb_q;assign tap_gray=gray_q;assign tap_edge=edge_q;assign tap_meta=meta_q;
    end else begin: no_roi_dual
        assign presentation_rgb=selected_rgb;
        assign tap_rgb=delayed_rgb;assign tap_gray=delayed_gray;
        assign tap_edge=selected_edge;assign tap_meta=process_meta;
    end endgenerate
    always @(posedge clk) begin
        if(rst) begin
            out_rgb<=0;out_hs<=1;out_vs<=1;out_de<=0;
            proc_rgb<=0;proc_gray<=0;proc_edge<=0;proc_x<=16'hffff;proc_y<=16'hffff;
            proc_de<=0;proc_hs<=1;proc_vs<=1;
        end else begin
            out_rgb<=tap_meta[32]?presentation_rgb:24'd0;
            out_hs<=tap_meta[33];out_vs<=tap_meta[34];out_de<=tap_meta[32];
            proc_rgb<=tap_meta[32]?tap_rgb:24'd0;
            proc_gray<=tap_meta[32]?tap_gray:8'd0;
            proc_edge<=tap_meta[32] && tap_edge;
            proc_x<=tap_meta[15:0];proc_y<=tap_meta[31:16];
            proc_de<=tap_meta[32];proc_hs<=tap_meta[33];proc_vs<=tap_meta[34];
        end
    end
endmodule
`default_nettype wire
