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

`include "khoree_defines.vh"

// ????????????
module khoree_id_ex(

    input wire clk,
    input wire rst,

    input wire[`KHOREE_InstBus] inst_i,            // ????
    input wire[`KHOREE_InstAddrBus] inst_addr_i,   // ????
    input wire reg_we_i,                    // ????????
    input wire[`KHOREE_RegAddrBus] reg_waddr_i,    // ????????
    input wire[`KHOREE_RegBus] reg1_rdata_i,       // ?????1???
    input wire[`KHOREE_RegBus] reg2_rdata_i,       // ?????2???
    input wire[`KHOREE_MemAddrBus] op1_i,
    input wire[`KHOREE_MemAddrBus] op2_i,
    input wire[`KHOREE_MemAddrBus] op1_jump_i,
    input wire[`KHOREE_MemAddrBus] op2_jump_i,
    input wire prdt_taken_i,

    input wire[`KHOREE_Hold_Flag_Bus] hold_flag_i, // ???????

    input wire stall_flag_i,

    output reg prdt_taken_o,
    output reg [`KHOREE_MemAddrBus] op1_o,
    output reg [`KHOREE_MemAddrBus] op2_o,
    output reg [`KHOREE_MemAddrBus] op1_jump_o,
    output reg [`KHOREE_MemAddrBus] op2_jump_o,
    output reg [`KHOREE_InstBus] inst_o,            // ????
    output reg [`KHOREE_InstAddrBus] inst_addr_o,   // ????
    output reg  reg_we_o,                    // ????????
    output reg [`KHOREE_RegAddrBus] reg_waddr_o,    // ????????
    output reg [`KHOREE_RegBus] reg1_rdata_o,       // ?????1???
    output reg [`KHOREE_RegBus] reg2_rdata_o        // ?????2???

    );

    wire hold_en = (hold_flag_i >= `KHOREE_Hold_Id);

    always @ (posedge clk) begin
        if (!rst) begin
            op1_jump_o <= `KHOREE_ZeroWord;
            op2_jump_o <= `KHOREE_ZeroWord;
            op2_o      <= `KHOREE_ZeroWord;
            op1_o      <= `KHOREE_ZeroWord;
            reg_we_o   <= `KHOREE_WriteDisable;
            reg_waddr_o<= `KHOREE_ZeroReg;
            reg1_rdata_o<= `KHOREE_ZeroWord;
            reg2_rdata_o<= `KHOREE_ZeroWord;
            inst_addr_o <= `KHOREE_ZeroWord;
            inst_o      <= `KHOREE_INST_NOP;
            prdt_taken_o <= 1'b0;
        end else if(stall_flag_i) begin
            op1_o      <= op1_o;
            op2_o      <= op2_o;
            op1_jump_o <= op1_jump_o;
            op2_jump_o <= op2_jump_o;
            reg_we_o   <= reg_we_o;
            reg_waddr_o <= reg_waddr_o;
            reg1_rdata_o<= reg1_rdata_o;
            reg2_rdata_o<= reg2_rdata_o;
            inst_addr_o <= inst_addr_o;
            inst_o      <= inst_o;
            prdt_taken_o <= prdt_taken_o;
        end else if(hold_en) begin
            op1_jump_o <= `KHOREE_ZeroWord;
            op2_jump_o <= `KHOREE_ZeroWord;
            op2_o      <= `KHOREE_ZeroWord;
            op1_o      <= `KHOREE_ZeroWord;
            reg_we_o   <= `KHOREE_WriteDisable;
            reg_waddr_o<= `KHOREE_ZeroReg;
            reg1_rdata_o<= `KHOREE_ZeroWord;
            reg2_rdata_o<= `KHOREE_ZeroWord;
            inst_addr_o <= `KHOREE_ZeroWord;
            inst_o      <= `KHOREE_INST_NOP;
            prdt_taken_o <= 1'b0;
        end else begin
            op1_o      <= op1_i;
            op2_o      <= op2_i;
            op1_jump_o <= op1_jump_i;
            op2_jump_o <= op2_jump_i;
            reg_we_o   <= reg_we_i;
            reg_waddr_o <= reg_waddr_i;
            reg1_rdata_o<= reg1_rdata_i;
            reg2_rdata_o<= reg2_rdata_i;
            inst_addr_o <= inst_addr_i;
            inst_o      <= inst_i;
            prdt_taken_o <= prdt_taken_i;
        end
    end

endmodule
