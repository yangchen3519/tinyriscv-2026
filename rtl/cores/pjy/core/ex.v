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

// 执行模块
// 纯组合逻辑电路
module pjy_ex(

    input wire rst,

    // from id
    input wire[`PJY_InstBus] inst_i,            // 指令内容
    input wire[`PJY_InstAddrBus] inst_addr_i,   // 指令地址
    input wire reg_we_i,                    // 是否写通用寄存器
    input wire[`PJY_RegAddrBus] reg_waddr_i,    // 写通用寄存器地址
    input wire[`PJY_RegBus] reg1_rdata_i,       // 通用寄存器1输入数据
    input wire[`PJY_RegBus] reg2_rdata_i,       // 通用寄存器2输入数据
    input wire csr_we_i,                    // 是否写CSR寄存器
    input wire[`PJY_MemAddrBus] csr_waddr_i,    // 写CSR寄存器地址
    input wire[`PJY_RegBus] csr_rdata_i,        // CSR寄存器输入数据
    input wire int_assert_i,                // 中断发生标志
    input wire[`PJY_InstAddrBus] int_addr_i,    // 中断跳转地址
    input wire[`PJY_MemAddrBus] op1_i,
    input wire[`PJY_MemAddrBus] op2_i,
    input wire[`PJY_MemAddrBus] op1_jump_i,
    input wire[`PJY_MemAddrBus] op2_jump_i,

    // from mem
    input wire[`PJY_MemBus] mem_rdata_i,        // 内存输入数据

    // from div
    input wire div_ready_i,                 // 除法运算完成标志
    input wire[`PJY_RegBus] div_result_i,       // 除法运算结果
    input wire div_busy_i,                  // 除法运算忙标志
    input wire[`PJY_RegAddrBus] div_reg_waddr_i,// 除法运算结束后要写的寄存器地址

    // to mem
    output reg[`PJY_MemBus] mem_wdata_o,        // 写内存数据
    output reg[`PJY_MemAddrBus] mem_raddr_o,    // 读内存地址
    output reg[`PJY_MemAddrBus] mem_waddr_o,    // 写内存地址
    output wire mem_we_o,                   // 是否要写内存
    output wire mem_req_o,                  // 请求访问内存标志

    // to regs
    output wire[`PJY_RegBus] reg_wdata_o,       // 写寄存器数据
    output wire reg_we_o,                   // 是否要写通用寄存器
    output wire[`PJY_RegAddrBus] reg_waddr_o,   // 写通用寄存器地址

    // to csr reg
    output reg[`PJY_RegBus] csr_wdata_o,        // 写CSR寄存器数据
    output wire csr_we_o,                   // 是否要写CSR寄存器
    output wire[`PJY_MemAddrBus] csr_waddr_o,   // 写CSR寄存器地址

    // to div
    output wire div_start_o,                // 开始除法运算标志
    output reg[`PJY_RegBus] div_dividend_o,     // 被除数
    output reg[`PJY_RegBus] div_divisor_o,      // 除数
    output reg[2:0] div_op_o,               // 具体是哪一条除法指令
    output reg[`PJY_RegAddrBus] div_reg_waddr_o,// 除法运算结束后要写的寄存器地址

    // to ctrl
    output wire hold_flag_o,                // 是否暂停标志
    output wire jump_flag_o,                // 是否跳转标志
    output wire[`PJY_InstAddrBus] jump_addr_o,  // 跳转目的地址

    // TASK4_SID_BEGIN: Send ID extension handshake
    input wire sid_busy_i,
    input wire sid_done_i,
    output wire sid_start_o,
    // TASK4_SID_END
    // TASK5_RT_BEGIN: Read Temperature extension handshake
    input wire rt_busy_i,
    input wire rt_done_i,
    input wire[7:0] rt_data_i,
    input wire rt_reg_we_i,
    input wire[`PJY_RegAddrBus] rt_reg_waddr_i,
    input wire[`PJY_RegBus] rt_reg_wdata_i,
    output wire rt_start_o,
    output wire[`PJY_RegAddrBus] rt_reg_waddr_o,
    // TASK5_RT_END
    // TASK6_IF_BEGIN: Integrated-and-Fire UART byte handshake
    input wire if_busy_i,
    input wire if_done_i,
    output wire if_start_o,
    output wire[7:0] if_tx_data_o,
    output wire[`PJY_RegAddrBus] if_reg_waddr_o
    // TASK6_IF_END

    );

    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_jump_add_op2_jump_res;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[4:0] uimm;
    // TASK4_SID_BEGIN: opcode 0x2f/funct3 0 sends student ID through UART
    wire sid_inst;
    // TASK4_SID_END
    // TASK5_RT_BEGIN
    wire rt_inst;
    // TASK5_RT_END
    // TASK6_IF_BEGIN
    wire if_inst;
    wire if_fire;
    wire[31:0] if_imm_sext;
    // TASK6_IF_END
    reg[`PJY_RegBus] reg_wdata;
    reg reg_we;
    reg[`PJY_RegAddrBus] reg_waddr;
    reg[`PJY_RegBus] div_wdata;
    reg div_we;
    reg[`PJY_RegAddrBus] div_waddr;
    reg div_hold_flag;
    reg div_jump_flag;
    reg[`PJY_InstAddrBus] div_jump_addr;
    reg hold_flag;
    reg jump_flag;
    reg[`PJY_InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg div_start;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign uimm = inst_i[19:15];
    // TASK4_SID_BEGIN
    assign sid_inst = (opcode == `PJY_INST_SID) && (funct3 == `PJY_INST_SID_F3);
    assign sid_start_o = sid_inst && (sid_busy_i == `PJY_False) && (sid_done_i == `PJY_False);
    // TASK4_SID_END
    // TASK5_RT_BEGIN
    assign rt_inst = (opcode == `PJY_INST_SID) && (funct3 == `PJY_INST_RT_F3);
    assign rt_start_o = rt_inst && (rt_busy_i == `PJY_False) && (rt_done_i == `PJY_False);
    assign rt_reg_waddr_o = reg_waddr_i;
    // TASK5_RT_END
    // TASK6_IF_BEGIN
    assign if_inst = (opcode == `PJY_INST_SID) && (funct3 == `PJY_INST_IF_F3);
    assign if_imm_sext = {{20{inst_i[31]}}, inst_i[31:20]};
    assign if_fire = if_inst && (if_imm_sext == `PJY_ZeroWord) && (reg1_rdata_i >= reg2_rdata_i);
    assign if_start_o = if_fire && (if_busy_i == `PJY_False) && (if_done_i == `PJY_False);
    assign if_tx_data_o = reg1_rdata_i[7:0];
    assign if_reg_waddr_o = reg_waddr_i;
    // TASK6_IF_END

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    // 有符号数比较
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    // 无符号数比较
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);

    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

    assign div_start_o = (int_assert_i == `PJY_INT_ASSERT)? `PJY_DivStop: div_start;

    assign reg_wdata_o = reg_wdata | div_wdata;
    // 响应中断时不写通用寄存器
    assign reg_we_o = (int_assert_i == `PJY_INT_ASSERT)? `PJY_WriteDisable: (reg_we || div_we);
    assign reg_waddr_o = reg_waddr | div_waddr;

    // 响应中断时不写内存
    assign mem_we_o = (int_assert_i == `PJY_INT_ASSERT)? `PJY_WriteDisable: mem_we;

    // 响应中断时不向总线请求访问内存
    assign mem_req_o = (int_assert_i == `PJY_INT_ASSERT)? `PJY_RIB_NREQ: mem_req;

    assign hold_flag_o = hold_flag || div_hold_flag;
    assign jump_flag_o = jump_flag || div_jump_flag || ((int_assert_i == `PJY_INT_ASSERT)? `PJY_JumpEnable: `PJY_JumpDisable);
    assign jump_addr_o = (int_assert_i == `PJY_INT_ASSERT)? int_addr_i: (jump_addr | div_jump_addr);

    // 响应中断时不写CSR寄存器
    assign csr_we_o = (int_assert_i == `PJY_INT_ASSERT)? `PJY_WriteDisable: csr_we_i;
    assign csr_waddr_o = csr_waddr_i;


    // 处理除法指令
    always @ (*) begin
        div_dividend_o = reg1_rdata_i;
        div_divisor_o = reg2_rdata_i;
        div_op_o = funct3;
        div_reg_waddr_o = reg_waddr_i;
        if (1'b0) begin
            div_we = `PJY_WriteDisable;
            div_wdata = `PJY_ZeroWord;
            div_waddr = `PJY_ZeroWord;
            case (funct3)
                `PJY_INST_DIV, `PJY_INST_DIVU, `PJY_INST_REM, `PJY_INST_REMU: begin
                    div_start = `PJY_DivStart;
                    div_jump_flag = `PJY_JumpEnable;
                    div_hold_flag = `PJY_HoldEnable;
                    div_jump_addr = op1_jump_add_op2_jump_res;
                end
                default: begin
                    div_start = `PJY_DivStop;
                    div_jump_flag = `PJY_JumpDisable;
                    div_hold_flag = `PJY_HoldDisable;
                    div_jump_addr = `PJY_ZeroWord;
                end
            endcase
        end else begin
            div_jump_flag = `PJY_JumpDisable;
            div_jump_addr = `PJY_ZeroWord;
            if (div_busy_i == `PJY_True) begin
                div_start = `PJY_DivStart;
                div_we = `PJY_WriteDisable;
                div_wdata = `PJY_ZeroWord;
                div_waddr = `PJY_ZeroWord;
                div_hold_flag = `PJY_HoldEnable;
            end else begin
                div_start = `PJY_DivStop;
                div_hold_flag = `PJY_HoldDisable;
                if (div_ready_i == `PJY_DivResultReady) begin
                    div_wdata = div_result_i;
                    div_waddr = div_reg_waddr_i;
                    div_we = `PJY_WriteEnable;
                end else begin
                    div_we = `PJY_WriteDisable;
                    div_wdata = `PJY_ZeroWord;
                    div_waddr = `PJY_ZeroWord;
                end
            end
        end
    end

    // 执行
    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `PJY_RIB_NREQ;
        csr_wdata_o = `PJY_ZeroWord;

        case (opcode)
            `PJY_INST_TYPE_I: begin
                case (funct3)
                    `PJY_INST_ADDI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `PJY_INST_SLTI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `PJY_INST_SLTIU: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `PJY_INST_XORI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `PJY_INST_ORI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `PJY_INST_ANDI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `PJY_INST_SLLI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `PJY_INST_SRI: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            `PJY_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `PJY_INST_ADD_SUB: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `PJY_INST_SLL: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `PJY_INST_SLT: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `PJY_INST_SLTU: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `PJY_INST_XOR: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `PJY_INST_SR: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `PJY_INST_OR: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `PJY_INST_AND: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `PJY_JumpDisable;
                            hold_flag = `PJY_HoldDisable;
                            jump_addr = `PJY_ZeroWord;
                            mem_wdata_o = `PJY_ZeroWord;
                            mem_raddr_o = `PJY_ZeroWord;
                            mem_waddr_o = `PJY_ZeroWord;
                            mem_we = `PJY_WriteDisable;
                            reg_wdata = `PJY_ZeroWord;
                        end
                    endcase
                end else begin
                    jump_flag = `PJY_JumpDisable;
                    hold_flag = `PJY_HoldDisable;
                    jump_addr = `PJY_ZeroWord;
                    mem_wdata_o = `PJY_ZeroWord;
                    mem_raddr_o = `PJY_ZeroWord;
                    mem_waddr_o = `PJY_ZeroWord;
                    mem_we = `PJY_WriteDisable;
                    reg_wdata = `PJY_ZeroWord;
                end
            end
            `PJY_INST_TYPE_L: begin
                case (funct3)
                    `PJY_INST_LB: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        mem_req = `PJY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `PJY_INST_LH: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        mem_req = `PJY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `PJY_INST_LW: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        mem_req = `PJY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        reg_wdata = mem_rdata_i;
                    end
                    `PJY_INST_LBU: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        mem_req = `PJY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_raddr_index)
                            2'b00: begin
                                reg_wdata = {24'h0, mem_rdata_i[7:0]};
                            end
                            2'b01: begin
                                reg_wdata = {24'h0, mem_rdata_i[15:8]};
                            end
                            2'b10: begin
                                reg_wdata = {24'h0, mem_rdata_i[23:16]};
                            end
                            default: begin
                                reg_wdata = {24'h0, mem_rdata_i[31:24]};
                            end
                        endcase
                    end
                    `PJY_INST_LHU: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        mem_req = `PJY_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            `PJY_INST_TYPE_S: begin
                case (funct3)
                    `PJY_INST_SB: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        reg_wdata = `PJY_ZeroWord;
                        mem_we = `PJY_WriteEnable;
                        mem_req = `PJY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        case (mem_waddr_index)
                            2'b00: begin
                                mem_wdata_o = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                            end
                            2'b01: begin
                                mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                            end
                            2'b10: begin
                                mem_wdata_o = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                            end
                            default: begin
                                mem_wdata_o = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                            end
                        endcase
                    end
                    `PJY_INST_SH: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        reg_wdata = `PJY_ZeroWord;
                        mem_we = `PJY_WriteEnable;
                        mem_req = `PJY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        if (mem_waddr_index == 2'b00) begin
                            mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                        end else begin
                            mem_wdata_o = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                        end
                    end
                    `PJY_INST_SW: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        reg_wdata = `PJY_ZeroWord;
                        mem_we = `PJY_WriteEnable;
                        mem_req = `PJY_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        mem_wdata_o = ((rt_reg_we_i == `PJY_WriteEnable) && (rt_reg_waddr_i == inst_i[24:20])) ?
                                      rt_reg_wdata_i : reg2_rdata_i;
                    end
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            `PJY_INST_TYPE_B: begin
                case (funct3)
                    `PJY_INST_BEQ: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = op1_eq_op2 & `PJY_JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `PJY_INST_BNE: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = (~op1_eq_op2) & `PJY_JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `PJY_INST_BLT: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `PJY_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `PJY_INST_BGE: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `PJY_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `PJY_INST_BLTU: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `PJY_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `PJY_INST_BGEU: begin
                        hold_flag = `PJY_HoldDisable;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `PJY_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            `PJY_INST_JAL, `PJY_INST_JALR: begin
                hold_flag = `PJY_HoldDisable;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                jump_flag = `PJY_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `PJY_INST_LUI, `PJY_INST_AUIPC: begin
                hold_flag = `PJY_HoldDisable;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                jump_addr = `PJY_ZeroWord;
                jump_flag = `PJY_JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `PJY_INST_NOP_OP: begin
                jump_flag = `PJY_JumpDisable;
                hold_flag = `PJY_HoldDisable;
                jump_addr = `PJY_ZeroWord;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                reg_wdata = `PJY_ZeroWord;
            end
            `PJY_INST_FENCE: begin
                hold_flag = `PJY_HoldDisable;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                reg_wdata = `PJY_ZeroWord;
                jump_flag = `PJY_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            `PJY_INST_CSR: begin
                jump_flag = `PJY_JumpDisable;
                hold_flag = `PJY_HoldDisable;
                jump_addr = `PJY_ZeroWord;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                case (funct3)
                    `PJY_INST_CSRRW: begin
                        csr_wdata_o = reg1_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `PJY_INST_CSRRS: begin
                        csr_wdata_o = reg1_rdata_i | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `PJY_INST_CSRRC: begin
                        csr_wdata_o = csr_rdata_i & (~reg1_rdata_i);
                        reg_wdata = csr_rdata_i;
                    end
                    `PJY_INST_CSRRWI: begin
                        csr_wdata_o = {27'h0, uimm};
                        reg_wdata = csr_rdata_i;
                    end
                    `PJY_INST_CSRRSI: begin
                        csr_wdata_o = {27'h0, uimm} | csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    `PJY_INST_CSRRCI: begin
                        csr_wdata_o = (~{27'h0, uimm}) & csr_rdata_i;
                        reg_wdata = csr_rdata_i;
                    end
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            // TASK4_SID_BEGIN: Send ID is a side-effect instruction with no register write
            `PJY_INST_SID: begin
                case (funct3)
                    `PJY_INST_SID_F3: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = (sid_done_i == `PJY_False) ? `PJY_HoldEnable : `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_we = `PJY_WriteDisable;
                        reg_waddr = `PJY_ZeroReg;
                        reg_wdata = `PJY_ZeroWord;
                    end
                    // TASK5_RT_BEGIN: Read LM75 temperature high byte and write rd
                    `PJY_INST_RT_F3: begin
                        jump_flag = rt_start_o ? `PJY_JumpEnable : `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = inst_addr_i + 32'h4;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_we = (rt_done_i == `PJY_True) ? `PJY_WriteEnable : `PJY_WriteDisable;
                        reg_waddr = reg_waddr_i;
                        reg_wdata = {24'h0, rt_data_i};
                    end
                    // TASK5_RT_END
                    // TASK6_IF_BEGIN: Integrated-and-Fire neuron primitive
                    `PJY_INST_IF_F3: begin
                        jump_flag = if_start_o ? `PJY_JumpEnable : `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = inst_addr_i + 32'h4;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_we = (if_fire && (if_done_i == `PJY_False)) ? `PJY_WriteDisable : `PJY_WriteEnable;
                        reg_waddr = reg_waddr_i;
                        if (if_imm_sext != `PJY_ZeroWord) begin
                            reg_wdata = reg1_rdata_i + if_imm_sext;
                        end else if (reg1_rdata_i >= reg2_rdata_i) begin
                            reg_wdata = `PJY_ZeroWord;
                        end else begin
                            reg_wdata = reg1_rdata_i;
                        end
                    end
                    // TASK6_IF_END
                    default: begin
                        jump_flag = `PJY_JumpDisable;
                        hold_flag = `PJY_HoldDisable;
                        jump_addr = `PJY_ZeroWord;
                        mem_wdata_o = `PJY_ZeroWord;
                        mem_raddr_o = `PJY_ZeroWord;
                        mem_waddr_o = `PJY_ZeroWord;
                        mem_we = `PJY_WriteDisable;
                        reg_we = `PJY_WriteDisable;
                        reg_waddr = `PJY_ZeroReg;
                        reg_wdata = `PJY_ZeroWord;
                    end
                endcase
            end
            // TASK4_SID_END
            default: begin
                jump_flag = `PJY_JumpDisable;
                hold_flag = `PJY_HoldDisable;
                jump_addr = `PJY_ZeroWord;
                mem_wdata_o = `PJY_ZeroWord;
                mem_raddr_o = `PJY_ZeroWord;
                mem_waddr_o = `PJY_ZeroWord;
                mem_we = `PJY_WriteDisable;
                reg_wdata = `PJY_ZeroWord;
            end
        endcase
    end

endmodule
