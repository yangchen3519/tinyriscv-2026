 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
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

`include "yx_defines.vh"

// id/ex pipeline register
module yx_id_ex(

    input wire clk,
    input wire rst,

    (*mark_debug = "true"*) input wire[`YX_InstBus] inst_i,            // 指令内容
    input wire[`YX_InstAddrBus] inst_addr_i,   // 指令地址
    input wire reg_we_i,
    input wire[`YX_RegAddrBus] reg_waddr_i,
    input wire[`YX_RegBus] reg1_rdata_i,
    input wire[`YX_RegBus] reg2_rdata_i,
    input wire[`YX_MemAddrBus] op1_i,
    input wire[`YX_MemAddrBus] op2_i,
    input wire[`YX_MemAddrBus] op1_jump_i,
    input wire[`YX_MemAddrBus] op2_jump_i,

    input wire[`YX_Hold_Flag_Bus] hold_flag_i, // 流水线暂停标�?
    output wire[`YX_MemAddrBus] op1_o,
    output wire[`YX_MemAddrBus] op2_o,
    output wire[`YX_MemAddrBus] op1_jump_o,
    output wire[`YX_MemAddrBus] op2_jump_o,
    output wire[`YX_InstBus] inst_o,            // 指令内容
    output wire[`YX_InstAddrBus] inst_addr_o,   // 指令地址
    output wire reg_we_o,
    output wire[`YX_RegAddrBus] reg_waddr_o,
    output wire[`YX_RegBus] reg1_rdata_o,
    output wire[`YX_RegBus] reg2_rdata_o

    );

    wire hold_en = (hold_flag_i >= `YX_Hold_Id);

    wire[`YX_InstBus] inst;
    yx_gen_pipe_dff #(32) inst_ff(clk, rst, hold_en, `YX_INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`YX_InstAddrBus] inst_addr;
    yx_gen_pipe_dff #(32) inst_addr_ff(clk, rst, hold_en, `YX_ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

    wire reg_we;
    yx_gen_pipe_dff #(1) reg_we_ff(clk, rst, hold_en, `YX_WriteDisable, reg_we_i, reg_we);
    assign reg_we_o = reg_we;

    wire[`YX_RegAddrBus] reg_waddr;
    yx_gen_pipe_dff #(5) reg_waddr_ff(clk, rst, hold_en, `YX_ZeroReg, reg_waddr_i, reg_waddr);
    assign reg_waddr_o = reg_waddr;

    wire[`YX_RegBus] reg1_rdata;
    yx_gen_pipe_dff #(32) reg1_rdata_ff(clk, rst, hold_en, `YX_ZeroWord, reg1_rdata_i, reg1_rdata);
    assign reg1_rdata_o = reg1_rdata;

    wire[`YX_RegBus] reg2_rdata;
    yx_gen_pipe_dff #(32) reg2_rdata_ff(clk, rst, hold_en, `YX_ZeroWord, reg2_rdata_i, reg2_rdata);
    assign reg2_rdata_o = reg2_rdata;

    wire[`YX_MemAddrBus] op1;
    yx_gen_pipe_dff #(32) op1_ff(clk, rst, hold_en, `YX_ZeroWord, op1_i, op1);
    assign op1_o = op1;

    wire[`YX_MemAddrBus] op2;
    yx_gen_pipe_dff #(32) op2_ff(clk, rst, hold_en, `YX_ZeroWord, op2_i, op2);
    assign op2_o = op2;

    wire[`YX_MemAddrBus] op1_jump;
    yx_gen_pipe_dff #(32) op1_jump_ff(clk, rst, hold_en, `YX_ZeroWord, op1_jump_i, op1_jump);
    assign op1_jump_o = op1_jump;

    wire[`YX_MemAddrBus] op2_jump;
    yx_gen_pipe_dff #(32) op2_jump_ff(clk, rst, hold_en, `YX_ZeroWord, op2_jump_i, op2_jump);
    assign op2_jump_o = op2_jump;

endmodule
