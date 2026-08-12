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

`define KHOREE_CpuResetAddr 32'h0

`define KHOREE_RstEnable 1'b0
`define KHOREE_RstDisable 1'b1
`define KHOREE_ZeroWord 32'h0
`define KHOREE_ZeroReg 5'h0
`define KHOREE_WriteEnable 1'b1
`define KHOREE_WriteDisable 1'b0
`define KHOREE_ReadEnable 1'b1
`define KHOREE_ReadDisable 1'b0
`define KHOREE_True 1'b1
`define KHOREE_False 1'b0
`define KHOREE_ChipEnable 1'b1
`define KHOREE_ChipDisable 1'b0
`define KHOREE_JumpEnable 1'b1
`define KHOREE_JumpDisable 1'b0
`define KHOREE_DivResultNotReady 1'b0
`define KHOREE_DivResultReady 1'b1
`define KHOREE_DivStart 1'b1
`define KHOREE_DivStop 1'b0
`define KHOREE_HoldEnable 1'b1
`define KHOREE_HoldDisable 1'b0
`define KHOREE_Stop 1'b1
`define KHOREE_NoStop 1'b0
`define KHOREE_RIB_ACK 1'b1
`define KHOREE_RIB_NACK 1'b0
`define KHOREE_RIB_REQ 1'b1
`define KHOREE_RIB_NREQ 1'b0
`define KHOREE_INT_ASSERT 1'b1
`define KHOREE_INT_DEASSERT 1'b0

`define KHOREE_INT_BUS 7:0
`define KHOREE_INT_NONE 8'h0
`define KHOREE_INT_RET 8'hff
`define KHOREE_INT_TIMER0 8'b00000001
`define KHOREE_INT_TIMER0_ENTRY_ADDR 32'h4

`define KHOREE_Hold_Flag_Bus   2:0
`define KHOREE_Hold_None 3'b000
`define KHOREE_Hold_Pc   3'b001
`define KHOREE_Hold_If   3'b010
`define KHOREE_Hold_Id   3'b011

// I type inst
`define KHOREE_INST_TYPE_I 7'b0010011
`define KHOREE_INST_ADDI   3'b000
`define KHOREE_INST_SLTI   3'b010
`define KHOREE_INST_SLTIU  3'b011
`define KHOREE_INST_XORI   3'b100
`define KHOREE_INST_ORI    3'b110
`define KHOREE_INST_ANDI   3'b111
`define KHOREE_INST_SLLI   3'b001
`define KHOREE_INST_SRI    3'b101

// L type inst
`define KHOREE_INST_TYPE_L 7'b0000011
`define KHOREE_INST_LB     3'b000
`define KHOREE_INST_LH     3'b001
`define KHOREE_INST_LW     3'b010
`define KHOREE_INST_LBU    3'b100
`define KHOREE_INST_LHU    3'b101

// S type inst
`define KHOREE_INST_TYPE_S 7'b0100011
`define KHOREE_INST_SB     3'b000
`define KHOREE_INST_SH     3'b001
`define KHOREE_INST_SW     3'b010

// R and M type inst
`define KHOREE_INST_TYPE_R_M 7'b0110011
// R type inst
`define KHOREE_INST_ADD_SUB 3'b000
`define KHOREE_INST_SLL    3'b001
`define KHOREE_INST_SLT    3'b010
`define KHOREE_INST_SLTU   3'b011
`define KHOREE_INST_XOR    3'b100
`define KHOREE_INST_SR     3'b101
`define KHOREE_INST_OR     3'b110
`define KHOREE_INST_AND    3'b111
// M type inst
`define KHOREE_INST_MUL    3'b000
`define KHOREE_INST_MULH   3'b001
`define KHOREE_INST_MULHSU 3'b010
`define KHOREE_INST_MULHU  3'b011
`define KHOREE_INST_DIV    3'b100
`define KHOREE_INST_DIVU   3'b101
`define KHOREE_INST_REM    3'b110
`define KHOREE_INST_REMU   3'b111

// J type inst
`define KHOREE_INST_JAL    7'b1101111
`define KHOREE_INST_JALR   7'b1100111

`define KHOREE_INST_LUI    7'b0110111
`define KHOREE_INST_AUIPC  7'b0010111
`define KHOREE_INST_NOP    32'h00000001
`define KHOREE_INST_NOP_OP 7'b0000001
`define KHOREE_INST_MRET   32'h30200073
`define KHOREE_INST_RET    32'h00008067

`define KHOREE_INST_FENCE  7'b0001111
`define KHOREE_INST_ECALL  32'h73
`define KHOREE_INST_EBREAK 32'h00100073

// J type inst
`define KHOREE_INST_TYPE_B 7'b1100011
`define KHOREE_INST_BEQ    3'b000
`define KHOREE_INST_BNE    3'b001
`define KHOREE_INST_BLT    3'b100
`define KHOREE_INST_BGE    3'b101
`define KHOREE_INST_BLTU   3'b110
`define KHOREE_INST_BGEU   3'b111

// CSR inst
`define KHOREE_INST_CSR    7'b1110011
`define KHOREE_INST_CSRRW  3'b001
`define KHOREE_INST_CSRRS  3'b010
`define KHOREE_INST_CSRRC  3'b011
`define KHOREE_INST_CSRRWI 3'b101
`define KHOREE_INST_CSRRSI 3'b110
`define KHOREE_INST_CSRRCI 3'b111

// CSR reg addr
`define KHOREE_CSR_CYCLE   12'hc00
`define KHOREE_CSR_CYCLEH  12'hc80
`define KHOREE_CSR_MTVEC   12'h305
`define KHOREE_CSR_MCAUSE  12'h342
`define KHOREE_CSR_MEPC    12'h341
`define KHOREE_CSR_MIE     12'h304
`define KHOREE_CSR_MSTATUS 12'h300
`define KHOREE_CSR_MSCRATCH 12'h340

`define KHOREE_RomNum 256 // rom depth(how many words)    4096 ->  256

`define KHOREE_MemNum 16  // memory depth(how many words)
`define KHOREE_MemBus 31:0
`define KHOREE_MemAddrBus 31:0

`define KHOREE_InstBus 31:0
`define KHOREE_InstAddrBus 31:0

// common regs
`define KHOREE_RegAddrBus 4:0
`define KHOREE_RegBus 31:0
`define KHOREE_DoubleRegBus 63:0
`define KHOREE_RegWidth 32
`define KHOREE_RegNum 32        // reg num
`define KHOREE_RegNumLog2 5


// ext inst
`define KHOREE_INST_TYPE_EXT 7'b0101111
`define KHOREE_INST_SID 3'b000
`define KHOREE_INST_RT 3'b001
`define KHOREE_INST_IF 3'b010
