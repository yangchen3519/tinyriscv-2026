// bridge_core
// 1. Receive RIB requests and serialize them into the 6-byte bridge format.
// 2. Receive 4-byte read data from bridge_FPGA and merge it back to 32-bit data.

`include "yc_defines.vh"

module yc_bridge_core(

    input wire clk,
    input wire rst,

    // RIB side
    input wire req_i,
    input wire we_i,
    input wire[`YC_MemAddrBus] addr_i,
    input wire[`YC_MemBus] data_i,
    output reg[`YC_MemBus] data_o,
    output reg ack_o,
    output wire hold_flag_o,

    // bridge_FPGA side
    output reg[7:0] tx_data_o,
    output reg tx_valid_o,
    input wire[7:0] rx_data_i

    );

    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] TX_CMD  = 3'd1;
    localparam [2:0] TX_ADDR = 3'd2;
    localparam [2:0] TX_DATA = 3'd3;
    localparam [2:0] RX_DATA = 3'd4;
    localparam [2:0] RX_WAIT = 3'd5;

    localparam [3:0] RAM_ADDR_TOP = 4'h1;

    reg[2:0] state;
    reg[1:0] byte_cnt;
    reg trans_we;
    reg trans_target;
    reg[`YC_RomAddrBus] trans_addr;
    reg[`YC_MemBus] trans_wdata;
    reg[`YC_MemBus] trans_rdata;

    // seen_* suppresses re-accepting the same request while req_i stays asserted.
    reg seen_valid;
    reg seen_we;
    reg seen_target;
    reg[`YC_RomAddrBus] seen_addr;
    reg[`YC_MemBus] seen_wdata;

    // One-entry skid buffer for the next request.
    reg next_req_valid;
    reg next_req_we;
    reg next_req_target;
    reg[`YC_RomAddrBus] next_req_addr;
    reg[`YC_MemBus] next_req_wdata;

    wire is_ram_req;
    wire input_match_seen;
    wire new_req;
    wire[`YC_RomAddrBus] phy_addr;
    wire[7:0] cmd_byte;
    wire trans_done;
    wire current_req_matches_trans;
    wire start_req_from_bus;
    wire capture_next_req;

    assign is_ram_req = (addr_i[31:28] == RAM_ADDR_TOP);
    assign phy_addr = is_ram_req ? {4'h0, addr_i[5:2]} : addr_i[9:2];
    assign input_match_seen = (seen_valid == 1'b1) &&
                              (we_i === seen_we) &&
                              (is_ram_req === seen_target) &&
                              (phy_addr === seen_addr) &&
                              ((we_i !== `YC_WriteEnable) || (data_i === seen_wdata));
    assign new_req = (req_i == `YC_RIB_REQ) && ((seen_valid == 1'b0) || (input_match_seen == 1'b0));
    assign cmd_byte = {trans_we, trans_target, 6'b0};
    assign trans_done = (((state == TX_DATA) || (state == RX_DATA)) && (byte_cnt == 2'd3));
    assign current_req_matches_trans = (req_i == `YC_RIB_REQ) &&
                                       (we_i === trans_we) &&
                                       (is_ram_req === trans_target) &&
                                       (phy_addr === trans_addr) &&
                                       ((trans_we !== `YC_WriteEnable) || (data_i === trans_wdata));

    // If the current transfer ends this cycle and the skid buffer is empty,
    // the module can immediately consume the visible bus request.
    assign start_req_from_bus = (((state == IDLE) || (trans_done == 1'b1)) &&
                                 (next_req_valid == 1'b0) &&
                                 (new_req == 1'b1));

    // Buffer only requests observed before the current transfer completes.
    assign capture_next_req = ((state != IDLE) &&
                               (trans_done == 1'b0) &&
                               (next_req_valid == 1'b0) &&
                               (new_req == 1'b1));

    assign hold_flag_o = (state != IDLE) || next_req_valid || new_req;

    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            state <= IDLE;
            byte_cnt <= 2'b00;
            trans_we <= `YC_WriteDisable;
            trans_target <= 1'b0;
            trans_addr <= 8'h0;
            trans_wdata <= `YC_ZeroWord;
            trans_rdata <= `YC_ZeroWord;
            seen_valid <= 1'b0;
            seen_we <= `YC_WriteDisable;
            seen_target <= 1'b0;
            seen_addr <= 8'h0;
            seen_wdata <= `YC_ZeroWord;
            next_req_valid <= 1'b0;
            next_req_we <= `YC_WriteDisable;
            next_req_target <= 1'b0;
            next_req_addr <= 8'h0;
            next_req_wdata <= `YC_ZeroWord;
            data_o <= `YC_ZeroWord;
            ack_o <= `YC_RIB_NACK;
            tx_data_o <= 8'h0;
            tx_valid_o <= 1'b0;
        end else begin
            ack_o <= `YC_RIB_NACK;
            tx_valid_o <= 1'b0;

            if (req_i != `YC_RIB_REQ) begin
                seen_valid <= 1'b0;
            end

            if (capture_next_req == 1'b1) begin
                seen_valid <= 1'b1;
                seen_we <= we_i;
                seen_target <= is_ram_req;
                seen_addr <= phy_addr;
                seen_wdata <= data_i;
                next_req_valid <= 1'b1;
                next_req_we <= we_i;
                next_req_target <= is_ram_req;
                next_req_addr <= phy_addr;
                next_req_wdata <= data_i;
            end

            case (state)
                IDLE: begin
                    tx_data_o <= 8'h0;
                    if (next_req_valid == 1'b1) begin
                        byte_cnt <= 2'b00;
                        next_req_valid <= 1'b0;
                        trans_we <= next_req_we;
                        trans_target <= next_req_target;
                        trans_addr <= next_req_addr;
                        trans_wdata <= next_req_wdata;
                        state <= TX_CMD;
                    end else if (start_req_from_bus == 1'b1) begin
                        byte_cnt <= 2'b00;
                        seen_valid <= 1'b1;
                        seen_we <= we_i;
                        seen_target <= is_ram_req;
                        seen_addr <= phy_addr;
                        seen_wdata <= data_i;
                        trans_we <= we_i;
                        trans_target <= is_ram_req;
                        trans_addr <= phy_addr;
                        trans_wdata <= data_i;
                        state <= TX_CMD;
                    end
                end

                TX_CMD: begin
                    tx_valid_o <= 1'b1;
                    tx_data_o <= cmd_byte;
                    state <= TX_ADDR;
                end

                TX_ADDR: begin
                    tx_valid_o <= 1'b1;
                    tx_data_o <= trans_addr;
                    byte_cnt <= 2'b00;
                    if (trans_we == `YC_WriteEnable) begin
                        state <= TX_DATA;
                    end else begin
                        state <= RX_WAIT;
                    end
                end

                RX_WAIT: begin
                    byte_cnt <= 2'b00;
                    state <= RX_DATA;
                end

                TX_DATA: begin
                    tx_valid_o <= 1'b1;
                    case (byte_cnt)
                        2'd0: tx_data_o <= trans_wdata[7:0];
                        2'd1: tx_data_o <= trans_wdata[15:8];
                        2'd2: tx_data_o <= trans_wdata[23:16];
                        default: tx_data_o <= trans_wdata[31:24];
                    endcase

                    if (byte_cnt == 2'd3) begin
                        byte_cnt <= 2'b00;
                        ack_o <= current_req_matches_trans ? `YC_RIB_ACK : `YC_RIB_NACK;
                        if (next_req_valid == 1'b1) begin
                            next_req_valid <= 1'b0;
                            trans_we <= next_req_we;
                            trans_target <= next_req_target;
                            trans_addr <= next_req_addr;
                            trans_wdata <= next_req_wdata;
                            state <= TX_CMD;
                        end else if (start_req_from_bus == 1'b1) begin
                            seen_valid <= 1'b1;
                            seen_we <= we_i;
                            seen_target <= is_ram_req;
                            seen_addr <= phy_addr;
                            seen_wdata <= data_i;
                            trans_we <= we_i;
                            trans_target <= is_ram_req;
                            trans_addr <= phy_addr;
                            trans_wdata <= data_i;
                            state <= TX_CMD;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        byte_cnt <= byte_cnt + 1'b1;
                    end
                end

                RX_DATA: begin
                    case (byte_cnt)
                        2'd0: trans_rdata[7:0] <= rx_data_i;
                        2'd1: trans_rdata[15:8] <= rx_data_i;
                        2'd2: trans_rdata[23:16] <= rx_data_i;
                        default: trans_rdata[31:24] <= rx_data_i;
                    endcase

                    if (byte_cnt == 2'd3) begin
                        byte_cnt <= 2'b00;
                        data_o <= {rx_data_i, trans_rdata[23:0]};
                        ack_o <= current_req_matches_trans ? `YC_RIB_ACK : `YC_RIB_NACK;
                        if (next_req_valid == 1'b1) begin
                            next_req_valid <= 1'b0;
                            trans_we <= next_req_we;
                            trans_target <= next_req_target;
                            trans_addr <= next_req_addr;
                            trans_wdata <= next_req_wdata;
                            state <= TX_CMD;
                        end else if (start_req_from_bus == 1'b1) begin
                            seen_valid <= 1'b1;
                            seen_we <= we_i;
                            seen_target <= is_ram_req;
                            seen_addr <= phy_addr;
                            seen_wdata <= data_i;
                            trans_we <= we_i;
                            trans_target <= is_ram_req;
                            trans_addr <= phy_addr;
                            trans_wdata <= data_i;
                            state <= TX_CMD;
                        end else begin
                            state <= IDLE;
                        end
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
