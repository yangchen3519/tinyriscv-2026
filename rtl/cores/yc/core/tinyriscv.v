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

// tinyriscv处理器核顶层模块
module yc_tinyriscv(

    input wire clk,
    input wire rst,

    // Data access channel.
    output wire[`YC_MemAddrBus] rib_ex_addr_o,
    input wire[`YC_MemBus] rib_ex_data_i,
    input wire rib_ex_ack_i,
    output wire[`YC_MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,

    // Instruction fetch channel.
    output wire[`YC_MemAddrBus] rib_pc_addr_o,
    input wire[`YC_MemBus] rib_pc_data_i,

    // Global hold from the system bus and external downloader.
    input wire rib_hold_flag_i,
    input wire debug_halt_flag_i,

    // Shared YC register-file interface.
    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i

    );

    // PC stage outputs.
    wire[`YC_InstAddrBus] pc_pc_o;

    // IF/ID pipeline register outputs.
    wire[`YC_InstBus] if_inst_o;
    wire[`YC_InstAddrBus] if_inst_addr_o;

    // Decode stage outputs.
    wire[`YC_RegAddrBus] id_reg1_raddr_o;
    wire[`YC_RegAddrBus] id_reg2_raddr_o;
    wire[`YC_InstBus] id_inst_o;
    wire[`YC_InstAddrBus] id_inst_addr_o;
    wire[`YC_RegBus] id_reg1_rdata_o;
    wire[`YC_RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`YC_RegAddrBus] id_reg_waddr_o;
    wire[`YC_MemAddrBus] id_op1_o;
    wire[`YC_MemAddrBus] id_op2_o;
    wire[`YC_MemAddrBus] id_op1_jump_o;
    wire[`YC_MemAddrBus] id_op2_jump_o;

    // ID/EX pipeline register outputs.
    wire[`YC_InstBus] ie_inst_o;
    wire[`YC_InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`YC_RegAddrBus] ie_reg_waddr_o;
    wire[`YC_RegBus] ie_reg1_rdata_o;
    wire[`YC_RegBus] ie_reg2_rdata_o;
    wire[`YC_MemAddrBus] ie_op1_o;
    wire[`YC_MemAddrBus] ie_op2_o;
    wire[`YC_MemAddrBus] ie_op1_jump_o;
    wire[`YC_MemAddrBus] ie_op2_jump_o;

    // Execute stage outputs.
    wire[`YC_MemBus] ex_mem_wdata_o;
    wire[`YC_MemAddrBus] ex_mem_raddr_o;
    wire[`YC_MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire[`YC_RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`YC_RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`YC_InstAddrBus] ex_jump_addr_o;

    // Register file read data.
    wire[`YC_RegBus] regs_rdata1_o;
    wire[`YC_RegBus] regs_rdata2_o;

    // Global control outputs.
    wire[`YC_Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`YC_InstAddrBus] ctrl_jump_addr_o;

    // Route load/store traffic onto the shared bus.
    assign rib_ex_addr_o = (ex_mem_we_o == `YC_WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;
    assign rib_ex_req_o = ex_mem_req_o;
    assign rib_ex_we_o = ex_mem_we_o;

    // Route the current PC onto the instruction fetch bus.
    assign rib_pc_addr_o = pc_pc_o;

    // Program counter register.
    yc_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );

    // Global jump/hold control.
    yc_ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_rib_i(rib_hold_flag_i),
        .debug_halt_flag_i(debug_halt_flag_i),
        .hold_flag_o(ctrl_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o)
    );

    assign regfile_we_o = ex_reg_we_o;
    assign regfile_waddr_o = ex_reg_waddr_o;
    assign regfile_wdata_o = ex_reg_wdata_o;
    assign regfile_raddr1_o = id_reg1_raddr_o;
    assign regfile_raddr2_o = id_reg2_raddr_o;
    assign regs_rdata1_o = regfile_rdata1_i;
    assign regs_rdata2_o = regfile_rdata2_i;

    // IF/ID pipeline register.
    yc_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // Decode stage.
    yc_id u_id(
        .rst(rst),
        .inst_i(if_inst_o),
        .inst_addr_i(if_inst_addr_o),
        .reg1_rdata_i(regs_rdata1_o),
        .reg2_rdata_i(regs_rdata2_o),
        .ex_jump_flag_i(ex_jump_flag_o),
        .reg1_raddr_o(id_reg1_raddr_o),
        .reg2_raddr_o(id_reg2_raddr_o),
        .inst_o(id_inst_o),
        .inst_addr_o(id_inst_addr_o),
        .reg1_rdata_o(id_reg1_rdata_o),
        .reg2_rdata_o(id_reg2_rdata_o),
        .reg_we_o(id_reg_we_o),
        .reg_waddr_o(id_reg_waddr_o),
        .op1_o(id_op1_o),
        .op2_o(id_op2_o),
        .op1_jump_o(id_op1_jump_o),
        .op2_jump_o(id_op2_jump_o)
    );

    // ID/EX pipeline register.
    yc_id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o)
    );

    // Execute stage.
    yc_ex u_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(ie_inst_o),
        .inst_addr_i(ie_inst_addr_o),
        .reg_we_i(ie_reg_we_o),
        .reg_waddr_i(ie_reg_waddr_o),
        .reg1_rdata_i(ie_reg1_rdata_o),
        .reg2_rdata_i(ie_reg2_rdata_o),
        .op1_i(ie_op1_o),
        .op2_i(ie_op2_o),
        .op1_jump_i(ie_op1_jump_o),
        .op2_jump_i(ie_op2_jump_o),
        .mem_rdata_i(rib_ex_data_i),
        .mem_ack_i(rib_ex_ack_i),
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o)
    );

endmodule
