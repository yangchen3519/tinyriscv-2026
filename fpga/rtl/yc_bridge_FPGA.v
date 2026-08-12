// bridge@FPGA侧
// 1. 接收来自 core 侧的 6-byte 数据包
// 2. 访问外部 ROM/RAM，并在读操作时按字节回传 32-bit 数据

`include "yc_defines.vh"

module yc_bridge_FPGA(

    input wire clk,
    input wire rst,

    // bridge@core side
    input wire rx_valid_i,
    input wire[7:0] rx_data_i,
    output reg[7:0] tx_data_o,
    output reg tx_valid_o,

    // external rom
    output reg rom_we_o,
    output reg[`YC_RomAddrBus] rom_addr_o,
    output reg[`YC_MemBus] rom_data_o,
    input wire[`YC_MemBus] rom_data_i,

    // external ram
    output reg ram_we_o,
    output reg[`YC_RamAddrBus] ram_addr_o,
    output reg[`YC_MemBus] ram_data_o,
    input wire[`YC_MemBus] ram_data_i

    );

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] RX_ADDR = 3'd1;
    localparam [2:0] RX_DATA = 3'd2;
    localparam [2:0] WR_MEM  = 3'd3;
    localparam [2:0] TX_DATA = 3'd4;

    reg[2:0] state;
    reg[1:0] byte_cnt;
    reg trans_we;
    reg trans_target;
    reg[`YC_RomAddrBus] trans_addr;
    reg[`YC_MemBus] trans_wdata;
    reg[`YC_MemBus] trans_rdata;

    wire[`YC_MemBus] mem_rdata;

    assign mem_rdata = (trans_target == 1'b1) ? ram_data_i : rom_data_i;

    always @ (*) begin
        tx_valid_o = 1'b0;
        tx_data_o = 8'h0;
        rom_we_o = `YC_WriteDisable;
        rom_addr_o = trans_addr;
        rom_data_o = trans_wdata;
        ram_we_o = `YC_WriteDisable;
        ram_addr_o = trans_addr[`YC_RamAddrBus];
        ram_data_o = trans_wdata;

        if (state == WR_MEM) begin
            if (trans_target == 1'b1) begin
                ram_we_o = `YC_WriteEnable;
            end else begin
                rom_we_o = `YC_WriteEnable;
            end
        end

        if (state == TX_DATA) begin
            tx_valid_o = 1'b1;
            case (byte_cnt)
                2'd0: tx_data_o = mem_rdata[7:0];
                2'd1: tx_data_o = trans_rdata[15:8];
                2'd2: tx_data_o = trans_rdata[23:16];
                default: tx_data_o = trans_rdata[31:24];
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            state <= IDLE;
            byte_cnt <= 2'b00;
            trans_we <= `YC_WriteDisable;
            trans_target <= 1'b0;
            trans_addr <= 8'h0;
            trans_wdata <= `YC_ZeroWord;
            trans_rdata <= `YC_ZeroWord;
        end else begin
            case (state)
                IDLE: begin
                    if (rx_valid_i == 1'b1) begin
                        byte_cnt <= 2'b00;
                        trans_we <= rx_data_i[7];
                        trans_target <= rx_data_i[6];
                        state <= RX_ADDR;
                    end
                end

                RX_ADDR: begin
                    if (rx_valid_i == 1'b1) begin
                        byte_cnt <= 2'b00;
                        trans_addr <= rx_data_i;
                        if (trans_we == `YC_WriteEnable) begin
                            trans_wdata <= `YC_ZeroWord;
                            state <= RX_DATA;
                        end else begin
                            state <= TX_DATA;
                        end
                    end
                end

                RX_DATA: begin
                    if (rx_valid_i == 1'b1) begin
                        case (byte_cnt)
                            2'd0: trans_wdata[7:0] <= rx_data_i;
                            2'd1: trans_wdata[15:8] <= rx_data_i;
                            2'd2: trans_wdata[23:16] <= rx_data_i;
                            default: trans_wdata[31:24] <= rx_data_i;
                        endcase

                        if (byte_cnt == 2'd3) begin
                            byte_cnt <= 2'b00;
                            state <= WR_MEM;
                        end else begin
                            byte_cnt <= byte_cnt + 1'b1;
                        end
                    end
                end

                WR_MEM: begin
                    if (rx_valid_i == 1'b1) begin
                        byte_cnt <= 2'b00;
                        trans_we <= rx_data_i[7];
                        trans_target <= rx_data_i[6];
                        state <= RX_ADDR;
                    end else begin
                        state <= IDLE;
                    end
                end

                TX_DATA: begin
                    if (byte_cnt == 2'd0) begin
                        trans_rdata <= mem_rdata;
                    end

                    if (byte_cnt == 2'd3) begin
                        byte_cnt <= 2'b00;
                        state <= IDLE;
                    end else begin
                        byte_cnt <= byte_cnt + 1'b1;
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
