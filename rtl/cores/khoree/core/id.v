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

`include "khoree_defines.vh"

// ????
// ???????
module khoree_id(

	input wire rst,

    // from if_id
    input wire[`KHOREE_InstBus] inst_i,             // ????
    input wire[`KHOREE_InstAddrBus] inst_addr_i,    // ????
    input wire prdt_taken_i,

    // from regs
    input wire[`KHOREE_RegBus] reg1_rdata_i,        // ?????1????
    input wire[`KHOREE_RegBus] reg2_rdata_i,        // ?????2????

    // from ex
    input wire ex_jump_flag_i,               // ????

    // to regs
    output reg[`KHOREE_RegAddrBus] reg1_raddr_o,    // ??????1??
    output reg[`KHOREE_RegAddrBus] reg2_raddr_o,    // ??????2??

    // to ex
    output wire prdt_taken_o,
    output reg[`KHOREE_MemAddrBus] op1_o,
    output reg[`KHOREE_MemAddrBus] op2_o,
    output reg[`KHOREE_MemAddrBus] op1_jump_o,
    output reg[`KHOREE_MemAddrBus] op2_jump_o,
    output reg[`KHOREE_InstBus] inst_o,             // ????
    output reg[`KHOREE_InstAddrBus] inst_addr_o,    // ????
    output reg[`KHOREE_RegBus] reg1_rdata_o,        // ?????1??
    output reg[`KHOREE_RegBus] reg2_rdata_o,        // ?????2??
    output reg reg_we_o,                     // ????????
    output reg[`KHOREE_RegAddrBus] reg_waddr_o      // ????????

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];

    wire[11:0] imm = inst_i[31:20];

    assign prdt_taken_o = prdt_taken_i;

    always @ (*) begin
        inst_o = inst_i;
        inst_addr_o = inst_addr_i;
        reg1_rdata_o = reg1_rdata_i;
        reg2_rdata_o = reg2_rdata_i;
        op1_o = `KHOREE_ZeroWord;
        op2_o = `KHOREE_ZeroWord;
        op1_jump_o = `KHOREE_ZeroWord;
        op2_jump_o = `KHOREE_ZeroWord;

        case (opcode)
            `KHOREE_INST_TYPE_EXT: begin
                case (funct3)
                    `KHOREE_INST_SID: begin
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        op1_o = 32'h30000000;
                        op2_o = `KHOREE_ZeroReg;
                    end
                    `KHOREE_INST_RT: begin
                        reg_we_o = `KHOREE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        op1_o = 32'h70030000;
                        op2_o = `KHOREE_ZeroReg;
                    end
                    `KHOREE_INST_IF: begin
                        reg_we_o = `KHOREE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'd31;
                        op1_o = reg1_rdata_i;
                        if (imm == 12'b0) begin
                            op2_o = reg2_rdata_i;
                        end
                        else begin
                            op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                        end
                    end
                    default: begin
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                        reg1_raddr_o = `KHOREE_ZeroReg;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                    end
                endcase

            end
            `KHOREE_INST_TYPE_I: begin
                case (funct3)
                    `KHOREE_INST_ADDI, `KHOREE_INST_SLTI, `KHOREE_INST_SLTIU, `KHOREE_INST_XORI, `KHOREE_INST_ORI, `KHOREE_INST_ANDI, `KHOREE_INST_SLLI, `KHOREE_INST_SRI: begin
                        reg_we_o = `KHOREE_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                        reg1_raddr_o = `KHOREE_ZeroReg;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                    end
                endcase
            end
            `KHOREE_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `KHOREE_INST_ADD_SUB, `KHOREE_INST_SLL, `KHOREE_INST_SLT, `KHOREE_INST_SLTU, `KHOREE_INST_XOR, `KHOREE_INST_SR, `KHOREE_INST_OR, `KHOREE_INST_AND: begin
                            reg_we_o = `KHOREE_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `KHOREE_WriteDisable;
                            reg_waddr_o = `KHOREE_ZeroReg;
                            reg1_raddr_o = `KHOREE_ZeroReg;
                            reg2_raddr_o = `KHOREE_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `KHOREE_WriteDisable;
                    reg_waddr_o = `KHOREE_ZeroReg;
                    reg1_raddr_o = `KHOREE_ZeroReg;
                    reg2_raddr_o = `KHOREE_ZeroReg;
                end
            end
            `KHOREE_INST_TYPE_L: begin
                case (funct3)
                    `KHOREE_INST_LB, `KHOREE_INST_LH, `KHOREE_INST_LW, `KHOREE_INST_LBU, `KHOREE_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        reg_we_o = `KHOREE_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `KHOREE_ZeroReg;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                    end
                endcase
            end
            `KHOREE_INST_TYPE_S: begin
                case (funct3)
                    `KHOREE_INST_SB, `KHOREE_INST_SW, `KHOREE_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `KHOREE_ZeroReg;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                    end
                endcase
            end
            `KHOREE_INST_TYPE_B: begin
                case (funct3)
                    `KHOREE_INST_BEQ, `KHOREE_INST_BNE, `KHOREE_INST_BLT, `KHOREE_INST_BGE, `KHOREE_INST_BLTU, `KHOREE_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = inst_i[31] ? 32'h4 : {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `KHOREE_ZeroReg;
                        reg2_raddr_o = `KHOREE_ZeroReg;
                        reg_we_o = `KHOREE_WriteDisable;
                        reg_waddr_o = `KHOREE_ZeroReg;
                    end
                endcase
            end
            `KHOREE_INST_JAL: begin
                reg_we_o = `KHOREE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = `KHOREE_ZeroWord;
                op2_jump_o = `KHOREE_ZeroWord;
            end
            `KHOREE_INST_JALR: begin
                reg_we_o = `KHOREE_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `KHOREE_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `KHOREE_INST_LUI: begin
                reg_we_o = `KHOREE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `KHOREE_ZeroWord;
            end
            `KHOREE_INST_AUIPC: begin
                reg_we_o = `KHOREE_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `KHOREE_INST_NOP_OP: begin
                reg_we_o = `KHOREE_WriteDisable;
                reg_waddr_o = `KHOREE_ZeroReg;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
            end
            `KHOREE_INST_FENCE: begin
                reg_we_o = `KHOREE_WriteDisable;
                reg_waddr_o = `KHOREE_ZeroReg;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            default: begin
                reg_we_o = `KHOREE_WriteDisable;
                reg_waddr_o = `KHOREE_ZeroReg;
                reg1_raddr_o = `KHOREE_ZeroReg;
                reg2_raddr_o = `KHOREE_ZeroReg;
            end
        endcase
    end

endmodule
