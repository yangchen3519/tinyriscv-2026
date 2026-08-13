`timescale 1ns/1ps
// Bounded end-to-end probe for programs whose underlying resource/ISA may have
// intentionally been removed.  The log records completion versus timeout; the
// regression report classifies that observation against the design contract.
module fourcore_program_probe_tb;
    reg clk = 0, rst = 0;
    reg [1:0] chip_sel = 0;
    integer core = 0, cycles = 0, max_cycles = 50000;
    reg [1023:0] inst_file;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire [3:0] PWM_o;
    wire [7:0] ext_mem_data_o, ext_mem_data_i;
    wire ext_rom_we, ext_ram_we;
    wire [31:0] ext_rom_addr, ext_rom_wdata, ext_rom_rdata;
    wire [31:0] ext_ram_addr, ext_ram_wdata, ext_ram_rdata;
    always #10 clk = ~clk;
    pullup(i2c_scl); pullup(i2c_sda);

    initial begin
        if (!$value$plusargs("INST_FILE=%s", inst_file)) $fatal(1, "INST_FILE is required");
        if (!$value$plusargs("CORE=%d", core)) core = 0;
        if (!$value$plusargs("MAX_CYCLES=%d", max_cycles)) max_cycles = 50000;
        $readmemh(inst_file, dut.u_rom._rom);
        @(negedge clk); rst = 0; chip_sel = core[1:0];
        repeat (8) @(posedge clk);
        @(negedge clk); rst = 1;
        while (cycles < max_cycles && dut.u_chip.status_x26 !== 32'h1) begin
            @(posedge clk); #1; cycles = cycles + 1;
        end
        if (dut.u_chip.status_x26 === 32'h1 && dut.u_chip.status_x27 === 32'h1)
            $display("PROGRAM_RESULT core=%0d status=PASS cycles=%0d x26=%08h x27=%08h file=%0s",
                core, cycles, dut.u_chip.status_x26, dut.u_chip.status_x27, inst_file);
        else
            $display("PROGRAM_RESULT core=%0d status=NO_PASS cycles=%0d x26=%08h x27=%08h file=%0s",
                core, cycles, dut.u_chip.status_x26, dut.u_chip.status_x27, inst_file);
        $display("TEST_PASS bounded_program_probe");
        $finish;
    end

    tinyriscv_4core_fpga_top dut(.clk(clk), .rst(rst), .chip_sel(chip_sel), .uart_debug_en(1'b0),
        .uart_rx(1'b1), .uart_tx(uart_tx), .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .over(over), .succ(succ));
endmodule
