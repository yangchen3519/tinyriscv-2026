`include "yx_defines.vh"

module yx_sid(

    input wire clk,
    input wire rst,

    input wire sid_req_i,
    input wire[`YX_InstAddrBus] inst_addr_i,
    input wire[`YX_MemBus] mem_rdata_i,

    output reg[`YX_MemBus] mem_wdata_o,
    output reg[`YX_MemAddrBus] mem_raddr_o,
    output reg[`YX_MemAddrBus] mem_waddr_o,
    output reg mem_we_o,
    output reg mem_req_o,
    output wire hold_flag_o

    );

    localparam UART_STATUS = 32'h30000004;
    localparam UART_TXDATA = 32'h3000000c;

    localparam S_IDLE        = 2'b00;
    localparam S_READ_STATUS = 2'b01;
    localparam S_WRITE_DATA  = 2'b10;
    localparam S_WRITE_GAP   = 2'b11;

    reg[1:0] state;
    reg[3:0] send_index;
    reg sid_done;
    reg[`YX_InstAddrBus] done_inst_addr;

    wire tx_idle;
    wire start_req;

    assign tx_idle = (mem_rdata_i[0] == 1'b0);
    assign start_req = sid_req_i & (~sid_done | (inst_addr_i != done_inst_addr));
    assign hold_flag_o = (state != S_IDLE) | start_req;

    always @ (*) begin
        case (send_index)
            4'd0: mem_wdata_o = 32'h00000032; // '2'
            4'd1: mem_wdata_o = 32'h00000030; // '0'
            4'd2: mem_wdata_o = 32'h00000032; // '2'
            4'd3: mem_wdata_o = 32'h00000035; // '5'
            4'd4: mem_wdata_o = 32'h00000032; // '2'
            4'd5: mem_wdata_o = 32'h00000031; // '1'
            4'd6: mem_wdata_o = 32'h00000030; // '0'
            4'd7: mem_wdata_o = 32'h00000038; // '8'
            4'd8: mem_wdata_o = 32'h00000039; // '9'
            default: mem_wdata_o = 32'h00000035; // '5'
        endcase
    end

    always @ (*) begin
        mem_raddr_o = UART_STATUS;
        mem_waddr_o = UART_TXDATA;
        mem_we_o = `YX_WriteDisable;
        mem_req_o = `YX_RIB_NREQ;

        case (state)
            S_IDLE: begin
                if (start_req == 1'b1) begin
                    mem_req_o = `YX_RIB_REQ;
                end
            end
            S_READ_STATUS: begin
                mem_req_o = `YX_RIB_REQ;
            end
            S_WRITE_DATA: begin
                mem_req_o = `YX_RIB_REQ;
                mem_we_o = `YX_WriteEnable;
            end
            default: begin
                mem_req_o = `YX_RIB_NREQ;
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            state <= S_IDLE;
            send_index <= 4'd0;
            sid_done <= 1'b0;
            done_inst_addr <= `YX_ZeroWord;
        end else begin
            case (state)
                S_IDLE: begin
                    send_index <= 4'd0;
                    if (start_req == 1'b1) begin
                        state <= S_READ_STATUS;
                    end
                end
                S_READ_STATUS: begin
                    if (tx_idle == 1'b1) begin
                        state <= S_WRITE_DATA;
                    end
                end
                S_WRITE_DATA: begin
                        if (send_index == 4'd9) begin
                            state <= S_IDLE;
                            sid_done <= 1'b1;
                            done_inst_addr <= inst_addr_i;
                        end else begin
                            send_index <= send_index + 4'd1;
                            state <= S_WRITE_GAP;
                        end
                end
                S_WRITE_GAP: begin
                    state <= S_READ_STATUS;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
