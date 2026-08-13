`timescale 1ns/1ps

// Board-level reproduction for the default Khoree core:
// reset -> KEY0/UART-debug download -> release KEY0 -> execute rT -> UART byte.
module khoree_uart_debug_temp_tb;
    localparam integer WORDS = 5;
    localparam integer FW_BYTES = WORDS * 4;
    localparam integer DATA_PACKETS = (FW_BYTES / 32) + 1;
    // The RTL reset value is divisor 0x1b8; its counter produces 441 clocks
    // per bit at the 50 MHz test clock.
    localparam integer UART_BIT_NS = 8820;
    localparam integer UART_HALF_BIT_NS = UART_BIT_NS / 2;

    reg clk = 1'b0;
    reg rst = 1'b0;
    reg [1:0] chip_sel = 2'b11;
    reg uart_debug_en = 1'b1;
    reg uart_rx = 1'b1;
    wire uart_tx;
    tri1 i2c_scl;
    tri1 i2c_sda;
    wire [3:0] PWM_o;
    wire over;
    wire succ;

    reg [31:0] program [0:WORDS-1];
    reg [7:0] packet [0:34];
    reg [7:0] rx_byte;
    integer i;
    integer p;
    integer byte_index;
    integer errors = 0;

    always #10 clk = ~clk;

    always @(posedge dut.u_chip.u_kh.s7_ack_i)
        $display("I2C_ACK time=%0t raw=%08h pc=%08h inst=%08h x2=%08h x8=%08h", $time,
                 dut.u_chip.u_kh.i2c_0.iic_read_data,
                 dut.u_chip.u_kh.u_tinyriscv.u_pc_reg.pc_o,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.inst_i,
                 dut.u_chip.u_shared_regs.regs[2],
                 dut.u_chip.u_shared_regs.regs[8]);

    always @(posedge clk) begin
        if (!uart_debug_en && dut.u_chip.u_kh.s3_we_o &&
            dut.u_chip.u_kh.s3_addr_o[7:0] == 8'h0c)
            $display("UART_WRITE time=%0t data=%02h pc=%08h", $time,
                     dut.u_chip.u_kh.s3_data_o[7:0],
                     dut.u_chip.u_kh.u_tinyriscv.u_pc_reg.pc_o);
    end

    function [7:0] firmware_byte;
        input integer index;
        integer word_index;
        integer lane;
        begin
            if (index >= FW_BYTES) begin
                firmware_byte = 8'h00;
            end else begin
                word_index = index / 4;
                lane = index % 4;
                case (lane)
                    0: firmware_byte = program[word_index][7:0];
                    1: firmware_byte = program[word_index][15:8];
                    2: firmware_byte = program[word_index][23:16];
                    default: firmware_byte = program[word_index][31:24];
                endcase
            end
        end
    endfunction

    function [15:0] packet_crc;
        input unused;
        integer index;
        integer bit_index;
        reg [15:0] crc;
        begin
            crc = 16'hffff;
            for (index = 1; index <= 32; index = index + 1) begin
                crc = crc ^ packet[index];
                for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                    if (crc[0]) crc = (crc >> 1) ^ 16'ha001;
                    else crc = crc >> 1;
                end
            end
            packet_crc = crc;
        end
    endfunction

    task send_uart_byte;
        input [7:0] data;
        integer bit_index;
        begin
            uart_rx = 1'b0;
            #(UART_BIT_NS);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                uart_rx = data[bit_index];
                #(UART_BIT_NS);
            end
            uart_rx = 1'b1;
            #(UART_BIT_NS);
        end
    endtask

    task receive_uart_byte;
        output [7:0] data;
        integer bit_index;
        begin
            @(negedge uart_tx);
            #(UART_BIT_NS + UART_HALF_BIT_NS);
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                data[bit_index] = uart_tx;
                #(UART_BIT_NS);
            end
            if (uart_tx !== 1'b1) errors = errors + 1;
            #(UART_HALF_BIT_NS);
        end
    endtask

    task finish_packet;
        reg [15:0] crc;
        integer index;
        begin
            crc = packet_crc(1'b0);
            packet[33] = crc[7:0];
            packet[34] = crc[15:8];
            for (index = 0; index < 34; index = index + 1)
                send_uart_byte(packet[index]);
            // Arm the receiver before the last byte finishes; the downloader
            // can begin its ACK during the sender's final stop-bit delay.
            fork
                send_uart_byte(packet[34]);
                receive_uart_byte(rx_byte);
            join
            if (rx_byte !== 8'h06) begin
                $display("DOWNLOAD_FAIL packet=%0d response=%02h", packet[0], rx_byte);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $readmemh("../firmware/test_command/Extend_Inst_Example/Temp/Khoree_Temp_smoke.data", program);
        for (i = 0; i < 35; i = i + 1) packet[i] = 8'h00;

        // Press reset while Khoree is selected, then release reset with KEY0
        // asserted so the shared downloader owns the CPU bus.
        repeat (8) @(posedge clk);
        @(negedge clk);
        rst = 1'b1;
        wait (dut.u_chip.u_shared_uart_debug.state == 5'd5);

        packet[0] = 8'h00;
        packet[1] = "T"; packet[2] = "e"; packet[3] = "m"; packet[4] = "p";
        packet[5] = "."; packet[6] = "b"; packet[7] = "i"; packet[8] = "n";
        packet[25] = (FW_BYTES >> 24) & 8'hff;
        packet[26] = (FW_BYTES >> 16) & 8'hff;
        packet[27] = (FW_BYTES >> 8) & 8'hff;
        packet[28] = FW_BYTES & 8'hff;
        finish_packet();

        byte_index = 0;
        for (p = 0; p < DATA_PACKETS; p = p + 1) begin
            for (i = 0; i < 35; i = i + 1) packet[i] = 8'h00;
            packet[0] = p + 1;
            for (i = 1; i <= 32; i = i + 1) begin
                packet[i] = firmware_byte(byte_index);
                byte_index = byte_index + 1;
            end
            finish_packet();
        end

        $display("DOWNLOAD_DONE packets=%0d bytes=%0d rom0=%08h rom4=%08h",
                 DATA_PACKETS + 1, FW_BYTES, dut.u_rom._rom[0], dut.u_rom._rom[4]);

        // Release KEY0. The already-reset CPU starts at ROM address zero.
        @(negedge clk);
        uart_debug_en = 1'b0;
        receive_uart_byte(rx_byte);
        $display("TEMP_UART byte=%02h i2c_raw=%08h x10=%08h", rx_byte,
                 dut.u_chip.u_kh.i2c_0.iic_read_data,
                 dut.u_chip.u_shared_regs.regs[10]);
        if (rx_byte == 8'h3f && errors == 0)
            $display("TEST_PASS khoree_uart_debug_temp_full_flow");
        else
            $display("TEST_FAIL khoree_uart_debug_temp_full_flow byte=%02h errors=%0d", rx_byte, errors);
        $finish;
    end

    initial begin
        #150000000;
        $display("TEST_FAIL khoree_uart_debug_temp_full_flow timeout state=%0d pc=%08h inst=%08h op1=%08h op2=%08h m0_req=%b m0_addr=%08h m0_we=%b stall=%b mem_req=%b mem_addr=%08h mem_we=%b chip_bridge_state=%0d fpga_bridge_state=%0d mem_ack_flag=%b i2c_state=%0d req=%b ack=%b raw=%08h addr_reads=%0d uart_ctrl=%08h uart_status=%08h",
                 dut.u_chip.u_shared_uart_debug.state,
                 dut.u_chip.u_kh.u_tinyriscv.u_pc_reg.pc_o,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.inst_i,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.op1_i,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.op2_i,
                 dut.u_chip.u_kh.m0_req_i,
                 dut.u_chip.u_kh.m0_addr_i,
                 dut.u_chip.u_kh.m0_we_i,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.stall,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.mem_req_o,
                 dut.u_chip.u_kh.mem_addr_o,
                 dut.u_chip.u_kh.mem_we_o,
                 dut.u_chip.u_kh_mem_bridge.state,
                 dut.u_kh_bridge_fpga.state,
                 dut.u_chip.u_kh.u_tinyriscv.u_ex.mem_ack_flag,
                 dut.u_chip.u_kh.i2c_0.cstate,
                 dut.u_chip.u_kh.s7_req_o,
                 dut.u_chip.u_kh.s7_ack_i,
                 dut.u_chip.u_kh.i2c_0.iic_read_data,
                 u_lm75.addr_read_count,
                 dut.u_chip.u_kh.uart_0.uart_ctrl,
                 dut.u_chip.u_kh.uart_0.uart_status);
        $finish;
    end

    tinyriscv_4core_fpga_top dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .uart_debug_en(uart_debug_en), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .over(over), .succ(succ)
    );

    // Bits [6:0] are don't-care in the course format.  Set them high so the
    // zero-delay slave model cannot create ambiguity at the byte boundary;
    // the required [14:7] field remains 63 decimal = 0x3f.
    lm75_model_rt #(.TEMP(8'h1f), .FRAC(8'hff)) u_lm75(
        .io_scl(i2c_scl), .io_sda(i2c_sda)
    );
endmodule
