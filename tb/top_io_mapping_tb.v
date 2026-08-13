`timescale 1ns/1ps

module top_io_mapping_tb;
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg [1:0] chip_sel = 2'b00;
    reg uart_debug_en = 1'b0;
    reg uart_rx = 1'b1;
    reg [7:0] ext_mem_data_i = 8'b0;
    reg ext_mem_tx_ready_i = 1'b0;
    reg ext_mem_rx_valid_i = 1'b0;
    reg [1:0] spare_in = 2'b0;
    wire uart_tx;
    wire [3:0] PWM_o;
    tri1 i2c_scl;
    tri1 i2c_sda;
    wire [7:0] ext_mem_data_o;
    wire ext_mem_tx_valid_o;
    wire ext_mem_rx_ready_o;
    wire over;
    wire succ;
    wire [1:0] spare_out;
    integer errors = 0;

    always #5 clk = ~clk;

    task check_map;
        input [1:0] value;
        begin
            chip_sel = value;
            #1;
            if (dut.chip_sel_core !== value) begin
                $display("FAIL IO_MAP input=%b got=%b", value, dut.chip_sel_core);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check_map(2'b00);
        check_map(2'b01);
        check_map(2'b10);
        check_map(2'b11);
        if (errors == 0)
            $display("TEST_PASS top_IO_chip_sel_mapping");
        else
            $display("TEST_FAIL top_IO_chip_sel_mapping errors=%0d", errors);
        $finish;
    end

    tinyriscv_4core_top_IO dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .uart_debug_en(uart_debug_en), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .ext_mem_data_i(ext_mem_data_i), .ext_mem_data_o(ext_mem_data_o),
        .ext_mem_tx_valid_o(ext_mem_tx_valid_o),
        .ext_mem_tx_ready_i(ext_mem_tx_ready_i),
        .ext_mem_rx_valid_i(ext_mem_rx_valid_i),
        .ext_mem_rx_ready_o(ext_mem_rx_ready_o),
        .over(over), .succ(succ), .spare_in(spare_in), .spare_out(spare_out)
    );
endmodule
