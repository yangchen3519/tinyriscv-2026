`include "yx_defines.vh"

module yx_id(
    input wire rst,
    input wire[`YX_InstBus] inst_i,
    input wire[`YX_InstAddrBus] inst_addr_i,
    input wire[`YX_RegBus] reg1_rdata_i,
    input wire[`YX_RegBus] reg2_rdata_i,
    input wire[`YX_RegBus] csr_rdata_i,
    input wire ex_jump_flag_i,
    output reg[`YX_RegAddrBus] reg1_raddr_o,
    output reg[`YX_RegAddrBus] reg2_raddr_o,
    output reg[`YX_MemAddrBus] csr_raddr_o,
    output reg[`YX_MemAddrBus] op1_o,
    output reg[`YX_MemAddrBus] op2_o,
    output reg[`YX_MemAddrBus] op1_jump_o,
    output reg[`YX_MemAddrBus] op2_jump_o,
    output reg[`YX_InstBus] inst_o,
    output reg[`YX_InstAddrBus] inst_addr_o,
    output reg[`YX_RegBus] reg1_rdata_o,
    output reg[`YX_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`YX_RegAddrBus] reg_waddr_o,
    output reg csr_we_o,
    output reg[`YX_RegBus] csr_rdata_o,
    output reg[`YX_MemAddrBus] csr_waddr_o
    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];

    always @ (*) begin
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        csr_rdata_o = `YX_ZeroWord;
        csr_raddr_o = `YX_ZeroWord;
        csr_waddr_o = `YX_ZeroWord;
        csr_we_o = `YX_WriteDisable;
        op1_o = `YX_ZeroWord;
        op2_o = `YX_ZeroWord;
        op1_jump_o = `YX_ZeroWord;
        op2_jump_o = `YX_ZeroWord;
        reg_we_o = `YX_WriteDisable;
        reg_waddr_o = `YX_ZeroReg;
        reg1_raddr_o = `YX_ZeroReg;
        reg2_raddr_o = `YX_ZeroReg;

        if (rst == `YX_RstDisable) begin
            case (opcode)
                `YX_INST_TYPE_I: begin
                    case (funct3)
                        `YX_INST_ADDI, `YX_INST_SLTI, `YX_INST_SLTIU, `YX_INST_XORI,
                        `YX_INST_ORI, `YX_INST_ANDI, `YX_INST_SLLI, `YX_INST_SRI: begin
                            reg_we_o = `YX_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        default: begin
                        end
                    endcase
                end
                `YX_INST_TYPE_R_M: begin
                    if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                        case (funct3)
                            `YX_INST_ADD_SUB, `YX_INST_SLL, `YX_INST_SLT, `YX_INST_SLTU,
                            `YX_INST_XOR, `YX_INST_SR, `YX_INST_OR, `YX_INST_AND: begin
                                reg_we_o = `YX_WriteEnable;
                                reg_waddr_o = rd;
                                reg1_raddr_o = rs1;
                                reg2_raddr_o = rs2;
                                op1_o = reg1_rdata_i;
                                op2_o = reg2_rdata_i;
                            end
                            default: begin
                            end
                        endcase
                    end
                end
                `YX_INST_TYPE_L: begin
                    case (funct3)
                        `YX_INST_LB, `YX_INST_LH, `YX_INST_LW, `YX_INST_LBU, `YX_INST_LHU: begin
                            reg1_raddr_o = rs1;
                            reg_we_o = `YX_WriteEnable;
                            reg_waddr_o = rd;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        default: begin
                        end
                    endcase
                end
                `YX_INST_TYPE_S: begin
                    case (funct3)
                        `YX_INST_SB, `YX_INST_SW, `YX_INST_SH: begin
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                        end
                        default: begin
                        end
                    endcase
                end
                `YX_INST_TYPE_B: begin
                    case (funct3)
                        `YX_INST_BEQ, `YX_INST_BNE, `YX_INST_BLT, `YX_INST_BGE, `YX_INST_BLTU, `YX_INST_BGEU: begin
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                            op1_jump_o = inst_addr_i;
                            op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                        end
                        default: begin
                        end
                    endcase
                end
                `YX_INST_JAL: begin
                    reg_we_o = `YX_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = inst_addr_i;
                    op2_o = 32'h4;
                    op1_jump_o = inst_addr_i;
                    op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                end
                `YX_INST_JALR: begin
                    reg_we_o = `YX_WriteEnable;
                    reg_waddr_o = rd;
                    reg1_raddr_o = rs1;
                    op1_o = inst_addr_i;
                    op2_o = 32'h4;
                    op1_jump_o = reg1_rdata_i;
                    op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
                end
                `YX_INST_LUI: begin
                    reg_we_o = `YX_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = {inst_i[31:12], 12'b0};
                end
                `YX_INST_AUIPC: begin
                    reg_we_o = `YX_WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = inst_addr_i;
                    op2_o = {inst_i[31:12], 12'b0};
                end
                `YX_INST_FENCE: begin
                    op1_jump_o = inst_addr_i;
                    op2_jump_o = 32'h4;
                end
                `YX_INST_SID: begin
                    case (funct3)
                        `YX_INST_RT_F3: begin
                            reg_we_o = `YX_WriteEnable;
                            reg_waddr_o = rd;
                        end
                        `YX_INST_IF_F3: begin
                            reg_we_o = `YX_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = 5'd31;
                            op1_o = reg1_rdata_i;
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                        default: begin
                        end
                    endcase
                end
                default: begin
                end
            endcase
        end
    end

endmodule
