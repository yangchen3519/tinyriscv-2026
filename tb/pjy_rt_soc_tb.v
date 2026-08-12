`timescale 1ns/1ps
`include "pjy_defines.vh"
module pjy_rt_soc_tb;
    reg clk=0, rst=`PJY_RstEnable;
    wire succ, uart_tx_pin, io_scl, io_sda;
    wire[2:0] PWM_o;
    reg[7:0] rx_byte;
    integer baud_cycles=32'h1b8+1, i, errors=0;
    pullup(io_sda);
    always #10 clk=~clk;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/pjy_rt_soc.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,pjy_rt_soc_tb);
    end
`endif
    task wait_uart_byte; output[7:0] data; begin
        @(negedge uart_tx_pin); #(baud_cycles*10); #(baud_cycles*20);
        for(i=0;i<8;i=i+1) begin data[i]=uart_tx_pin; #(baud_cycles*20); end
        if(uart_tx_pin!==1'b1) errors=errors+1;
    end endtask
    initial begin
        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/Temp/Temp.data",u_top.u_ext_rom._rom);
        repeat(8) @(posedge clk); rst=`PJY_RstDisable;
        @(posedge u_top.u_soc.rt_done); @(posedge u_top.u_soc.rt_reg_we); wait_uart_byte(rx_byte);
        if(rx_byte!==8'h1a || u_top.u_soc.rt_data!==8'h1a) errors=errors+1;
        if(errors==0) $display("TEST_PASS PJY_rT_LM75_uart_1a");
        else $display("TEST_FAIL PJY_rT errors=%0d uart=%02h data=%02h",errors,rx_byte,u_top.u_soc.rt_data);
        $finish;
    end
    initial begin #20000000; $display("TEST_FAIL PJY_rT timeout"); $finish; end
    pjy_tinyriscv_fpga_top u_top(.clk(clk),.rst(rst),.succ(succ),.uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin),.uart_rx_pin(1'b1),.PWM_o(PWM_o),.io_scl(io_scl),.io_sda(io_sda));
    lm75_model_rt u_lm75(.io_scl(io_scl),.io_sda(io_sda));
endmodule
