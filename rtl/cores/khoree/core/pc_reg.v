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

// PC?????
module khoree_pc_reg(

    input wire clk,
    input wire rst,

    input wire jump_flag_i,                 // ????
    input wire[`KHOREE_InstAddrBus] jump_addr_i,   // ????
    input wire[`KHOREE_Hold_Flag_Bus] hold_flag_i, // ???????
    input wire stall_flag_i,
    input wire prdt_taken_i,
    input wire [`KHOREE_InstAddrBus] prdt_addr_i,

    output reg[`KHOREE_InstAddrBus] pc_o           // PC??

    );


    always @ (posedge clk) begin
        // ??
        if (rst == `KHOREE_RstEnable) begin
            pc_o <= `KHOREE_CpuResetAddr;
        // ??
        end else if (jump_flag_i == `KHOREE_JumpEnable) begin
            pc_o <= jump_addr_i;
        // ??
        end else if (stall_flag_i || (hold_flag_i >= `KHOREE_Hold_Pc)) begin
            pc_o <= pc_o;
        end else if (prdt_taken_i) begin
            pc_o <= prdt_addr_i;
        // ???4
        end else begin
            pc_o <= pc_o + 4'h4;
        end
    end

endmodule
