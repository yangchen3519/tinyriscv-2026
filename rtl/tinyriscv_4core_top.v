`timescale 1ns/1ps

// Four-core course chip.  rst is active low.  chip_sel is sampled only while
// reset is asserted and remains frozen for the complete run that follows.
module tinyriscv_4core_top(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] chip_sel,
    input  wire       uart_debug_en,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [3:0] PWM_o,
    inout  wire       i2c_scl,
    inout  wire       i2c_sda,
    output wire i2c_scl_drive_low_o,
    output wire i2c_sda_drive_low_o,
    input  wire [7:0] ext_mem_data_i,
    output wire [7:0] ext_mem_data_o,
    output wire       ext_mem_tx_valid_o,
    input  wire       ext_mem_tx_ready_i,
    input  wire       ext_mem_rx_valid_i,
    output wire       ext_mem_rx_ready_o,
    output wire       over,
    output wire       succ
);

    // chip_sel is wired as {KEY4_n, KEY3_n, KEY2_n}; board keys are active
    // low.  Thus 111 is no key and each other valid code is one key press.
    localparam SEL_YC = 3'b111;
    localparam SEL_YX = 3'b110;
    localparam SEL_PJY = 3'b101;
    localparam SEL_KHOREE = 3'b011;

    reg [2:0] selected;
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

    // One shared YC chip-side memory bridge for all four cores.
    wire yc_mem_req, yx_mem_req, pjy_mem_req, kh_mem_req;
    wire yc_mem_we, yx_mem_we, pjy_mem_we, kh_mem_we;
    wire [31:0] yc_mem_addr, yx_mem_addr, pjy_mem_addr, kh_mem_addr;
    wire [31:0] yc_mem_wdata, yx_mem_wdata, pjy_mem_wdata, kh_mem_wdata;
    wire [31:0] shared_mem_rdata;
    wire shared_mem_ack, shared_mem_hold;
    wire [7:0] shared_mem_tx_data;
    wire shared_mem_tx_valid;
    wire shared_mem_req = valid_sel & (sel_yc ? yc_mem_req : sel_yx ? yx_mem_req :
                                        sel_pjy ? pjy_mem_req : kh_mem_req);
    wire shared_mem_we = valid_sel & (sel_yc ? yc_mem_we : sel_yx ? yx_mem_we :
                                      sel_pjy ? pjy_mem_we : kh_mem_we);
    wire [31:0] shared_mem_addr = sel_yc ? yc_mem_addr : sel_yx ? yx_mem_addr :
                                     sel_pjy ? pjy_mem_addr : sel_kh ? kh_mem_addr : 32'b0;
    wire [31:0] shared_mem_wdata = sel_yc ? yc_mem_wdata : sel_yx ? yx_mem_wdata :
                                      sel_pjy ? pjy_mem_wdata : sel_kh ? kh_mem_wdata : 32'b0;

    yc_bridge_core u_shared_mem_bridge(
        .clk(clk), .rst(rst), .req_i(shared_mem_req), .we_i(shared_mem_we),
        .addr_i(shared_mem_addr), .data_i(shared_mem_wdata),
        .data_o(shared_mem_rdata), .ack_o(shared_mem_ack),
        .hold_flag_o(shared_mem_hold), .tx_data_o(shared_mem_tx_data),
        .tx_valid_o(shared_mem_tx_valid), .rx_data_i(ext_mem_data_i)
    );

    wire yc_uart_tx, yx_uart_tx, pjy_uart_tx, kh_uart_tx;
    wire yc_succ, yx_succ, pjy_succ, pjy_over, kh_succ;
    wire yc_scl_low, yc_sda_low;
    wire yx_scl, yx_sda_low, pjy_scl, pjy_sda_low, kh_scl, kh_sda_low;
    wire [2:0] unused_pwm_yc, unused_pwm_yx, unused_pwm_kh;
    wire [3:0] unused_pwm_pjy;
    wire pjy_halted;

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
    assign ext_mem_data_o = valid_sel ? shared_mem_tx_data : 8'b0;
    assign ext_mem_tx_valid_o = valid_sel & shared_mem_tx_valid;
    assign ext_mem_rx_ready_o = 1'b0;
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
        .mem_wdata_o(yc_mem_wdata), .mem_rdata_i(shared_mem_rdata),
        .mem_ack_i(shared_mem_ack & sel_yc), .mem_hold_i(shared_mem_hold & sel_yc)
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
        .mem_wdata_o(yx_mem_wdata), .mem_rdata_i(shared_mem_rdata),
        .mem_ack_i(shared_mem_ack & sel_yx), .mem_hold_i(shared_mem_hold & sel_yx)
    );

    pjy_tinyriscv_soc_top u_pjy(
        .clk(clk), .rst(rst_pjy), .over(pjy_over), .succ(pjy_succ), .halted_ind(pjy_halted),
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
        .mem_wdata_o(pjy_mem_wdata), .mem_rdata_i(shared_mem_rdata),
        .mem_ack_i(shared_mem_ack & sel_pjy), .mem_hold_i(shared_mem_hold & sel_pjy)
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
        .mem_wdata_o(kh_mem_wdata), .mem_rdata_i(shared_mem_rdata),
        .mem_ack_i(shared_mem_ack & sel_kh), .mem_hold_i(shared_mem_hold & sel_kh)
    );

endmodule
