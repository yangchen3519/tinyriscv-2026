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

// tinyriscv处�?�器� �顶层模�?-
module khoree_tinyriscv(

    input wire clk,
    input wire rst,

    output wire[`KHOREE_MemAddrBus] rib_ex_addr_o,    // 读�?写�-设的地�?�
    input wire[`KHOREE_MemBus] rib_ex_data_i,         // 从�-设读�?-的数�?�
    output wire[`KHOREE_MemBus] rib_ex_data_o,        // 写入�-设的数�?�
    output wire rib_ex_req_o,                  // 访�-��-设请求
    output wire rib_ex_we_o,                   // 写�-设� ��-
    input wire rib_ex_ack_i,

    output wire[`KHOREE_MemAddrBus] rib_pc_addr_o,    // �?-指地�?�
    input wire[`KHOREE_MemBus] rib_pc_data_i,         // �?-到的指令内容

    input wire rib_hold_flag_i,                // 总线暂�?�� ��-

    output wire regfile_we_o,
    output wire[`KHOREE_RegAddrBus] regfile_waddr_o,
    output wire[`KHOREE_RegBus] regfile_wdata_o,
    output wire[`KHOREE_RegAddrBus] regfile_raddr1_o,
    output wire[`KHOREE_RegAddrBus] regfile_raddr2_o,
    input wire[`KHOREE_RegBus] regfile_rdata1_i,
    input wire[`KHOREE_RegBus] regfile_rdata2_i

    );

    // pc_reg模�?-�"出信�?�
	wire[`KHOREE_InstAddrBus] pc_pc_o;

    // if_id模�?-�"出信�?�
	wire[`KHOREE_InstBus] if_inst_o;
    wire[`KHOREE_InstAddrBus] if_inst_addr_o;
    wire if_prdt_taken_o;

    // id模�?-�"出信�?�
    wire[`KHOREE_RegAddrBus] id_reg1_raddr_o;
    wire[`KHOREE_RegAddrBus] id_reg2_raddr_o;
    wire[`KHOREE_InstBus] id_inst_o;
    wire[`KHOREE_InstAddrBus] id_inst_addr_o;
    wire[`KHOREE_RegBus] id_reg1_rdata_o;
    wire[`KHOREE_RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`KHOREE_RegAddrBus] id_reg_waddr_o;
    wire[`KHOREE_MemAddrBus] id_op1_o;
    wire[`KHOREE_MemAddrBus] id_op2_o;
    wire[`KHOREE_MemAddrBus] id_op1_jump_o;
    wire[`KHOREE_MemAddrBus] id_op2_jump_o;
    wire id_prdt_taken_o;

    // id_ex模�?-�"出信�?�
    wire[`KHOREE_InstBus] ie_inst_o;
    wire[`KHOREE_InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`KHOREE_RegAddrBus] ie_reg_waddr_o;
    wire[`KHOREE_RegBus] ie_reg1_rdata_o;
    wire[`KHOREE_RegBus] ie_reg2_rdata_o;
    wire[`KHOREE_MemAddrBus] ie_op1_o;
    wire[`KHOREE_MemAddrBus] ie_op2_o;
    wire[`KHOREE_MemAddrBus] ie_op1_jump_o;
    wire[`KHOREE_MemAddrBus] ie_op2_jump_o;
    wire ie_prdt_taken_o;

    // ex模�?-�"出信�?�
    wire[`KHOREE_MemBus] ex_mem_wdata_o;
    wire[`KHOREE_MemAddrBus] ex_mem_raddr_o;
    wire[`KHOREE_MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire ex_mem_ack_i;
    wire[`KHOREE_RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`KHOREE_RegAddrBus] ex_reg_waddr_o;
    wire ex_stall_o;
    wire ex_hold_flag_unused;
    wire ex_jump_flag_o;
    wire[`KHOREE_InstAddrBus] ex_jump_addr_o;

    // regs模�?-�"出信�?�
    wire[`KHOREE_RegBus] regs_rdata1_o;
    wire[`KHOREE_RegBus] regs_rdata2_o;

    // ctrl模�?-�"出信�?�
    wire[`KHOREE_Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`KHOREE_InstAddrBus] ctrl_jump_addr_o;

    // branch prediction
    wire inst_jal;
    wire inst_bxx;
    wire inst_jalr;
    wire [`KHOREE_InstAddrBus] jump_and_branch_imm;
    wire bpu_prdt_taken_o;
    wire [`KHOREE_InstAddrBus] bpu_prdt_addr_o;

    assign rib_ex_addr_o = (ex_mem_we_o == `KHOREE_WriteEnable)? ex_mem_waddr_o: ex_mem_raddr_o;
    assign rib_ex_data_o = ex_mem_wdata_o;
    assign rib_ex_req_o = ex_mem_req_o;
    assign rib_ex_we_o = ex_mem_we_o;
    assign ex_mem_ack_i = rib_ex_ack_i;

    assign rib_pc_addr_o = pc_pc_o;

    // The four-core top owns the only physical register file (YC implementation).
    assign regfile_we_o = ex_reg_we_o;
    assign regfile_waddr_o = ex_reg_waddr_o;
    assign regfile_wdata_o = ex_reg_wdata_o;
    assign regfile_raddr1_o = id_reg1_raddr_o;
    assign regfile_raddr2_o = id_reg2_raddr_o;
    assign regs_rdata1_o = regfile_rdata1_i;
    assign regs_rdata2_o = regfile_rdata2_i;


    // pc_reg模�?-例�-
    khoree_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .stall_flag_i(ex_stall_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o),
        .prdt_taken_i(bpu_prdt_taken_o),
        .prdt_addr_i(bpu_prdt_addr_o)
    );

    // ctrl模�?-例�-
    khoree_ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .hold_flag_rib_i(rib_hold_flag_i),
        .hold_flag_o(ctrl_hold_flag_o),
        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o)
    );

    khoree_pre_id u_pre_id(
        .inst_i(rib_pc_data_i),
        .inst_jal_o(inst_jal),
        .inst_jalr_o(inst_jalr),
        .inst_bxx_o(inst_bxx),
        .jump_and_branch_imm_o(jump_and_branch_imm)
    );

    khoree_bpu u_bpu(
        .pc_i(pc_pc_o),
        .inst_jal_i(inst_jal),
        .inst_jalr_i(inst_jalr),
        .inst_bxx_i(inst_bxx),
        .jump_and_branch_imm_i(jump_and_branch_imm),
        .prdt_taken_o(bpu_prdt_taken_o),
        .prdt_addr_o(bpu_prdt_addr_o)
    );

    // if_id模�?-例�-
    khoree_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .stall_flag_i(ex_stall_o),
        .inst_o(if_inst_o),
        .prdt_taken_i(bpu_prdt_taken_o),
        .prdt_taken_o(if_prdt_taken_o),
        .inst_addr_o(if_inst_addr_o)
    );

    // id模�?-例�-
    khoree_id u_id(
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
        .op2_jump_o(id_op2_jump_o),
        .prdt_taken_i(if_prdt_taken_o),
        .prdt_taken_o(id_prdt_taken_o)
    );

    // id_ex模�?-例�-
    khoree_id_ex u_id_ex(
        .clk(clk),
        .rst(rst),
        .inst_i(id_inst_o),
        .inst_addr_i(id_inst_addr_o),
        .reg_we_i(id_reg_we_o),
        .reg_waddr_i(id_reg_waddr_o),
        .reg1_rdata_i(id_reg1_rdata_o),
        .reg2_rdata_i(id_reg2_rdata_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .stall_flag_i(ex_stall_o),
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
        .op2_jump_o(ie_op2_jump_o),
        .prdt_taken_i(id_prdt_taken_o),
        .prdt_taken_o(ie_prdt_taken_o)
    );

    // ex模�?-例�-
    khoree_ex u_ex(
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
        .mem_wdata_o(ex_mem_wdata_o),
        .mem_raddr_o(ex_mem_raddr_o),
        .mem_waddr_o(ex_mem_waddr_o),
        .mem_we_o(ex_mem_we_o),
        .mem_req_o(ex_mem_req_o),
        .mem_ack_i(ex_mem_ack_i),
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_unused),
        .stall(ex_stall_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o),
        .prdt_taken_i(ie_prdt_taken_o)
    );

endmodule
