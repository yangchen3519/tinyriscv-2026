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

// ??????????
module khoree_if_id(

    input wire clk,
    input wire rst,

    input wire[`KHOREE_InstBus] inst_i,            // ????
    input wire[`KHOREE_InstAddrBus] inst_addr_i,   // ????
    input wire prdt_taken_i,
    output reg prdt_taken_o,

    input wire[`KHOREE_Hold_Flag_Bus] hold_flag_i, // ???????

    input wire stall_flag_i,

    output reg [`KHOREE_InstBus] inst_o,           // ????
    output reg [`KHOREE_InstAddrBus] inst_addr_o   // ????

    );

    wire hold_en = (hold_flag_i >= `KHOREE_Hold_If);

    always @ (posedge clk) begin
        if (!rst) begin
            inst_o <= `KHOREE_INST_NOP;
            inst_addr_o <= `KHOREE_ZeroWord;
            prdt_taken_o <= 1'b0;
        end else if(stall_flag_i) begin
            inst_o <= inst_o;
            inst_addr_o <= inst_addr_o;
            prdt_taken_o <= prdt_taken_o;
        end else if(hold_en) begin
            inst_o <= `KHOREE_INST_NOP;
            inst_addr_o <= `KHOREE_ZeroWord;
            prdt_taken_o <= 1'b0;
        end else begin
            inst_o <= inst_i;
            inst_addr_o <= inst_addr_i;
            prdt_taken_o <= prdt_taken_i;
        end
    end

endmodule
