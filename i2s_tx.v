`timescale 1ns/1ps
// Vendor-independent I2S: 32-bit slots, signed 16-bit PCM in bits [31:16].
// LRCLK and DIN change at BCLK falling edges. The MSB follows an LRCLK
// transition by one full BCLK. Both channels receive the same frame sample.
module i2s_tx #(
    parameter integer HALF_DIV = 24
)(
    input wire clk,
    input wire rst_n,
    input wire [15:0] pcm_sample,
    output reg sample_req,
    output reg bclk,
    output reg lrclk,
    output reg din
);
    reg [15:0] divider;
    reg [5:0] phase;
    reg [15:0] frame_sample;
    wire [5:0] next_phase = phase + 6'd1;

    always @(posedge clk) begin
        if (!rst_n) begin
            divider <= 0;
            phase <= 63;
            frame_sample <= 0;
            sample_req <= 0;
            bclk <= 0;
            lrclk <= 0;
            din <= 0;
        end else begin
            sample_req <= 0;
            if (divider == HALF_DIV - 1) begin
                divider <= 0;
                bclk <= ~bclk;
                if (bclk) begin
                    phase <= next_phase;
                    lrclk <= next_phase[5];
                    // Request early enough for a synchronous block-ROM read.
                    if (next_phase == 63)
                        sample_req <= 1;
                    if (next_phase == 0)
                        frame_sample <= pcm_sample;
                    if (next_phase >= 1 && next_phase <= 16)
                        din <= frame_sample[16 - next_phase];
                    else if (next_phase >= 33 && next_phase <= 48)
                        din <= frame_sample[48 - next_phase];
                    else
                        din <= 0;
                end
            end else begin
                divider <= divider + 1'b1;
            end
        end
    end
endmodule
