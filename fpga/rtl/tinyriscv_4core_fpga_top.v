`timescale 1ns/1ps
`include "yc_defines.vh"

// Synthesizable FPGA wrapper: four cores share one YC chip bridge (inside
// tinyriscv_4core_top), one YC FPGA bridge, one YC ROM and one YC RAM.
module tinyriscv_4core_fpga_top(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] chip_sel,
    input  wire       uart_debug_en,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [3:0] PWM_o,
    inout  wire       i2c_scl,
    inout  wire       i2c_sda,
    output wire       over,
    output wire       succ
);
    wire [7:0] chip_tx_data;
    wire chip_tx_valid;
    wire [7:0] chip_rx_data;
    wire fpga_tx_valid_unused;

    wire rom_we;
    wire [`YC_RomAddrBus] rom_addr;
    wire [`YC_MemBus] rom_wdata;
    wire [`YC_MemBus] rom_rdata;
    wire ram_we;
    wire [`YC_RamAddrBus] ram_addr;
    wire [`YC_MemBus] ram_wdata;
    wire [`YC_MemBus] ram_rdata;

    tinyriscv_4core_top u_chip(
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .uart_debug_en(uart_debug_en), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .ext_mem_data_i(chip_rx_data), .ext_mem_data_o(chip_tx_data),
        .ext_mem_tx_valid_o(chip_tx_valid), .ext_mem_tx_ready_i(1'b1),
        .ext_mem_rx_valid_i(1'b0), .ext_mem_rx_ready_o(),
        .over(over), .succ(succ)
    );

    yc_bridge_FPGA u_bridge_fpga(
        .clk(clk), .rst(rst),
        .rx_valid_i(chip_tx_valid), .rx_data_i(chip_tx_data),
        .tx_data_o(chip_rx_data), .tx_valid_o(fpga_tx_valid_unused),
        .rom_we_o(rom_we), .rom_addr_o(rom_addr), .rom_data_o(rom_wdata),
        .rom_data_i(rom_rdata), .ram_we_o(ram_we), .ram_addr_o(ram_addr),
        .ram_data_o(ram_wdata), .ram_data_i(ram_rdata)
    );

    yc_rom u_rom(
        .clk(clk), .rst(rst), .we_i(rom_we), .addr_i(rom_addr),
        .data_i(rom_wdata), .data_o(rom_rdata)
    );

    yc_ram u_ram(
        .clk(clk), .rst(rst), .we_i(ram_we), .addr_i(ram_addr),
        .data_i(ram_wdata), .data_o(ram_rdata)
    );
endmodule
