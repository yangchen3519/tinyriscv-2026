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

`define PJY_CpuResetAddr 32'h0

`define PJY_RstEnable 1'b0
`define PJY_RstDisable 1'b1
`define PJY_ZeroWord 32'h0
`define PJY_ZeroReg 5'h0
`define PJY_WriteEnable 1'b1
`define PJY_WriteDisable 1'b0
`define PJY_ReadEnable 1'b1
`define PJY_ReadDisable 1'b0
`define PJY_True 1'b1
`define PJY_False 1'b0
`define PJY_ChipEnable 1'b1
`define PJY_ChipDisable 1'b0
`define PJY_JumpEnable 1'b1
`define PJY_JumpDisable 1'b0
`define PJY_DivResultNotReady 1'b0
`define PJY_DivResultReady 1'b1
`define PJY_DivStart 1'b1
`define PJY_DivStop 1'b0
`define PJY_HoldEnable 1'b1
`define PJY_HoldDisable 1'b0
`define PJY_Stop 1'b1
`define PJY_NoStop 1'b0
`define PJY_RIB_ACK 1'b1
`define PJY_RIB_NACK 1'b0
`define PJY_RIB_REQ 1'b1
`define PJY_RIB_NREQ 1'b0
`define PJY_INT_ASSERT 1'b1
`define PJY_INT_DEASSERT 1'b0

`define PJY_INT_BUS 7:0
`define PJY_INT_NONE 8'h0
`define PJY_INT_RET 8'hff
`define PJY_INT_TIMER0 8'b00000001
`define PJY_INT_TIMER0_ENTRY_ADDR 32'h4

`define PJY_Hold_Flag_Bus   2:0
`define PJY_Hold_None 3'b000
`define PJY_Hold_Pc   3'b001
`define PJY_Hold_If   3'b010
`define PJY_Hold_Id   3'b011

// I type inst
`define PJY_INST_TYPE_I 7'b0010011
`define PJY_INST_ADDI   3'b000
`define PJY_INST_SLTI   3'b010
`define PJY_INST_SLTIU  3'b011
`define PJY_INST_XORI   3'b100
`define PJY_INST_ORI    3'b110
`define PJY_INST_ANDI   3'b111
`define PJY_INST_SLLI   3'b001
`define PJY_INST_SRI    3'b101

// L type inst
`define PJY_INST_TYPE_L 7'b0000011
`define PJY_INST_LB     3'b000
`define PJY_INST_LH     3'b001
`define PJY_INST_LW     3'b010
`define PJY_INST_LBU    3'b100
`define PJY_INST_LHU    3'b101

// S type inst
`define PJY_INST_TYPE_S 7'b0100011
`define PJY_INST_SB     3'b000
`define PJY_INST_SH     3'b001
`define PJY_INST_SW     3'b010

// R and M type inst
`define PJY_INST_TYPE_R_M 7'b0110011
// R type inst
`define PJY_INST_ADD_SUB 3'b000
`define PJY_INST_SLL    3'b001
`define PJY_INST_SLT    3'b010
`define PJY_INST_SLTU   3'b011
`define PJY_INST_XOR    3'b100
`define PJY_INST_SR     3'b101
`define PJY_INST_OR     3'b110
`define PJY_INST_AND    3'b111
// M type inst
`define PJY_INST_MUL    3'b000
`define PJY_INST_MULH   3'b001
`define PJY_INST_MULHSU 3'b010
`define PJY_INST_MULHU  3'b011
`define PJY_INST_DIV    3'b100
`define PJY_INST_DIVU   3'b101
`define PJY_INST_REM    3'b110
`define PJY_INST_REMU   3'b111

// J type inst
`define PJY_INST_JAL    7'b1101111
`define PJY_INST_JALR   7'b1100111

`define PJY_INST_LUI    7'b0110111
`define PJY_INST_AUIPC  7'b0010111
`define PJY_INST_NOP    32'h00000001
`define PJY_INST_NOP_OP 7'b0000001
`define PJY_INST_MRET   32'h30200073
`define PJY_INST_RET    32'h00008067

`define PJY_INST_FENCE  7'b0001111
`define PJY_INST_ECALL  32'h73
`define PJY_INST_EBREAK 32'h00100073

// J type inst
`define PJY_INST_TYPE_B 7'b1100011
`define PJY_INST_BEQ    3'b000
`define PJY_INST_BNE    3'b001
`define PJY_INST_BLT    3'b100
`define PJY_INST_BGE    3'b101
`define PJY_INST_BLTU   3'b110
`define PJY_INST_BGEU   3'b111

// CSR inst
`define PJY_INST_CSR    7'b1110011
`define PJY_INST_CSRRW  3'b001
`define PJY_INST_CSRRS  3'b010
`define PJY_INST_CSRRC  3'b011
`define PJY_INST_CSRRWI 3'b101
`define PJY_INST_CSRRSI 3'b110
`define PJY_INST_CSRRCI 3'b111

// CSR reg addr
`define PJY_CSR_CYCLE   12'hc00
`define PJY_CSR_CYCLEH  12'hc80
`define PJY_CSR_MTVEC   12'h305
`define PJY_CSR_MCAUSE  12'h342
`define PJY_CSR_MEPC    12'h341
`define PJY_CSR_MIE     12'h304
`define PJY_CSR_MSTATUS 12'h300
`define PJY_CSR_MSCRATCH 12'h340

// TASK4_SID_BEGIN: Send ID extension instruction
`define PJY_INST_SID    7'b0101111
`define PJY_INST_SID_F3 3'b000
// TASK4_SID_END
// TASK5_RT_BEGIN: Read Temperature extension instruction
`define PJY_INST_RT_F3  3'b001
// TASK5_RT_END
// TASK6_IF_BEGIN: Integrated-and-Fire extension instruction
`define PJY_INST_IF_F3  3'b010
// TASK6_IF_END

// TASK1_EXT_MEM_BEGIN: ROM/RAM移到FPGA侧后缩小外部存储深度
// `define RomNum 4096  // rom depth(how many words)
`define PJY_RomNum 256  // external rom depth(how many words)

// `define MemNum 4096  // memory depth(how many words)
`define PJY_MemNum 16  // external ram depth(how many words)
// TASK1_EXT_MEM_END
`define PJY_MemBus 31:0
`define PJY_MemAddrBus 31:0

`define PJY_InstBus 31:0
`define PJY_InstAddrBus 31:0

// common regs
`define PJY_RegAddrBus 4:0
`define PJY_RegBus 31:0
`define PJY_DoubleRegBus 63:0
`define PJY_RegWidth 32
`define PJY_RegNum 32        // reg num
`define PJY_RegNumLog2 5
