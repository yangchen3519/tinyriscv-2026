 /*
 Copyright 2020 Blue Liang, liangkangnan@163.com

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

`include "pjy_defines.vh"

// TASK3_I2C_BEGIN: I2C master外设，用于读取LM75温度高8位
module pjy_i2c(

    input wire clk,
    input wire rst,

    input wire we_i,
    input wire[`PJY_MemAddrBus] addr_i,
    input wire[`PJY_MemBus] data_i,

    output reg[`PJY_MemBus] data_o,
    output reg io_scl,
    input wire io_sda_i,
    output wire io_sda_drive_low_o,

    // TASK5_RT_BEGIN: direct LM75 read path for rT instruction
    input wire rt_start_i,
    output wire rt_busy_o,
    output reg rt_done_o,
    output wire[7:0] rt_data_o
    // TASK5_RT_END

    );

    localparam I2C_ADDR = 8'h01;
    localparam I2C_WDATA = 8'h02;
    localparam I2C_RDATA = 8'h03;

    // 50MHz / (2 * 250) = 100kHz
    localparam I2C_DIV = 16'd250;

    localparam S_IDLE          = 5'd0;
    localparam S_START         = 5'd1;
    localparam S_SEND_LOW      = 5'd2;
    localparam S_SEND_HIGH     = 5'd3;
    localparam S_ACK_LOW       = 5'd4;
    localparam S_ACK_HIGH      = 5'd5;
    localparam S_RESTART_0     = 5'd6;
    localparam S_RESTART_1     = 5'd7;
    localparam S_RESTART_2     = 5'd8;
    localparam S_READ_LOW      = 5'd9;
    localparam S_READ_HIGH     = 5'd10;
    localparam S_READ_SAMPLE   = 5'd11;
    localparam S_MACK_LOW      = 5'd12;
    localparam S_MACK_HIGH     = 5'd13;
    localparam S_NACK_LOW      = 5'd14;
    localparam S_NACK_HIGH     = 5'd15;
    localparam S_STOP_0        = 5'd16;
    localparam S_STOP_1        = 5'd17;
    localparam S_STOP_2        = 5'd18;

    localparam NEXT_REG_PTR    = 2'd0;
    localparam NEXT_RESTART    = 2'd1;
    localparam NEXT_READ       = 2'd2;

    reg[4:0] state;
    reg[15:0] div_cnt;
    reg[7:0] dev_addr;
    reg[7:0] reg_ptr;
    reg[7:0] tx_data;
    reg[7:0] rx_data;
    reg[7:0] rx_low_data;
    reg[2:0] bit_cnt;
    reg read_byte_index;
    reg[1:0] next_after_ack;
    reg busy;
    reg start_req;
    reg sda_low;
    // TASK5_RT_BEGIN
    reg rt_start_seen;
    // TASK5_RT_END

    wire tick = (div_cnt == I2C_DIV - 1'b1);
    wire[7:0] reg_addr = addr_i[23:16];
    wire sda_in = io_sda_i;
    assign io_sda_drive_low_o = sda_low;
    // TASK5_RT_BEGIN
    assign rt_busy_o = busy;
    assign rt_data_o = rx_data;
    // TASK5_RT_END

    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            div_cnt <= 16'h0;
        end else if (busy == `PJY_True) begin
            if (tick) begin
                div_cnt <= 16'h0;
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end else begin
            div_cnt <= 16'h0;
        end
    end

    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            dev_addr <= 8'h48;
            reg_ptr <= 8'h0;
            tx_data <= 8'h0;
            rx_data <= 8'h0;
            rx_low_data <= 8'h0;
            start_req <= `PJY_False;
            // TASK5_RT_BEGIN
            rt_start_seen <= `PJY_False;
            // TASK5_RT_END
        end else begin
            start_req <= `PJY_False;
            // TASK5_RT_BEGIN
            if (rt_start_i == `PJY_False) begin
                rt_start_seen <= `PJY_False;
            end
            if (rt_start_i == `PJY_True && rt_start_seen == `PJY_False && busy == `PJY_False) begin
                rt_start_seen <= `PJY_True;
                dev_addr <= 8'h48;
                reg_ptr <= 8'h00;
                start_req <= `PJY_True;
            end
            // TASK5_RT_END
            if (we_i == `PJY_WriteEnable) begin
                case (reg_addr)
                    I2C_ADDR: begin
                        dev_addr <= data_i[7:0];
                    end
                    I2C_WDATA: begin
                        reg_ptr <= data_i[7:0];
                        start_req <= `PJY_True;
                    end
                    default: begin

                    end
                endcase
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            state <= S_IDLE;
            io_scl <= 1'b1;
            sda_low <= 1'b0;
            bit_cnt <= 3'd7;
            read_byte_index <= 1'b0;
            next_after_ack <= NEXT_REG_PTR;
            busy <= `PJY_False;
            // TASK5_RT_BEGIN
            rt_done_o <= `PJY_False;
            // TASK5_RT_END
        end else begin
            // TASK5_RT_BEGIN
            rt_done_o <= `PJY_False;
            // TASK5_RT_END
            case (state)
                S_IDLE: begin
                    io_scl <= 1'b1;
                    sda_low <= 1'b0;
                    busy <= `PJY_False;
                    if (start_req == `PJY_True) begin
                        busy <= `PJY_True;
                        state <= S_START;
                    end
                end
                S_START: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b1;
                        tx_data <= {dev_addr[6:0], 1'b0};
                        bit_cnt <= 3'd7;
                        next_after_ack <= NEXT_REG_PTR;
                        state <= S_SEND_LOW;
                    end
                end
                S_SEND_LOW: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= ~tx_data[bit_cnt];
                        state <= S_SEND_HIGH;
                    end
                end
                S_SEND_HIGH: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        if (bit_cnt == 3'd0) begin
                            state <= S_ACK_LOW;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state <= S_SEND_LOW;
                        end
                    end
                end
                S_ACK_LOW: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b0;
                        state <= S_ACK_HIGH;
                    end
                end
                S_ACK_HIGH: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        case (next_after_ack)
                            NEXT_REG_PTR: begin
                                tx_data <= reg_ptr;
                                bit_cnt <= 3'd7;
                                next_after_ack <= NEXT_RESTART;
                                state <= S_SEND_LOW;
                            end
                            NEXT_RESTART: begin
                                state <= S_RESTART_0;
                            end
                            default: begin
                                bit_cnt <= 3'd7;
                                rx_data <= 8'h0;
                                rx_low_data <= 8'h0;
                                read_byte_index <= 1'b0;
                                state <= S_READ_LOW;
                            end
                        endcase
                    end
                end
                S_RESTART_0: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b0;
                        state <= S_RESTART_1;
                    end
                end
                S_RESTART_1: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b0;
                        state <= S_RESTART_2;
                    end
                end
                S_RESTART_2: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b1;
                        tx_data <= {dev_addr[6:0], 1'b1};
                        bit_cnt <= 3'd7;
                        next_after_ack <= NEXT_READ;
                        state <= S_SEND_LOW;
                    end
                end
                S_READ_LOW: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b0;
                        state <= S_READ_HIGH;
                    end
                end
                S_READ_HIGH: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        state <= S_READ_SAMPLE;
                    end
                end
                S_READ_SAMPLE: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        if (read_byte_index == 1'b0) begin
                            rx_data[bit_cnt] <= sda_in;
                        end else begin
                            rx_low_data[bit_cnt] <= sda_in;
                        end
                        if (bit_cnt == 3'd0) begin
                            if (read_byte_index == 1'b0) begin
                                state <= S_MACK_LOW;
                            end else begin
                                state <= S_NACK_LOW;
                            end
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                            state <= S_READ_LOW;
                        end
                    end
                end
                S_MACK_LOW: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b1;
                        state <= S_MACK_HIGH;
                    end
                end
                S_MACK_HIGH: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b1;
                        read_byte_index <= 1'b1;
                        bit_cnt <= 3'd7;
                        state <= S_READ_LOW;
                    end
                end
                S_NACK_LOW: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b0;
                        state <= S_NACK_HIGH;
                    end
                end
                S_NACK_HIGH: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b0;
                        state <= S_STOP_0;
                    end
                end
                S_STOP_0: begin
                    if (tick) begin
                        io_scl <= 1'b0;
                        sda_low <= 1'b1;
                        state <= S_STOP_1;
                    end
                end
                S_STOP_1: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b1;
                        state <= S_STOP_2;
                    end
                end
                S_STOP_2: begin
                    if (tick) begin
                        io_scl <= 1'b1;
                        sda_low <= 1'b0;
                        // TASK5_RT_BEGIN
                        rt_done_o <= 1'b1;
                        // TASK5_RT_END
                        state <= S_IDLE;
                    end
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    always @ (*) begin
        if (rst == `PJY_RstEnable) begin
            data_o = `PJY_ZeroWord;
        end else begin
            case (reg_addr)
                I2C_ADDR: begin
                    data_o = {24'h0, dev_addr};
                end
                I2C_WDATA: begin
                    data_o = {24'h0, reg_ptr};
                end
                I2C_RDATA: begin
                    data_o = {24'h0, rx_data};
                end
                default: begin
                    data_o = `PJY_ZeroWord;
                end
            endcase
        end
    end

endmodule
// TASK3_I2C_END
