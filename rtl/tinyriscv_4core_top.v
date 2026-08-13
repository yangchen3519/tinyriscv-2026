`timescale 1ns/1ps

// Four-core course chip.  rst is active low.  chip_sel is sampled only while
// reset is asserted and remains frozen for the complete run that follows.
module tinyriscv_4core_top(
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] chip_sel,
    input  wire       uart_debug_en,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [3:0] PWM_o,
    inout  wire       i2c_scl,
    inout  wire       i2c_sda,
    // Explicit open-drain controls are exported for the ASIC PAD wrapper.
    // They mirror the internal tri-state decisions and are harmless when the
    // logic top is used directly in RTL/FPGA simulation.
    output wire       i2c_scl_drive_low_o,
    output wire       i2c_sda_drive_low_o,
    input  wire [7:0] ext_mem_data_i,
    output wire [7:0] ext_mem_data_o,
    output wire       ext_mem_tx_valid_o,
    input  wire       ext_mem_tx_ready_i,
    input  wire       ext_mem_rx_valid_i,
    output wire       ext_mem_rx_ready_o,
    output wire       over,
    output wire       succ
);

    localparam SEL_YC = 2'b00;
    localparam SEL_YX = 2'b01;
    localparam SEL_PJY = 2'b10;
    localparam SEL_KHOREE = 2'b11;

    reg [1:0] selected;
    always @(posedge clk) begin
        if (!rst)
            selected <= chip_sel;
    end

    wire sel_yc = (selected == SEL_YC);
    wire sel_yx = (selected == SEL_YX);
    wire sel_pjy = (selected == SEL_PJY);
    wire sel_kh = (selected == SEL_KHOREE);
    wire valid_sel = sel_yc | sel_yx | sel_pjy | sel_kh;

    // Active-low reset keeps every unselected core continuously reset.
    wire rst_yc = rst & sel_yc;
    wire rst_yx = rst & sel_yx;
    wire rst_pjy = rst & sel_pjy;
    wire rst_kh = rst & sel_kh;

    wire yc_rf_we, yx_rf_we, pjy_rf_we, kh_rf_we;
    wire [4:0] yc_rf_wa, yx_rf_wa, pjy_rf_wa, kh_rf_wa;
    wire [31:0] yc_rf_wd, yx_rf_wd, pjy_rf_wd, kh_rf_wd;
    wire [4:0] yc_rf_ra1, yx_rf_ra1, pjy_rf_ra1, kh_rf_ra1;
    wire [4:0] yc_rf_ra2, yx_rf_ra2, pjy_rf_ra2, kh_rf_ra2;
    wire [31:0] rf_rd1, rf_rd2, status_x26, status_x27;

    wire rf_we = valid_sel & ((sel_yc & yc_rf_we) | (sel_yx & yx_rf_we) |
                              (sel_pjy & pjy_rf_we) | (sel_kh & kh_rf_we));
    wire [4:0] rf_wa = sel_yc ? yc_rf_wa : sel_yx ? yx_rf_wa :
                         sel_pjy ? pjy_rf_wa : sel_kh ? kh_rf_wa : 5'b0;
    wire [31:0] rf_wd = sel_yc ? yc_rf_wd : sel_yx ? yx_rf_wd :
                            sel_pjy ? pjy_rf_wd : sel_kh ? kh_rf_wd : 32'b0;
    wire [4:0] rf_ra1 = sel_yc ? yc_rf_ra1 : sel_yx ? yx_rf_ra1 :
                          sel_pjy ? pjy_rf_ra1 : sel_kh ? kh_rf_ra1 : 5'b0;
    wire [4:0] rf_ra2 = sel_yc ? yc_rf_ra2 : sel_yx ? yx_rf_ra2 :
                          sel_pjy ? pjy_rf_ra2 : sel_kh ? kh_rf_ra2 : 5'b0;

    yc_regs u_shared_regs(
        .clk(clk), .rst(rst), .we_i(rf_we), .waddr_i(rf_wa), .wdata_i(rf_wd),
        .raddr1_i(rf_ra1), .rdata1_o(rf_rd1),
        .raddr2_i(rf_ra2), .rdata2_o(rf_rd2),
        .status_x26_o(status_x26), .status_x27_o(status_x27)
    );

    wire yc_pwm_we, yx_pwm_we, pjy_pwm_we, kh_pwm_we;
    wire [31:0] yc_pwm_addr, yx_pwm_addr, pjy_pwm_addr, kh_pwm_addr;
    wire [31:0] yc_pwm_wdata, yx_pwm_wdata, pjy_pwm_wdata, kh_pwm_wdata;
    wire [31:0] pwm_rdata;
    wire pwm_we = valid_sel & ((sel_yc & yc_pwm_we) | (sel_yx & yx_pwm_we) |
                               (sel_pjy & pjy_pwm_we) | (sel_kh & kh_pwm_we));
    // YC keeps the original 0x6xxx_xxxx address on its slave port.  The
    // YX/PJY/Khoree RIB implementations strip the decoded high nibble before
    // presenting slave-6 addresses, so restore it at the shared-resource
    // boundary to give the single YC PWM a uniform address map.
    wire [31:0] pwm_addr = sel_yc ? yc_pwm_addr :
                             sel_yx ? {4'h6, yx_pwm_addr[27:0]} :
                             sel_pjy ? {4'h6, pjy_pwm_addr[27:0]} :
                             sel_kh ? {4'h6, kh_pwm_addr[27:0]} : 32'b0;
    wire [31:0] pwm_wdata = sel_yc ? yc_pwm_wdata : sel_yx ? yx_pwm_wdata :
                               sel_pjy ? pjy_pwm_wdata : sel_kh ? kh_pwm_wdata : 32'b0;

    yc_pwm u_shared_pwm(
        .clk(clk), .rst(rst), .we_i(pwm_we), .addr_i(pwm_addr),
        .data_i(pwm_wdata), .data_o(pwm_rdata), .PWM_o(PWM_o)
    );

    wire dbg_req, dbg_we;
    wire [31:0] dbg_addr, dbg_wdata;
    wire [31:0] yc_dbg_rdata, yx_dbg_rdata, pjy_dbg_rdata, kh_dbg_rdata;
    wire yc_dbg_ack, yx_dbg_ack, pjy_dbg_ack, kh_dbg_ack;
    wire [31:0] dbg_rdata = sel_yc ? yc_dbg_rdata : sel_yx ? yx_dbg_rdata :
                               sel_pjy ? pjy_dbg_rdata : sel_kh ? kh_dbg_rdata : 32'b0;
    wire dbg_ack = valid_sel & (sel_yc ? yc_dbg_ack : sel_yx ? yx_dbg_ack :
                                sel_pjy ? pjy_dbg_ack : kh_dbg_ack);

    yc_uart_debug u_shared_uart_debug(
        .clk(clk), .rst(rst), .debug_en_i(uart_debug_en & valid_sel),
        .req_o(dbg_req), .mem_we_o(dbg_we), .mem_addr_o(dbg_addr),
        .mem_wdata_o(dbg_wdata), .mem_ack_i(dbg_ack), .mem_rdata_i(dbg_rdata)
    );

    // Each core keeps its original chip-side bridge protocol.  Only the
    // selected bridge is visible on the shared physical 8-bit pad group.
    wire yc_mem_req, yx_mem_req, pjy_mem_req, kh_mem_req;
    wire yc_mem_we, yx_mem_we, pjy_mem_we, kh_mem_we;
    wire [31:0] yc_mem_addr, yx_mem_addr, pjy_mem_addr, kh_mem_addr;
    wire [31:0] yc_mem_wdata, yx_mem_wdata, pjy_mem_wdata, kh_mem_wdata;
    wire [31:0] yc_mem_rdata, yx_mem_rdata, pjy_rom_rdata, pjy_ram_rdata;
    wire [31:0] kh_rom_rdata, kh_ram_rdata;
    wire yc_mem_ack, yc_mem_hold, yx_mem_hold, pjy_mem_hold;
    wire kh_mem_busy, kh_mem_done, kh_rom_done, kh_ram_done;
    wire [7:0] yc_mem_tx_data, yx_mem_tx_data, pjy_mem_tx_data, kh_mem_tx_data;
    wire yc_mem_tx_valid, kh_mem_tx_valid, kh_mem_tx_ready, kh_mem_rx_ready;
    wire pjy_rom_req = pjy_mem_req && (pjy_mem_addr[31:28] == 4'h0);
    wire pjy_ram_req = pjy_mem_req && (pjy_mem_addr[31:28] == 4'h1);
    wire kh_rom_req = kh_mem_req && (kh_mem_addr[31:28] == 4'h0);
    wire kh_ram_req = kh_mem_req && (kh_mem_addr[31:28] == 4'h1);
    wire [31:0] pjy_mem_rdata = pjy_ram_req ? pjy_ram_rdata : pjy_rom_rdata;
    wire [31:0] kh_mem_rdata = kh_ram_done ? kh_ram_rdata :
                               kh_rom_done ? kh_rom_rdata :
                               kh_ram_req  ? kh_ram_rdata : kh_rom_rdata;

    yc_bridge_core u_yc_mem_bridge(
        .clk(clk), .rst(rst_yc), .req_i(yc_mem_req), .we_i(yc_mem_we),
        .addr_i(yc_mem_addr), .data_i(yc_mem_wdata), .data_o(yc_mem_rdata),
        .ack_o(yc_mem_ack), .hold_flag_o(yc_mem_hold),
        .tx_data_o(yc_mem_tx_data), .tx_valid_o(yc_mem_tx_valid),
        .rx_data_i(ext_mem_data_i)
    );

    yx_bridge u_yx_mem_bridge(
        .clk(clk), .rst(rst_yx), .req_i(yx_mem_req), .we_i(yx_mem_we),
        .addr_i(yx_mem_addr), .data_i(yx_mem_wdata), .data_o(yx_mem_rdata),
        .fpga_i(ext_mem_data_i), .fpga_o(yx_mem_tx_data),
        .bridge_hold(yx_mem_hold)
    );

    pjy_mem_bridge_chip u_pjy_mem_bridge(
        .clk(clk), .rst(rst_pjy),
        .s0_req_i(pjy_rom_req), .s0_we_i(pjy_mem_we),
        .s0_addr_i(pjy_mem_addr), .s0_data_i(pjy_mem_wdata),
        .s0_data_o(pjy_rom_rdata),
        .s1_req_i(pjy_ram_req), .s1_we_i(pjy_mem_we),
        .s1_addr_i(pjy_mem_addr), .s1_data_i(pjy_mem_wdata),
        .s1_data_o(pjy_ram_rdata), .hold_flag_o(pjy_mem_hold),
        .ext_mem_data_o(pjy_mem_tx_data), .ext_mem_data_i(ext_mem_data_i)
    );

    khoree_mem_bridge_chip u_kh_mem_bridge(
        .clk(clk), .rst(rst_kh),
        .rom_req_i(kh_rom_req), .rom_addr_i(kh_mem_addr),
        .rom_we_i(kh_mem_we), .rom_wdata_i(kh_mem_wdata),
        .rom_rdata_o(kh_rom_rdata),
        .ram_req_i(kh_ram_req), .ram_addr_i(kh_mem_addr),
        .ram_we_i(kh_mem_we), .ram_wdata_i(kh_mem_wdata),
        .ram_rdata_o(kh_ram_rdata), .busy_o(kh_mem_busy),
        .done_o(kh_mem_done), .rom_done_o(kh_rom_done),
        .ram_done_o(kh_ram_done), .c2f_data_o(kh_mem_tx_data),
        .c2f_valid_o(kh_mem_tx_valid), .c2f_ready_i(ext_mem_tx_ready_i),
        .f2c_data_i(ext_mem_data_i), .f2c_valid_i(ext_mem_rx_valid_i),
        .f2c_ready_o(kh_mem_rx_ready), .saw_rom_write_o(),
        .saw_rom_read_o(), .saw_ram_write_o(), .saw_ram_read_o(),
        .last_cmd_o(), .last_addr_o()
    );

    wire yc_uart_tx, yx_uart_tx, pjy_uart_tx, kh_uart_tx;
    wire yc_succ, yx_succ, pjy_succ, pjy_over, kh_succ;
    wire yc_scl_low, yc_sda_low;
    wire yx_scl, yx_sda_low, pjy_scl, pjy_sda_low, kh_scl, kh_sda_low;
    wire [2:0] unused_pwm_yc, unused_pwm_yx, unused_pwm_kh;
    wire [3:0] unused_pwm_pjy;

    // One physical open-drain I2C pad pair, driven only by the selected tile.
    assign i2c_scl_drive_low_o = (sel_yc && yc_scl_low) ||
                                 (sel_yx && !yx_scl) ||
                                 (sel_pjy && !pjy_scl) ||
                                 (sel_kh && !kh_scl);
    assign i2c_sda_drive_low_o = (sel_yc && yc_sda_low) ||
                                 (sel_yx && yx_sda_low) ||
                                 (sel_pjy && pjy_sda_low) ||
                                 (sel_kh && kh_sda_low);
    assign i2c_scl = i2c_scl_drive_low_o ? 1'b0 : 1'bz;
    assign i2c_sda = i2c_sda_drive_low_o ? 1'b0 : 1'bz;

    assign uart_tx = sel_yc ? yc_uart_tx : sel_yx ? yx_uart_tx :
                     sel_pjy ? pjy_uart_tx : sel_kh ? kh_uart_tx : 1'b1;
    assign ext_mem_data_o = sel_yc ? yc_mem_tx_data :
                            sel_yx ? yx_mem_tx_data :
                            sel_pjy ? pjy_mem_tx_data :
                            sel_kh ? kh_mem_tx_data : 8'b0;
    assign ext_mem_tx_valid_o = sel_yc ? yc_mem_tx_valid :
                                sel_yx ? 1'b1 : sel_pjy ? 1'b1 :
                                sel_kh ? kh_mem_tx_valid : 1'b0;
    assign ext_mem_rx_ready_o = sel_kh & kh_mem_rx_ready;
    assign over = valid_sel ? ~status_x26[0] : 1'b1;
    assign succ = valid_sel ? ~status_x27[0] : 1'b1;

    yc_tinyriscv_soc_top u_yc(
        .clk(clk), .rst(rst_yc), .succ(yc_succ), .uart_debug_pin(uart_debug_en & sel_yc),
        .uart_tx_pin(yc_uart_tx), .uart_rx_pin(uart_rx), .PWM_o(unused_pwm_yc),
        .i2c_scl_i(i2c_scl), .i2c_sda_i(i2c_sda),
        .i2c_scl_drive_low_o(yc_scl_low), .i2c_sda_drive_low_o(yc_sda_low),
        .regfile_we_o(yc_rf_we), .regfile_waddr_o(yc_rf_wa), .regfile_wdata_o(yc_rf_wd),
        .regfile_raddr1_o(yc_rf_ra1), .regfile_raddr2_o(yc_rf_ra2),
        .regfile_rdata1_i(rf_rd1), .regfile_rdata2_i(rf_rd2),
        .status_x26_i(status_x26), .status_x27_i(status_x27),
        .pwm_we_o(yc_pwm_we), .pwm_addr_o(yc_pwm_addr), .pwm_wdata_o(yc_pwm_wdata), .pwm_rdata_i(pwm_rdata),
        .debug_req_i(dbg_req & sel_yc), .debug_we_i(dbg_we), .debug_addr_i(dbg_addr), .debug_wdata_i(dbg_wdata),
        .debug_rdata_o(yc_dbg_rdata), .debug_ack_o(yc_dbg_ack),
        .mem_req_o(yc_mem_req), .mem_we_o(yc_mem_we), .mem_addr_o(yc_mem_addr),
        .mem_wdata_o(yc_mem_wdata), .mem_rdata_i(yc_mem_rdata),
        .mem_ack_i(yc_mem_ack), .mem_hold_i(yc_mem_hold)
    );

    yx_tinyriscv_soc_top u_yx(
        .clk(clk), .rst(rst_yx), .succ(yx_succ), .uart_debug_pin(uart_debug_en & sel_yx),
        .uart_tx_pin(yx_uart_tx), .uart_rx_pin(uart_rx), .PWM_o(unused_pwm_yx),
        .io_sda_i(i2c_sda), .io_sda_drive_low_o(yx_sda_low), .io_scl(yx_scl),
        .regfile_we_o(yx_rf_we), .regfile_waddr_o(yx_rf_wa), .regfile_wdata_o(yx_rf_wd),
        .regfile_raddr1_o(yx_rf_ra1), .regfile_raddr2_o(yx_rf_ra2), .regfile_rdata1_i(rf_rd1), .regfile_rdata2_i(rf_rd2),
        .status_x27_i(status_x27), .pwm_we_o(yx_pwm_we), .pwm_addr_o(yx_pwm_addr),
        .pwm_wdata_o(yx_pwm_wdata), .pwm_rdata_i(pwm_rdata),
        .debug_req_i(dbg_req & sel_yx), .debug_we_i(dbg_we), .debug_addr_i(dbg_addr), .debug_wdata_i(dbg_wdata),
        .debug_rdata_o(yx_dbg_rdata), .debug_ack_o(yx_dbg_ack),
        .mem_req_o(yx_mem_req), .mem_we_o(yx_mem_we), .mem_addr_o(yx_mem_addr),
        .mem_wdata_o(yx_mem_wdata), .mem_rdata_i(yx_mem_rdata),
        .mem_ack_i(~yx_mem_hold), .mem_hold_i(yx_mem_hold)
    );

    pjy_tinyriscv_soc_top u_pjy(
        .clk(clk), .rst(rst_pjy), .over(pjy_over), .succ(pjy_succ),
        .uart_debug_pin(uart_debug_en & sel_pjy), .uart_tx_pin(pjy_uart_tx), .uart_rx_pin(uart_rx),
        .PWM_o(unused_pwm_pjy),
        .io_scl(pjy_scl), .io_sda_i(i2c_sda), .io_sda_drive_low_o(pjy_sda_low),
        .regfile_we_o(pjy_rf_we), .regfile_waddr_o(pjy_rf_wa), .regfile_wdata_o(pjy_rf_wd),
        .regfile_raddr1_o(pjy_rf_ra1), .regfile_raddr2_o(pjy_rf_ra2), .regfile_rdata1_i(rf_rd1), .regfile_rdata2_i(rf_rd2),
        .status_x26_i(status_x26), .status_x27_i(status_x27),
        .pwm_we_o(pjy_pwm_we), .pwm_addr_o(pjy_pwm_addr), .pwm_wdata_o(pjy_pwm_wdata), .pwm_rdata_i(pwm_rdata),
        .debug_req_i(dbg_req & sel_pjy), .debug_we_i(dbg_we), .debug_addr_i(dbg_addr), .debug_wdata_i(dbg_wdata),
        .debug_rdata_o(pjy_dbg_rdata), .debug_ack_o(pjy_dbg_ack),
        .mem_req_o(pjy_mem_req), .mem_we_o(pjy_mem_we), .mem_addr_o(pjy_mem_addr),
        .mem_wdata_o(pjy_mem_wdata), .mem_rdata_i(pjy_mem_rdata),
        .mem_ack_i(~pjy_mem_hold), .mem_hold_i(pjy_mem_hold)
    );

    khoree_tinyriscv_soc_top u_kh(
        .clk(clk), .rst(rst_kh), .succ(kh_succ), .uart_debug_pin(uart_debug_en & sel_kh),
        .uart_tx_pin(kh_uart_tx), .uart_rx_pin(uart_rx), .PWM_o(unused_pwm_kh),
        .io_scl(kh_scl), .io_sda_i(i2c_sda), .io_sda_drive_low_o(kh_sda_low),
        .regfile_we_o(kh_rf_we), .regfile_waddr_o(kh_rf_wa), .regfile_wdata_o(kh_rf_wd),
        .regfile_raddr1_o(kh_rf_ra1), .regfile_raddr2_o(kh_rf_ra2), .regfile_rdata1_i(rf_rd1), .regfile_rdata2_i(rf_rd2),
        .status_x26_i(status_x26), .status_x27_i(status_x27),
        .pwm_we_o(kh_pwm_we), .pwm_addr_o(kh_pwm_addr), .pwm_wdata_o(kh_pwm_wdata), .pwm_rdata_i(pwm_rdata),
        .debug_req_i(dbg_req & sel_kh), .debug_we_i(dbg_we), .debug_addr_i(dbg_addr), .debug_wdata_i(dbg_wdata),
        .debug_rdata_o(kh_dbg_rdata), .debug_ack_o(kh_dbg_ack),
        .mem_req_o(kh_mem_req), .mem_we_o(kh_mem_we), .mem_addr_o(kh_mem_addr),
        .mem_wdata_o(kh_mem_wdata), .mem_rdata_i(kh_mem_rdata),
        .mem_ack_i(kh_mem_done), .mem_rom_ack_i(kh_rom_done),
        .mem_ram_ack_i(kh_ram_done), .mem_hold_i(kh_mem_busy)
    );

endmodule
