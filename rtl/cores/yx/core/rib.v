`include "yx_defines.vh"

module yx_rib(
    input wire clk,
    input wire rst,

    input wire[`YX_MemAddrBus] m0_addr_i,
    input wire[`YX_MemBus] m0_data_i,
    output reg[`YX_MemBus] m0_data_o,
    input wire m0_req_i,
    input wire m0_we_i,

    input wire[`YX_MemAddrBus] m1_addr_i,
    input wire[`YX_MemBus] m1_data_i,
    output reg[`YX_MemBus] m1_data_o,
    input wire m1_req_i,
    input wire m1_we_i,

    input wire[`YX_MemAddrBus] m3_addr_i,
    input wire[`YX_MemBus] m3_data_i,
    output reg[`YX_MemBus] m3_data_o,
    input wire m3_req_i,
    input wire m3_we_i,

    output reg[`YX_MemAddrBus] s0_addr_o,
    output reg[`YX_MemBus] s0_data_o,
    input wire[`YX_MemBus] s0_data_i,
    output reg s0_we_o,
    output reg s0_req_o,

    output reg[`YX_MemAddrBus] s3_addr_o,
    output reg[`YX_MemBus] s3_data_o,
    input wire[`YX_MemBus] s3_data_i,
    output reg s3_we_o,

    output reg[`YX_MemAddrBus] s6_addr_o,
    output reg[`YX_MemBus] s6_data_o,
    input wire[`YX_MemBus] s6_data_i,
    output reg s6_we_o,

    output reg[`YX_MemAddrBus] s7_addr_o,
    output reg[`YX_MemBus] s7_data_o,
    input wire[`YX_MemBus] s7_data_i,
    output reg s7_we_o,

    output reg hold_flag_o
    );

    localparam [1:0] GRANT_M0 = 2'd0;
    localparam [1:0] GRANT_M1 = 2'd1;
    localparam [1:0] GRANT_M3 = 2'd3;

    reg[1:0] grant;
    reg[`YX_MemAddrBus] active_addr;
    reg[`YX_MemBus] active_wdata;
    reg active_we;
    reg active_req;
    reg[`YX_MemBus] active_rdata;

    always @ (*) begin
        if (m3_req_i == `YX_RIB_REQ) begin
            grant = GRANT_M3;
            hold_flag_o = `YX_HoldEnable;
        end else if (m0_req_i == `YX_RIB_REQ) begin
            grant = GRANT_M0;
            hold_flag_o = `YX_HoldEnable;
        end else begin
            grant = GRANT_M1;
            hold_flag_o = `YX_HoldDisable;
        end
    end

    always @ (*) begin
        case (grant)
            GRANT_M3: begin
                active_addr = m3_addr_i;
                active_wdata = m3_data_i;
                active_we = m3_we_i;
                active_req = m3_req_i;
            end
            GRANT_M0: begin
                active_addr = m0_addr_i;
                active_wdata = m0_data_i;
                active_we = m0_we_i;
                active_req = m0_req_i;
            end
            default: begin
                active_addr = m1_addr_i;
                active_wdata = m1_data_i;
                active_we = m1_we_i;
                active_req = m1_req_i;
            end
        endcase
    end

    always @ (*) begin
        active_rdata = `YX_ZeroWord;
        s0_addr_o = `YX_ZeroWord;
        s3_addr_o = `YX_ZeroWord;
        s6_addr_o = `YX_ZeroWord;
        s7_addr_o = `YX_ZeroWord;
        s0_data_o = `YX_ZeroWord;
        s3_data_o = `YX_ZeroWord;
        s6_data_o = `YX_ZeroWord;
        s7_data_o = `YX_ZeroWord;
        s0_req_o = `YX_RIB_NREQ;
        s0_we_o = `YX_WriteDisable;
        s3_we_o = `YX_WriteDisable;
        s6_we_o = `YX_WriteDisable;
        s7_we_o = `YX_WriteDisable;

        if (active_req == `YX_RIB_REQ) begin
            case (active_addr[31:28])
                4'h0, 4'h1, 4'hf: begin
                    s0_req_o = `YX_RIB_REQ;
                    s0_we_o = active_we;
                    s0_addr_o = active_addr;
                    s0_data_o = active_wdata;
                    active_rdata = s0_data_i;
                end
                4'h3: begin
                    s3_we_o = active_we;
                    s3_addr_o = {4'h0, active_addr[27:0]};
                    s3_data_o = active_wdata;
                    active_rdata = s3_data_i;
                end
                4'h6: begin
                    s6_we_o = active_we;
                    s6_addr_o = {4'h0, active_addr[27:0]};
                    s6_data_o = active_wdata;
                    active_rdata = s6_data_i;
                end
                4'h7: begin
                    s7_we_o = active_we;
                    s7_addr_o = {4'h0, active_addr[27:0]};
                    s7_data_o = active_wdata;
                    active_rdata = s7_data_i;
                end
                default: begin
                    active_rdata = `YX_ZeroWord;
                end
            endcase
        end
    end

    always @ (*) begin
        m0_data_o = `YX_ZeroWord;
        m1_data_o = `YX_INST_NOP;
        m3_data_o = `YX_ZeroWord;
        case (grant)
            GRANT_M0: m0_data_o = active_rdata;
            GRANT_M1: m1_data_o = (active_req == `YX_RIB_REQ) ? active_rdata : `YX_INST_NOP;
            GRANT_M3: m3_data_o = active_rdata;
            default: begin
            end
        endcase
    end

endmodule
