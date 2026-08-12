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

`include "yc_defines.vh"

// PC寄存器模块
module yc_pc_reg(

    input wire clk,
    input wire rst,

    // Branch/jump control.
    input wire jump_flag_i,
    input wire[`YC_InstAddrBus] jump_addr_i,

    // Pipeline hold control.
    input wire[`YC_Hold_Flag_Bus] hold_flag_i,

    // Current PC value.
    output reg[`YC_InstAddrBus] pc_o

    );


    always @ (posedge clk) begin
        // Reset PC to the architectural reset vector.
        if (rst == `YC_RstEnable) begin
            pc_o <= `YC_CpuResetAddr;
        // Apply redirect from the execute stage.
        end else if (jump_flag_i == `YC_JumpEnable) begin
            pc_o <= jump_addr_i;
        // Hold PC when the front end is stalled.
        end else if (hold_flag_i >= `YC_Hold_Pc) begin
            pc_o <= pc_o;
        // Otherwise fetch the next sequential instruction.
        end else begin
            pc_o <= pc_o + 4'h4;
        end
    end

endmodule
