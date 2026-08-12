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

`include "pjy_defines.vh"


// RIB总线模块
module pjy_rib(

    input wire clk,
    input wire rst,

    // master 0 interface
    input wire[`PJY_MemAddrBus] m0_addr_i,     // 主设备0读、写地址
    input wire[`PJY_MemBus] m0_data_i,         // 主设备0写数据
    output reg[`PJY_MemBus] m0_data_o,         // 主设备0读取到的数据
    input wire m0_req_i,                   // 主设备0访问请求标志
    input wire m0_we_i,                    // 主设备0写标志

    // master 1 interface
    input wire[`PJY_MemAddrBus] m1_addr_i,     // 主设备1读、写地址
    input wire[`PJY_MemBus] m1_data_i,         // 主设备1写数据
    output reg[`PJY_MemBus] m1_data_o,         // 主设备1读取到的数据
    input wire m1_req_i,                   // 主设备1访问请求标志
    input wire m1_we_i,                    // 主设备1写标志

    // master 2 interface
    input wire[`PJY_MemAddrBus] m2_addr_i,     // 主设备2读、写地址
    input wire[`PJY_MemBus] m2_data_i,         // 主设备2写数据
    output reg[`PJY_MemBus] m2_data_o,         // 主设备2读取到的数据
    input wire m2_req_i,                   // 主设备2访问请求标志
    input wire m2_we_i,                    // 主设备2写标志

    // master 3 interface
    input wire[`PJY_MemAddrBus] m3_addr_i,     // 主设备3读、写地址
    input wire[`PJY_MemBus] m3_data_i,         // 主设备3写数据
    output reg[`PJY_MemBus] m3_data_o,         // 主设备3读取到的数据
    input wire m3_req_i,                   // 主设备3访问请求标志
    input wire m3_we_i,                    // 主设备3写标志

    // slave 0 interface
    output reg[`PJY_MemAddrBus] s0_addr_o,     // 从设备0读、写地址
    output reg[`PJY_MemBus] s0_data_o,         // 从设备0写数据
    input wire[`PJY_MemBus] s0_data_i,         // 从设备0读取到的数据
    output reg s0_we_o,                    // 从设备0写标志
    // TASK1_EXT_MEM_BEGIN: 给片外存储桥接器提供明确的slave请求信号
    output reg s0_req_o,
    // TASK1_EXT_MEM_END

    // slave 1 interface
    output reg[`PJY_MemAddrBus] s1_addr_o,     // 从设备1读、写地址
    output reg[`PJY_MemBus] s1_data_o,         // 从设备1写数据
    input wire[`PJY_MemBus] s1_data_i,         // 从设备1读取到的数据
    output reg s1_we_o,                    // 从设备1写标志
    // TASK1_EXT_MEM_BEGIN: 给片外存储桥接器提供明确的slave请求信号
    output reg s1_req_o,
    // TASK1_EXT_MEM_END

    // slave 2 interface
    output reg[`PJY_MemAddrBus] s2_addr_o,     // 从设备2读、写地址
    output reg[`PJY_MemBus] s2_data_o,         // 从设备2写数据
    input wire[`PJY_MemBus] s2_data_i,         // 从设备2读取到的数据
    output reg s2_we_o,                    // 从设备2写标志

    // slave 3 interface
    output reg[`PJY_MemAddrBus] s3_addr_o,     // 从设备3读、写地址
    output reg[`PJY_MemBus] s3_data_o,         // 从设备3写数据
    input wire[`PJY_MemBus] s3_data_i,         // 从设备3读取到的数据
    output reg s3_we_o,                    // 从设备3写标志

    // slave 4 interface
    output reg[`PJY_MemAddrBus] s4_addr_o,     // 从设备4读、写地址
    output reg[`PJY_MemBus] s4_data_o,         // 从设备4写数据
    input wire[`PJY_MemBus] s4_data_i,         // 从设备4读取到的数据
    output reg s4_we_o,                    // 从设备4写标志

    // slave 5 interface
    output reg[`PJY_MemAddrBus] s5_addr_o,     // 从设备5读、写地址
    output reg[`PJY_MemBus] s5_data_o,         // 从设备5写数据
    input wire[`PJY_MemBus] s5_data_i,         // 从设备5读取到的数据
    output reg s5_we_o,                    // 从设备5写标志

    // TASK2_PWM_BEGIN: slave6用于PWM外设，地址段0x6000_0000
    output reg[`PJY_MemAddrBus] s6_addr_o,
    output reg[`PJY_MemBus] s6_data_o,
    input wire[`PJY_MemBus] s6_data_i,
    output reg s6_we_o,
    // TASK2_PWM_END

    // TASK3_I2C_BEGIN: slave7用于I2C外设，地址段0x7000_0000
    output reg[`PJY_MemAddrBus] s7_addr_o,
    output reg[`PJY_MemBus] s7_data_o,
    input wire[`PJY_MemBus] s7_data_i,
    output reg s7_we_o,
    // TASK3_I2C_END

    output reg hold_flag_o                 // 暂停流水线标志

    );


    // 访问地址的最高4位决定要访问的是哪一个从设备
    // 因此最多支持16个从设备
    parameter [3:0]slave_0 = 4'b0000;
    parameter [3:0]slave_1 = 4'b0001;
    parameter [3:0]slave_2 = 4'b0010;
    parameter [3:0]slave_3 = 4'b0011;
    parameter [3:0]slave_4 = 4'b0100;
    parameter [3:0]slave_5 = 4'b0101;
    // TASK2_PWM_BEGIN: PWM地址段
    parameter [3:0]slave_6 = 4'b0110;
    // TASK2_PWM_END
    // TASK3_I2C_BEGIN: I2C地址段
    parameter [3:0]slave_7 = 4'b0111;
    // TASK3_I2C_END

    parameter [1:0]grant0 = 2'h0;
    parameter [1:0]grant1 = 2'h1;
    parameter [1:0]grant2 = 2'h2;
    parameter [1:0]grant3 = 2'h3;

    wire[3:0] req;
    reg[1:0] grant;


    // 主设备请求信号
    assign req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i};

    // 仲裁逻辑
    // 固定优先级仲裁机制
    // 优先级由高到低：主设备3，主设备0，主设备2，主设备1
    always @ (*) begin
        if (req[3]) begin
            grant = grant3;
            hold_flag_o = `PJY_HoldEnable;
        end else if (req[0]) begin
            grant = grant0;
            hold_flag_o = `PJY_HoldEnable;
        end else if (req[2]) begin
            grant = grant2;
            hold_flag_o = `PJY_HoldEnable;
        end else begin
            grant = grant1;
            hold_flag_o = `PJY_HoldDisable;
        end
    end

    // 根据仲裁结果，选择(访问)对应的从设备
    always @ (*) begin
        m0_data_o = `PJY_ZeroWord;
        m1_data_o = `PJY_INST_NOP;
        m2_data_o = `PJY_ZeroWord;
        m3_data_o = `PJY_ZeroWord;

        s0_addr_o = `PJY_ZeroWord;
        s1_addr_o = `PJY_ZeroWord;
        s2_addr_o = `PJY_ZeroWord;
        s3_addr_o = `PJY_ZeroWord;
        s4_addr_o = `PJY_ZeroWord;
        s5_addr_o = `PJY_ZeroWord;
        // TASK2_PWM_BEGIN: PWM slave默认输出
        s6_addr_o = `PJY_ZeroWord;
        // TASK2_PWM_END
        // TASK3_I2C_BEGIN: I2C slave默认输出
        s7_addr_o = `PJY_ZeroWord;
        // TASK3_I2C_END
        s0_data_o = `PJY_ZeroWord;
        s1_data_o = `PJY_ZeroWord;
        s2_data_o = `PJY_ZeroWord;
        s3_data_o = `PJY_ZeroWord;
        s4_data_o = `PJY_ZeroWord;
        s5_data_o = `PJY_ZeroWord;
        // TASK2_PWM_BEGIN: PWM slave默认输出
        s6_data_o = `PJY_ZeroWord;
        // TASK2_PWM_END
        // TASK3_I2C_BEGIN: I2C slave默认输出
        s7_data_o = `PJY_ZeroWord;
        // TASK3_I2C_END
        s0_we_o = `PJY_WriteDisable;
        s1_we_o = `PJY_WriteDisable;
        // TASK1_EXT_MEM_BEGIN: 默认无片外ROM/RAM访问请求
        s0_req_o = `PJY_RIB_NREQ;
        s1_req_o = `PJY_RIB_NREQ;
        // TASK1_EXT_MEM_END
        s2_we_o = `PJY_WriteDisable;
        s3_we_o = `PJY_WriteDisable;
        s4_we_o = `PJY_WriteDisable;
        s5_we_o = `PJY_WriteDisable;
        // TASK2_PWM_BEGIN: PWM slave默认不写
        s6_we_o = `PJY_WriteDisable;
        // TASK2_PWM_END
        // TASK3_I2C_BEGIN: I2C slave默认不写
        s7_we_o = `PJY_WriteDisable;
        // TASK3_I2C_END

        case (grant)
            grant0: begin
                case (m0_addr_i[31:28])
                    slave_0: begin
                        s0_req_o = `PJY_RIB_REQ;
                        s0_we_o = m0_we_i;
                        s0_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s0_data_o = m0_data_i;
                        m0_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_req_o = `PJY_RIB_REQ;
                        s1_we_o = m0_we_i;
                        s1_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s1_data_o = m0_data_i;
                        m0_data_o = s1_data_i;
                    end
                    slave_2: begin
                        s2_we_o = m0_we_i;
                        s2_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s2_data_o = m0_data_i;
                        m0_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i;
                        s3_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s3_data_o = m0_data_i;
                        m0_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m0_we_i;
                        s4_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s4_data_o = m0_data_i;
                        m0_data_o = s4_data_i;
                    end
                    slave_5: begin
                        s5_we_o = m0_we_i;
                        s5_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s5_data_o = m0_data_i;
                        m0_data_o = s5_data_i;
                    end
                    // TASK2_PWM_BEGIN: PWM slave访问
                    slave_6: begin
                        s6_we_o = m0_we_i;
                        s6_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s6_data_o = m0_data_i;
                        m0_data_o = s6_data_i;
                    end
                    // TASK2_PWM_END
                    // TASK3_I2C_BEGIN: I2C slave访问
                    slave_7: begin
                        s7_we_o = m0_we_i;
                        s7_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s7_data_o = m0_data_i;
                        m0_data_o = s7_data_i;
                    end
                    // TASK3_I2C_END
                    default: begin

                    end
                endcase
            end
            grant1: begin
                case (m1_addr_i[31:28])
                    slave_0: begin
                        s0_req_o = `PJY_RIB_REQ;
                        s0_we_o = m1_we_i;
                        s0_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s0_data_o = m1_data_i;
                        m1_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_req_o = `PJY_RIB_REQ;
                        s1_we_o = m1_we_i;
                        s1_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s1_data_o = m1_data_i;
                        m1_data_o = s1_data_i;
                    end
                    slave_2: begin
                        s2_we_o = m1_we_i;
                        s2_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s2_data_o = m1_data_i;
                        m1_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m1_we_i;
                        s3_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s3_data_o = m1_data_i;
                        m1_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m1_we_i;
                        s4_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s4_data_o = m1_data_i;
                        m1_data_o = s4_data_i;
                    end
                    slave_5: begin
                        s5_we_o = m1_we_i;
                        s5_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s5_data_o = m1_data_i;
                        m1_data_o = s5_data_i;
                    end
                    // TASK2_PWM_BEGIN: PWM slave访问
                    slave_6: begin
                        s6_we_o = m1_we_i;
                        s6_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s6_data_o = m1_data_i;
                        m1_data_o = s6_data_i;
                    end
                    // TASK2_PWM_END
                    // TASK3_I2C_BEGIN: I2C slave访问
                    slave_7: begin
                        s7_we_o = m1_we_i;
                        s7_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s7_data_o = m1_data_i;
                        m1_data_o = s7_data_i;
                    end
                    // TASK3_I2C_END
                    default: begin

                    end
                endcase
            end
            grant2: begin
                case (m2_addr_i[31:28])
                    slave_0: begin
                        s0_req_o = `PJY_RIB_REQ;
                        s0_we_o = m2_we_i;
                        s0_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s0_data_o = m2_data_i;
                        m2_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_req_o = `PJY_RIB_REQ;
                        s1_we_o = m2_we_i;
                        s1_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s1_data_o = m2_data_i;
                        m2_data_o = s1_data_i;
                    end
                    slave_2: begin
                        s2_we_o = m2_we_i;
                        s2_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s2_data_o = m2_data_i;
                        m2_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m2_we_i;
                        s3_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s3_data_o = m2_data_i;
                        m2_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m2_we_i;
                        s4_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s4_data_o = m2_data_i;
                        m2_data_o = s4_data_i;
                    end
                    slave_5: begin
                        s5_we_o = m2_we_i;
                        s5_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s5_data_o = m2_data_i;
                        m2_data_o = s5_data_i;
                    end
                    // TASK2_PWM_BEGIN: PWM slave访问
                    slave_6: begin
                        s6_we_o = m2_we_i;
                        s6_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s6_data_o = m2_data_i;
                        m2_data_o = s6_data_i;
                    end
                    // TASK2_PWM_END
                    // TASK3_I2C_BEGIN: I2C slave访问
                    slave_7: begin
                        s7_we_o = m2_we_i;
                        s7_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s7_data_o = m2_data_i;
                        m2_data_o = s7_data_i;
                    end
                    // TASK3_I2C_END
                    default: begin

                    end
                endcase
            end
            grant3: begin
                case (m3_addr_i[31:28])
                    slave_0: begin
                        s0_req_o = `PJY_RIB_REQ;
                        s0_we_o = m3_we_i;
                        s0_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s0_data_o = m3_data_i;
                        m3_data_o = s0_data_i;
                    end
                    slave_1: begin
                        s1_req_o = `PJY_RIB_REQ;
                        s1_we_o = m3_we_i;
                        s1_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s1_data_o = m3_data_i;
                        m3_data_o = s1_data_i;
                    end
                    slave_2: begin
                        s2_we_o = m3_we_i;
                        s2_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s2_data_o = m3_data_i;
                        m3_data_o = s2_data_i;
                    end
                    slave_3: begin
                        s3_we_o = m3_we_i;
                        s3_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s3_data_o = m3_data_i;
                        m3_data_o = s3_data_i;
                    end
                    slave_4: begin
                        s4_we_o = m3_we_i;
                        s4_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s4_data_o = m3_data_i;
                        m3_data_o = s4_data_i;
                    end
                    slave_5: begin
                        s5_we_o = m3_we_i;
                        s5_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s5_data_o = m3_data_i;
                        m3_data_o = s5_data_i;
                    end
                    // TASK2_PWM_BEGIN: PWM slave访问
                    slave_6: begin
                        s6_we_o = m3_we_i;
                        s6_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s6_data_o = m3_data_i;
                        m3_data_o = s6_data_i;
                    end
                    // TASK2_PWM_END
                    // TASK3_I2C_BEGIN: I2C slave访问
                    slave_7: begin
                        s7_we_o = m3_we_i;
                        s7_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s7_data_o = m3_data_i;
                        m3_data_o = s7_data_i;
                    end
                    // TASK3_I2C_END
                    default: begin

                    end
                endcase
            end
            default: begin

            end
        endcase
    end

endmodule
