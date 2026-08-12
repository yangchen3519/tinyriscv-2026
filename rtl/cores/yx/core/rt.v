`include "yx_defines.vh"

module yx_rt(

    input wire clk,
    input wire rst,

    input wire rt_req_i,
    input wire[`YX_InstAddrBus] inst_addr_i,
    input wire[`YX_RegAddrBus] reg_waddr_i,
    input wire[`YX_MemBus] mem_rdata_i,

    output reg[`YX_RegBus] reg_wdata_o,
    output reg reg_we_o,
    output reg[`YX_RegAddrBus] reg_waddr_o,
    output reg[`YX_MemBus] mem_wdata_o,
    output reg[`YX_MemAddrBus] mem_raddr_o,
    output reg[`YX_MemAddrBus] mem_waddr_o,
    output reg mem_we_o,
    output reg mem_req_o,
    output wire hold_flag_o

    );

    localparam I2C_TEMP = 32'h70040000;

    localparam S_IDLE      = 3'b000;
    localparam S_START     = 3'b001;
    localparam S_POLL      = 3'b010;
    localparam S_READ      = 3'b011;
    localparam S_DONE      = 3'b100;

    reg[2:0] state;
    reg rt_done;
    reg[`YX_InstAddrBus] done_inst_addr;
    reg[`YX_RegAddrBus] saved_reg_waddr;
    reg[15:0] temp_raw;

    wire start_req;

    assign start_req = rt_req_i & (~rt_done | (inst_addr_i != done_inst_addr));
    assign hold_flag_o = (state != S_IDLE) | start_req;

    always @ (*) begin
        mem_wdata_o = `YX_ZeroWord;
        mem_raddr_o = I2C_TEMP;
        mem_waddr_o = I2C_TEMP;
        mem_we_o = `YX_WriteDisable;
        mem_req_o = `YX_RIB_NREQ;
        reg_wdata_o = `YX_ZeroWord;
        reg_we_o = `YX_WriteDisable;
        reg_waddr_o = `YX_ZeroReg;

        case (state)
            S_IDLE: begin
                if (start_req == 1'b1) begin
                    mem_req_o = `YX_RIB_REQ;
                    mem_we_o = `YX_WriteEnable;
                end
            end
            S_START: begin
                mem_req_o = `YX_RIB_REQ;
                mem_we_o = `YX_WriteEnable;
            end
            S_POLL: begin
                mem_req_o = `YX_RIB_REQ;
            end
            S_READ: begin
                mem_req_o = `YX_RIB_REQ;
            end
            S_DONE: begin
                reg_wdata_o = {24'h0, temp_raw[14:7]};
                reg_we_o = `YX_WriteEnable;
                reg_waddr_o = saved_reg_waddr;
            end
            default: begin
                mem_req_o = `YX_RIB_NREQ;
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            state <= S_IDLE;
            rt_done <= 1'b0;
            done_inst_addr <= `YX_ZeroWord;
            saved_reg_waddr <= `YX_ZeroReg;
            temp_raw <= 16'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start_req == 1'b1) begin
                        saved_reg_waddr <= reg_waddr_i;
                        state <= S_START;
                    end
                end
                S_START: begin
                    state <= S_POLL;
                end
                S_POLL: begin
                    if (mem_rdata_i[31] == 1'b0) begin
                        state <= S_READ;
                    end
                end
                S_READ: begin
                    temp_raw <= mem_rdata_i[15:0];
                    state <= S_DONE;
                end
                S_DONE: begin
                    rt_done <= 1'b1;
                    done_inst_addr <= inst_addr_i;
                    state <= S_IDLE;
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule
