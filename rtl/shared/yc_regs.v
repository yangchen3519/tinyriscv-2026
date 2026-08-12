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

// 通用寄存器模块
module yc_regs(

    input wire clk,
    input wire rst,

    // Write-back port from execute.
    input wire we_i,
    input wire[`YC_RegAddrBus] waddr_i,
    input wire[`YC_RegBus] wdata_i,

    // Read port 1 for decode.
    input wire[`YC_RegAddrBus] raddr1_i,
    output reg[`YC_RegBus] rdata1_o,

    // Read port 2 for decode.
    input wire[`YC_RegAddrBus] raddr2_i,
    output reg[`YC_RegBus] rdata2_o,
    output wire[`YC_RegBus] status_x26_o,
    output wire[`YC_RegBus] status_x27_o

    );

    reg[`YC_RegBus] regs[0:`YC_RegNum - 1];
    assign status_x26_o = regs[26];
    assign status_x27_o = regs[27];

    // Commit register writes on the rising clock edge.
    always @ (posedge clk) begin
        if (rst == `YC_RstDisable) begin
            if ((we_i == `YC_WriteEnable) && (waddr_i != `YC_ZeroReg)) begin
                regs[waddr_i] <= wdata_i;
            end
        end
    end

    // Read port 1 with simple write-through bypass.
    always @ (*) begin
        if (raddr1_i == `YC_ZeroReg) begin
            rdata1_o = `YC_ZeroWord;
        end else if (raddr1_i == waddr_i && we_i == `YC_WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = regs[raddr1_i];
        end
    end

    // Read port 2 with simple write-through bypass.
    always @ (*) begin
        if (raddr2_i == `YC_ZeroReg) begin
            rdata2_o = `YC_ZeroWord;
        end else if (raddr2_i == waddr_i && we_i == `YC_WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = regs[raddr2_i];
        end
    end

endmodule
