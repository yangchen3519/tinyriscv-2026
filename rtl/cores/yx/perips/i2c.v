`timescale 1ns / 1ps

module yx_i2c(
    input  wire        clk,
    input  wire        rst,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,
    input  wire        i2c_sda_i,
    output wire        i2c_sda_drive_low_o,
    output reg         i2c_scl
);

    localparam ADDR_SLV  = 32'h0001_0000;
    localparam ADDR_TX   = 32'h0002_0000;
    localparam ADDR_RX   = 32'h0003_0000;
    localparam ADDR_TEMP = 32'h0004_0000;

    localparam LM75_ADDR = 7'b1001000;

    // 50 MHz system clock -> about 200 kHz I2C SCL, within LM75A fast-mode timing.
    parameter CLK_DIV = 250;

    reg [9:0] clk_cnt;
    wire tick_0 = (clk_cnt == 0);
    wire tick_1 = (clk_cnt == CLK_DIV/4);
    wire tick_2 = (clk_cnt == CLK_DIV/2);
    wire tick_3 = (clk_cnt == CLK_DIV*3/4);

    reg [6:0] slv_addr;
    reg [7:0] tx_data;
    reg [7:0] rx_data;
    reg [15:0] temp_data;
    reg busy;

    reg start_tx;
    reg start_rx;
    reg start_temp;
    reg rw_bit;

    always @(posedge clk) begin
        if (rst == 1'b0) begin
            slv_addr <= 7'b0;
            tx_data <= 8'b0;
            start_tx <= 1'b0;
            start_rx <= 1'b0;
            start_temp <= 1'b0;
        end else begin
            if (busy) begin
                start_tx <= 1'b0;
                start_rx <= 1'b0;
                start_temp <= 1'b0;
            end

            if (we_i && !busy) begin
                case (addr_i)
                    ADDR_SLV: slv_addr <= data_i[6:0];
                    ADDR_TX: begin
                        tx_data <= data_i[7:0];
                        start_tx <= 1'b1;
                    end
                    ADDR_RX: begin
                        start_rx <= 1'b1;
                    end
                    ADDR_TEMP: begin
                        start_temp <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
    end

    always @(*) begin
        case (addr_i)
            ADDR_SLV:  data_o = {busy, 24'b0, slv_addr};
            ADDR_TX:   data_o = {busy, 23'b0, tx_data};
            ADDR_RX:   data_o = {busy, 23'b0, rx_data};
            ADDR_TEMP: data_o = {busy, 15'b0, temp_data};
            default:   data_o = 32'b0;
        endcase
    end

    localparam IDLE  = 3'd0,
               START = 3'd1,
               ADDR  = 3'd2,
               ACK1  = 3'd3,
               DATA  = 3'd4,
               ACK2  = 3'd5,
               STOP  = 3'd6;

    reg [2:0] state;
    reg [3:0] bit_cnt;
    reg [7:0] shift_reg;
    reg temp_mode;
    reg temp_lsb_phase;

    reg sda_out;
    reg sda_dir;

    assign i2c_sda_drive_low_o = sda_dir && !sda_out;
    wire sda_in = i2c_sda_i;

    always @(posedge clk) begin
        if (rst == 1'b0) begin
            state <= IDLE;
            busy <= 1'b0;
            clk_cnt <= 10'd0;
            i2c_scl <= 1'b1;
            sda_out <= 1'b1;
            sda_dir <= 1'b1;
            bit_cnt <= 4'd0;
            shift_reg <= 8'd0;
            rx_data <= 8'd0;
            temp_data <= 16'd0;
            temp_mode <= 1'b0;
            temp_lsb_phase <= 1'b0;
            rw_bit <= 1'b0;
        end else begin
            if (state == IDLE) begin
                i2c_scl <= 1'b1;
                sda_out <= 1'b1;
                sda_dir <= 1'b1;
                busy <= 1'b0;
                clk_cnt <= 10'd0;
                temp_lsb_phase <= 1'b0;

                if (start_tx || start_rx || start_temp) begin
                    busy <= 1'b1;
                    state <= START;
                    temp_mode <= start_temp;
                    rw_bit <= start_rx | start_temp;
                    shift_reg <= {start_temp ? LM75_ADDR : slv_addr, start_rx | start_temp};
                end
            end else begin
                if (clk_cnt == CLK_DIV - 1) begin
                    clk_cnt <= 10'd0;
                end else begin
                    clk_cnt <= clk_cnt + 1'b1;
                end

                case (state)
                    START: begin
                        if (tick_1) begin
                            sda_out <= 1'b0;
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            state <= ADDR;
                            bit_cnt <= 4'd8;
                        end
                    end

                    ADDR: begin
                        if (tick_0) begin
                            i2c_scl <= 1'b0;
                        end
                        if (tick_1) begin
                            sda_dir <= 1'b1;
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end
                        if (tick_2) begin
                            i2c_scl <= 1'b1;
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            if (bit_cnt > 1) begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end else begin
                                state <= ACK1;
                            end
                        end
                    end

                    ACK1: begin
                        if (tick_0) begin
                            i2c_scl <= 1'b0;
                        end
                        if (tick_1) begin
                            sda_dir <= 1'b0;
                        end
                        if (tick_2) begin
                            i2c_scl <= 1'b1;
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            state <= DATA;
                            bit_cnt <= 4'd8;
                            if (rw_bit == 1'b0) begin
                                shift_reg <= tx_data;
                                sda_dir <= 1'b1;
                            end else begin
                                shift_reg <= 8'd0;
                                sda_dir <= 1'b0;
                            end
                        end
                    end

                    DATA: begin
                        if (tick_0) begin
                            i2c_scl <= 1'b0;
                        end
                        if (tick_1 && rw_bit == 1'b0) begin
                            sda_dir <= 1'b1;
                            sda_out <= shift_reg[7];
                            shift_reg <= {shift_reg[6:0], 1'b0};
                        end
                        if (tick_2) begin
                            i2c_scl <= 1'b1;
                        end
                        if (tick_3 && rw_bit == 1'b1) begin
                            shift_reg <= {shift_reg[6:0], sda_in};
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            if (bit_cnt > 1) begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end else begin
                                state <= ACK2;
                                if (rw_bit == 1'b1) begin
                                    if (temp_mode) begin
                                        if (temp_lsb_phase) begin
                                            temp_data[7:0] <= shift_reg;
                                        end else begin
                                            temp_data[15:8] <= shift_reg;
                                        end
                                    end else begin
                                        rx_data <= shift_reg;
                                    end
                                end
                            end
                        end
                    end

                    ACK2: begin
                        if (tick_0) begin
                            i2c_scl <= 1'b0;
                        end
                        if (tick_1) begin
                            if (rw_bit == 1'b0) begin
                                sda_dir <= 1'b0;
                            end else begin
                                sda_dir <= 1'b1;
                                sda_out <= (temp_mode && !temp_lsb_phase) ? 1'b0 : 1'b1;
                            end
                        end
                        if (tick_2) begin
                            i2c_scl <= 1'b1;
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            if (rw_bit == 1'b1 && temp_mode && !temp_lsb_phase) begin
                                temp_lsb_phase <= 1'b1;
                                shift_reg <= 8'd0;
                                bit_cnt <= 4'd8;
                                sda_dir <= 1'b0;
                                state <= DATA;
                            end else begin
                                state <= STOP;
                                sda_dir <= 1'b1;
                            end
                        end
                    end

                    STOP: begin
                        if (tick_0) begin
                            i2c_scl <= 1'b0;
                            sda_out <= 1'b0;
                        end
                        if (tick_2) begin
                            i2c_scl <= 1'b1;
                        end
                        if (tick_3) begin
                            sda_out <= 1'b1;
                        end
                        if (clk_cnt == CLK_DIV - 1) begin
                            state <= IDLE;
                        end
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

endmodule
