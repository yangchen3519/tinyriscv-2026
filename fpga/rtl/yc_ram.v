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

// external ram: 16d x 32w
module yc_ram(

    input wire clk,
    input wire rst,

    input wire we_i,                   // write enable
    input wire[`YC_RamAddrBus] addr_i,    // addr
    input wire[`YC_MemBus] data_i,

    output reg[`YC_MemBus] data_o         // read data

    );

    reg[`YC_MemBus] _ram[0:`YC_RamNum - 1];

    always @ (posedge clk) begin
        if (we_i == `YC_WriteEnable) begin
            _ram[addr_i] <= data_i;
        end
    end

    always @ (*) begin
        if (rst == `YC_RstEnable) begin
            data_o = `YC_ZeroWord;
        end else begin
            data_o = _ram[addr_i];
        end
    end

endmodule
