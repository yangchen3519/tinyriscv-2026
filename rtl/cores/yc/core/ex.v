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

// 执行模块
// 纯组合�?�辑电路
module yc_ex(

    input wire clk,
    input wire rst,

    // from id
    input wire[`YC_InstBus] inst_i,            // Instruction word
    input wire[`YC_InstAddrBus] inst_addr_i,   // Instruction address
    input wire reg_we_i,                    // Register write enable
    input wire[`YC_RegAddrBus] reg_waddr_i,    // Register write address
    input wire[`YC_RegBus] reg1_rdata_i,       // Register source 1 data
    input wire[`YC_RegBus] reg2_rdata_i,       // Register source 2 data
    input wire[`YC_MemAddrBus] op1_i,
    input wire[`YC_MemAddrBus] op2_i,
    input wire[`YC_MemAddrBus] op1_jump_i,
    input wire[`YC_MemAddrBus] op2_jump_i,

    // from mem
    input wire[`YC_MemBus] mem_rdata_i,        // Memory read data
    input wire mem_ack_i,                   // Memory access acknowledge

    // to mem
    output reg[`YC_MemBus] mem_wdata_o,        // Memory write data
    output reg[`YC_MemAddrBus] mem_raddr_o,    // Memory read address
    output reg[`YC_MemAddrBus] mem_waddr_o,    // Memory write address
    output wire mem_we_o,                   // Memory write enable
    output wire mem_req_o,                  // Memory access request

    // to regs
    output wire[`YC_RegBus] reg_wdata_o,       // Register write-back data
    output wire reg_we_o,                   // Register write-back enable
    output wire[`YC_RegAddrBus] reg_waddr_o,   // Register write-back address

    // to ctrl
    output wire hold_flag_o,                // Pipeline hold request
    output wire jump_flag_o,                // Redirect request
    output wire[`YC_InstAddrBus] jump_addr_o   // Redirect target

    );

    localparam [31:0] I2C_CTRL_ADDR = 32'h7001_0000;
    localparam [31:0] I2C_RXDATA_ADDR = 32'h7003_0000;
    // Robust LM75 flow: write Temp pointer 0x00, issue a repeated START,
    // then read back the 2-byte temperature register.
    localparam [31:0] I2C_CTRL_START_TEMP_READ = 32'h0090_002f;
    localparam [1:0] IF_ST_IDLE = 2'd0;
    localparam [1:0] IF_ST_WAIT_READY = 2'd1;
    localparam [1:0] IF_ST_SEND_CMD = 2'd2;
    localparam [1:0] IF_ST_WB = 2'd3;
    localparam [3:0] RT_ST_IDLE = 4'd0;
    localparam [3:0] RT_ST_START = 4'd1;
    localparam [3:0] RT_ST_WAIT = 4'd2;
    localparam [3:0] RT_ST_READ_RX = 4'd3;
    localparam [3:0] RT_ST_WB = 4'd4;

    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[31:0] sr_shift;
    wire[31:0] sri_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] sri_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] op1_add_simm_res;
    wire[31:0] op1_jump_add_op2_jump_res;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire[6:0] opcode;
    wire[2:0] funct3;
    wire[6:0] funct7;
    wire[4:0] rd;
    wire[4:0] uimm;
    wire[31:0] imm;
    reg[`YC_RegBus] reg_wdata;
    reg reg_we;
    reg[`YC_RegAddrBus] reg_waddr;
    reg hold_flag;
    reg jump_flag;
    reg[`YC_InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg if_fire_active;
    reg [1:0] if_fire_state;
    reg [7:0] if_fire_byte;
    reg [4:0] if_fire_rd;
    reg [`YC_InstAddrBus] if_fire_resume_pc;
    reg rt_active;
    reg [3:0] rt_state;
    reg [4:0] rt_rd;
    reg [`YC_RegBus] rt_result;
    reg [`YC_InstAddrBus] rt_resume_pc;
    reg rt_i2c_seen_busy;
    reg ext_mem_active;
    reg ext_mem_is_load;
    reg ext_mem_rmw;
    reg ext_mem_write_phase;
    reg ext_mem_ack_seen_low;
    reg [2:0] ext_mem_funct3;
    reg [`YC_RegAddrBus] ext_mem_rd;
    reg [`YC_MemAddrBus] ext_mem_addr;
    reg [`YC_RegBus] ext_mem_wdata;
    reg [`YC_RegBus] ext_mem_rmw_wdata;
    reg [`YC_InstAddrBus] ext_mem_resume_pc;
    reg if_fire_active_next;
    reg [1:0] if_fire_state_next;
    reg [7:0] if_fire_byte_next;
    reg [4:0] if_fire_rd_next;
    reg [`YC_InstAddrBus] if_fire_resume_pc_next;
    reg rt_active_next;
    reg [3:0] rt_state_next;
    reg [4:0] rt_rd_next;
    reg [`YC_RegBus] rt_result_next;
    reg [`YC_InstAddrBus] rt_resume_pc_next;
    reg rt_i2c_seen_busy_next;
    reg ext_mem_active_next;
    reg ext_mem_is_load_next;
    reg ext_mem_rmw_next;
    reg ext_mem_write_phase_next;
    reg ext_mem_ack_seen_low_next;
    reg [2:0] ext_mem_funct3_next;
    reg [`YC_RegAddrBus] ext_mem_rd_next;
    reg [`YC_MemAddrBus] ext_mem_addr_next;
    reg [`YC_RegBus] ext_mem_wdata_next;
    reg [`YC_RegBus] ext_mem_rmw_wdata_next;
    reg [`YC_InstAddrBus] ext_mem_resume_pc_next;
    wire if_inst_hit;
    wire if_fire_inst_hit;
    wire rt_inst_hit;
    wire ext_mem_addr_hit;
    wire ext_load_inst_hit;
    wire ext_store_inst_hit;
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];
    assign funct7 = inst_i[31:25];
    assign rd = inst_i[11:7];
    assign uimm = inst_i[19:15];
    assign imm = {{20{inst_i[31]}}, inst_i[31:20]};

    assign sr_shift = reg1_rdata_i >> reg2_rdata_i[4:0];
    assign sri_shift = reg1_rdata_i >> inst_i[24:20];
    assign sr_shift_mask = 32'hffffffff >> reg2_rdata_i[4:0];
    assign sri_shift_mask = 32'hffffffff >> inst_i[24:20];

    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_add_simm_res = op1_i + imm;
    assign op1_jump_add_op2_jump_res = op1_jump_i + op2_jump_i;

    // Signed compare.
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    // Unsigned compare.
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);

    assign mem_raddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]}) & 2'b11;
    assign mem_waddr_index = (reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]}) & 2'b11;

    assign reg_wdata_o = reg_wdata;
    // Register writes come directly from the execute datapath.
    assign reg_we_o = reg_we;
    assign reg_waddr_o = reg_waddr;

    // Memory write control for stores and MMIO transactions.
    assign mem_we_o = mem_we;

    // Memory request control for loads, stores, and MMIO transactions.
    assign mem_req_o = mem_req;

    assign hold_flag_o = hold_flag;
    assign jump_flag_o = jump_flag;
    assign jump_addr_o = jump_addr;

    // Custom instruction decodes and external memory classification.
    assign if_inst_hit = (opcode == `YC_INST_TYPE_A) && (funct3 == `YC_INST_if);
    assign if_fire_inst_hit = if_inst_hit && (imm[11:0] == 12'h0) && op1_ge_op2_signed;
    assign rt_inst_hit = (opcode == `YC_INST_TYPE_A) && (funct3 == `YC_INST_rT);
    assign ext_mem_addr_hit = (op1_add_op2_res[31:28] == 4'h0) || (op1_add_op2_res[31:28] == 4'h1);
    assign ext_load_inst_hit = (opcode == `YC_INST_TYPE_L) && ext_mem_addr_hit;
    assign ext_store_inst_hit = (opcode == `YC_INST_TYPE_S) &&
                                ((funct3 == `YC_INST_SB) || (funct3 == `YC_INST_SH) || (funct3 == `YC_INST_SW)) &&
                                ext_mem_addr_hit;

    function [`YC_RegBus] load_ext_data;
        input [2:0] load_funct3;
        input [`YC_MemAddrBus] load_addr;
        input [`YC_RegBus] load_data;
        begin
            case (load_funct3)
                `YC_INST_LB: begin
                    case (load_addr[1:0])
                        2'b00: load_ext_data = {{24{load_data[7]}}, load_data[7:0]};
                        2'b01: load_ext_data = {{24{load_data[15]}}, load_data[15:8]};
                        2'b10: load_ext_data = {{24{load_data[23]}}, load_data[23:16]};
                        default: load_ext_data = {{24{load_data[31]}}, load_data[31:24]};
                    endcase
                end
                `YC_INST_LH: begin
                    if (load_addr[1:0] == 2'b00) begin
                        load_ext_data = {{16{load_data[15]}}, load_data[15:0]};
                    end else begin
                        load_ext_data = {{16{load_data[31]}}, load_data[31:16]};
                    end
                end
                `YC_INST_LBU: begin
                    case (load_addr[1:0])
                        2'b00: load_ext_data = {24'h0, load_data[7:0]};
                        2'b01: load_ext_data = {24'h0, load_data[15:8]};
                        2'b10: load_ext_data = {24'h0, load_data[23:16]};
                        default: load_ext_data = {24'h0, load_data[31:24]};
                    endcase
                end
                `YC_INST_LHU: begin
                    if (load_addr[1:0] == 2'b00) begin
                        load_ext_data = {16'h0, load_data[15:0]};
                    end else begin
                        load_ext_data = {16'h0, load_data[31:16]};
                    end
                end
                default: begin
                    load_ext_data = load_data;
                end
            endcase
        end
    endfunction

    function [`YC_RegBus] store_ext_data;
        input [2:0] store_funct3;
        input [`YC_MemAddrBus] store_addr;
        input [`YC_RegBus] old_data;
        input [`YC_RegBus] new_data;
        begin
            case (store_funct3)
                `YC_INST_SB: begin
                    case (store_addr[1:0])
                        2'b00: store_ext_data = {old_data[31:8], new_data[7:0]};
                        2'b01: store_ext_data = {old_data[31:16], new_data[7:0], old_data[7:0]};
                        2'b10: store_ext_data = {old_data[31:24], new_data[7:0], old_data[15:0]};
                        default: store_ext_data = {new_data[7:0], old_data[23:0]};
                    endcase
                end
                `YC_INST_SH: begin
                    if (store_addr[1:0] == 2'b00) begin
                        store_ext_data = {old_data[31:16], new_data[15:0]};
                    end else begin
                        store_ext_data = {new_data[15:0], old_data[15:0]};
                    end
                end
                default: begin
                    store_ext_data = new_data;
                end
            endcase
        end
    endfunction

    always @ (posedge clk) begin
        if (rst == `YC_RstEnable) begin
            if_fire_active <= 1'b0;
            if_fire_state <= IF_ST_IDLE;
            if_fire_byte <= 8'h0;
            if_fire_rd <= `YC_ZeroReg;
            if_fire_resume_pc <= `YC_ZeroWord;
            rt_active <= 1'b0;
            rt_state <= RT_ST_IDLE;
            rt_rd <= `YC_ZeroReg;
            rt_result <= `YC_ZeroWord;
            rt_resume_pc <= `YC_ZeroWord;
            rt_i2c_seen_busy <= 1'b0;
            ext_mem_active <= 1'b0;
            ext_mem_is_load <= 1'b0;
            ext_mem_rmw <= 1'b0;
            ext_mem_write_phase <= 1'b0;
            ext_mem_ack_seen_low <= 1'b0;
            ext_mem_funct3 <= 3'b000;
            ext_mem_rd <= `YC_ZeroReg;
            ext_mem_addr <= `YC_ZeroWord;
            ext_mem_wdata <= `YC_ZeroWord;
            ext_mem_rmw_wdata <= `YC_ZeroWord;
            ext_mem_resume_pc <= `YC_ZeroWord;
        end else begin
            if_fire_active <= if_fire_active_next;
            if_fire_state <= if_fire_state_next;
            if_fire_byte <= if_fire_byte_next;
            if_fire_rd <= if_fire_rd_next;
            if_fire_resume_pc <= if_fire_resume_pc_next;
            rt_active <= rt_active_next;
            rt_state <= rt_state_next;
            rt_rd <= rt_rd_next;
            rt_result <= rt_result_next;
            rt_resume_pc <= rt_resume_pc_next;
            rt_i2c_seen_busy <= rt_i2c_seen_busy_next;
            ext_mem_active <= ext_mem_active_next;
            ext_mem_is_load <= ext_mem_is_load_next;
            ext_mem_rmw <= ext_mem_rmw_next;
            ext_mem_write_phase <= ext_mem_write_phase_next;
            ext_mem_ack_seen_low <= ext_mem_ack_seen_low_next;
            ext_mem_funct3 <= ext_mem_funct3_next;
            ext_mem_rd <= ext_mem_rd_next;
            ext_mem_addr <= ext_mem_addr_next;
            ext_mem_wdata <= ext_mem_wdata_next;
            ext_mem_rmw_wdata <= ext_mem_rmw_wdata_next;
            ext_mem_resume_pc <= ext_mem_resume_pc_next;
        end
    end

    // Main execute combinational logic.
    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `YC_RIB_NREQ;
        if_fire_active_next = if_fire_active;
        if_fire_state_next = if_fire_state;
        if_fire_byte_next = if_fire_byte;
        if_fire_rd_next = if_fire_rd;
        if_fire_resume_pc_next = if_fire_resume_pc;
        rt_active_next = rt_active;
        rt_state_next = rt_state;
        rt_rd_next = rt_rd;
        rt_result_next = rt_result;
        rt_resume_pc_next = rt_resume_pc;
        rt_i2c_seen_busy_next = rt_i2c_seen_busy;
        ext_mem_active_next = ext_mem_active;
        ext_mem_is_load_next = ext_mem_is_load;
        ext_mem_rmw_next = ext_mem_rmw;
        ext_mem_write_phase_next = ext_mem_write_phase;
        ext_mem_ack_seen_low_next = ext_mem_ack_seen_low;
        ext_mem_funct3_next = ext_mem_funct3;
        ext_mem_rd_next = ext_mem_rd;
        ext_mem_addr_next = ext_mem_addr;
        ext_mem_wdata_next = ext_mem_wdata;
        ext_mem_rmw_wdata_next = ext_mem_rmw_wdata;
        ext_mem_resume_pc_next = ext_mem_resume_pc;

        if ((ext_mem_active == 1'b1) || (ext_load_inst_hit == 1'b1) || (ext_store_inst_hit == 1'b1)) begin
            jump_flag = `YC_JumpDisable;
            jump_addr = `YC_ZeroWord;
            mem_wdata_o = `YC_ZeroWord;
            mem_raddr_o = `YC_ZeroWord;
            mem_waddr_o = `YC_ZeroWord;
            mem_we = `YC_WriteDisable;
            reg_wdata = `YC_ZeroWord;
            hold_flag = `YC_HoldEnable;
            reg_we = `YC_WriteDisable;
            if (ext_mem_active == 1'b0) begin
                ext_mem_active_next = 1'b1;
                ext_mem_is_load_next = (opcode == `YC_INST_TYPE_L);
                ext_mem_rmw_next = (opcode == `YC_INST_TYPE_S) && (funct3 != `YC_INST_SW);
                ext_mem_write_phase_next = 1'b0;
                ext_mem_ack_seen_low_next = 1'b0;
                ext_mem_funct3_next = funct3;
                ext_mem_rd_next = reg_waddr_i;
                ext_mem_addr_next = op1_add_op2_res;
                ext_mem_wdata_next = reg2_rdata_i;
                ext_mem_rmw_wdata_next = `YC_ZeroWord;
                ext_mem_resume_pc_next = inst_addr_i + 32'h4;
            end else begin
                mem_req = `YC_RIB_REQ;
                mem_raddr_o = ext_mem_addr;
                mem_waddr_o = ext_mem_addr;
                if (mem_ack_i != `YC_RIB_ACK) begin
                    ext_mem_ack_seen_low_next = 1'b1;
                end
                if (ext_mem_is_load == 1'b1) begin
                    mem_we = `YC_WriteDisable;
                    mem_wdata_o = `YC_ZeroWord;
                    if ((ext_mem_ack_seen_low == 1'b1) && (mem_ack_i == `YC_RIB_ACK)) begin
                        jump_flag = `YC_JumpEnable;
                        jump_addr = ext_mem_resume_pc;
                        hold_flag = `YC_HoldDisable;
                        ext_mem_active_next = 1'b0;
                        ext_mem_ack_seen_low_next = 1'b0;
                        reg_we = `YC_WriteEnable;
                        reg_waddr = ext_mem_rd;
                        reg_wdata = load_ext_data(ext_mem_funct3, ext_mem_addr, mem_rdata_i);
                    end
                end else if ((ext_mem_rmw == 1'b1) && (ext_mem_write_phase == 1'b0)) begin
                    mem_we = `YC_WriteDisable;
                    mem_wdata_o = `YC_ZeroWord;
                    if ((ext_mem_ack_seen_low == 1'b1) && (mem_ack_i == `YC_RIB_ACK)) begin
                        ext_mem_write_phase_next = 1'b1;
                        ext_mem_ack_seen_low_next = 1'b0;
                        ext_mem_rmw_wdata_next = store_ext_data(ext_mem_funct3, ext_mem_addr, mem_rdata_i, ext_mem_wdata);
                    end
                end else begin
                    mem_we = `YC_WriteEnable;
                    mem_wdata_o = (ext_mem_rmw == 1'b1) ? ext_mem_rmw_wdata : ext_mem_wdata;
                    if ((ext_mem_ack_seen_low == 1'b1) && (mem_ack_i == `YC_RIB_ACK)) begin
                        jump_flag = `YC_JumpEnable;
                        jump_addr = ext_mem_resume_pc;
                        hold_flag = `YC_HoldDisable;
                        ext_mem_active_next = 1'b0;
                        ext_mem_write_phase_next = 1'b0;
                        ext_mem_ack_seen_low_next = 1'b0;
                    end
                end
            end
        end else if ((if_fire_active == 1'b1) || (if_fire_inst_hit == 1'b1)) begin
            jump_flag = `YC_JumpDisable;
            jump_addr = `YC_ZeroWord;
            mem_wdata_o = `YC_ZeroWord;
            mem_raddr_o = `YC_ZeroWord;
            mem_waddr_o = `YC_ZeroWord;
            mem_we = `YC_WriteDisable;
            reg_wdata = `YC_ZeroWord;
            hold_flag = `YC_HoldEnable;
            reg_we = `YC_WriteDisable;
            if (if_fire_active == 1'b0) begin
                if_fire_active_next = 1'b1;
                if_fire_state_next = IF_ST_WAIT_READY;
                if_fire_byte_next = op1_i[7:0];
                if_fire_rd_next = reg_waddr_i;
                if_fire_resume_pc_next = inst_addr_i + 32'h4;
            end else begin
                case (if_fire_state)
                    IF_ST_WAIT_READY: begin
                        mem_req = `YC_RIB_REQ;
                        mem_we = `YC_WriteDisable;
                        mem_raddr_o = `YC_UART_STATUS_ADDR;
                        if (mem_rdata_i[0] == 1'b0) begin
                            if_fire_state_next = IF_ST_SEND_CMD;
                        end
                    end
                    IF_ST_SEND_CMD: begin
                        mem_req = `YC_RIB_REQ;
                        mem_we = `YC_WriteEnable;
                        mem_waddr_o = `YC_UART_CMD_ADDR;
                        mem_raddr_o = `YC_UART_CMD_ADDR;
                        mem_wdata_o = {16'h0, `YC_UART_CMD_SEND_BYTE, if_fire_byte};
                        if_fire_state_next = IF_ST_WB;
                    end
                    IF_ST_WB: begin
                        jump_flag = `YC_JumpEnable;
                        jump_addr = if_fire_resume_pc;
                        hold_flag = `YC_HoldDisable;
                        reg_we = `YC_WriteEnable;
                        reg_waddr = if_fire_rd;
                        reg_wdata = `YC_ZeroWord;
                        if_fire_active_next = 1'b0;
                        if_fire_state_next = IF_ST_IDLE;
                        if_fire_byte_next = 8'h0;
                        if_fire_rd_next = `YC_ZeroReg;
                        if_fire_resume_pc_next = `YC_ZeroWord;
                    end
                    default: begin
                        if_fire_active_next = 1'b0;
                        if_fire_state_next = IF_ST_IDLE;
                        if_fire_byte_next = 8'h0;
                        if_fire_rd_next = `YC_ZeroReg;
                        if_fire_resume_pc_next = `YC_ZeroWord;
                    end
                endcase
            end
        end else if ((rt_active == 1'b1) || (rt_inst_hit == 1'b1)) begin
            jump_flag = `YC_JumpDisable;
            jump_addr = `YC_ZeroWord;
            mem_wdata_o = `YC_ZeroWord;
            mem_raddr_o = `YC_ZeroWord;
            mem_waddr_o = `YC_ZeroWord;
            mem_we = `YC_WriteDisable;
            reg_wdata = `YC_ZeroWord;
            hold_flag = `YC_HoldEnable;
            reg_we = `YC_WriteDisable;
            if (rt_active == 1'b0) begin
                rt_active_next = 1'b1;
                rt_state_next = RT_ST_START;
                rt_rd_next = reg_waddr_i;
                rt_resume_pc_next = op1_jump_add_op2_jump_res;
                rt_i2c_seen_busy_next = 1'b0;
            end else begin
                case (rt_state)
                    RT_ST_START: begin
                        mem_req = `YC_RIB_REQ;
                        mem_we = `YC_WriteEnable;
                        mem_waddr_o = I2C_CTRL_ADDR;
                        mem_raddr_o = I2C_CTRL_ADDR;
                        mem_wdata_o = I2C_CTRL_START_TEMP_READ;
                        rt_state_next = RT_ST_WAIT;
                        rt_i2c_seen_busy_next = 1'b0;
                    end
                    RT_ST_WAIT: begin
                        mem_req = `YC_RIB_REQ;
                        mem_we = `YC_WriteDisable;
                        mem_raddr_o = I2C_CTRL_ADDR;
                        if (mem_rdata_i[9] == 1'b1) begin
                            rt_i2c_seen_busy_next = 1'b1;
                        end else if ((rt_i2c_seen_busy == 1'b1) && (mem_rdata_i[10] == 1'b1)) begin
                            if (mem_rdata_i[11] == 1'b1) begin
                                rt_result_next = `YC_ZeroWord;
                                rt_state_next = RT_ST_WB;
                            end else begin
                                rt_state_next = RT_ST_READ_RX;
                            end
                        end
                    end
                    RT_ST_READ_RX: begin
                        mem_req = `YC_RIB_REQ;
                        mem_we = `YC_WriteDisable;
                        mem_raddr_o = I2C_RXDATA_ADDR;
                        // The assignment only requires Temp[14:7].
                        rt_result_next = {24'h0, mem_rdata_i[14:7]};
                        rt_state_next = RT_ST_WB;
                        rt_i2c_seen_busy_next = 1'b0;
                    end
                    RT_ST_WB: begin
                        jump_flag = `YC_JumpEnable;
                        jump_addr = rt_resume_pc;
                        hold_flag = `YC_HoldDisable;
                        reg_we = `YC_WriteEnable;
                        reg_waddr = rt_rd;
                        reg_wdata = rt_result;
                        rt_active_next = 1'b0;
                        rt_state_next = RT_ST_IDLE;
                        rt_rd_next = `YC_ZeroReg;
                        rt_resume_pc_next = `YC_ZeroWord;
                        rt_i2c_seen_busy_next = 1'b0;
                    end
                    default: begin
                        rt_active_next = 1'b0;
                        rt_state_next = RT_ST_IDLE;
                        rt_rd_next = `YC_ZeroReg;
                        rt_result_next = `YC_ZeroWord;
                        rt_resume_pc_next = `YC_ZeroWord;
                        rt_i2c_seen_busy_next = 1'b0;
                    end
                endcase
            end
        end else begin
            case (opcode)
            `YC_INST_TYPE_I: begin
                case (funct3)
                    `YC_INST_ADDI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = op1_add_op2_res;
                    end
                    `YC_INST_SLTI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                    end
                    `YC_INST_SLTIU: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                    end
                    `YC_INST_XORI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = op1_i ^ op2_i;
                    end
                    `YC_INST_ORI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = op1_i | op2_i;
                    end
                    `YC_INST_ANDI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = op1_i & op2_i;
                    end
                    `YC_INST_SLLI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = reg1_rdata_i << inst_i[24:20];
                    end
                    `YC_INST_SRI: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        if (inst_i[30] == 1'b1) begin
                            reg_wdata = (sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask));
                        end else begin
                            reg_wdata = reg1_rdata_i >> inst_i[24:20];
                        end
                    end
                    default: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                    end
                endcase
            end
            `YC_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `YC_INST_ADD_SUB: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            if (inst_i[30] == 1'b0) begin
                                reg_wdata = op1_add_op2_res;
                            end else begin
                                reg_wdata = op1_i - op2_i;
                            end
                        end
                        `YC_INST_SLL: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = op1_i << op2_i[4:0];
                        end
                        `YC_INST_SLT: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
                        end
                        `YC_INST_SLTU: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
                        end
                        `YC_INST_XOR: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = op1_i ^ op2_i;
                        end
                        `YC_INST_SR: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            if (inst_i[30] == 1'b1) begin
                                reg_wdata = (sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask));
                            end else begin
                                reg_wdata = reg1_rdata_i >> reg2_rdata_i[4:0];
                            end
                        end
                        `YC_INST_OR: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = op1_i | op2_i;
                        end
                        `YC_INST_AND: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = op1_i & op2_i;
                        end
                        default: begin
                            jump_flag = `YC_JumpDisable;
                            hold_flag = `YC_HoldDisable;
                            jump_addr = `YC_ZeroWord;
                            mem_wdata_o = `YC_ZeroWord;
                            mem_raddr_o = `YC_ZeroWord;
                            mem_waddr_o = `YC_ZeroWord;
                            mem_we = `YC_WriteDisable;
                            reg_wdata = `YC_ZeroWord;
                        end
                    endcase
                end else begin
                    jump_flag = `YC_JumpDisable;
                    hold_flag = `YC_HoldDisable;
                    jump_addr = `YC_ZeroWord;
                    mem_wdata_o = `YC_ZeroWord;
                    mem_raddr_o = `YC_ZeroWord;
                    mem_waddr_o = `YC_ZeroWord;
                    mem_we = `YC_WriteDisable;
                    reg_wdata = `YC_ZeroWord;
                end
            end
            `YC_INST_TYPE_L: begin
                case (funct3)
                    `YC_INST_LB: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
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
                    `YC_INST_LH: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                        end
                    end
                    `YC_INST_LW: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
                        reg_wdata = mem_rdata_i;
                    end
                    `YC_INST_LBU: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
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
                    `YC_INST_LHU: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_REQ;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
                        if (mem_raddr_index == 2'b0) begin
                            reg_wdata = {16'h0, mem_rdata_i[15:0]};
                        end else begin
                            reg_wdata = {16'h0, mem_rdata_i[31:16]};
                        end
                    end
                    default: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                    end
                endcase
            end
            `YC_INST_TYPE_S: begin
                case (funct3)
                    `YC_INST_SB: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        reg_wdata = `YC_ZeroWord;
                        mem_we = `YC_WriteEnable;
                        mem_req = `YC_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
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
                    `YC_INST_SH: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        reg_wdata = `YC_ZeroWord;
                        mem_we = `YC_WriteEnable;
                        mem_req = `YC_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        hold_flag = `YC_HoldDisable;
                        if (mem_waddr_index == 2'b00) begin
                            mem_wdata_o = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                        end else begin
                            mem_wdata_o = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                        end
                    end
                    `YC_INST_SW: begin
                        jump_flag = `YC_JumpDisable;
                        jump_addr = `YC_ZeroWord;
                        reg_wdata = `YC_ZeroWord;
                        mem_we = `YC_WriteEnable;
                        mem_req = `YC_RIB_REQ;
                        mem_waddr_o = op1_add_op2_res;
                        mem_raddr_o = op1_add_op2_res;
                        mem_wdata_o = reg2_rdata_i;
                        hold_flag = `YC_HoldDisable;
                    end
                    default: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                    end
                endcase
            end
            `YC_INST_TYPE_B: begin
                case (funct3)
                    `YC_INST_BEQ: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = op1_eq_op2 & `YC_JumpEnable;
                        jump_addr = {32{op1_eq_op2}} & op1_jump_add_op2_jump_res;
                    end
                    `YC_INST_BNE: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = (~op1_eq_op2) & `YC_JumpEnable;
                        jump_addr = {32{(~op1_eq_op2)}} & op1_jump_add_op2_jump_res;
                    end
                    `YC_INST_BLT: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = (~op1_ge_op2_signed) & `YC_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `YC_INST_BGE: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = (op1_ge_op2_signed) & `YC_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_signed)}} & op1_jump_add_op2_jump_res;
                    end
                    `YC_INST_BLTU: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = (~op1_ge_op2_unsigned) & `YC_JumpEnable;
                        jump_addr = {32{(~op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    `YC_INST_BGEU: begin
                        hold_flag = `YC_HoldDisable;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                        jump_flag = (op1_ge_op2_unsigned) & `YC_JumpEnable;
                        jump_addr = {32{(op1_ge_op2_unsigned)}} & op1_jump_add_op2_jump_res;
                    end
                    default: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                    end
                endcase
            end
            `YC_INST_TYPE_A: begin
                case (funct3)
                    `YC_INST_sID: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        reg_wdata = `YC_ZeroWord;
                        mem_we = `YC_WriteEnable;
                        mem_req = `YC_RIB_REQ;
                        mem_waddr_o = `YC_UART_CMD_ADDR;
                        mem_raddr_o = `YC_UART_CMD_ADDR;
                        mem_wdata_o = {16'h0, `YC_UART_CMD_SEND_ID, 8'h00};
                    end
                    `YC_INST_if: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        mem_req = `YC_RIB_NREQ;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        if (imm[11:0] != 12'h0) begin
                            reg_wdata = op1_add_simm_res;
                        end else begin
                            reg_wdata = op1_i;
                        end
                    end
                    default: begin
                        jump_flag = `YC_JumpDisable;
                        hold_flag = `YC_HoldDisable;
                        jump_addr = `YC_ZeroWord;
                        mem_wdata_o = `YC_ZeroWord;
                        mem_raddr_o = `YC_ZeroWord;
                        mem_waddr_o = `YC_ZeroWord;
                        mem_we = `YC_WriteDisable;
                        reg_wdata = `YC_ZeroWord;
                    end
                endcase
            end
            `YC_INST_JAL, `YC_INST_JALR: begin
                hold_flag = `YC_HoldDisable;
                mem_wdata_o = `YC_ZeroWord;
                mem_raddr_o = `YC_ZeroWord;
                mem_waddr_o = `YC_ZeroWord;
                mem_we = `YC_WriteDisable;
                jump_flag = `YC_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
                reg_wdata = op1_add_op2_res;
            end
            `YC_INST_LUI, `YC_INST_AUIPC: begin
                hold_flag = `YC_HoldDisable;
                mem_wdata_o = `YC_ZeroWord;
                mem_raddr_o = `YC_ZeroWord;
                mem_waddr_o = `YC_ZeroWord;
                mem_we = `YC_WriteDisable;
                jump_addr = `YC_ZeroWord;
                jump_flag = `YC_JumpDisable;
                reg_wdata = op1_add_op2_res;
            end
            `YC_INST_NOP_OP: begin
                jump_flag = `YC_JumpDisable;
                hold_flag = `YC_HoldDisable;
                jump_addr = `YC_ZeroWord;
                mem_wdata_o = `YC_ZeroWord;
                mem_raddr_o = `YC_ZeroWord;
                mem_waddr_o = `YC_ZeroWord;
                mem_we = `YC_WriteDisable;
                reg_wdata = `YC_ZeroWord;
            end
            `YC_INST_FENCE: begin
                hold_flag = `YC_HoldDisable;
                mem_wdata_o = `YC_ZeroWord;
                mem_raddr_o = `YC_ZeroWord;
                mem_waddr_o = `YC_ZeroWord;
                mem_we = `YC_WriteDisable;
                reg_wdata = `YC_ZeroWord;
                jump_flag = `YC_JumpEnable;
                jump_addr = op1_jump_add_op2_jump_res;
            end
            default: begin
                jump_flag = `YC_JumpDisable;
                hold_flag = `YC_HoldDisable;
                jump_addr = `YC_ZeroWord;
                mem_wdata_o = `YC_ZeroWord;
                mem_raddr_o = `YC_ZeroWord;
                mem_waddr_o = `YC_ZeroWord;
                mem_we = `YC_WriteDisable;
                reg_wdata = `YC_ZeroWord;
            end
        endcase
    end
end

endmodule
