`timescale 1ns/1ps
module fourcore_pjy_extensions_tb;
`ifdef FSDB
    reg [1023:0] fsdb_file;
    initial begin
        if (!$value$plusargs("FSDB_FILE=%s", fsdb_file)) fsdb_file = "../results/vcs/fourcore_pjy_extensions.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0, fourcore_pjy_extensions_tb);
    end
`endif
    reg clk = 0, rst = 0;
    reg [1:0] chip_sel = 2'b10;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire [3:0] PWM_o;
    wire [7:0] ext_mem_data_o, ext_mem_data_i;
    wire ext_rom_we, ext_ram_we;
    wire [7:0] ext_rom_addr;
    wire [3:0] ext_ram_addr;
    wire [31:0] ext_rom_wdata, ext_rom_rdata;
    wire [31:0] ext_ram_wdata, ext_ram_rdata;
    reg [7:0] rx_byte;
    reg [7:0] sid_expected [0:9];
    integer baud_cycles = 32'h1b8 + 1;
    integer bit_idx, sid_idx, errors = 0;
    always #10 clk = ~clk;
    pullup(i2c_scl); pullup(i2c_sda);

    task reset_pjy; begin
        @(negedge clk); rst = 0; chip_sel = 2'b10;
        repeat (8) @(posedge clk);
        @(negedge clk); rst = 1;
    end endtask

    task wait_uart_byte; output [7:0] data; begin
        @(negedge uart_tx); #(baud_cycles*10); #(baud_cycles*20);
        for (bit_idx=0; bit_idx<8; bit_idx=bit_idx+1) begin data[bit_idx] = uart_tx; #(baud_cycles*20); end
        if (uart_tx !== 1'b1) errors = errors + 1;
    end endtask

    initial begin
        sid_expected[0]="2"; sid_expected[1]="0"; sid_expected[2]="2"; sid_expected[3]="5";
        sid_expected[4]="2"; sid_expected[5]="1"; sid_expected[6]="0"; sid_expected[7]="9";
        sid_expected[8]="0"; sid_expected[9]="5";

        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/sID/sID_inst.data", u_ext_rom._rom);
        reset_pjy();
        for (sid_idx=0; sid_idx<10; sid_idx=sid_idx+1) begin
            wait_uart_byte(rx_byte);
            if (rx_byte !== sid_expected[sid_idx]) errors = errors + 1;
        end
        wait(dut.u_pjy.u_sid_uart_sender.done_o === 1'b1);
        if (errors == 0) $display("PASS FINAL_TOP PJY_sID received_2025210905");
        else $display("FAIL FINAL_TOP PJY_sID errors=%0d", errors);

        @(negedge clk); rst = 0; repeat (8) @(posedge clk);
        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/Temp/Temp.data", u_ext_rom._rom);
        @(negedge clk); rst = 1;
        @(posedge dut.u_pjy.rt_done); @(posedge dut.u_pjy.rt_reg_we); wait_uart_byte(rx_byte);
        if (rx_byte !== 8'h1a || dut.u_pjy.rt_data !== 8'h1a) errors = errors + 1;
        if (rx_byte === 8'h1a && dut.u_pjy.rt_data === 8'h1a)
            $display("PASS FINAL_TOP PJY_rT_LM75_uart_1a");
        else $display("FAIL FINAL_TOP PJY_rT uart=%02h data=%02h", rx_byte, dut.u_pjy.rt_data);

        @(negedge clk); rst = 0; repeat (8) @(posedge clk);
        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/IF/IF_inst.data", u_ext_rom._rom);
        @(negedge clk); rst = 1;
        @(posedge dut.u_pjy.if_tx_valid); wait_uart_byte(rx_byte);
        if (rx_byte !== 8'h8a) errors = errors + 1;
        @(posedge dut.u_pjy.if_done); repeat (20) @(posedge clk); #1;
        if (rx_byte === 8'h8a)
            $display("PASS FINAL_TOP PJY_IF byte_8a");
        else $display("FAIL FINAL_TOP PJY_IF byte=%02h x30=%08h", rx_byte, dut.u_shared_regs.regs[30]);

        if (errors == 0) $display("TEST_PASS final_top_PJY_extensions all_3_programs");
        else $display("TEST_FAIL final_top_PJY_extensions errors=%0d", errors);
        $finish;
    end
    initial begin #60000000; $display("TEST_FAIL final_top_PJY_extensions timeout"); $finish; end

    tinyriscv_4core_top dut(.clk(clk), .rst(rst), .chip_sel(chip_sel), .uart_debug_en(1'b0),
        .uart_rx(1'b1), .uart_tx(uart_tx), .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .ext_mem_data_i(ext_mem_data_i), .ext_mem_data_o(ext_mem_data_o), .over(over), .succ(succ));
    pjy_mem_bridge_fpga u_mem_bridge_fpga(.clk(clk), .rst(rst), .ext_mem_data_i(ext_mem_data_o), .ext_mem_data_o(ext_mem_data_i),
        .rom_we_o(ext_rom_we), .rom_addr_o(ext_rom_addr), .rom_data_o(ext_rom_wdata), .rom_data_i(ext_rom_rdata),
        .ram_we_o(ext_ram_we), .ram_addr_o(ext_ram_addr), .ram_data_o(ext_ram_wdata), .ram_data_i(ext_ram_rdata));
    yc_rom u_ext_rom(.clk(clk), .rst(rst), .we_i(ext_rom_we), .addr_i(ext_rom_addr), .data_i(ext_rom_wdata), .data_o(ext_rom_rdata));
    yc_ram u_ext_ram(.clk(clk), .rst(rst), .we_i(ext_ram_we), .addr_i(ext_ram_addr), .data_i(ext_ram_wdata), .data_o(ext_ram_rdata));
    lm75_model_rt u_lm75(.io_scl(i2c_scl), .io_sda(i2c_sda));
endmodule
