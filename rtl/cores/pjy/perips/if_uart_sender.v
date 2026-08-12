 /*
 Copyright 2026

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 */

// TASK6_IF_BEGIN: one-byte UART sender for Integrated-and-Fire instruction
module pjy_if_uart_sender(

    input wire clk,
    input wire rst,

    input wire start_i,
    input wire[7:0] data_i,
    input wire uart_tx_busy_i,

    output reg busy_o,
    output reg done_o,
    output reg tx_valid_o,
    output reg[7:0] tx_data_o

    );

    localparam S_IDLE      = 3'b001;
    localparam S_SEND      = 3'b010;
    localparam S_WAIT_BUSY = 3'b011;
    localparam S_WAIT_IDLE = 3'b100;

    reg[2:0] state;
    reg start_seen;
    reg sent_once;

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            state <= S_IDLE;
            start_seen <= 1'b0;
            busy_o <= 1'b0;
            done_o <= 1'b0;
            tx_valid_o <= 1'b0;
            tx_data_o <= 8'h0;
            sent_once <= 1'b0;
        end else begin
            done_o <= 1'b0;
            tx_valid_o <= 1'b0;

            if (start_i == 1'b0) begin
                start_seen <= 1'b0;
            end

            case (state)
                S_IDLE: begin
                    busy_o <= 1'b0;
                    if (start_i == 1'b1 && start_seen == 1'b0) begin
                        start_seen <= 1'b1;
                        if (sent_once == 1'b1) begin
                            done_o <= 1'b1;
                        end else begin
                            tx_data_o <= data_i;
                            busy_o <= 1'b1;
                            state <= S_SEND;
                        end
                    end
                end
                S_SEND: begin
                    busy_o <= 1'b1;
                    if (uart_tx_busy_i == 1'b0) begin
                        tx_valid_o <= 1'b1;
                        state <= S_WAIT_BUSY;
                    end
                end
                S_WAIT_BUSY: begin
                    busy_o <= 1'b1;
                    if (uart_tx_busy_i == 1'b1) begin
                        state <= S_WAIT_IDLE;
                    end
                end
                S_WAIT_IDLE: begin
                    busy_o <= 1'b1;
                    if (uart_tx_busy_i == 1'b0) begin
                        busy_o <= 1'b0;
                        done_o <= 1'b1;
                        sent_once <= 1'b1;
                        state <= S_IDLE;
                    end
                end
                default: begin
                    state <= S_IDLE;
                    busy_o <= 1'b0;
                end
            endcase
        end
    end

endmodule
// TASK6_IF_END
