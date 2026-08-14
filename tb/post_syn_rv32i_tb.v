`timescale 1ns/1ps

module post_syn_rv32i_tb;
    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg  [1:0]  chip_sel = 2'b00;
    wire        uart_tx;
    wire [3:0]  PWM_o;
    tri         i2c_scl;
    tri         i2c_sda;
    wire        over;
    wire        succ;
    wire [1:0]  spare_out;

    wire [7:0] chip_out;
    wire [7:0] chip_in;
    wire       chip_valid;
    wire       chip_ready;
    wire       chip_rx_valid;
    wire       chip_rx_ready;

    reg [1:0] selected;
    wire syc  = selected == 2'b00;
    wire syx  = selected == 2'b01;
    wire spjy = selected == 2'b10;
    wire skh  = selected == 2'b11;

    wire yc_rwe, yc_awe, yx_rwe, yx_awe;
    wire pj_rwe, pj_awe, kh_rwe, kh_awe;
    wire [7:0] yc_ra, yx_ra, pj_ra, kh_ra;
    wire [3:0] yc_aa, yx_aa, pj_aa, kh_aa;
    wire [31:0] yc_rd, yc_ad, yx_rd, yx_ad;
    wire [31:0] pj_rd, pj_ad, kh_rd, kh_ad;
    wire [31:0] rom_rdata, ram_rdata;
    wire rom_we, ram_we;
    wire [7:0] rom_addr;
    wire [3:0] ram_addr;
    wire [31:0] rom_wdata, ram_wdata;
    wire [7:0] yc_back, yx_back, pj_back, kh_back;
    wire yc_back_valid, kh_ready, kh_back_valid;

    integer errors = 0;
    integer core;
    integer cycles;
    reg saw_running;
    reg [1023:0] inst_file;

    always #10 clk = ~clk;
    always @(posedge clk)
        if (!rst)
            selected <= chip_sel;

    pullup(i2c_scl);
    pullup(i2c_sda);

    initial begin
        if (!$value$plusargs("INST_FILE=%s", inst_file))
            inst_file = "../firmware/test_command/Baisc_Inst_Example/inst_add.data";
        $sdf_annotate("../../../../result/syn/data/tinyriscv_4core_top_IO.syn.sdf",
                      u_chip, , "post_syn_sdf.log", "MAXIMUM");

        $readmemh(inst_file, u_rom._rom);
        for (core = 0; core < 4; core = core + 1) begin
            @(negedge clk);
            rst = 1'b0;
            chip_sel = core[1:0];
            repeat (10) @(posedge clk);
            @(negedge clk);
            rst = 1'b1;

            cycles = 0;
            saw_running = 1'b0;
            while (cycles < 2000000 && !(saw_running && over === 1'b0 && succ === 1'b0)) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
                if (over === 1'b1 || succ === 1'b1)
                    saw_running = 1'b1;
            end
            repeat (20) @(posedge clk);
            #1;
            if (!saw_running || over !== 1'b0 || succ !== 1'b0) begin
                $display("TEST_FAIL post_syn_RV32I core=%0d cycles=%0d over=%b succ=%b",
                         core, cycles, over, succ);
                errors = errors + 1;
            end else begin
                $display("TEST_PASS post_syn_RV32I core=%0d cycles=%0d", core, cycles);
            end
        end

        if (errors == 0)
            $display("POST_SYN_SIM_PASS cores=4 file=%0s", inst_file);
        else
            $display("POST_SYN_SIM_FAIL errors=%0d", errors);
        $finish;
    end

    initial begin
        #200000000;
        $display("POST_SYN_SIM_FAIL global_timeout");
        $finish;
    end

    tinyriscv_4core_top_IO u_chip (
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .uart_debug_en(1'b0), .uart_rx(1'b1), .uart_tx(uart_tx),
        .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .ext_mem_data_i(chip_in), .ext_mem_data_o(chip_out),
        .ext_mem_tx_valid_o(chip_valid), .ext_mem_tx_ready_i(chip_ready),
        .ext_mem_rx_valid_i(chip_rx_valid), .ext_mem_rx_ready_o(chip_rx_ready),
        .over(over), .succ(succ), .spare_in(2'b00), .spare_out(spare_out)
    );

    yc_bridge_FPGA u_yc_bridge_fpga (
        .clk(clk), .rst(rst & syc), .rx_valid_i(chip_valid & syc),
        .rx_data_i(chip_out), .tx_data_o(yc_back), .tx_valid_o(yc_back_valid),
        .rom_we_o(yc_rwe), .rom_addr_o(yc_ra), .rom_data_o(yc_rd),
        .rom_data_i(rom_rdata), .ram_we_o(yc_awe), .ram_addr_o(yc_aa),
        .ram_data_o(yc_ad), .ram_data_i(ram_rdata)
    );
    yx_fpga_bridge u_yx_bridge_fpga (
        .clk(clk), .rst(rst & syx), .fpga_o(yx_back), .fpga_i(chip_out),
        .rom_we_o(yx_rwe), .rom_addr_o(yx_ra), .rom_data_o(yx_rd),
        .rom_data_i(rom_rdata), .ram_we_o(yx_awe), .ram_addr_o(yx_aa),
        .ram_data_o(yx_ad), .ram_data_i(ram_rdata)
    );
    pjy_mem_bridge_fpga u_pjy_bridge_fpga (
        .clk(clk), .rst(rst & spjy), .ext_mem_data_i(chip_out),
        .ext_mem_data_o(pj_back), .rom_we_o(pj_rwe), .rom_addr_o(pj_ra),
        .rom_data_o(pj_rd), .rom_data_i(rom_rdata), .ram_we_o(pj_awe),
        .ram_addr_o(pj_aa), .ram_data_o(pj_ad), .ram_data_i(ram_rdata)
    );
    khoree_mem_bridge_fpga u_kh_bridge_fpga (
        .clk(clk), .rst(rst & skh), .c2f_data_i(chip_out),
        .c2f_valid_i(chip_valid & skh), .c2f_ready_o(kh_ready),
        .f2c_data_o(kh_back), .f2c_valid_o(kh_back_valid),
        .f2c_ready_i(chip_rx_ready), .rom_we_o(kh_rwe), .rom_addr_o(kh_ra),
        .rom_data_o(kh_rd), .rom_data_i(rom_rdata), .ram_we_o(kh_awe),
        .ram_addr_o(kh_aa), .ram_data_o(kh_ad), .ram_data_i(ram_rdata)
    );

    assign chip_in       = syc ? yc_back : syx ? yx_back : spjy ? pj_back : kh_back;
    assign chip_ready    = skh ? kh_ready : 1'b1;
    assign chip_rx_valid = skh ? kh_back_valid : 1'b0;
    assign rom_we        = syc ? yc_rwe : syx ? yx_rwe : spjy ? pj_rwe : kh_rwe;
    assign rom_addr      = syc ? yc_ra  : syx ? yx_ra  : spjy ? pj_ra  : kh_ra;
    assign rom_wdata     = syc ? yc_rd  : syx ? yx_rd  : spjy ? pj_rd  : kh_rd;
    assign ram_we        = syc ? yc_awe : syx ? yx_awe : spjy ? pj_awe : kh_awe;
    assign ram_addr      = syc ? yc_aa  : syx ? yx_aa  : spjy ? pj_aa  : kh_aa;
    assign ram_wdata     = syc ? yc_ad  : syx ? yx_ad  : spjy ? pj_ad  : kh_ad;

    yc_rom u_rom (.clk(clk), .rst(rst), .we_i(rom_we), .addr_i(rom_addr),
                  .data_i(rom_wdata), .data_o(rom_rdata));
    yc_ram u_ram (.clk(clk), .rst(rst), .we_i(ram_we), .addr_i(ram_addr),
                  .data_i(ram_wdata), .data_o(ram_rdata));
endmodule
