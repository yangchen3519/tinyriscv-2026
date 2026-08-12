`include "yc_defines.vh"

// ----------------------------------------------------------------------------
// LM75-oriented I2C master with a 4-phase bit cell
//
// Each transferred bit is split into four phases:
//   0. LOW setup   : SCL low, master may change/release SDA
//   1. LOW hold    : keep SDA stable while SCL stays low
//   2. HIGH sample : release SCL high and wait until the bus is really high
//   3. HIGH hold   : sample / finish the bit while SCL is stably high
//
// This keeps SDA changes away from the SCL rising edge and gives the slave
// a full high-level window to recognize address bits and drive ACK.
//
// MMIO map
//   0x7001_0000 : ctrl/status
//                 read  -> {20'h0, ack_err, done, busy, ctrl_reg[8:0]}
//                 write -> [0] start
//                          [1] read_after_pointer
//                          [2] send_pointer_byte
//                          [3] repeated_start_en
//                          [4] send_txdata_byte
//                          [8] pointer bit0 (LM75 Temp=0 / Conf=1)
//                          [23:17] slave_addr
//   0x7002_0000 : txdata, low byte used when [4] send_txdata_byte is set
//   0x7003_0000 : rxdata, with byte0 in [15:8] and byte1 in [7:0]
// ----------------------------------------------------------------------------
module yc_i2c(
    input  wire        clk,
    input  wire        rst,

    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,

    (*mark_debug = "True"*)input  wire        i2c_scl_i,
    (*mark_debug = "True"*)input  wire        i2c_sda_i,
    (*mark_debug = "True"*)output wire        i2c_scl_drive_low_o,
    (*mark_debug = "True"*)output wire        i2c_sda_drive_low_o
);

    localparam [31:0] I2C_CTRL_ADDR   = 32'h7001_0000;
    localparam [31:0] I2C_TXDATA_ADDR = 32'h7002_0000;
    localparam [31:0] I2C_RXDATA_ADDR = 32'h7003_0000;

    // Legacy-visible state numbers kept for ILA / existing testbench probes.
    localparam [4:0] ST_IDLE            = 5'd0;
    localparam [4:0] ST_LOAD_CMD        = 5'd1;
    localparam [4:0] ST_START_A         = 5'd2;
    localparam [4:0] ST_START_B         = 5'd3;
    localparam [4:0] ST_SEND_ADDR_LOW   = 5'd4;
    localparam [4:0] ST_SEND_ADDR_HIGH  = 5'd5;
    localparam [4:0] ST_ADDR_ACK_LOW    = 5'd6;
    localparam [4:0] ST_ADDR_ACK_HIGH   = 5'd7;
    localparam [4:0] ST_SEND_DATA_LOW   = 5'd8;
    localparam [4:0] ST_SEND_DATA_HIGH  = 5'd9;
    localparam [4:0] ST_DATA_ACK_LOW    = 5'd10;
    localparam [4:0] ST_DATA_ACK_HIGH   = 5'd11;
    localparam [4:0] ST_RESTART_A       = 5'd12;
    localparam [4:0] ST_RESTART_B       = 5'd13;
    localparam [4:0] ST_RESTART_C       = 5'd14;
    localparam [4:0] ST_READ_DATA_LOW   = 5'd15;
    localparam [4:0] ST_READ_DATA_HIGH  = 5'd16;
    localparam [4:0] ST_MASTER_ACK_LOW  = 5'd17;
    localparam [4:0] ST_MASTER_ACK_HIGH = 5'd18;
    localparam [4:0] ST_STOP_A          = 5'd19;
    localparam [4:0] ST_STOP_B          = 5'd20;
    localparam [4:0] ST_STOP_C          = 5'd21;
    localparam [4:0] ST_DONE            = 5'd22;

    localparam [3:0] OP_IDLE       = 4'd0;
    localparam [3:0] OP_LOAD_CMD   = 4'd1;
    localparam [3:0] OP_START      = 4'd2;
    localparam [3:0] OP_SEND_ADDR  = 4'd3;
    localparam [3:0] OP_ADDR_ACK   = 4'd4;
    localparam [3:0] OP_SEND_DATA  = 4'd5;
    localparam [3:0] OP_DATA_ACK   = 4'd6;
    localparam [3:0] OP_RESTART    = 4'd7;
    localparam [3:0] OP_READ_DATA  = 4'd8;
    localparam [3:0] OP_MASTER_ACK = 4'd9;
    localparam [3:0] OP_STOP       = 4'd10;
    localparam [3:0] OP_DONE       = 4'd11;

    localparam [1:0] PH_LOW_SETUP  = 2'd0;
    localparam [1:0] PH_LOW_HOLD   = 2'd1;
    localparam [1:0] PH_HIGH_WAIT  = 2'd2;
    localparam [1:0] PH_HIGH_HOLD  = 2'd3;

    // 50 MHz / (125 * 4) = 100 kHz.
    localparam integer CLK_DIV = 125;
    localparam [1:0] DIRECT_READ_BYTES = 2'd2;

    reg [15:0] clk_div_cnt;
    reg        tick;

    reg [31:0] ctrl_reg;
    reg [31:0] txdata_reg;
    reg [31:0] rxdata_reg;

    (*mark_debug = "True"*)reg [6:0] slave_addr_reg;
    (*mark_debug = "True"*)reg [7:0] shifter;

    (*mark_debug = "True"*)reg busy_reg;
    (*mark_debug = "True"*)reg done_reg;
    (*mark_debug = "True"*)reg ack_err_reg;

    (*mark_debug = "True"*)reg scl_drv_low;
    (*mark_debug = "True"*)reg sda_drv_low;

    reg sda_s0;
    reg sda_s1;
    reg scl_s0;
    reg scl_s1;
    reg sda_in;
    reg scl_in;

    (*mark_debug = "True"*)reg [4:0] cur_state;
    (*mark_debug = "True"*)reg [3:0] op_state;
    (*mark_debug = "True"*)reg [1:0] phase_cnt;
    (*mark_debug = "True"*)reg [1:0] byte_cnt;
    (*mark_debug = "True"*)reg [2:0] bit_cnt;
    reg reg_addr_has_been_sent;
    reg        cmd_read_after_ptr;
    reg        cmd_send_pointer;
    reg        cmd_restart_en;
    reg        cmd_send_txdata;
    reg [7:0]  pointer_byte_reg;

    wire last_byte = (byte_cnt == (DIRECT_READ_BYTES - 1'b1));
    wire shifter_bit_is_one = shifter[bit_cnt];
    wire master_ack_low = !last_byte;

    assign i2c_scl_drive_low_o = scl_drv_low;
    assign i2c_sda_drive_low_o = sda_drv_low;

    function [4:0] legacy_state;
        input [3:0] op_sel;
        input [1:0] phase_sel;
        begin
            case (op_sel)
                OP_IDLE: begin
                    legacy_state = ST_IDLE;
                end
                OP_LOAD_CMD: begin
                    legacy_state = ST_LOAD_CMD;
                end
                OP_START: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_START_A : ST_START_B;
                end
                OP_SEND_ADDR: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_SEND_ADDR_LOW : ST_SEND_ADDR_HIGH;
                end
                OP_ADDR_ACK: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_ADDR_ACK_LOW : ST_ADDR_ACK_HIGH;
                end
                OP_SEND_DATA: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_SEND_DATA_LOW : ST_SEND_DATA_HIGH;
                end
                OP_DATA_ACK: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_DATA_ACK_LOW : ST_DATA_ACK_HIGH;
                end
                OP_RESTART: begin
                    case (phase_sel)
                        PH_LOW_SETUP: legacy_state = ST_RESTART_A;
                        PH_LOW_HOLD:  legacy_state = ST_RESTART_B;
                        default:      legacy_state = ST_RESTART_C;
                    endcase
                end
                OP_READ_DATA: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_READ_DATA_LOW : ST_READ_DATA_HIGH;
                end
                OP_MASTER_ACK: begin
                    legacy_state = (phase_sel[1] == 1'b0) ? ST_MASTER_ACK_LOW : ST_MASTER_ACK_HIGH;
                end
                OP_STOP: begin
                    case (phase_sel)
                        PH_LOW_SETUP: legacy_state = ST_STOP_A;
                        PH_LOW_HOLD:  legacy_state = ST_STOP_B;
                        default:      legacy_state = ST_STOP_C;
                    endcase
                end
                default: begin
                    legacy_state = ST_DONE;
                end
            endcase
        end
    endfunction

    always @(posedge clk) begin
        if (rst == `YC_RstEnable) begin
            clk_div_cnt <= 16'd0;
            tick <= 1'b0;
        end else if (clk_div_cnt == (CLK_DIV - 1'b1)) begin
            clk_div_cnt <= 16'd0;
            tick <= 1'b1;
        end else begin
            clk_div_cnt <= clk_div_cnt + 1'b1;
            tick <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (rst == `YC_RstEnable) begin
            ctrl_reg <= `YC_ZeroWord;
            txdata_reg <= `YC_ZeroWord;
        end else begin
            if (we_i == `YC_WriteEnable) begin
                case (addr_i)
                    I2C_CTRL_ADDR: begin
                        ctrl_reg <= data_i;
                    end
                    I2C_TXDATA_ADDR: begin
                        txdata_reg <= data_i;
                    end
                    default: begin
                    end
                endcase
            end
            if (op_state == OP_LOAD_CMD) begin
                ctrl_reg[0] <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (addr_i)
            I2C_CTRL_ADDR:   data_o = {20'h0, ack_err_reg, done_reg, busy_reg, ctrl_reg[8:0]};
            I2C_TXDATA_ADDR: data_o = txdata_reg;
            I2C_RXDATA_ADDR: data_o = rxdata_reg;
            default:         data_o = `YC_ZeroWord;
        endcase
    end

    always @(posedge clk) begin
        if (rst == `YC_RstEnable) begin
            sda_s0 <= 1'b1;
            sda_s1 <= 1'b1;
            sda_in <= 1'b1;
            scl_s0 <= 1'b1;
            scl_s1 <= 1'b1;
            scl_in <= 1'b1;
        end else begin
            sda_s0 <= i2c_sda_i;
            sda_s1 <= sda_s0;
            sda_in <= sda_s1;
            scl_s0 <= i2c_scl_i;
            scl_s1 <= scl_s0;
            scl_in <= scl_s1;
        end
    end

    always @(*) begin
        cur_state = legacy_state(op_state, phase_cnt);
    end

    always @(posedge clk) begin
        if (rst == `YC_RstEnable) begin
            op_state <= OP_IDLE;
            phase_cnt <= PH_LOW_SETUP;
            slave_addr_reg <= 7'h00;
            shifter <= 8'h00;
            busy_reg <= 1'b0;
            done_reg <= 1'b1;
            ack_err_reg <= 1'b0;
            scl_drv_low <= 1'b0;
            sda_drv_low <= 1'b0;
            byte_cnt <= 2'b00;
            bit_cnt <= 3'd7;
            reg_addr_has_been_sent <= 1'b0;
            cmd_read_after_ptr <= 1'b0;
            cmd_send_pointer <= 1'b0;
            cmd_restart_en <= 1'b0;
            cmd_send_txdata <= 1'b0;
            pointer_byte_reg <= 8'h00;
            rxdata_reg <= `YC_ZeroWord;
        end else if (tick) begin
            case (op_state)
                OP_IDLE: begin
                    phase_cnt <= PH_LOW_SETUP;
                    scl_drv_low <= 1'b0;
                    sda_drv_low <= 1'b0;
                    reg_addr_has_been_sent <= 1'b0;
                    if (ctrl_reg[0] == 1'b1) begin
                        op_state <= OP_LOAD_CMD;
                    end
                end

                OP_LOAD_CMD: begin
                    op_state <= OP_START;
                    phase_cnt <= PH_LOW_SETUP;
                    slave_addr_reg <= ctrl_reg[23:17];
                    shifter <= {
                        ctrl_reg[23:17],
                        (ctrl_reg[1] == 1'b1) &&
                        (ctrl_reg[2] == 1'b0) &&
                        (ctrl_reg[4] == 1'b0)
                    };
                    busy_reg <= 1'b1;
                    done_reg <= 1'b0;
                    ack_err_reg <= 1'b0;
                    scl_drv_low <= 1'b0;
                    sda_drv_low <= 1'b0;
                    byte_cnt <= 2'b00;
                    bit_cnt <= 3'd7;
                    reg_addr_has_been_sent <= 1'b0;
                    cmd_read_after_ptr <= ctrl_reg[1];
                    cmd_send_pointer <= ctrl_reg[2];
                    cmd_restart_en <= ctrl_reg[3];
                    cmd_send_txdata <= ctrl_reg[4];
                    pointer_byte_reg <= {7'h00, ctrl_reg[8]};
                    rxdata_reg <= `YC_ZeroWord;
                end

                OP_START: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if ((scl_in == 1'b1) && (sda_in == 1'b1)) begin
                                phase_cnt <= PH_LOW_HOLD;
                            end
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b1;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b1;
                            op_state <= OP_SEND_ADDR;
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_SEND_ADDR: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= ~shifter_bit_is_one;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= ~shifter_bit_is_one;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= ~shifter_bit_is_one;
                            if (bit_cnt == 3'd0) begin
                                op_state <= OP_ADDR_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_ADDR_ACK: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= 1'b0;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            bit_cnt <= 3'd7;
                            if (sda_in == 1'b1) begin
                                ack_err_reg <= 1'b1;
                                op_state <= OP_STOP;
                            end else if (reg_addr_has_been_sent == 1'b0 && cmd_send_pointer == 1'b1) begin
                                shifter <= pointer_byte_reg;
                                op_state <= OP_SEND_DATA;
                            end else if (cmd_read_after_ptr == 1'b1) begin
                                shifter <= 8'h00;
                                op_state <= OP_READ_DATA;
                            end else begin
                                op_state <= OP_STOP;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_SEND_DATA: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= ~shifter_bit_is_one;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= ~shifter_bit_is_one;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= ~shifter_bit_is_one;
                            if (bit_cnt == 3'd0) begin
                                op_state <= OP_DATA_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_DATA_ACK: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= 1'b0;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            bit_cnt <= 3'd7;
                            if (sda_in == 1'b1) begin
                                ack_err_reg <= 1'b1;
                                op_state <= OP_STOP;
                            end else if (reg_addr_has_been_sent == 1'b0) begin
                                reg_addr_has_been_sent <= 1'b1;
                                if (cmd_send_txdata == 1'b1) begin
                                    shifter <= txdata_reg[7:0];
                                    op_state <= OP_SEND_DATA;
                                end else if (cmd_read_after_ptr == 1'b1) begin
                                    if ((cmd_restart_en == 1'b1) || (cmd_send_pointer == 1'b1)) begin
                                        op_state <= OP_RESTART;
                                    end else begin
                                        shifter <= 8'h00;
                                        op_state <= OP_READ_DATA;
                                    end
                                end else begin
                                    op_state <= OP_STOP;
                                end
                            end else if (cmd_read_after_ptr == 1'b1) begin
                                if (cmd_restart_en == 1'b1) begin
                                    op_state <= OP_RESTART;
                                end else begin
                                    shifter <= 8'h00;
                                    op_state <= OP_READ_DATA;
                                end
                            end else begin
                                op_state <= OP_STOP;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_RESTART: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= 1'b0;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if ((scl_in == 1'b1) && (sda_in == 1'b1)) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b1;
                            shifter <= {slave_addr_reg, 1'b1};
                            op_state <= OP_SEND_ADDR;
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_READ_DATA: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= 1'b0;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            shifter[bit_cnt] <= sda_in;
                            if (bit_cnt == 3'd0) begin
                                op_state <= OP_MASTER_ACK;
                            end else begin
                                bit_cnt <= bit_cnt - 1'b1;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_MASTER_ACK: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= master_ack_low;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= master_ack_low;
                            if (scl_in == 1'b1) begin
                                if ((master_ack_low == 1'b1) || (sda_in == 1'b1)) begin
                                    phase_cnt <= PH_HIGH_HOLD;
                                end
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= master_ack_low;
                            if (byte_cnt == 2'b00) begin
                                rxdata_reg[15:8] <= shifter;
                            end else begin
                                rxdata_reg[7:0] <= shifter;
                            end

                            if (last_byte) begin
                                op_state <= OP_STOP;
                            end else begin
                                op_state <= OP_READ_DATA;
                                byte_cnt <= byte_cnt + 1'b1;
                                bit_cnt <= 3'd7;
                                shifter <= 8'h00;
                            end
                            phase_cnt <= PH_LOW_SETUP;
                        end
                    endcase
                end

                OP_STOP: begin
                    case (phase_cnt)
                        PH_LOW_SETUP: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= sda_drv_low;
                            phase_cnt <= PH_LOW_HOLD;
                        end

                        PH_LOW_HOLD: begin
                            scl_drv_low <= 1'b1;
                            sda_drv_low <= 1'b1;
                            phase_cnt <= PH_HIGH_WAIT;
                        end

                        PH_HIGH_WAIT: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b1;
                            if (scl_in == 1'b1) begin
                                phase_cnt <= PH_HIGH_HOLD;
                            end
                        end

                        default: begin
                            scl_drv_low <= 1'b0;
                            sda_drv_low <= 1'b0;
                            if ((scl_in == 1'b1) && (sda_in == 1'b1)) begin
                                busy_reg <= 1'b0;
                                done_reg <= 1'b1;
                                op_state <= OP_DONE;
                                phase_cnt <= PH_LOW_SETUP;
                            end
                        end
                    endcase
                end

                OP_DONE: begin
                    scl_drv_low <= 1'b0;
                    sda_drv_low <= 1'b0;
                    phase_cnt <= PH_LOW_SETUP;
                    op_state <= OP_IDLE;
                end

                default: begin
                    op_state <= OP_IDLE;
                    phase_cnt <= PH_LOW_SETUP;
                    scl_drv_low <= 1'b0;
                    sda_drv_low <= 1'b0;
                    busy_reg <= 1'b0;
                    done_reg <= 1'b1;
                    ack_err_reg <= 1'b0;
                    reg_addr_has_been_sent <= 1'b0;
                    cmd_read_after_ptr <= 1'b0;
                    cmd_send_pointer <= 1'b0;
                    cmd_restart_en <= 1'b0;
                    cmd_send_txdata <= 1'b0;
                    pointer_byte_reg <= 8'h00;
                end
            endcase
        end
    end

endmodule
