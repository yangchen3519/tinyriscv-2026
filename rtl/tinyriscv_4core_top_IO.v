`timescale 1ns/1ps

// TSMC180 PAD-level wrapper.  Instance names intentionally match
// designs/tsmc180/tinyriscv/io.file; do not rename them independently.
module tinyriscv_4core_top_IO (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] chip_sel,
    input  wire       uart_debug_en,
    input  wire       uart_rx,
    output wire       uart_tx,
    output wire [3:0] PWM_o,
    inout  wire       i2c_scl,
    inout  wire       i2c_sda,
    input  wire [7:0] ext_mem_data_i,
    output wire [7:0] ext_mem_data_o,
    output wire       ext_mem_tx_valid_o,
    input  wire       ext_mem_tx_ready_i,
    input  wire       ext_mem_rx_valid_i,
    output wire       ext_mem_rx_ready_o,
    output wire       over,
    output wire       succ,
    input  wire       spare_in,
    output wire [1:0] spare_out
);

    wire       clk_core;
    wire       rst_core;
    wire [2:0] chip_sel_core;
    wire       uart_debug_en_core;
    wire       uart_rx_core;
    wire       uart_tx_core;
    wire [3:0] pwm_core;
    wire       i2c_scl_core;
    wire       i2c_sda_core;
    wire       i2c_scl_drive_low_core;
    wire       i2c_sda_drive_low_core;
    wire [7:0] ext_mem_data_i_core;
    wire [7:0] ext_mem_data_o_core;
    wire       ext_mem_tx_valid_core;
    wire       ext_mem_tx_ready_core;
    wire       ext_mem_rx_valid_core;
    wire       ext_mem_rx_ready_core;
    wire       over_core;
    wire       succ_core;
    wire       unused_spare_in_core;

    // Input PADs.
    PDDW0204CDG mclk       (.OEN(1'b1), .I(1'b0), .PAD(clk),
                            .C(clk_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mrst       (.OEN(1'b1), .I(1'b0), .PAD(rst),
                            .C(rst_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG muart_d    (.OEN(1'b1), .I(1'b0), .PAD(uart_debug_en),
                            .C(uart_debug_en_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG muart_rx   (.OEN(1'b1), .I(1'b0), .PAD(uart_rx),
                            .C(uart_rx_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // The fixed legacy chip-select/JTAG locations carry the three selector bits.
    PDDW0204CDG mchip_sel  (.OEN(1'b1), .I(1'b0), .PAD(chip_sel[0]),
                            .C(chip_sel_core[0]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mjtag_TCK  (.OEN(1'b1), .I(1'b0), .PAD(chip_sel[1]),
                            .C(chip_sel_core[1]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mjtag_TMS  (.OEN(1'b1), .I(1'b0), .PAD(chip_sel[2]),
                            .C(chip_sel_core[2]), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // Fixed SPI locations are repurposed for external-memory handshaking.
    PDDW0204CDG mspi_miso  (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_tx_ready_i),
                            .C(ext_mem_tx_ready_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mspi_ss    (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_rx_valid_i),
                            .C(ext_mem_rx_valid_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // GPIO[7:0] locations carry the byte entering the ASIC.
    PDDW0204CDG mgpio0 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[0]), .C(ext_mem_data_i_core[0]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio1 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[1]), .C(ext_mem_data_i_core[1]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio2 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[2]), .C(ext_mem_data_i_core[2]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio3 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[3]), .C(ext_mem_data_i_core[3]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio4 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[4]), .C(ext_mem_data_i_core[4]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio5 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[5]), .C(ext_mem_data_i_core[5]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio6 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[6]), .C(ext_mem_data_i_core[6]), .DS(1'b0), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG mgpio7 (.OEN(1'b1), .I(1'b0), .PAD(ext_mem_data_i[7]), .C(ext_mem_data_i_core[7]), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // One unused legacy input PAD is retained because io.file fixes its position.
    PDDW0204CDG mjtag_TDI  (.OEN(1'b1), .I(1'b0), .PAD(spare_in),
                            .C(unused_spare_in_core), .DS(1'b0), .PE(1'b0), .IE(1'b1));

    // Output PADs.
    PDDW0204CDG mover      (.OEN(1'b0), .I(over_core), .PAD(over),
                            .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG msucc      (.OEN(1'b0), .I(succ_core), .PAD(succ),
                            .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG muart_tx   (.OEN(1'b0), .I(uart_tx_core), .PAD(uart_tx),
                            .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mPWM_0     (.OEN(1'b0), .I(pwm_core[0]), .PAD(PWM_o[0]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mPWM_1     (.OEN(1'b0), .I(pwm_core[1]), .PAD(PWM_o[1]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mPWM_2     (.OEN(1'b0), .I(pwm_core[2]), .PAD(PWM_o[2]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mPWM_3     (.OEN(1'b0), .I(pwm_core[3]), .PAD(PWM_o[3]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mspi_mosi  (.OEN(1'b0), .I(ext_mem_tx_valid_core), .PAD(ext_mem_tx_valid_o), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mspi_clk   (.OEN(1'b0), .I(ext_mem_rx_ready_core), .PAD(ext_mem_rx_ready_o), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));

    // GPIO[15:8] locations carry the byte leaving the ASIC.
    PDDW0204CDG mgpio8 (.OEN(1'b0), .I(ext_mem_data_o_core[0]), .PAD(ext_mem_data_o[0]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpio9 (.OEN(1'b0), .I(ext_mem_data_o_core[1]), .PAD(ext_mem_data_o[1]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioA (.OEN(1'b0), .I(ext_mem_data_o_core[2]), .PAD(ext_mem_data_o[2]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioB (.OEN(1'b0), .I(ext_mem_data_o_core[3]), .PAD(ext_mem_data_o[3]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioC (.OEN(1'b0), .I(ext_mem_data_o_core[4]), .PAD(ext_mem_data_o[4]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioD (.OEN(1'b0), .I(ext_mem_data_o_core[5]), .PAD(ext_mem_data_o[5]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioE (.OEN(1'b0), .I(ext_mem_data_o_core[6]), .PAD(ext_mem_data_o[6]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mgpioF (.OEN(1'b0), .I(ext_mem_data_o_core[7]), .PAD(ext_mem_data_o[7]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));

    // Unused legacy output PADs are driven to a defined value.
    PDDW0204CDG mjtag_TDO (.OEN(1'b0), .I(1'b0), .PAD(spare_out[0]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));
    PDDW0204CDG mhalt     (.OEN(1'b0), .I(1'b0), .PAD(spare_out[1]), .C(), .DS(1'b1), .PE(1'b0), .IE(1'b0));

    // Open-drain I2C PADs: output only drives zero; OEN releases the line.
    PDDW0204CDG mscl (.OEN(~i2c_scl_drive_low_core), .I(1'b0), .PAD(i2c_scl),
                      .C(i2c_scl_core), .DS(1'b1), .PE(1'b0), .IE(1'b1));
    PDDW0204CDG msda (.OEN(~i2c_sda_drive_low_core), .I(1'b0), .PAD(i2c_sda),
                      .C(i2c_sda_core), .DS(1'b1), .PE(1'b0), .IE(1'b1));

    tinyriscv_4core_top u_fourcore (
        .clk(clk_core),
        .rst(rst_core),
        .chip_sel(chip_sel_core),
        .uart_debug_en(uart_debug_en_core),
        .uart_rx(uart_rx_core),
        .uart_tx(uart_tx_core),
        .PWM_o(pwm_core),
        .i2c_scl(i2c_scl_core),
        .i2c_sda(i2c_sda_core),
        .i2c_scl_drive_low_o(i2c_scl_drive_low_core),
        .i2c_sda_drive_low_o(i2c_sda_drive_low_core),
        .ext_mem_data_i(ext_mem_data_i_core),
        .ext_mem_data_o(ext_mem_data_o_core),
        .ext_mem_tx_valid_o(ext_mem_tx_valid_core),
        .ext_mem_tx_ready_i(ext_mem_tx_ready_core),
        .ext_mem_rx_valid_i(ext_mem_rx_valid_core),
        .ext_mem_rx_ready_o(ext_mem_rx_ready_core),
        .over(over_core),
        .succ(succ_core)
    );

endmodule
