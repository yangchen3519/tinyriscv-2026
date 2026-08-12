`include "yx_defines.vh"

module yx_tinyriscv_soc_top(
    input wire clk,
    input wire rst,
    output reg succ,
    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,
    output wire [2:0] PWM_o,
    input wire io_sda_i,
    output wire io_sda_drive_low_o,
    output wire io_scl,
    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i,
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

    wire[`YX_MemAddrBus] m0_addr_i;
    wire[`YX_MemBus] m0_data_i;
    wire[`YX_MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;

    wire[`YX_MemAddrBus] m1_addr_i;
    wire[`YX_MemBus] m1_data_o;
    wire m1_req_i;

    wire[`YX_MemAddrBus] m3_addr_i;
    wire[`YX_MemBus] m3_data_i;
    wire[`YX_MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    wire[`YX_MemAddrBus] s0_addr_o;
    wire[`YX_MemBus] s0_data_o;
    wire[`YX_MemBus] s0_data_i;
    wire s0_req_o;
    wire s0_we_o;

    wire[`YX_MemAddrBus] s3_addr_o;
    wire[`YX_MemBus] s3_data_o;
    wire[`YX_MemBus] s3_data_i;
    wire s3_we_o;

    wire[`YX_MemAddrBus] s6_addr_o;
    wire[`YX_MemBus] s6_data_o;
    wire[`YX_MemBus] s6_data_i;
    wire s6_we_o;

    wire[`YX_MemAddrBus] s7_addr_o;
    wire[`YX_MemBus] s7_data_o;
    wire[`YX_MemBus] s7_data_i;
    wire s7_we_o;

    wire rib_hold_flag_o;
    wire bridge_hold = mem_hold_i;
    assign mem_req_o = s0_req_o;
    assign mem_we_o = s0_we_o;
    assign mem_addr_o = s0_addr_o;
    assign mem_wdata_o = s0_data_o;
    assign s0_data_i = mem_rdata_i;
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
    assign debug_ack_o = debug_req_i &&
                         (((debug_addr_i[31:28] != 4'h0) && (debug_addr_i[31:28] != 4'h1)) ||
                          !bridge_hold);

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            succ <= 1'b1;
        end else begin
            succ <= ~status_x27_i[0];
        end
    end

    yx_tinyriscv_core u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_req_o(m1_req_i),
        .rib_pc_data_i(m1_data_o),
        .rib_hold_flag_i(rib_hold_flag_o),
        .bridge_hold_flag_i(bridge_hold),
        .uart_debug_i(uart_debug_pin),
        .int_i(`YX_INT_NONE),
        .regfile_we_o(regfile_we_o),
        .regfile_waddr_o(regfile_waddr_o),
        .regfile_wdata_o(regfile_wdata_o),
        .regfile_raddr1_o(regfile_raddr1_o),
        .regfile_raddr2_o(regfile_raddr2_o),
        .regfile_rdata1_i(regfile_rdata1_i),
        .regfile_rdata2_i(regfile_rdata2_i)
    );

    yx_uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    yx_i2c u_i2c(
        .clk(clk),
        .rst(rst),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .i2c_sda_i(io_sda_i),
        .i2c_sda_drive_low_o(io_sda_drive_low_o),
        .i2c_scl(io_scl)
    );

    yx_rib u_rib(
        .clk(clk),
        .rst(rst),
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`YX_ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(m1_req_i),
        .m1_we_i(`YX_WriteDisable),
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_req_o(s0_req_o),
        .s0_we_o(s0_we_o),
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
