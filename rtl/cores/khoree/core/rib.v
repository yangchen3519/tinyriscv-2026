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


// RIB????
module khoree_rib(

    input wire clk,
    input wire rst,

    // master 0 interface
    input wire[`KHOREE_MemAddrBus] m0_addr_i,     // ???0?????
    input wire[`KHOREE_MemBus] m0_data_i,         // ???0???
    output reg[`KHOREE_MemBus] m0_data_o,         // ???0??????
    input wire m0_req_i,                   // ???0??????
    input wire m0_we_i,                    // ???0???
    output wire m0_ack_o,

    // master 1 interface
    input wire[`KHOREE_MemAddrBus] m1_addr_i,     // ???1?????
    input wire[`KHOREE_MemBus] m1_data_i,         // ???1???
    output reg[`KHOREE_MemBus] m1_data_o,         // ???1??????
    input wire m1_req_i,                   // ???1??????
    input wire m1_we_i,                    // ???1???

    // master 2 interface
    input wire[`KHOREE_MemAddrBus] m2_addr_i,     // ???2?????
    input wire[`KHOREE_MemBus] m2_data_i,         // ???2???
    output reg[`KHOREE_MemBus] m2_data_o,         // ???2??????
    input wire m2_req_i,                   // ???2??????
    input wire m2_we_i,                    // ???2???

    // master 3 interface
    input wire[`KHOREE_MemAddrBus] m3_addr_i,     // ???3?????
    input wire[`KHOREE_MemBus] m3_data_i,         // ???3???
    output reg[`KHOREE_MemBus] m3_data_o,         // ???3??????
    input wire m3_req_i,                   // ???3??????
    input wire m3_we_i,                    // ???3???

    // slave 0 interface
    output reg[`KHOREE_MemAddrBus] s0_addr_o,     // ???0?????
    output reg[`KHOREE_MemBus] s0_data_o,         // ???0???
    input wire[`KHOREE_MemBus] s0_data_i,         // ???0??????
    output reg s0_we_o,                    // ???0???
    input wire s0_ack_i,

    // slave 1 interface
    output reg[`KHOREE_MemAddrBus] s1_addr_o,     // ???1?????
    output reg[`KHOREE_MemBus] s1_data_o,         // ???1???
    input wire[`KHOREE_MemBus] s1_data_i,         // ???1??????
    output reg s1_we_o,                    // ???1???
    input wire s1_ack_i,

    // slave 2 interface
    output reg[`KHOREE_MemAddrBus] s2_addr_o,     // ???2?????
    output reg[`KHOREE_MemBus] s2_data_o,         // ???2???
    input wire[`KHOREE_MemBus] s2_data_i,         // ???2??????
    output reg s2_we_o,                    // ???2???

    // slave 3 interface
    output reg[`KHOREE_MemAddrBus] s3_addr_o,     // ???3?????
    output reg[`KHOREE_MemBus] s3_data_o,         // ???3???
    input wire[`KHOREE_MemBus] s3_data_i,         // ???3??????
    output reg s3_we_o,                    // ???3???

    // slave 4 interface
    output reg[`KHOREE_MemAddrBus] s4_addr_o,     // ???4?????
    output reg[`KHOREE_MemBus] s4_data_o,         // ???4???
    input wire[`KHOREE_MemBus] s4_data_i,         // ???4??????
    output reg s4_we_o,                    // ???4???

    // slave 5 interface
    output reg[`KHOREE_MemAddrBus] s5_addr_o,     // ???5?????
    output reg[`KHOREE_MemBus] s5_data_o,         // ???5???
    input wire[`KHOREE_MemBus] s5_data_i,         // ???5??????
    output reg s5_we_o,                    // ???5???

    // slave 6 interface
    output reg[`KHOREE_MemAddrBus] s6_addr_o,     // ???6?????
    output reg[`KHOREE_MemBus] s6_data_o,         // ???6???
    input wire[`KHOREE_MemBus] s6_data_i,         // ???6??????
    output reg s6_we_o,                    // ???6???

    // slave 7 interface
    output reg[`KHOREE_MemAddrBus] s7_addr_o,     // ???7?????
    output reg[`KHOREE_MemBus] s7_data_o,         // ???7???
    input wire[`KHOREE_MemBus] s7_data_i,         // ???7??????
    output reg s7_we_o,                    // ???7???
    output wire s7_req_o,
    input wire s7_ack_i,

    output reg hold_flag_o                 // ???????

    );

    reg m0_ack;
    assign m0_ack_o = m0_ack;
    // Only present an I2C request while master 0 is actually addressing
    // slave 7.  Driving this from every CPU request keeps req_i high during
    // instruction fetches, so the I2C controller cannot detect the rising
    // edge of the later rT access and the core stalls forever.
    assign s7_req_o = m0_req_i && (m0_addr_i[31:28] == 4'h7);

    // ???????4??????????????
    // ??????16????
    parameter [3:0]slave_0 = 4'b0000;
    parameter [3:0]slave_1 = 4'b0001;
    parameter [3:0]slave_2 = 4'b0010;
    parameter [3:0]slave_3 = 4'b0011;
    parameter [3:0]slave_4 = 4'b0100;
    parameter [3:0]slave_5 = 4'b0101;
    parameter [3:0]slave_6 = 4'b0110;
    parameter [3:0]slave_7 = 4'b0111;

    parameter [1:0]grant0 = 2'h0;
    parameter [1:0]grant1 = 2'h1;
    parameter [1:0]grant2 = 2'h2;
    parameter [1:0]grant3 = 2'h3;

    wire[3:0] req;
    reg[1:0] grant;

    // ???????
    assign req = {m3_req_i, m2_req_i, m1_req_i, m0_req_i};

    // ????
    // ?????????
    // ???????????3????0????2????1
    always @ (*) begin
        if (req[3]) begin
            grant = grant3;
            hold_flag_o = `KHOREE_HoldEnable;
        end else if (req[0]) begin
            grant = grant0;
            hold_flag_o = `KHOREE_HoldEnable;
        end else if (req[2]) begin
            grant = grant2;
            hold_flag_o = `KHOREE_HoldEnable;
        end else begin
            grant = grant1;
            hold_flag_o = `KHOREE_HoldDisable;
        end
    end

    // ?????????(??)??????
    always @ (*) begin
        m0_data_o = `KHOREE_ZeroWord;
        m0_ack = `KHOREE_RIB_NACK;
        m1_data_o = `KHOREE_INST_NOP;
        m2_data_o = `KHOREE_ZeroWord;
        m3_data_o = `KHOREE_ZeroWord;

        s0_addr_o = `KHOREE_ZeroWord;
        s1_addr_o = `KHOREE_ZeroWord;
        s2_addr_o = `KHOREE_ZeroWord;
        s3_addr_o = `KHOREE_ZeroWord;
        s4_addr_o = `KHOREE_ZeroWord;
        s5_addr_o = `KHOREE_ZeroWord;
        s6_addr_o = `KHOREE_ZeroWord;
        s7_addr_o = `KHOREE_ZeroWord;

        s0_data_o = `KHOREE_ZeroWord;
        s1_data_o = `KHOREE_ZeroWord;
        s2_data_o = `KHOREE_ZeroWord;
        s3_data_o = `KHOREE_ZeroWord;
        s4_data_o = `KHOREE_ZeroWord;
        s5_data_o = `KHOREE_ZeroWord;
        s6_data_o = `KHOREE_ZeroWord;
        s7_data_o = `KHOREE_ZeroWord;

        s0_we_o = `KHOREE_WriteDisable;
        s1_we_o = `KHOREE_WriteDisable;
        s2_we_o = `KHOREE_WriteDisable;
        s3_we_o = `KHOREE_WriteDisable;
        s4_we_o = `KHOREE_WriteDisable;
        s5_we_o = `KHOREE_WriteDisable;
        s6_we_o = `KHOREE_WriteDisable;
        s7_we_o = `KHOREE_WriteDisable;

        case (grant)
            grant0: begin
                case (m0_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m0_we_i;
                        s0_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s0_data_o = m0_data_i;
                        m0_data_o = s0_data_i;
                        m0_ack = s0_ack_i;
                    end
                    slave_1: begin
                        s1_we_o = m0_we_i;
                        s1_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s1_data_o = m0_data_i;
                        m0_data_o = s1_data_i;
                        m0_ack = s1_ack_i;
                    end
                    slave_2: begin
                        s2_we_o = m0_we_i;
                        s2_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s2_data_o = m0_data_i;
                        m0_data_o = s2_data_i;
                        m0_ack = `KHOREE_RIB_ACK;
                    end
                    slave_3: begin
                        s3_we_o = m0_we_i;
                        s3_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s3_data_o = m0_data_i;
                        m0_data_o = s3_data_i;
                        m0_ack = `KHOREE_RIB_ACK;
                    end
                    slave_4: begin
                        s4_we_o = m0_we_i;
                        s4_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s4_data_o = m0_data_i;
                        m0_data_o = s4_data_i;
                        m0_ack = `KHOREE_RIB_ACK;
                    end
                    slave_5: begin
                        s5_we_o = m0_we_i;
                        s5_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s5_data_o = m0_data_i;
                        m0_data_o = s5_data_i;
                        m0_ack = `KHOREE_RIB_ACK;
                    end
                    slave_6: begin
                        s6_we_o = m0_we_i;
                        s6_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s6_data_o = m0_data_i;
                        m0_data_o = s6_data_i;
                        m0_ack = `KHOREE_RIB_ACK;
                    end
                    slave_7: begin
                        s7_we_o = m0_we_i;
                        s7_addr_o = {{4'h0}, {m0_addr_i[27:0]}};
                        s7_data_o = m0_data_i;
                        m0_data_o = s7_data_i;
                        m0_ack = s7_ack_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant1: begin
                case (m1_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m1_we_i;
                        s0_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s0_data_o = m1_data_i;
                        m1_data_o = s0_data_i;
                    end
                    slave_1: begin
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
                    slave_6: begin
                        s6_we_o = m1_we_i;
                        s6_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s6_data_o = m1_data_i;
                        m1_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m1_we_i;
                        s7_addr_o = {{4'h0}, {m1_addr_i[27:0]}};
                        s7_data_o = m1_data_i;
                        m1_data_o = s7_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant2: begin
                case (m2_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m2_we_i;
                        s0_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s0_data_o = m2_data_i;
                        m2_data_o = s0_data_i;
                    end
                    slave_1: begin
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
                    slave_6: begin
                        s6_we_o = m2_we_i;
                        s6_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s6_data_o = m2_data_i;
                        m2_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m2_we_i;
                        s7_addr_o = {{4'h0}, {m2_addr_i[27:0]}};
                        s7_data_o = m2_data_i;
                        m2_data_o = s7_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            grant3: begin
                case (m3_addr_i[31:28])
                    slave_0: begin
                        s0_we_o = m3_we_i;
                        s0_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s0_data_o = m3_data_i;
                        m3_data_o = s0_data_i;
                    end
                    slave_1: begin
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
                    slave_6: begin
                        s6_we_o = m3_we_i;
                        s6_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s6_data_o = m3_data_i;
                        m3_data_o = s6_data_i;
                    end
                    slave_7: begin
                        s7_we_o = m3_we_i;
                        s7_addr_o = {{4'h0}, {m3_addr_i[27:0]}};
                        s7_data_o = m3_data_i;
                        m3_data_o = s7_data_i;
                    end
                    default: begin

                    end
                endcase
            end
            default: begin

            end
        endcase
    end

endmodule
