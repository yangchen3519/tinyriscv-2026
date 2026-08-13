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

`include "pjy_defines.vh"

// tinyriscv处理器核顶层模块
module pjy_tinyriscv(

    input wire clk,
    input wire rst,

    output wire[`PJY_MemAddrBus] rib_ex_addr_o,    // 读、写外设的地址
    input wire[`PJY_MemBus] rib_ex_data_i,         // 从外设读取的数据
    output wire[`PJY_MemBus] rib_ex_data_o,        // 写入外设的数据
    output wire rib_ex_req_o,                  // 访问外设请求
    output wire rib_ex_we_o,                   // 写外设标志

    output wire[`PJY_MemAddrBus] rib_pc_addr_o,    // 取指地址
    input wire[`PJY_MemBus] rib_pc_data_i,         // 取到的指令内容


    input wire rib_hold_flag_i,                // 总线暂停标志
    // TASK1_EXT_MEM_BEGIN: 片外ROM/RAM桥接器暂停标志
    input wire mem_hold_flag_i,
    // TASK1_EXT_MEM_END
    input wire debug_halt_flag_i,

    // TASK4_SID_BEGIN: Send ID extension handshake
    output wire sid_start_o,
    input wire sid_busy_i,
    input wire sid_done_i,
    // TASK4_SID_END
    // TASK5_RT_BEGIN: Read Temperature extension handshake
    output wire rt_start_o,
    output wire[`PJY_RegAddrBus] rt_reg_waddr_o,
    input wire rt_busy_i,
    input wire rt_done_i,
    input wire[7:0] rt_data_i,
    input wire rt_reg_we_i,
    input wire[`PJY_RegAddrBus] rt_reg_waddr_i,
    input wire[`PJY_RegBus] rt_reg_wdata_i,
    // TASK5_RT_END
    // TASK6_IF_BEGIN: Integrated-and-Fire UART byte handshake
    output wire if_start_o,
    output wire[7:0] if_tx_data_o,
    output wire[`PJY_RegAddrBus] if_reg_waddr_o,
    input wire if_busy_i,
    input wire if_done_i,
    input wire if_reg_we_i,
    input wire[`PJY_RegAddrBus] if_reg_waddr_i,
    input wire[`PJY_RegBus] if_reg_wdata_i,
    input wire custom_hold_flag_i,
    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i
    // TASK6_IF_END

    );

    // pc_reg模块输出信号
	wire[`PJY_InstAddrBus] pc_pc_o;

    // if_id模块输出信号
	wire[`PJY_InstBus] if_inst_o;
    wire[`PJY_InstAddrBus] if_inst_addr_o;

    // id模块输出信号
    wire[`PJY_RegAddrBus] id_reg1_raddr_o;
    wire[`PJY_RegAddrBus] id_reg2_raddr_o;
    wire[`PJY_InstBus] id_inst_o;
    wire[`PJY_InstAddrBus] id_inst_addr_o;
    wire[`PJY_RegBus] id_reg1_rdata_o;
    wire[`PJY_RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`PJY_RegAddrBus] id_reg_waddr_o;
    wire[`PJY_MemAddrBus] id_op1_o;
    wire[`PJY_MemAddrBus] id_op2_o;
    wire[`PJY_MemAddrBus] id_op1_jump_o;
    wire[`PJY_MemAddrBus] id_op2_jump_o;

    // id_ex模块输出信号
    wire[`PJY_InstBus] ie_inst_o;
    wire[`PJY_InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`PJY_RegAddrBus] ie_reg_waddr_o;
    wire[`PJY_RegBus] ie_reg1_rdata_o;
    wire[`PJY_RegBus] ie_reg2_rdata_o;
    wire[`PJY_MemAddrBus] ie_op1_o;
    wire[`PJY_MemAddrBus] ie_op2_o;
    wire[`PJY_MemAddrBus] ie_op1_jump_o;
    wire[`PJY_MemAddrBus] ie_op2_jump_o;

    // ex模块输出信号
    wire[`PJY_MemBus] ex_mem_wdata_o;
    wire[`PJY_MemAddrBus] ex_mem_raddr_o;
    wire[`PJY_MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire[`PJY_RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`PJY_RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`PJY_InstAddrBus] ex_jump_addr_o;
    // TASK4_SID_BEGIN
    wire ex_sid_start_o;
    assign sid_start_o = ex_sid_start_o;
    // TASK4_SID_END
    // TASK5_RT_BEGIN
    wire ex_rt_start_o;
    assign rt_start_o = ex_rt_start_o;
    wire[`PJY_RegAddrBus] ex_rt_reg_waddr_o;
    assign rt_reg_waddr_o = ex_rt_reg_waddr_o;
    // TASK5_RT_END
    // TASK6_IF_BEGIN
    wire ex_if_start_o;
    wire[7:0] ex_if_tx_data_o;
    wire[`PJY_RegAddrBus] ex_if_reg_waddr_o;
    assign if_start_o = ex_if_start_o;
    assign if_tx_data_o = ex_if_tx_data_o;
    assign if_reg_waddr_o = ex_if_reg_waddr_o;
    // TASK6_IF_END

    // regs模块输出信号
    wire[`PJY_RegBus] regs_rdata1_o;
    wire[`PJY_RegBus] regs_rdata2_o;

    // ctrl模块输出信号
    wire[`PJY_Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`PJY_InstAddrBus] ctrl_jump_addr_o;

    assign rib_ex_addr_o = (ex_mem_we_o == `PJY_WriteEnable)? ex_mem_waddr_o: ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;
    assign rib_ex_req_o = ex_mem_req_o;
    assign rib_ex_we_o = ex_mem_we_o;

    assign rib_pc_addr_o = pc_pc_o;


    // pc_reg模块例化
    pjy_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );

    // ctrl模块例化
    pjy_ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_ex_i(ex_hold_flag_o | custom_hold_flag_i),
        .hold_flag_rib_i(rib_hold_flag_i),
        // TASK1_EXT_MEM_BEGIN: 片外ROM/RAM访问期间冻结流水线
        // TASK5_RT_BEGIN
        // TASK6_IF_BEGIN: custom multi-cycle instructions flush younger ID/EX work through hold_flag_ex_i
        .hold_flag_mem_i(mem_hold_flag_i),
        // TASK6_IF_END
        // TASK5_RT_END
        // TASK1_EXT_MEM_END
        .hold_flag_o(ctrl_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o),
        .debug_halt_flag_i(debug_halt_flag_i)
    );

    assign regfile_we_o = ex_reg_we_o | rt_reg_we_i | if_reg_we_i;
    assign regfile_waddr_o = (rt_reg_we_i == `PJY_WriteEnable) ? rt_reg_waddr_i :
                            ((if_reg_we_i == `PJY_WriteEnable) ? if_reg_waddr_i : ex_reg_waddr_o);
    assign regfile_wdata_o = (rt_reg_we_i == `PJY_WriteEnable) ? rt_reg_wdata_i :
                            ((if_reg_we_i == `PJY_WriteEnable) ? if_reg_wdata_i : ex_reg_wdata_o);
    assign regfile_raddr1_o = id_reg1_raddr_o;
    assign regfile_raddr2_o = id_reg2_raddr_o;
    assign regs_rdata1_o = regfile_rdata1_i;
    assign regs_rdata2_o = regfile_rdata2_i;
    // if_id模块例化
    pjy_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // id模块例化
    pjy_id u_id(
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

    // id_ex模块例化
    pjy_id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(ie_inst_o),
        .inst_addr_o(ie_inst_addr_o),
        .reg_we_o(ie_reg_we_o),
        .reg_waddr_o(ie_reg_waddr_o),
        .reg1_rdata_o(ie_reg1_rdata_o),
        .reg2_rdata_o(ie_reg2_rdata_o),
        .op1_i(id_op1_o),
        .op2_i(id_op2_o),
        .op1_jump_i(id_op1_jump_o),
        .op2_jump_i(id_op2_jump_o),
        .op1_o(ie_op1_o),
        .op2_o(ie_op2_o),
        .op1_jump_o(ie_op1_jump_o),
        .op2_jump_o(ie_op2_jump_o)
    );

    // ex模块例化
    pjy_ex u_ex(
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
        .jump_addr_o(ex_jump_addr_o),
        // TASK4_SID_BEGIN
        .sid_busy_i(sid_busy_i),
        .sid_done_i(sid_done_i),
        .sid_start_o(ex_sid_start_o),
        // TASK4_SID_END
        // TASK5_RT_BEGIN
        .rt_busy_i(rt_busy_i),
        .rt_done_i(rt_done_i),
        .rt_data_i(rt_data_i),
        .rt_reg_we_i(rt_reg_we_i),
        .rt_reg_waddr_i(rt_reg_waddr_i),
        .rt_reg_wdata_i(rt_reg_wdata_i),
        .rt_start_o(ex_rt_start_o),
        .rt_reg_waddr_o(ex_rt_reg_waddr_o),
        // TASK5_RT_END
        // TASK6_IF_BEGIN
        .if_busy_i(if_busy_i),
        .if_done_i(if_done_i),
        .if_start_o(ex_if_start_o),
        .if_tx_data_o(ex_if_tx_data_o),
        .if_reg_waddr_o(ex_if_reg_waddr_o)
        // TASK6_IF_END
    );

endmodule
