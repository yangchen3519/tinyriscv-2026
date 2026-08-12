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


// 4 channels PWM module
module yc_pwm(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire [31:0] addr_i,
    input wire [31:0] data_i,
    output reg [31:0] data_o,
    output reg [3:0] PWM_o
);

    localparam PWM_A0 = 32'h6000_0000;
    localparam PWM_A1 = 32'h6001_0000;
    localparam PWM_A2 = 32'h6002_0000;
    localparam PWM_A3 = 32'h6003_0000;
    localparam PWM_B0 = 32'h6010_0000;
    localparam PWM_B1 = 32'h6011_0000;
    localparam PWM_B2 = 32'h6012_0000;
    localparam PWM_B3 = 32'h6013_0000;
    localparam PWM_C = 32'h6004_0000;

    // A0-A3: period values of 4 PWM channels
    reg [31:0] pwm_a0;
    reg [31:0] pwm_a1;
    reg [31:0] pwm_a2;
    reg [31:0] pwm_a3;

    // B0-B3: duty values of 4 PWM channels
    reg [31:0] pwm_b0;
    reg [31:0] pwm_b1;
    reg [31:0] pwm_b2;
    reg [31:0] pwm_b3;

    // C[3:0]: enable of 4 PWM channels
    reg [31:0] pwm_c;

    reg [31:0] pwm_cnt0;
    reg [31:0] pwm_cnt1;
    reg [31:0] pwm_cnt2;
    reg [31:0] pwm_cnt3;

    // write regs
    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            pwm_a0 <= `YC_ZeroWord;
            pwm_a1 <= `YC_ZeroWord;
            pwm_a2 <= `YC_ZeroWord;
            pwm_a3 <= `YC_ZeroWord;
            pwm_b0 <= `YC_ZeroWord;
            pwm_b1 <= `YC_ZeroWord;
            pwm_b2 <= `YC_ZeroWord;
            pwm_b3 <= `YC_ZeroWord;
            pwm_c <= `YC_ZeroWord;
        end else begin
            if (we_i == `YC_WriteEnable) begin
                case (addr_i)
                    PWM_A0: begin
                        pwm_a0 <= data_i;
                    end
                    PWM_A1: begin
                        pwm_a1 <= data_i;
                    end
                    PWM_A2: begin
                        pwm_a2 <= data_i;
                    end
                    PWM_A3: begin
                        pwm_a3 <= data_i;
                    end
                    PWM_B0: begin
                        pwm_b0 <= data_i;
                    end
                    PWM_B1: begin
                        pwm_b1 <= data_i;
                    end
                    PWM_B2: begin
                        pwm_b2 <= data_i;
                    end
                    PWM_B3: begin
                        pwm_b3 <= data_i;
                    end
                    PWM_C: begin
                        pwm_c <= {28'h0, data_i[3:0]};
                    end
                endcase
            end
        end
    end

    // read regs
    always @ (*) begin
        if (rst == `YC_RstEnable) begin
            data_o = `YC_ZeroWord;
        end else begin
            case (addr_i)
                PWM_A0: begin
                    data_o = pwm_a0;
                end
                PWM_A1: begin
                    data_o = pwm_a1;
                end
                PWM_A2: begin
                    data_o = pwm_a2;
                end
                PWM_A3: begin
                    data_o = pwm_a3;
                end
                PWM_B0: begin
                    data_o = pwm_b0;
                end
                PWM_B1: begin
                    data_o = pwm_b1;
                end
                PWM_B2: begin
                    data_o = pwm_b2;
                end
                PWM_B3: begin
                    data_o = pwm_b3;
                end
                PWM_C: begin
                    data_o = pwm_c;
                end
                default: begin
                    data_o = `YC_ZeroWord;
                end
            endcase
        end
    end

    // pwm counter and output
    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            pwm_cnt0 <= `YC_ZeroWord;
            pwm_cnt1 <= `YC_ZeroWord;
            pwm_cnt2 <= `YC_ZeroWord;
            pwm_cnt3 <= `YC_ZeroWord;
            PWM_o <= 4'h0;
        end else begin
            if ((pwm_c[0] == 1'b1) && (pwm_a0 != `YC_ZeroWord)) begin
                if (pwm_cnt0 >= (pwm_a0 - 1'b1)) begin
                    pwm_cnt0 <= `YC_ZeroWord;
                end else begin
                    pwm_cnt0 <= pwm_cnt0 + 1'b1;
                end
                PWM_o[0] <= (pwm_cnt0 < pwm_b0)? 1'b1: 1'b0;
            end else begin
                pwm_cnt0 <= `YC_ZeroWord;
                PWM_o[0] <= 1'b0;
            end

            if ((pwm_c[1] == 1'b1) && (pwm_a1 != `YC_ZeroWord)) begin
                if (pwm_cnt1 >= (pwm_a1 - 1'b1)) begin
                    pwm_cnt1 <= `YC_ZeroWord;
                end else begin
                    pwm_cnt1 <= pwm_cnt1 + 1'b1;
                end
                PWM_o[1] <= (pwm_cnt1 < pwm_b1)? 1'b1: 1'b0;
            end else begin
                pwm_cnt1 <= `YC_ZeroWord;
                PWM_o[1] <= 1'b0;
            end

            if ((pwm_c[2] == 1'b1) && (pwm_a2 != `YC_ZeroWord)) begin
                if (pwm_cnt2 >= (pwm_a2 - 1'b1)) begin
                    pwm_cnt2 <= `YC_ZeroWord;
                end else begin
                    pwm_cnt2 <= pwm_cnt2 + 1'b1;
                end
                PWM_o[2] <= (pwm_cnt2 < pwm_b2)? 1'b1: 1'b0;
            end else begin
                pwm_cnt2 <= `YC_ZeroWord;
                PWM_o[2] <= 1'b0;
            end

            if ((pwm_c[3] == 1'b1) && (pwm_a3 != `YC_ZeroWord)) begin
                if (pwm_cnt3 >= (pwm_a3 - 1'b1)) begin
                    pwm_cnt3 <= `YC_ZeroWord;
                end else begin
                    pwm_cnt3 <= pwm_cnt3 + 1'b1;
                end
                PWM_o[3] <= (pwm_cnt3 < pwm_b3)? 1'b1: 1'b0;
            end else begin
                pwm_cnt3 <= `YC_ZeroWord;
                PWM_o[3] <= 1'b0;
            end
        end
    end

endmodule
