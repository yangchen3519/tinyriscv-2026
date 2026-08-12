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

`define YC_CpuResetAddr 32'h0

`define YC_RstEnable 1'b0
`define YC_RstDisable 1'b1
`define YC_ZeroWord 32'h0
`define YC_ZeroReg 5'h0
`define YC_WriteEnable 1'b1
`define YC_WriteDisable 1'b0
`define YC_ReadEnable 1'b1
`define YC_ReadDisable 1'b0
`define YC_True 1'b1
`define YC_False 1'b0
`define YC_ChipEnable 1'b1
`define YC_ChipDisable 1'b0
`define YC_JumpEnable 1'b1
`define YC_JumpDisable 1'b0
`define YC_DivResultNotReady 1'b0
`define YC_DivResultReady 1'b1
`define YC_DivStart 1'b1
`define YC_DivStop 1'b0
`define YC_HoldEnable 1'b1
`define YC_HoldDisable 1'b0
`define YC_Stop 1'b1
`define YC_NoStop 1'b0
`define YC_RIB_ACK 1'b1
`define YC_RIB_NACK 1'b0
`define YC_RIB_REQ 1'b1
`define YC_RIB_NREQ 1'b0
`define YC_Hold_Flag_Bus   2:0
`define YC_Hold_None 3'b000
`define YC_Hold_Pc   3'b001
`define YC_Hold_If   3'b010
`define YC_Hold_Id   3'b011

// I type inst
`define YC_INST_TYPE_I 7'b0010011
`define YC_INST_ADDI   3'b000
`define YC_INST_SLTI   3'b010
`define YC_INST_SLTIU  3'b011
`define YC_INST_XORI   3'b100
`define YC_INST_ORI    3'b110
`define YC_INST_ANDI   3'b111
`define YC_INST_SLLI   3'b001
`define YC_INST_SRI    3'b101

// L type inst
`define YC_INST_TYPE_L 7'b0000011
`define YC_INST_LB     3'b000
`define YC_INST_LH     3'b001
`define YC_INST_LW     3'b010
`define YC_INST_LBU    3'b100
`define YC_INST_LHU    3'b101

// S type inst
`define YC_INST_TYPE_S 7'b0100011
`define YC_INST_SB     3'b000
`define YC_INST_SH     3'b001
`define YC_INST_SW     3'b010

// R and M type inst
`define YC_INST_TYPE_R_M 7'b0110011
// R type inst
`define YC_INST_ADD_SUB 3'b000
`define YC_INST_SLL    3'b001
`define YC_INST_SLT    3'b010
`define YC_INST_SLTU   3'b011
`define YC_INST_XOR    3'b100
`define YC_INST_SR     3'b101
`define YC_INST_OR     3'b110
`define YC_INST_AND    3'b111
// J type inst
`define YC_INST_JAL    7'b1101111
`define YC_INST_JALR   7'b1100111

`define YC_INST_LUI    7'b0110111
`define YC_INST_AUIPC  7'b0010111
`define YC_INST_NOP    32'h00000001
`define YC_INST_NOP_OP 7'b0000001
`define YC_INST_RET    32'h00008067

`define YC_INST_FENCE  7'b0001111

// J type inst
`define YC_INST_TYPE_B 7'b1100011
`define YC_INST_BEQ    3'b000
`define YC_INST_BNE    3'b001
`define YC_INST_BLT    3'b100
`define YC_INST_BGE    3'b101
`define YC_INST_BLTU   3'b110
`define YC_INST_BGEU   3'b111

// inst
`define YC_INST_TYPE_A 7'b0101111
`define YC_INST_sID 3'b000
`define YC_INST_rT 3'b001
`define YC_INST_if 3'b010

// UART MMIO and command encoding
`define YC_UART_BASE_ADDR 32'h30000000
`define YC_UART_CTRL_ADDR 32'h30000000
`define YC_UART_STATUS_ADDR 32'h30000004
`define YC_UART_BAUD_ADDR 32'h30000008
`define YC_UART_TXDATA_ADDR 32'h3000000c
`define YC_UART_RXDATA_ADDR 32'h30000010
`define YC_UART_CMD_ADDR 32'h30000014

`define YC_UART_CMD_NONE 8'h00
`define YC_UART_CMD_SEND_ID 8'h01
`define YC_UART_CMD_SEND_BYTE 8'h02


`define YC_RomNum 256      // ROM 深度是 256 个字
`define YC_RomAddrBus 7:0  // ROM 地址总线宽度是 8 位
`define YC_RamNum 16       // RAM 深度是 16 个字
`define YC_RamAddrBus 3:0  // RAM 地址总线宽度是 4 位
`define YC_MemBus 31:0     // 数据总线宽度是 32 位
`define YC_MemAddrBus 31:0 // 系统内存地址总线宽度是 32 位，桥接模块做截断

`define YC_InstBus 31:0
`define YC_InstAddrBus 31:0

// common regs
`define YC_RegAddrBus 4:0
`define YC_RegBus 31:0
`define YC_DoubleRegBus 63:0
`define YC_RegWidth 32
`define YC_RegNum 32        // reg num
`define YC_RegNumLog2 5
