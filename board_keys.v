`timescale 1ns/1ps
`default_nettype none
// Active-low board switches. Short commands fire on debounced release;
// K1 short/long = previous/next; K2 short/long = start-stop/cancel.
// K3 is dedicated CRESET_N and cannot be bound to this module.
module board_keys #(
    parameter integer CLOCK_HZ = 74400000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 800
)(
    input wire clk, rst,
    input wire [1:0] key_n,
    output reg key_valid = 0,
    output reg [3:0] key_code = 0,
    output wire [15:0] diagnostic_state
);
    localparam integer DB_TICKS = (CLOCK_HZ / 1000) * DEBOUNCE_MS;
    localparam integer LONG_TICKS = (CLOCK_HZ / 1000) * LONG_PRESS_MS;
    localparam integer DB_BITS = DB_TICKS < 2 ? 1 : $clog2(DB_TICKS);
    localparam integer LONG_BITS = LONG_TICKS < 2 ? 1 : $clog2(LONG_TICKS);
    (* async_reg="true" *) reg [1:0] key_meta = 2'b11, key_sync = 2'b11;
    reg [1:0] candidate = 2'b11, stable = 2'b11, active = 0;
    reg [DB_BITS-1:0] debounce_count = 0;
    reg [LONG_BITS-1:0] hold_count = 0;
    reg settled = 0, armed = 0, long_sent = 0;
    wire [1:0] pressed = ~stable;
    wire single_key = pressed == 2'b01 || pressed == 2'b10;
    assign diagnostic_state={4'd0,long_sent,armed,settled,single_key,active,stable,key_sync};
    always @(posedge clk) begin
        key_meta <= key_n;
        key_sync <= key_meta;
        key_valid <= 0;
        if (rst) begin
            key_meta <= 2'b11; key_sync <= 2'b11;
            candidate <= 2'b11; stable <= 2'b11; active <= 0;
            debounce_count <= 0; hold_count <= 0;
            settled <= 0; armed <= 0; long_sent <= 0; key_code <= 0;
        end else begin
            if (key_sync != candidate) begin
                candidate <= key_sync;
                debounce_count <= 0;
            end else if (debounce_count != DB_TICKS-1) begin
                debounce_count <= debounce_count + 1'b1;
            end else begin
                stable <= candidate;
                settled <= 1;
            end
            if (settled) begin
                if (pressed == 0) begin
                    if (active != 0 && !long_sent) begin
                        key_valid <= 1;
                        key_code <= active[0] ? 4'd7 : 4'd3;
                    end
                    active <= 0; armed <= 1; hold_count <= 0; long_sent <= 0;
                end else if (!single_key || (active != 0 && pressed != active)) begin
                    // Chords/overlapping keys are ignored until every key is released.
                    active <= 0; armed <= 0; hold_count <= 0; long_sent <= 0;
                end else if (armed) begin
                    active <= pressed; armed <= 0; hold_count <= 0; long_sent <= 0;
                end else if (active != 0 && !long_sent) begin
                    if (hold_count == LONG_TICKS-1) begin
                        key_valid <= 1; key_code <= active[0] ? 4'd11 : 4'd12; long_sent <= 1;
                    end else hold_count <= hold_count + 1'b1;
                end
            end
        end
    end
endmodule
`default_nettype wire
