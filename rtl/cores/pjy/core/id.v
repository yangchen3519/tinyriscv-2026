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

`include "pjy_defines.vh"

// 译码模块
// 纯组合逻辑电路
module pjy_id(

	input wire rst,

    // from if_id
    input wire[`PJY_InstBus] inst_i,             // 指令内容
    input wire[`PJY_InstAddrBus] inst_addr_i,    // 指令地址

    // from regs
    input wire[`PJY_RegBus] reg1_rdata_i,        // 通用寄存器1输入数据
    input wire[`PJY_RegBus] reg2_rdata_i,        // 通用寄存器2输入数据

    // from csr reg
    input wire[`PJY_RegBus] csr_rdata_i,         // CSR寄存器输入数据

    // from ex
    input wire ex_jump_flag_i,               // 跳转标志

    // to regs
    output reg[`PJY_RegAddrBus] reg1_raddr_o,    // 读通用寄存器1地址
    output reg[`PJY_RegAddrBus] reg2_raddr_o,    // 读通用寄存器2地址

    // to csr reg
    output reg[`PJY_MemAddrBus] csr_raddr_o,     // 读CSR寄存器地址

    // to ex
    output reg[`PJY_MemAddrBus] op1_o,
    output reg[`PJY_MemAddrBus] op2_o,
    output reg[`PJY_MemAddrBus] op1_jump_o,
    output reg[`PJY_MemAddrBus] op2_jump_o,
    output reg[`PJY_InstBus] inst_o,             // 指令内容
    output reg[`PJY_InstAddrBus] inst_addr_o,    // 指令地址
    output reg[`PJY_RegBus] reg1_rdata_o,        // 通用寄存器1数据
    output reg[`PJY_RegBus] reg2_rdata_o,        // 通用寄存器2数据
    output reg reg_we_o,                     // 写通用寄存器标志
    output reg[`PJY_RegAddrBus] reg_waddr_o,     // 写通用寄存器地址
    output reg csr_we_o,                     // 写CSR寄存器标志
    output reg[`PJY_RegBus] csr_rdata_o,         // CSR寄存器数据
    output reg[`PJY_MemAddrBus] csr_waddr_o      // 写CSR寄存器地址

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
        csr_rdata_o = csr_rdata_i;
        csr_raddr_o = `PJY_ZeroWord;
        csr_waddr_o = `PJY_ZeroWord;
        csr_we_o = `PJY_WriteDisable;
        op1_o = `PJY_ZeroWord;
        op2_o = `PJY_ZeroWord;
        op1_jump_o = `PJY_ZeroWord;
        op2_jump_o = `PJY_ZeroWord;

        case (opcode)
            `PJY_INST_TYPE_I: begin
                case (funct3)
                    `PJY_INST_ADDI, `PJY_INST_SLTI, `PJY_INST_SLTIU, `PJY_INST_XORI, `PJY_INST_ORI, `PJY_INST_ANDI, `PJY_INST_SLLI, `PJY_INST_SRI: begin
                        reg_we_o = `PJY_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `PJY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                    end
                endcase
            end
            `PJY_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `PJY_INST_ADD_SUB, `PJY_INST_SLL, `PJY_INST_SLT, `PJY_INST_SLTU, `PJY_INST_XOR, `PJY_INST_SR, `PJY_INST_OR, `PJY_INST_AND: begin
                            reg_we_o = `PJY_WriteEnable;
                            reg_waddr_o = rd;
                            reg1_raddr_o = rs1;
                            reg2_raddr_o = rs2;
                            op1_o = reg1_rdata_i;
                            op2_o = reg2_rdata_i;
                        end
                        default: begin
                            reg_we_o = `PJY_WriteDisable;
                            reg_waddr_o = `PJY_ZeroReg;
                            reg1_raddr_o = `PJY_ZeroReg;
                            reg2_raddr_o = `PJY_ZeroReg;
                        end
                    endcase
                end else begin
                    reg_we_o = `PJY_WriteDisable;
                    reg_waddr_o = `PJY_ZeroReg;
                    reg1_raddr_o = `PJY_ZeroReg;
                    reg2_raddr_o = `PJY_ZeroReg;
                end
            end
            `PJY_INST_TYPE_L: begin
                case (funct3)
                    `PJY_INST_LB, `PJY_INST_LH, `PJY_INST_LW, `PJY_INST_LBU, `PJY_INST_LHU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = `PJY_ZeroReg;
                        reg_we_o = `PJY_WriteEnable;
                        reg_waddr_o = rd;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                    end
                endcase
            end
            `PJY_INST_TYPE_S: begin
                case (funct3)
                    `PJY_INST_SB, `PJY_INST_SW, `PJY_INST_SH: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                    end
                    default: begin
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                    end
                endcase
            end
            `PJY_INST_TYPE_B: begin
                case (funct3)
                    `PJY_INST_BEQ, `PJY_INST_BNE, `PJY_INST_BLT, `PJY_INST_BGE, `PJY_INST_BLTU, `PJY_INST_BGEU: begin
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        op1_jump_o = inst_addr_i;
                        op2_jump_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                    end
                    default: begin
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                    end
                endcase
            end
            `PJY_INST_JAL: begin
                reg_we_o = `PJY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = inst_addr_i;
                op2_jump_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end
            `PJY_INST_JALR: begin
                reg_we_o = `PJY_WriteEnable;
                reg1_raddr_o = rs1;
                reg2_raddr_o = `PJY_ZeroReg;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                op1_jump_o = reg1_rdata_i;
                op2_jump_o = {{20{inst_i[31]}}, inst_i[31:20]};
            end
            `PJY_INST_LUI: begin
                reg_we_o = `PJY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `PJY_ZeroWord;
            end
            `PJY_INST_AUIPC: begin
                reg_we_o = `PJY_WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end
            `PJY_INST_NOP_OP: begin
                reg_we_o = `PJY_WriteDisable;
                reg_waddr_o = `PJY_ZeroReg;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
            end
            `PJY_INST_FENCE: begin
                reg_we_o = `PJY_WriteDisable;
                reg_waddr_o = `PJY_ZeroReg;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
                op1_jump_o = inst_addr_i;
                op2_jump_o = 32'h4;
            end
            `PJY_INST_CSR: begin
                reg_we_o = `PJY_WriteDisable;
                reg_waddr_o = `PJY_ZeroReg;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
                csr_raddr_o = `PJY_ZeroWord;
                csr_waddr_o = `PJY_ZeroWord;
                csr_we_o = `PJY_WriteDisable;
            end
            // TASK5_RT_BEGIN
            // TASK6_IF_BEGIN
            `PJY_INST_SID: begin
                case (funct3)
                    `PJY_INST_SID_F3: begin
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                    end
                    `PJY_INST_RT_F3: begin
                        reg_we_o = `PJY_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                    end
                    `PJY_INST_IF_F3: begin
                        reg_we_o = `PJY_WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'd31;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        reg_we_o = `PJY_WriteDisable;
                        reg_waddr_o = `PJY_ZeroReg;
                        reg1_raddr_o = `PJY_ZeroReg;
                        reg2_raddr_o = `PJY_ZeroReg;
                    end
                endcase
            end
            // TASK6_IF_END
            // TASK5_RT_END
            default: begin
                reg_we_o = `PJY_WriteDisable;
                reg_waddr_o = `PJY_ZeroReg;
                reg1_raddr_o = `PJY_ZeroReg;
                reg2_raddr_o = `PJY_ZeroReg;
            end
        endcase
    end

endmodule
