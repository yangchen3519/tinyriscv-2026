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

`include "yc_defines.vh"

// Shared on-chip bus interconnect.
module yc_rib(

    input wire clk,
    input wire rst,

    // Master 0 interface: load/store path from the core.
    input wire[`YC_MemAddrBus] m0_addr_i,
    input wire[`YC_MemBus] m0_data_i,
    output reg[`YC_MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,

    // Master 1 interface: instruction fetch path from the core.
    input wire[`YC_MemAddrBus] m1_addr_i,
    input wire[`YC_MemBus] m1_data_i,
    output reg[`YC_MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    // Master 3 interface: uart_debug downloader path.
    input wire[`YC_MemAddrBus] m3_addr_i,
    input wire[`YC_MemBus] m3_data_i,
    output reg[`YC_MemBus] m3_data_o,
    output reg m3_ack_o,
    input wire m3_req_i,
    input wire m3_we_i,

    // Slave 0 interface: bridge to ROM/RAM space.
    output reg[`YC_MemAddrBus] s0_addr_o,
    output reg[`YC_MemBus] s0_data_o,
    input wire[`YC_MemBus] s0_data_i,
    output reg s0_req_o,
    output reg s0_we_o,
    input wire s0_ack_i,
    input wire s0_hold_i,

    // Slave 3 interface: UART.
    output reg[`YC_MemAddrBus] s3_addr_o,
    output reg[`YC_MemBus] s3_data_o,
    input wire[`YC_MemBus] s3_data_i,
    output reg s3_we_o,

    // Slave 6 interface: PWM.
    output reg[`YC_MemAddrBus] s6_addr_o,
    output reg[`YC_MemBus] s6_data_o,
    input wire[`YC_MemBus] s6_data_i,
    output reg s6_we_o,

    // Slave 7 interface: I2C.
    output reg[`YC_MemAddrBus] s7_addr_o,
    output reg[`YC_MemBus] s7_data_o,
    input wire[`YC_MemBus] s7_data_i,
    output reg s7_we_o,

    output reg hold_flag_o

    );

    parameter [3:0] slave_0 = 4'b0000;
    parameter [3:0] slave_1 = 4'b0001;
    parameter [3:0] slave_3 = 4'b0011;
    parameter [3:0] slave_6 = 4'b0110;
    parameter [3:0] slave_7 = 4'b0111;

    parameter [1:0] grant0 = 2'h0;
    parameter [1:0] grant1 = 2'h1;
    parameter [1:0] grant3 = 2'h2;

    wire[2:0] req;
    reg[1:0] grant;

    // Fixed priority: master3 > master0 > master1.
    assign req = {m3_req_i, m1_req_i, m0_req_i};

    always @ (*) begin
        if (req[2]) begin
            grant = grant3;
        end else if (req[0]) begin
            grant = grant0;
        end else begin
            grant = grant1;
        end
    end

    // Propagate hold requests from the external memory bridge.
    always @ (*) begin
        if (s0_hold_i == `YC_HoldEnable) begin
            hold_flag_o = `YC_HoldEnable;
        end else begin
            hold_flag_o = `YC_HoldDisable;
        end
    end

    // Default everything idle, then route the currently granted master.
    always @ (*) begin
        m0_data_o = `YC_ZeroWord;
        m1_data_o = `YC_INST_NOP;
        m3_data_o = `YC_ZeroWord;
        m3_ack_o = `YC_RIB_NACK;

        s0_addr_o = `YC_ZeroWord;
        s3_addr_o = `YC_ZeroWord;
        s6_addr_o = `YC_ZeroWord;
        s7_addr_o = `YC_ZeroWord;
        s0_data_o = `YC_ZeroWord;
        s3_data_o = `YC_ZeroWord;
        s6_data_o = `YC_ZeroWord;
        s7_data_o = `YC_ZeroWord;
        s0_req_o = `YC_RIB_NREQ;
        s0_we_o = `YC_WriteDisable;
        s3_we_o = `YC_WriteDisable;
        s6_we_o = `YC_WriteDisable;
        s7_we_o = `YC_WriteDisable;

        case (grant)
            grant0: begin
                case (m0_addr_i[31:28])
                    slave_0, slave_1: begin
                        s0_req_o = m0_req_i;
                        s0_we_o = m0_we_i;
                        s0_addr_o = m0_addr_i;
                        s0_data_o = m0_data_i;
                        m0_data_o = s0_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i;
                        s3_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s3_data_o = m0_data_i;
                        m0_data_o = s3_data_i;
                    end
                    slave_6: begin
                        s6_we_o = m0_we_i;
                        s6_addr_o = m0_addr_i;
                        s6_data_o = m0_data_i;
                        m0_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m0_we_i;
                        s7_addr_o = m0_addr_i;
                        s7_data_o = m0_data_i;
                        m0_data_o = s7_data_i;
                    end
                    default: begin
                    end
                endcase
            end
            grant1: begin
                case (m1_addr_i[31:28])
                    slave_0, slave_1: begin
                        s0_req_o = m1_req_i;
                        s0_we_o = m1_we_i;
                        s0_addr_o = m1_addr_i;
                        s0_data_o = m1_data_i;
                        m1_data_o = s0_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m1_we_i;
                        s3_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s3_data_o = m1_data_i;
                        m1_data_o = s3_data_i;
                    end
                    slave_6: begin
                        s6_we_o = m1_we_i;
                        s6_addr_o = m1_addr_i;
                        s6_data_o = m1_data_i;
                        m1_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m1_we_i;
                        s7_addr_o = m1_addr_i;
                        s7_data_o = m1_data_i;
                        m1_data_o = s7_data_i;
                    end
                    default: begin
                    end
                endcase
            end
            grant3: begin
                case (m3_addr_i[31:28])
                    slave_0, slave_1: begin
                        s0_req_o = m3_req_i;
                        s0_we_o = m3_we_i;
                        s0_addr_o = m3_addr_i;
                        s0_data_o = m3_data_i;
                        m3_data_o = s0_data_i;
                        m3_ack_o = s0_ack_i;
                    end
                    slave_3: begin
                        s3_we_o = m3_we_i;
                        s3_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s3_data_o = m3_data_i;
                        m3_data_o = s3_data_i;
                        m3_ack_o = m3_req_i;
                    end
                    slave_6: begin
                        s6_we_o = m3_we_i;
                        s6_addr_o = m3_addr_i;
                        s6_data_o = m3_data_i;
                        m3_data_o = s6_data_i;
                        m3_ack_o = m3_req_i;
                    end
                    slave_7: begin
                        s7_we_o = m3_we_i;
                        s7_addr_o = m3_addr_i;
                        s7_data_o = m3_data_i;
                        m3_data_o = s7_data_i;
                        m3_ack_o = m3_req_i;
                    end
                    default: begin
                    end
                endcase
            end
            default: begin
            end
        endcase
    end

endmodule
