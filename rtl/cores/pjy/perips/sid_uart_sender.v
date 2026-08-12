 /*
 Copyright 2026

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

// TASK4_SID_BEGIN: Send ID extension UART byte sequencer
module pjy_sid_uart_sender(

    input wire clk,
    input wire rst,

    input wire start_i,
    input wire uart_tx_busy_i,

    output reg busy_o,
    output reg done_o,
    output reg tx_valid_o,
    output reg[7:0] tx_data_o,
    output reg[3:0] sid_index_o

    );

    localparam ID_LEN = 4'd10;

    localparam S_IDLE      = 3'b001;
    localparam S_SEND      = 3'b010;
    localparam S_WAIT_BUSY = 3'b011;
    localparam S_WAIT_IDLE = 3'b100;

    reg[2:0] state;
    reg start_seen;
    reg sent_once;

    function [7:0] sid_byte;
        input [3:0] index;
        begin
            case (index)
                4'd0: sid_byte = 8'h32; // 2
                4'd1: sid_byte = 8'h30; // 0
                4'd2: sid_byte = 8'h32; // 2
                4'd3: sid_byte = 8'h35; // 5
                4'd4: sid_byte = 8'h32; // 2
                4'd5: sid_byte = 8'h31; // 1
                4'd6: sid_byte = 8'h30; // 0
                4'd7: sid_byte = 8'h39; // 9
                4'd8: sid_byte = 8'h30; // 0
                4'd9: sid_byte = 8'h32; // 2 (PJY: 2025210902)
                default: sid_byte = 8'h00;
            endcase
        end
    endfunction

    always @ (posedge clk) begin
        if (rst == 1'b0) begin
            state <= S_IDLE;
            start_seen <= 1'b0;
            busy_o <= 1'b0;
            done_o <= 1'b0;
            tx_valid_o <= 1'b0;
            tx_data_o <= 8'h0;
            sid_index_o <= 4'h0;
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
                    sid_index_o <= 4'h0;
                    if (start_i == 1'b1 && start_seen == 1'b0) begin
                        start_seen <= 1'b1;
                        if (sent_once == 1'b1) begin
                            done_o <= 1'b1;
                        end else begin
                            busy_o <= 1'b1;
                            state <= S_SEND;
                        end
                    end
                end
                S_SEND: begin
                    busy_o <= 1'b1;
                    if (uart_tx_busy_i == 1'b0) begin
                        tx_valid_o <= 1'b1;
                        tx_data_o <= sid_byte(sid_index_o);
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
                        if (sid_index_o == (ID_LEN - 1'b1)) begin
                            busy_o <= 1'b0;
                            done_o <= 1'b1;
                            sent_once <= 1'b1;
                            state <= S_IDLE;
                        end else begin
                            sid_index_o <= sid_index_o + 1'b1;
                            state <= S_SEND;
                        end
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
// TASK4_SID_END
