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

// Chip-side SoC tile. External ROM/RAM and the FPGA-side bridge are
// deliberately outside this synthesis hierarchy.
module yc_tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg succ,

    input wire uart_debug_pin,

    output wire uart_tx_pin,
    input wire uart_rx_pin,
    output wire[2:0] PWM_o,
    input wire i2c_scl_i,
    input wire i2c_sda_i,
    output wire i2c_scl_drive_low_o,
    output wire i2c_sda_drive_low_o,

    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i,
    input wire[31:0] status_x26_i,
    input wire[31:0] status_x27_i,

    output wire pwm_we_o,
    output wire[31:0] pwm_addr_o,
    output wire[31:0] pwm_wdata_o,
    input wire[31:0] pwm_rdata_i,

    input wire debug_req_i,
    input wire debug_we_i,
    input wire[31:0] debug_addr_i,
    input wire[31:0] debug_wdata_i,
    output wire[31:0] debug_rdata_o,
    output wire debug_ack_o,

    output wire mem_req_o,
    output wire mem_we_o,
    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i,
    input wire mem_ack_i,
    input wire mem_hold_i

    );


    // Keep original status/debug signals internal in this board-level top.
    reg over;
    wire halted_ind;

    // master 0 interface
    wire[`YC_MemAddrBus] m0_addr_i;
    wire[`YC_MemBus] m0_data_i;
    wire[`YC_MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;

    // master 1 interface
    wire[`YC_MemAddrBus] m1_addr_i;
    wire[`YC_MemBus] m1_data_i;
    wire[`YC_MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // Master 3 interface: uart_debug downloader path.
    wire[`YC_MemAddrBus] m3_addr_i;
    wire[`YC_MemBus] m3_data_i;
    wire[`YC_MemBus] m3_data_o;
    wire m3_ack_o;
    wire m3_req_i;
    wire m3_we_i;

    // Slave 0 interface: bridge to ROM/RAM.
    wire[`YC_MemAddrBus] s0_addr_o;
    wire[`YC_MemBus] s0_data_o;
    wire[`YC_MemBus] s0_data_i;
    wire s0_req_o;
    wire s0_we_o;

    // Slave 3 interface: UART.
    wire[`YC_MemAddrBus] s3_addr_o;
    wire[`YC_MemBus] s3_data_o;
    wire[`YC_MemBus] s3_data_i;
    wire s3_we_o;

    // Slave 6 interface: PWM.
    wire[`YC_MemAddrBus] s6_addr_o;
    wire[`YC_MemBus] s6_data_o;
    wire[`YC_MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface
    wire[`YC_MemAddrBus] s7_addr_o;
    wire[`YC_MemBus] s7_data_o;
    wire[`YC_MemBus] s7_data_i;
    wire s7_we_o;

    assign PWM_o = 3'b000;
    assign pwm_we_o = s6_we_o;
    assign pwm_addr_o = s6_addr_o;
    assign pwm_wdata_o = s6_data_o;
    assign s6_data_i = pwm_rdata_i;
    assign m3_req_i = debug_req_i;
    assign m3_we_i = debug_we_i;
    assign m3_addr_i = debug_addr_i;
    assign m3_data_i = debug_wdata_i;
    assign debug_rdata_o = m3_data_o;
    assign debug_ack_o = m3_ack_o;

    // I2C pad bridge

    // rib
    wire rib_hold_flag_o;

    assign mem_req_o = s0_req_o;
    assign mem_we_o = s0_we_o;
    assign mem_addr_o = s0_addr_o;
    assign mem_wdata_o = s0_data_o;
    assign s0_data_i = mem_rdata_i;

    wire core_halt_req;

    // Halt the core while uart_debug owns the shared memory path.
    assign core_halt_req = uart_debug_pin;

    // Low level means the core is halted.
    assign halted_ind = ~core_halt_req;

    // Test firmware publishes completion status through x26/x27.
    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~status_x26_i[0];
            succ <= ~status_x27_i[0];
        end
    end

    // Core instance.
    yc_tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_ack_i(mem_ack_i),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),
        .rib_hold_flag_i(rib_hold_flag_o),
        .debug_halt_flag_i(core_halt_req),
        .regfile_we_o(regfile_we_o),
        .regfile_waddr_o(regfile_waddr_o),
        .regfile_wdata_o(regfile_wdata_o),
        .regfile_raddr1_o(regfile_raddr1_o),
        .regfile_raddr2_o(regfile_raddr2_o),
        .regfile_rdata1_i(regfile_rdata1_i),
        .regfile_rdata2_i(regfile_rdata2_i)
    );

    // UART peripheral.
    yc_uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // I2C peripheral.
    yc_i2c i2c_0(
        .clk(clk),
        .rst(rst),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .i2c_scl_i(i2c_scl_i),
        .i2c_sda_i(i2c_sda_i),
        .i2c_scl_drive_low_o(i2c_scl_drive_low_o),
        .i2c_sda_drive_low_o(i2c_sda_drive_low_o)
    );

    // Shared bus fabric.
    yc_rib u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`YC_ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`YC_RIB_REQ),
        .m1_we_i(`YC_WriteDisable),
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_ack_o(m3_ack_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_req_o(s0_req_o),
        .s0_we_o(s0_we_o),
        .s0_ack_i(mem_ack_i),
        .s0_hold_i(mem_hold_i),
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        .hold_flag_o(rib_hold_flag_o)
    );

endmodule
