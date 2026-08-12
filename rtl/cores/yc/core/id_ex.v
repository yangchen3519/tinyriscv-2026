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

`include "yc_defines.vh"

module yc_id_ex(

    input wire clk,
    input wire rst,

    input wire[`YC_InstBus] inst_i,
    input wire[`YC_InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`YC_RegAddrBus] reg_waddr_i,
    input wire[`YC_RegBus] reg1_rdata_i,
    input wire[`YC_RegBus] reg2_rdata_i,
    input wire[`YC_MemAddrBus] op1_i,
    input wire[`YC_MemAddrBus] op2_i,
    input wire[`YC_MemAddrBus] op1_jump_i,
    input wire[`YC_MemAddrBus] op2_jump_i,

    input wire[`YC_Hold_Flag_Bus] hold_flag_i,

    output wire[`YC_MemAddrBus] op1_o,
    output wire[`YC_MemAddrBus] op2_o,
    output wire[`YC_MemAddrBus] op1_jump_o,
    output wire[`YC_MemAddrBus] op2_jump_o,
    output wire[`YC_InstBus] inst_o,
    output wire[`YC_InstAddrBus] inst_addr_o,
    output wire reg_we_o,
    output wire[`YC_RegAddrBus] reg_waddr_o,
    output wire[`YC_RegBus] reg1_rdata_o,
    output wire[`YC_RegBus] reg2_rdata_o

    );

    wire hold_en = (hold_flag_i >= `YC_Hold_Id);

    wire[`YC_InstBus] inst;
    yc_gen_pipe_dff #(32) inst_ff(clk, rst, hold_en, `YC_INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`YC_InstAddrBus] inst_addr;
    yc_gen_pipe_dff #(32) inst_addr_ff(clk, rst, hold_en, `YC_ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

    wire reg_we;
    yc_gen_pipe_dff #(1) reg_we_ff(clk, rst, hold_en, `YC_WriteDisable, reg_we_i, reg_we);
    assign reg_we_o = reg_we;

    wire[`YC_RegAddrBus] reg_waddr;
    yc_gen_pipe_dff #(5) reg_waddr_ff(clk, rst, hold_en, `YC_ZeroReg, reg_waddr_i, reg_waddr);
    assign reg_waddr_o = reg_waddr;

    wire[`YC_RegBus] reg1_rdata;
    yc_gen_pipe_dff #(32) reg1_rdata_ff(clk, rst, hold_en, `YC_ZeroWord, reg1_rdata_i, reg1_rdata);
    assign reg1_rdata_o = reg1_rdata;

    wire[`YC_RegBus] reg2_rdata;
    yc_gen_pipe_dff #(32) reg2_rdata_ff(clk, rst, hold_en, `YC_ZeroWord, reg2_rdata_i, reg2_rdata);
    assign reg2_rdata_o = reg2_rdata;

    wire[`YC_MemAddrBus] op1;
    yc_gen_pipe_dff #(32) op1_ff(clk, rst, hold_en, `YC_ZeroWord, op1_i, op1);
    assign op1_o = op1;

    wire[`YC_MemAddrBus] op2;
    yc_gen_pipe_dff #(32) op2_ff(clk, rst, hold_en, `YC_ZeroWord, op2_i, op2);
    assign op2_o = op2;

    wire[`YC_MemAddrBus] op1_jump;
    yc_gen_pipe_dff #(32) op1_jump_ff(clk, rst, hold_en, `YC_ZeroWord, op1_jump_i, op1_jump);
    assign op1_jump_o = op1_jump;

    wire[`YC_MemAddrBus] op2_jump;
    yc_gen_pipe_dff #(32) op2_jump_ff(clk, rst, hold_en, `YC_ZeroWord, op2_jump_i, op2_jump);
    assign op2_jump_o = op2_jump;

endmodule