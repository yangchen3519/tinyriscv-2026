`timescale 1ns/1ps
`include "pjy_defines.vh"

module pjy_basic_all_tb;
    reg clk = 1'b0;
    reg rst = `PJY_RstEnable;
    wire succ, uart_tx_pin, io_scl, io_sda;
    wire[2:0] PWM_o;
    reg[1023:0] inst_file;
    integer r, cycles;
    always #10 clk = ~clk;

    initial begin
        if (!$value$plusargs("INST_FILE=%s", inst_file)) inst_file = "inst.data";
        $display("BASIC_CASE %0s", inst_file);
        $readmemh(inst_file, u_top.u_ext_rom._rom);
        repeat (8) @(posedge clk);
        rst = `PJY_RstDisable;
        cycles = 0;
        while (cycles < 2000000 && u_top.u_shared_regs.regs[26] !== 32'h1) begin
            @(posedge clk); cycles = cycles + 1;
        end
        repeat (200) @(posedge clk);
        if (u_top.u_shared_regs.regs[26] == 32'h1 &&
            u_top.u_shared_regs.regs[27] == 32'h1 && succ == 1'b0)
            $display("BASIC_PASS %0s cycles=%0d", inst_file, cycles);
        else begin
            $display("BASIC_FAIL %0s cycles=%0d pc=%08x x26=%08x x27=%08x", inst_file, cycles,
                u_top.u_soc.u_tinyriscv.u_pc_reg.pc_o,
                u_top.u_shared_regs.regs[26], u_top.u_shared_regs.regs[27]);
            for (r=0; r<32; r=r+1) $display("REG x%0d = %08x", r, u_top.u_shared_regs.regs[r]);
        end
        $finish;
    end

    pjy_tinyriscv_fpga_top u_top(
        .clk(clk), .rst(rst), .succ(succ), .uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin), .uart_rx_pin(1'b1), .PWM_o(PWM_o),
        .io_scl(io_scl), .io_sda(io_sda)
    );
endmodule
