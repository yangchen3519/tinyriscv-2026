`timescale 1ns/1ps
module shared_uart_debug_tb;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/shared_uart_debug.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,shared_uart_debug_tb);
    end
`endif
    reg clk=0, rst=0;
    reg[2:0] chip_sel=3'b010;
    reg uart_debug_en=1'b1, uart_rx=1'b1;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire[3:0] PWM_o;
    wire[7:0] ext_mem_data_o;
    wire[7:0] ext_mem_data_i;
    wire ext_rom_we, ext_ram_we;
    wire[31:0] ext_rom_addr, ext_rom_wdata, ext_rom_rdata;
    wire[31:0] ext_ram_addr, ext_ram_wdata, ext_ram_rdata;
    reg[7:0] packet[0:34];
    integer i, selected_arg;
    always #10 clk=~clk;
    pullup(i2c_scl); pullup(i2c_sda);
    task send_byte; input[7:0] data; integer bitno; begin
        uart_rx=1'b0; #8680;
        for(bitno=0;bitno<8;bitno=bitno+1) begin uart_rx=data[bitno]; #8680; end
        uart_rx=1'b1; #8680;
    end endtask
    initial begin
        if($value$plusargs("CHIP_SEL=%d",selected_arg)) chip_sel=selected_arg[2:0];
        for(i=0;i<35;i=i+1) packet[i]=8'h00;
        // Valid first packet: sequence 0, filename "a", file size 0,
        // Modbus CRC16 over bytes 1..32 = 16'h3836 (low byte first).
        packet[1]=8'h61; packet[33]=8'h36; packet[34]=8'h38;
        repeat(8) @(posedge clk); @(negedge clk); rst=1'b1;
        wait(dut.u_chip.u_shared_uart_debug.state==5'd5);
        for(i=0;i<35;i=i+1) send_byte(packet[i]);
        wait(dut.u_chip.u_shared_uart_debug.remain_packet_count==16'd1);
        if(dut.u_chip.u_shared_uart_debug.remain_packet_count==16'd1 && dut.u_chip.selected==chip_sel)
            $display("TEST_PASS shared_uart_debug_35byte_crc_ack core=%0d",chip_sel);
        else
            $display("TEST_FAIL shared_uart_debug count=%0d sel=%b",dut.u_chip.u_shared_uart_debug.remain_packet_count,dut.u_chip.selected);
        $finish;
    end
    initial begin #10000000; $display("TEST_FAIL shared_uart_debug timeout state=%0d rec=%0d req=%b ack=%b hold=%b rdata=%08h status=%08h",
        dut.u_chip.u_shared_uart_debug.state,dut.u_chip.u_shared_uart_debug.rec_bytes_index,dut.u_chip.dbg_req,dut.u_chip.dbg_ack,
        dut.u_chip.u_pjy.mem_hold_flag_o,dut.u_chip.dbg_rdata,dut.u_chip.u_pjy.s3_data_i); $finish; end
    tinyriscv_4core_fpga_top dut(.clk(clk),.rst(rst),.chip_sel(chip_sel),.uart_debug_en(uart_debug_en),
        .uart_rx(uart_rx),.uart_tx(uart_tx),.PWM_o(PWM_o),.i2c_scl(i2c_scl),.i2c_sda(i2c_sda),
        .over(over),.succ(succ));
endmodule
