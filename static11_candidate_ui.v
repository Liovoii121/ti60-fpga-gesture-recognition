`timescale 1ns/1ps
`default_nettype none
// Reuses the original sign_live_ui two synchronous-ROM pipeline.
// Static 11-class candidate display only: no trusted classes, judgement or score outputs.
// Display seen, quality-passing candidates even when firmware accept is zero.
// Control inputs must already be in the pixel clock domain; latch at frame_tick.
module static11_candidate_ui #(
    parameter FONT_FILE="font_rows.mem", TEXT_FILE="text_cells.mem"
)(
    input wire clk,rst,frame_tick,recognition_mode,enable,
    input wire [15:0] x,y,
    input wire [47:0] rgb_in,
    input wire de_in,hs_in,vs_in,
    input wire [4:0] target_id,candidate_id,
    input wire result_seen,capture_quality,candidate_valid,busy,
    input wire signed [7:0] result_score,
    input wire signed [8:0] result_margin,
    output wire [47:0] rgb_out,
    output reg de_out,hs_out,vs_out
);
    reg [4:0] target_s,candidate_s;
    reg signed [7:0] score_s;reg signed [8:0] margin_s;
    reg seen_s,quality_s,valid_s,busy_s;
    // Recognition session owns the guide, including after a completed result.
    reg guide_s;
    reg enabled_s;
    wire roi_border=guide_s&&de_in&&x>=512&&x<1408&&y>=92&&y<988&&
        (x<514||x>=1406||y<94||y>=986);
    wire [47:0] overlay_rgb=roi_border?48'h00ff8000ff80:rgb_in;
    // Preserve the last completed, quality-passing class across new jobs/cancel.
    reg [4:0] last_candidate;
    reg have_last;
    (* syn_romstyle="logic" *) reg [15:0] font_rom[0:2047];
    (* syn_romstyle="logic" *) reg [6:0] text_rom[0:2047];
    initial begin $readmemh(FONT_FILE,font_rom);$readmemh(TEXT_FILE,text_rom);end
    // 16x16 glyphs scaled3x to48px; independent paired-pixel indices at thirds.
    wire[8:0]xo=x[8:0]-9'd16;wire[8:0]xo_next=xo+1'b1;
    wire[8:0]tx0=xo/3,tx1=xo_next/3;
    wire[15:0]tx=16'd32+tx0;
    wire[8:0]yo=y[8:0]-9'd16;
    wire[15:0]ty=16'd8+yo/3;
    wire [15:0] lx=tx-16'd32;
    wire [4:0] column=lx[8:4];
    reg text_on;
    reg [5:0] row;
    reg [3:0] gy;
    always @* begin
        text_on=0;row=0;gy=0;
        if(de_in && have_last && tx>=32 && tx<192 && ty>=8 && ty<24)begin text_on=1;row=valid_s?4:3;gy=ty-8;end
        if(de_in && have_last && tx>=32 && tx<160 && ty>=72 && ty<88)begin text_on=1;row=5;gy=ty-72;end
        if(de_in && have_last && tx>=32 && tx<160 && ty>=96 && ty<112)begin text_on=1;row=6;gy=ty-96;end
        if(de_in && tx>=32 && tx<176 && ty>=48 && ty<64)begin text_on=1;row={1'b0,target_s};gy=ty-48;end
        if(de_in && have_last && tx>=32 && tx<112 && ty>=24 && ty<40)begin
            text_on=1;row=6'd32+{1'b0,last_candidate};gy=ty-24;
        end
        if(!enabled_s||x<16||x>=496||y<16||y>=328)text_on=0;
    end
    wire number_area=x>=16&&x<496&&y>=16&&y<328&&have_last&&tx>=96&&tx<160&&((ty>=72&&ty<88)||(ty>=96&&ty<112));
    wire signed [8:0] number_value=ty<96?$signed(score_s):margin_s;
    wire [8:0] magnitude=number_value<0?-number_value:number_value;
    wire [1:0] number_column=(tx-96)>>4;
    reg [6:0] number_glyph;
    always @* case(number_column)
      0:number_glyph=number_value<0?11:0;
      1:number_glyph=1+(magnitude/100)%10;
      2:number_glyph=1+(magnitude/10)%10;
      3:number_glyph=1+magnitude%10;
    endcase
    wire [10:0] text_addr={row,column};
    reg [6:0] glyph1;
    reg [3:0] gy1,gx1,gx2,gxb1,gxb2;
    reg [15:0] bits2;
    reg text1,text2;
    reg [47:0] rgb1,rgb2;
    reg de1,hs1,vs1;
    always @(posedge clk)begin
        glyph1<=number_area?number_glyph:text_rom[text_addr];
        bits2<=font_rom[{glyph1,gy1}];
    end
    always @(posedge clk)begin
        if(rst)begin
            enabled_s<=0;guide_s<=0;last_candidate<=31;have_last<=0;target_s<=0;candidate_s<=0;seen_s<=0;quality_s<=0;valid_s<=0;busy_s<=0;
            gy1<=0;gx1<=0;gx2<=0;gxb1<=0;gxb2<=0;text1<=0;text2<=0;rgb1<=0;rgb2<=0;
            de1<=0;hs1<=0;vs1<=0;de_out<=0;hs_out<=0;vs_out<=0;
        end else begin
            if(frame_tick && result_seen && capture_quality && candidate_id<25 && !busy)begin
                last_candidate<=candidate_id;have_last<=1;
            end
            if(frame_tick && result_seen && !busy && (!capture_quality || candidate_id>=25))have_last<=0;
            if(!enable)have_last<=0;
            if(frame_tick)begin enabled_s<=enable;score_s<=result_score;margin_s<=result_margin;guide_s<=recognition_mode&&enable;target_s<=target_id;candidate_s<=candidate_id;seen_s<=result_seen;
                quality_s<=capture_quality;valid_s<=candidate_valid;busy_s<=busy;end
            gy1<=gy;gx1<=lx[3:0];gx2<=gx1;gxb1<=tx1[3:0];gxb2<=gxb1;text1<=text_on;text2<=text1;
            rgb1<=overlay_rgb;rgb2<=rgb1;de1<=de_in;hs1<=hs_in;vs1<=vs_in;
            de_out<=de1;hs_out<=hs1;vs_out<=vs1;
        end
    end
    assign rgb_out=text2?{(bits2[15-gxb2]?(valid_s?24'h17e8a6:24'hffd070):24'h14283c),(bits2[15-gx2]?(valid_s?24'h17e8a6:24'hffd070):24'h14283c)}:rgb2;
endmodule
`default_nettype wire

