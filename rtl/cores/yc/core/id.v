 /*                                                                      
 Copyright 2019 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`include "yc_defines.vh"

module yc_id(

	input wire rst,

    input wire[`YC_InstBus] inst_i,
    input wire[`YC_InstAddrBus] inst_addr_i,

    input wire[`YC_RegBus] reg1_rdata_i,
    input wire[`YC_RegBus] reg2_rdata_i,

    input wire ex_jump_flag_i,

    output reg[`YC_RegAddrBus] reg1_raddr_o,
    output reg[`YC_RegAddrBus] reg2_raddr_o,

    output reg[`YC_MemAddrBus] op1_o,
    output reg[`YC_MemAddrBus] op2_o,
    output reg[`YC_MemAddrBus] op1_jump_o,
    output reg[`YC_MemAddrBus] op2_jump_o,
    output reg[`YC_InstBus] inst_o,
    output reg[`YC_InstAddrBus] inst_addr_o,
    output reg[`YC_RegBus] reg1_rdata_o,
    output reg[`YC_RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`YC_RegAddrBus] reg_waddr_o

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
        op1_o = `YC_ZeroWord;
        op2_o = `YC_ZeroWord;
        op1_jump_o = `YC_ZeroWord;
        op2_jump_o = `YC_ZeroWord;

        case (opcode)
            `YC_INST_TYPE_I: begin
                case (funct3)
                    `YC_INST_ADDI, `YC_INST_SLTI, `YC_INST_SLTIU, `YC_INST_XORI, `YC_INST_ORI, `YC_INST_ANDI, `YC_INST_SLLI, `YC_INST_SRI: begin
                        reg_we_o = `YC_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `YC_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                    end
                endcase
            end
            `YC_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `YC_INST_ADD_SUB, `YC_INST_SLL, `YC_INST_SLT, `YC_INST_SLTU, `YC_INST_XOR, `YC_INST_SR, `YC_INST_OR, `YC_INST_AND: begin
                            reg_we_o = `YC_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `YC_WriteDisable;
                            reg_waddr_o = `YC_ZeroReg;
                            reg1_raddr_o = `YC_ZeroReg;
                            reg2_raddr_o = `YC_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `YC_WriteDisable;
                    reg_waddr_o = `YC_ZeroReg;
                    reg1_raddr_o = `YC_ZeroReg;
                    reg2_raddr_o = `YC_ZeroReg;
                end
            end
            `YC_INST_TYPE_L: begin
                case (funct3)
                    `YC_INST_LB, `YC_INST_LH, `YC_INST_LW, `YC_INST_LBU, `YC_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                    end
                endcase
            end
            `YC_INST_TYPE_S: begin
                case (funct3)
                    `YC_INST_SB, `YC_INST_SW, `YC_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                    end
                endcase
            end
            `YC_INST_TYPE_B: begin
                case (funct3)
                    `YC_INST_BEQ, `YC_INST_BNE, `YC_INST_BLT, `YC_INST_BGE, `YC_INST_BLTU, `YC_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                    end
                endcase
            end
            `YC_INST_TYPE_A: begin
                case (funct3)
                    `YC_INST_sID: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                        op1_o = `YC_ZeroWord;
                        op2_o = `YC_ZeroWord;
                    end
                    `YC_INST_rT: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = `YC_ZeroWord;
                        op2_o = `YC_ZeroWord;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = 32'h4;
                    end
                    `YC_INST_if: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'b11111;
                        reg_we_o = `YC_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                    end
                    default: begin
                        reg1_raddr_o = `YC_ZeroReg;
                        reg2_raddr_o = `YC_ZeroReg;
                        reg_we_o = `YC_WriteDisable;
                        reg_waddr_o = `YC_ZeroReg;
                    end
                endcase
            end
            `YC_INST_JAL: begin
                reg_we_o = `YC_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `YC_INST_JALR: begin
                reg_we_o = `YC_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `YC_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `YC_INST_LUI: begin
                reg_we_o = `YC_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `YC_ZeroWord;
            end
            `YC_INST_AUIPC: begin
                reg_we_o = `YC_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `YC_INST_NOP_OP: begin
                reg_we_o = `YC_WriteDisable;
                reg_waddr_o = `YC_ZeroReg;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
            end
            `YC_INST_FENCE: begin
                reg_we_o = `YC_WriteDisable;
                reg_waddr_o = `YC_ZeroReg;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            default: begin
                reg_we_o = `YC_WriteDisable;
                reg_waddr_o = `YC_ZeroReg;
                reg1_raddr_o = `YC_ZeroReg;
                reg2_raddr_o = `YC_ZeroReg;
            end
        endcase
    end

endmodule