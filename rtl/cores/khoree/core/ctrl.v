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

// 控制模�?-
// �?'出跳转�?暂�?��?水线信�?�
module khoree_ctrl(

    input wire rst,

    // from ex
    input wire jump_flag_i,
    input wire[`KHOREE_InstAddrBus] jump_addr_i,
    // from rib
    input wire hold_flag_rib_i,

    output reg[`KHOREE_Hold_Flag_Bus] hold_flag_o,

    // to pc_reg
    output reg jump_flag_o,
    output reg[`KHOREE_InstAddrBus] jump_addr_o

    );


    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;
        // 默认�?暂�?�
        hold_flag_o = `KHOREE_Hold_None;
        // 按优先级处�?��?�?�模�?-的请求
        if (jump_flag_i == `KHOREE_JumpEnable) begin
            // 暂�?�整�?��?水线
            hold_flag_o = `KHOREE_Hold_Id;
        end else if (hold_flag_rib_i == `KHOREE_HoldEnable) begin
            // 暂�?�PC，�?��?-指地�?��?�?�
            hold_flag_o = `KHOREE_Hold_If;
        end else begin
            hold_flag_o = `KHOREE_Hold_None;
        end
    end

endmodule
