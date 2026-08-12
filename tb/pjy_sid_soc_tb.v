`timescale 1ns/1ps
`include "pjy_defines.vh"
module pjy_sid_soc_tb;
    reg clk=0, rst=`PJY_RstEnable;
    wire succ, uart_tx_pin, io_scl, io_sda;
    wire[2:0] PWM_o;
    reg[7:0] expected[0:9];
    reg[7:0] rx_byte;
    integer rx_count=0, errors=0, i;
    integer baud_cycles=32'h1b8+1;
    always #10 clk=~clk;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/pjy_sid_soc.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,pjy_sid_soc_tb);
    end
`endif
    initial begin
        expected[0]=8'h32; expected[1]=8'h30; expected[2]=8'h32; expected[3]=8'h35;
        expected[4]=8'h32; expected[5]=8'h31; expected[6]=8'h30; expected[7]=8'h39;
        // PJY student ID is 2025210902.
        expected[8]=8'h30; expected[9]=8'h32;
        $readmemh("../inputs/pjy/test_command/Extend_Inst_Example/sID/sID_inst.data", u_top.u_ext_rom._rom);
        repeat(8) @(posedge clk); rst=`PJY_RstDisable;
        wait(rx_count==10); wait(u_top.u_soc.u_sid_uart_sender.done_o==1'b1); repeat(20) @(posedge clk);
        if(errors==0) $display("TEST_PASS PJY_sID received_2025210902");
        else $display("TEST_FAIL PJY_sID errors=%0d",errors);
        $finish;
    end
    initial begin
        wait(rst==`PJY_RstDisable);
        forever begin
            @(negedge uart_tx_pin); #(baud_cycles*10); #(baud_cycles*20);
            for(i=0;i<8;i=i+1) begin rx_byte[i]=uart_tx_pin; #(baud_cycles*20); end
            if(uart_tx_pin!==1'b1 || rx_count>=10 || rx_byte!==expected[rx_count]) errors=errors+1;
            rx_count=rx_count+1;
        end
    end
    initial begin #20000000; $display("TEST_FAIL PJY_sID timeout count=%0d",rx_count); $finish; end
    pjy_tinyriscv_fpga_top u_top(.clk(clk),.rst(rst),.succ(succ),.uart_debug_pin(1'b0),
        .uart_tx_pin(uart_tx_pin),.uart_rx_pin(1'b1),.PWM_o(PWM_o),.io_scl(io_scl),.io_sda(io_sda));
endmodule
