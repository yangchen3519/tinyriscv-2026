`timescale 1ns/1ps
module fourcore_pwm_program_tb;
`ifdef FSDB
    reg [1023:0] fsdb_file;
    initial begin
        if (!$value$plusargs("FSDB_FILE=%s", fsdb_file))
            fsdb_file = "../results/vcs/fourcore_pwm_program.fsdb";
        $fsdbDumpfile(fsdb_file);
        $fsdbDumpvars(0, fourcore_pwm_program_tb);
    end
`endif
    reg clk = 0, rst = 0;
    reg [2:0] chip_sel = 0;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire [3:0] PWM_o;
    wire [7:0] ext_mem_data_o, ext_mem_data_i;
    wire ext_rom_we, ext_ram_we;
    wire [31:0] ext_rom_addr, ext_rom_wdata, ext_rom_rdata;
    wire [31:0] ext_ram_addr, ext_ram_wdata, ext_ram_rdata;
    reg [1023:0] inst_file;
    integer errors = 0;

    always #10 clk = ~clk;
    pullup(i2c_scl);
    pullup(i2c_sda);

    task run_core;
        input [2:0] owner;
        integer cycles;
        begin
            @(negedge clk); rst = 0; chip_sel = owner;
            repeat (8) @(posedge clk);
            @(negedge clk); rst = 1;
            cycles = 0;
            while (cycles < 200000 && dut.u_chip.u_shared_pwm.pwm_c !== 32'h0000_000f) begin
                @(posedge clk); #1; cycles = cycles + 1;
            end
            repeat (4) @(posedge clk); #1;
            if (dut.u_chip.u_shared_pwm.pwm_a0 !== 32'd100000000 ||
                dut.u_chip.u_shared_pwm.pwm_b0 !== 32'd50000000  ||
                dut.u_chip.u_shared_pwm.pwm_a1 !== 32'd50000000  ||
                dut.u_chip.u_shared_pwm.pwm_b1 !== 32'd25000000  ||
                dut.u_chip.u_shared_pwm.pwm_a2 !== 32'd4000000   ||
                dut.u_chip.u_shared_pwm.pwm_b2 !== 32'd2000000   ||
                dut.u_chip.u_shared_pwm.pwm_a3 !== 32'd8000000   ||
                dut.u_chip.u_shared_pwm.pwm_b3 !== 32'd4000000   ||
                dut.u_chip.u_shared_pwm.pwm_c  !== 32'h0000_000f) begin
                $display("FAIL PWM_E2E core=%0d cycles=%0d A=%0d,%0d,%0d,%0d B=%0d,%0d,%0d,%0d C=%08h",
                    owner, cycles,
                    dut.u_chip.u_shared_pwm.pwm_a0, dut.u_chip.u_shared_pwm.pwm_a1,
                    dut.u_chip.u_shared_pwm.pwm_a2, dut.u_chip.u_shared_pwm.pwm_a3,
                    dut.u_chip.u_shared_pwm.pwm_b0, dut.u_chip.u_shared_pwm.pwm_b1,
                    dut.u_chip.u_shared_pwm.pwm_b2, dut.u_chip.u_shared_pwm.pwm_b3,
                    dut.u_chip.u_shared_pwm.pwm_c);
                errors = errors + 1;
            end else begin
                $display("PASS PWM_E2E core=%0d target=yc_pwm.u_shared_pwm cycles=%0d", owner, cycles);
            end
        end
    endtask

    initial begin
        if (!$value$plusargs("INST_FILE=%s", inst_file))
            inst_file = "../inputs/pjy/test_command/Other_Example/PWM/PWM_inst.data";
        $readmemh(inst_file, dut.u_rom._rom);
        run_core(3'b000);
        run_core(3'b001);
        run_core(3'b010);
        run_core(3'b011);
        if (errors == 0) $display("TEST_PASS fourcore_PWM_program shared_yc_pwm");
        else $display("TEST_FAIL fourcore_PWM_program errors=%0d", errors);
        $finish;
    end
    initial begin
        #200000000;
        $display("TEST_FAIL fourcore_PWM_program global_timeout");
        $finish;
    end

    tinyriscv_4core_fpga_top dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel), .uart_debug_en(1'b0),
        .uart_rx(1'b1), .uart_tx(uart_tx), .PWM_o(PWM_o),
        .i2c_scl(i2c_scl), .i2c_sda(i2c_sda), .over(over), .succ(succ));
endmodule
