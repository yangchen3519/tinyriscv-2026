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

`define YX_CpuResetAddr 32'h0

`define YX_RstEnable 1'b0
`define YX_RstDisable 1'b1
`define YX_ZeroWord 32'h0
`define YX_ZeroReg 5'h0
`define YX_WriteEnable 1'b1
`define YX_WriteDisable 1'b0
`define YX_ReadEnable 1'b1
`define YX_ReadDisable 1'b0
`define YX_True 1'b1
`define YX_False 1'b0
`define YX_ChipEnable 1'b1
`define YX_ChipDisable 1'b0
`define YX_JumpEnable 1'b1
`define YX_JumpDisable 1'b0
`define YX_HoldEnable 1'b1
`define YX_HoldDisable 1'b0
`define YX_Stop 1'b1
`define YX_NoStop 1'b0
`define YX_RIB_ACK 1'b1
`define YX_RIB_NACK 1'b0
`define YX_RIB_REQ 1'b1
`define YX_RIB_NREQ 1'b0
`define YX_INT_ASSERT 1'b1
`define YX_INT_DEASSERT 1'b0

`define YX_INT_BUS 7:0
`define YX_INT_NONE 8'h0

`define YX_Hold_Flag_Bus   2:0
`define YX_Hold_None 3'b000
`define YX_Hold_Pc   3'b001
`define YX_Hold_If   3'b010
`define YX_Hold_Id   3'b011

// I type inst
`define YX_INST_TYPE_I 7'b0010011
`define YX_INST_ADDI   3'b000
`define YX_INST_SLTI   3'b010
`define YX_INST_SLTIU  3'b011
`define YX_INST_XORI   3'b100
`define YX_INST_ORI    3'b110
`define YX_INST_ANDI   3'b111
`define YX_INST_SLLI   3'b001
`define YX_INST_SRI    3'b101

// L type inst
`define YX_INST_TYPE_L 7'b0000011
`define YX_INST_LB     3'b000
`define YX_INST_LH     3'b001
`define YX_INST_LW     3'b010
`define YX_INST_LBU    3'b100
`define YX_INST_LHU    3'b101

// S type inst
`define YX_INST_TYPE_S 7'b0100011
`define YX_INST_SB     3'b000
`define YX_INST_SH     3'b001
`define YX_INST_SW     3'b010

// R and M type inst
`define YX_INST_TYPE_R_M 7'b0110011
// R type inst
`define YX_INST_ADD_SUB 3'b000
`define YX_INST_SLL    3'b001
`define YX_INST_SLT    3'b010
`define YX_INST_SLTU   3'b011
`define YX_INST_XOR    3'b100
`define YX_INST_SR     3'b101
`define YX_INST_OR     3'b110
`define YX_INST_AND    3'b111

// J type inst
`define YX_INST_JAL    7'b1101111
`define YX_INST_JALR   7'b1100111

`define YX_INST_LUI    7'b0110111
`define YX_INST_AUIPC  7'b0010111
`define YX_INST_NOP    32'h00000001
`define YX_INST_NOP_OP 7'b0000001
`define YX_INST_RET    32'h00008067

`define YX_INST_FENCE  7'b0001111

// J type inst
`define YX_INST_TYPE_B 7'b1100011
`define YX_INST_BEQ    3'b000
`define YX_INST_BNE    3'b001
`define YX_INST_BLT    3'b100
`define YX_INST_BGE    3'b101
`define YX_INST_BLTU   3'b110
`define YX_INST_BGEU   3'b111


// Custom extend inst
`define YX_INST_SID    7'b0101111
`define YX_INST_SID_F3 3'b000
`define YX_INST_RT_F3  3'b001
`define YX_INST_IF_F3  3'b010


`define YX_RomNum 4096  // rom depth(how many words)

`define YX_MemNum 4096  // memory depth(how many words)
`define YX_MemBus 31:0
`define YX_MemAddrBus 31:0

`define YX_InstBus 31:0
`define YX_InstAddrBus 31:0

// common regs
`define YX_RegAddrBus 4:0
`define YX_RegBus 31:0
`define YX_DoubleRegBus 63:0
`define YX_RegWidth 32
`define YX_RegNum 32        // reg num
`define YX_RegNumLog2 5

