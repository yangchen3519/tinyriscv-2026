`timescale 1ns/1ps
`include "pjy_defines.vh"
module pjy_if_soc_tb;
    reg clk=0, rst=`PJY_RstEnable;
    wire succ, uart_tx_pin, io_scl, io_sda;
    wire[2:0] PWM_o;
    reg[7:0] rx_byte;
    integer baud_cycles=32'h1b8+1, i, errors=0;
    always #10 clk=~clk;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/pjy_if_soc.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,pjy_if_soc_tb);
    end
`endif
    task wait_uart_byte; output[7:0] data; begin
        @(negedge uart_tx_pin); #(baud_cycles*10); #(baud_cycles*20);
        for(i=0;i<8;i=i+1) begin data[i]=uart_tx_pin; #(baud_cycles*20); end
        if(uart_tx_pin!==1'b1) errors=errors+1;
    end endtask
    initial begin
        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/IF/IF_inst.data",u_top.u_ext_rom._rom);
        repeat(8) @(posedge clk); rst=`PJY_RstDisable;
        @(posedge u_top.u_soc.if_tx_valid); wait_uart_byte(rx_byte);
        // IF_inst.data produces the reference byte 0x8a.
        if(rx_byte!==8'h8a) errors=errors+1;
        @(posedge u_top.u_soc.if_done); repeat(20) @(posedge clk);
        if(errors==0) $display("TEST_PASS PJY_IF byte_8a");
        else $display("TEST_FAIL PJY_IF errors=%0d byte=%02h x30=%08h",errors,rx_byte,u_top.u_shared_regs.regs[30]);
        $finish;
    end
    initial begin #5000000; $display("TEST_FAIL PJY_IF timeout"); $finish; end
    pjy_tinyriscv_fpga_top u_top(.clk(clk),.rst(rst),.succ(succ),.uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin),.uart_rx_pin(1'b1),.PWM_o(PWM_o),.io_scl(io_scl),.io_sda(io_sda));
endmodule
