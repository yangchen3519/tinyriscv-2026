`timescale 1ns/1ps
module fourcore_rv32i_smoke_tb;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/fourcore_rv32i.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,fourcore_rv32i_smoke_tb);
    end
`endif
    reg clk=0, rst=0;
    reg[1:0] chip_sel=0;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire[3:0] PWM_o;
    wire[7:0] ext_mem_data_o, ext_mem_data_i;
    wire ext_rom_we, ext_ram_we;
    wire[31:0] ext_rom_addr, ext_rom_wdata, ext_rom_rdata;
    wire[31:0] ext_ram_addr, ext_ram_wdata, ext_ram_rdata;
    integer errors=0;
    reg[1023:0] inst_file;
    always #10 clk=~clk;
    pullup(i2c_scl); pullup(i2c_sda);

    task run_core; input[1:0] owner; integer cycles; reg saw_zero; begin
        @(negedge clk); rst=0; chip_sel=owner; repeat(8) @(posedge clk); @(negedge clk); rst=1;
        cycles=0; saw_zero=0;
        while(cycles<2000000 && !(saw_zero && dut.u_chip.status_x26===32'h1)) begin
            @(posedge clk); #1; cycles=cycles+1;
            if(dut.u_chip.status_x26===32'h0) saw_zero=1;
        end
        repeat(20) @(posedge clk); #1;
        if(!saw_zero || dut.u_chip.status_x26!==32'h1 || dut.u_chip.status_x27!==32'h1) begin
            $display("FAIL core=%0d RV32I cycles=%0d x26=%08h x27=%08h",owner,cycles,dut.u_chip.status_x26,dut.u_chip.status_x27);
            errors=errors+1;
        end else $display("PASS core=%0d RV32I cycles=%0d",owner,cycles);
    end endtask

    initial begin
        if(!$value$plusargs("INST_FILE=%s",inst_file))
            inst_file="../inputs/pjy/test_command/Baisc_Inst_Example/inst_add.data";
        $readmemh(inst_file,dut.u_rom._rom);
        run_core(2'b00); run_core(2'b01); run_core(2'b10); run_core(2'b11);
        if(errors==0) $display("TEST_PASS fourcore_RV32I %0s",inst_file);
        else $display("TEST_FAIL fourcore_RV32I errors=%0d",errors);
        $finish;
    end
    initial begin #200000000; $display("TEST_FAIL fourcore_RV32I global_timeout"); $finish; end

    tinyriscv_4core_fpga_top dut(.clk(clk),.rst(rst),.chip_sel(chip_sel),.uart_debug_en(1'b0),
        .uart_rx(1'b1),.uart_tx(uart_tx),.PWM_o(PWM_o),.i2c_scl(i2c_scl),.i2c_sda(i2c_sda),
        .over(over),.succ(succ));
endmodule
