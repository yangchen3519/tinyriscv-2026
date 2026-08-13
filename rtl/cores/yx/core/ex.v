`include "yx_defines.vh"

module yx_ex(
    input wire clk,
    input wire rst,
    input wire[`YX_InstBus] inst_i,
    input wire[`YX_InstAddrBus] inst_addr_i,
    input wire reg_we_i,
    input wire[`YX_RegAddrBus] reg_waddr_i,
    input wire[`YX_RegBus] reg1_rdata_i,
    input wire[`YX_RegBus] reg2_rdata_i,
    input wire[`YX_MemAddrBus] op1_i,
    input wire[`YX_MemAddrBus] op2_i,
    input wire[`YX_MemAddrBus] op1_jump_i,
    input wire[`YX_MemAddrBus] op2_jump_i,
    input wire[`YX_MemBus] mem_rdata_i,
    output reg[`YX_MemBus] mem_wdata_o,
    output reg[`YX_MemAddrBus] mem_raddr_o,
    output reg[`YX_MemAddrBus] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,
    output wire[`YX_RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`YX_RegAddrBus] reg_waddr_o,
    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`YX_InstAddrBus] jump_addr_o
    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] shamt_i = inst_i[24:20];
    wire[4:0] shamt_r = reg2_rdata_i[4:0];

    wire[`YX_RegBus] add_res = op1_i + op2_i;
    wire[`YX_RegBus] sub_res = op1_i - op2_i;
    wire[`YX_RegBus] jump_add_res = op1_jump_i + op2_jump_i;
    wire[`YX_RegBus] sri_shift = reg1_rdata_i >> shamt_i;
    wire[`YX_RegBus] sr_shift = reg1_rdata_i >> shamt_r;
    wire[`YX_RegBus] sri_shift_mask = 32'hffffffff >> shamt_i;
    wire[`YX_RegBus] sr_shift_mask = 32'hffffffff >> shamt_r;
    wire op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    wire op1_ge_op2_unsigned = op1_i >= op2_i;
    wire op1_eq_op2 = (op1_i == op2_i);
    wire[1:0] mem_raddr_index = add_res[1:0];
    wire[1:0] mem_waddr_index = add_res[1:0];

    wire sid_req = (opcode == `YX_INST_SID) && (funct3 == `YX_INST_SID_F3);
    wire rt_req = (opcode == `YX_INST_SID) && (funct3 == `YX_INST_RT_F3);
    wire if_req = (opcode == `YX_INST_SID) && (funct3 == `YX_INST_IF_F3);
    wire if_send_req = if_req && (inst_i[31:20] == 12'h0) && (reg1_rdata_i >= reg2_rdata_i);

    wire sid_hold_flag;
    wire sid_mem_we;
    wire sid_mem_req;
    wire[`YX_MemBus] sid_mem_wdata;
    wire[`YX_MemAddrBus] sid_mem_raddr;
    wire[`YX_MemAddrBus] sid_mem_waddr;
    wire rt_hold_flag;
    wire rt_mem_we;
    wire rt_mem_req;
    wire rt_reg_we;
    wire[`YX_RegBus] rt_reg_wdata;
    wire[`YX_RegAddrBus] rt_reg_waddr;
    wire[`YX_MemBus] rt_mem_wdata;
    wire[`YX_MemAddrBus] rt_mem_raddr;
    wire[`YX_MemAddrBus] rt_mem_waddr;
    wire if_hold_flag;
    wire if_mem_we;
    wire if_mem_req;
    wire if_reg_we;
    wire[`YX_RegBus] if_reg_wdata;
    wire[`YX_RegAddrBus] if_reg_waddr;
    wire[`YX_MemBus] if_mem_wdata;
    wire[`YX_MemAddrBus] if_mem_raddr;
    wire[`YX_MemAddrBus] if_mem_waddr;

    reg[`YX_RegBus] rv_reg_wdata;
    reg rv_reg_we;
    reg[`YX_RegAddrBus] rv_reg_waddr;
    reg[`YX_MemBus] rv_mem_wdata;
    reg[`YX_MemAddrBus] rv_mem_raddr;
    reg[`YX_MemAddrBus] rv_mem_waddr;
    reg rv_mem_we;
    reg rv_mem_req;
    reg rv_hold_flag;
    reg rv_jump_flag;
    reg[`YX_InstAddrBus] rv_jump_addr;

    wire ext_active = (sid_hold_flag == `YX_HoldEnable) ||
                      (rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable) ||
                      (if_hold_flag == `YX_HoldEnable) || (if_reg_we == `YX_WriteEnable);
    wire mem_we_o_ext = (sid_hold_flag == `YX_HoldEnable) ? sid_mem_we :
                        ((rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable)) ? rt_mem_we :
                        ((if_hold_flag == `YX_HoldEnable) || (if_reg_we == `YX_WriteEnable)) ? if_mem_we :
                        `YX_WriteDisable;
    wire mem_req_o_ext = (sid_hold_flag == `YX_HoldEnable) ? sid_mem_req :
                         ((rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable)) ? rt_mem_req :
                         ((if_hold_flag == `YX_HoldEnable) || (if_reg_we == `YX_WriteEnable)) ? if_mem_req :
                         `YX_RIB_NREQ;

    assign reg_wdata_o = rv_reg_wdata | rt_reg_wdata | if_reg_wdata;
    assign reg_we_o = rv_reg_we | rt_reg_we | if_reg_we;
    assign reg_waddr_o = rv_reg_waddr | rt_reg_waddr | if_reg_waddr;
    assign mem_we_o = ext_active ? mem_we_o_ext : rv_mem_we;
    assign mem_req_o = ext_active ? mem_req_o_ext : rv_mem_req;
    assign hold_flag_o = rv_hold_flag | sid_hold_flag | rt_hold_flag | if_hold_flag;
    assign jump_flag_o = ext_active ? `YX_JumpDisable : rv_jump_flag;
    assign jump_addr_o = ext_active ? `YX_ZeroWord : rv_jump_addr;

    yx_sid u_sid(
        .clk(clk),
        .rst(rst),
        .sid_req_i(sid_req),
        .inst_addr_i(inst_addr_i),
        .mem_rdata_i(mem_rdata_i),
        .mem_wdata_o(sid_mem_wdata),
        .mem_raddr_o(sid_mem_raddr),
        .mem_waddr_o(sid_mem_waddr),
        .mem_we_o(sid_mem_we),
        .mem_req_o(sid_mem_req),
        .hold_flag_o(sid_hold_flag)
    );

    yx_rt u_rt(
        .clk(clk),
        .rst(rst),
        .rt_req_i(rt_req),
        .inst_addr_i(inst_addr_i),
        .reg_waddr_i(reg_waddr_i),
        .mem_rdata_i(mem_rdata_i),
        .reg_wdata_o(rt_reg_wdata),
        .reg_we_o(rt_reg_we),
        .reg_waddr_o(rt_reg_waddr),
        .mem_wdata_o(rt_mem_wdata),
        .mem_raddr_o(rt_mem_raddr),
        .mem_waddr_o(rt_mem_waddr),
        .mem_we_o(rt_mem_we),
        .mem_req_o(rt_mem_req),
        .hold_flag_o(rt_hold_flag)
    );

    yx_if_ext u_if_ext(
        .clk(clk),
        .rst(rst),
        .if_req_i(if_send_req),
        .inst_addr_i(inst_addr_i),
        .reg_waddr_i(reg_waddr_i),
        .reg1_rdata_i(reg1_rdata_i),
        .mem_rdata_i(mem_rdata_i),
        .reg_wdata_o(if_reg_wdata),
        .reg_we_o(if_reg_we),
        .reg_waddr_o(if_reg_waddr),
        .mem_wdata_o(if_mem_wdata),
        .mem_raddr_o(if_mem_raddr),
        .mem_waddr_o(if_mem_waddr),
        .mem_we_o(if_mem_we),
        .mem_req_o(if_mem_req),
        .hold_flag_o(if_hold_flag)
    );

    always @ (*) begin
        mem_wdata_o = ext_active ? ((sid_hold_flag == `YX_HoldEnable) ? sid_mem_wdata :
                                    ((rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable)) ? rt_mem_wdata :
                                    if_mem_wdata) : rv_mem_wdata;
        mem_raddr_o = ext_active ? ((sid_hold_flag == `YX_HoldEnable) ? sid_mem_raddr :
                                    ((rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable)) ? rt_mem_raddr :
                                    if_mem_raddr) : rv_mem_raddr;
        mem_waddr_o = ext_active ? ((sid_hold_flag == `YX_HoldEnable) ? sid_mem_waddr :
                                    ((rt_hold_flag == `YX_HoldEnable) || (rt_reg_we == `YX_WriteEnable)) ? rt_mem_waddr :
                                    if_mem_waddr) : rv_mem_waddr;
    end

    always @ (*) begin
        rv_reg_we = reg_we_i;
        rv_reg_waddr = reg_waddr_i;
        rv_reg_wdata = `YX_ZeroWord;
        rv_mem_wdata = `YX_ZeroWord;
        rv_mem_raddr = `YX_ZeroWord;
        rv_mem_waddr = `YX_ZeroWord;
        rv_mem_we = `YX_WriteDisable;
        rv_mem_req = `YX_RIB_NREQ;
        rv_hold_flag = `YX_HoldDisable;
        rv_jump_flag = `YX_JumpDisable;
        rv_jump_addr = `YX_ZeroWord;

        if (ext_active) begin
            rv_reg_we = `YX_WriteDisable;
            rv_reg_waddr = `YX_ZeroReg;
        end else begin
        case (opcode)
            `YX_INST_TYPE_I: begin
                case (funct3)
                    `YX_INST_ADDI: rv_reg_wdata = add_res;
                    `YX_INST_SLTI: rv_reg_wdata = {31'h0, ~op1_ge_op2_signed};
                    `YX_INST_SLTIU: rv_reg_wdata = {31'h0, ~op1_ge_op2_unsigned};
                    `YX_INST_XORI: rv_reg_wdata = op1_i ^ op2_i;
                    `YX_INST_ORI: rv_reg_wdata = op1_i | op2_i;
                    `YX_INST_ANDI: rv_reg_wdata = op1_i & op2_i;
                    `YX_INST_SLLI: rv_reg_wdata = reg1_rdata_i << shamt_i;
                    `YX_INST_SRI: rv_reg_wdata = inst_i[30] ? ((sri_shift & sri_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sri_shift_mask))) : sri_shift;
                    default: begin
                        rv_reg_we = `YX_WriteDisable;
                        rv_reg_waddr = `YX_ZeroReg;
                    end
                endcase
            end
            `YX_INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `YX_INST_ADD_SUB: rv_reg_wdata = inst_i[30] ? sub_res : add_res;
                        `YX_INST_SLL: rv_reg_wdata = reg1_rdata_i << shamt_r;
                        `YX_INST_SLT: rv_reg_wdata = {31'h0, ~op1_ge_op2_signed};
                        `YX_INST_SLTU: rv_reg_wdata = {31'h0, ~op1_ge_op2_unsigned};
                        `YX_INST_XOR: rv_reg_wdata = op1_i ^ op2_i;
                        `YX_INST_SR: rv_reg_wdata = inst_i[30] ? ((sr_shift & sr_shift_mask) | ({32{reg1_rdata_i[31]}} & (~sr_shift_mask))) : sr_shift;
                        `YX_INST_OR: rv_reg_wdata = op1_i | op2_i;
                        `YX_INST_AND: rv_reg_wdata = op1_i & op2_i;
                        default: begin
                            rv_reg_we = `YX_WriteDisable;
                            rv_reg_waddr = `YX_ZeroReg;
                        end
                    endcase
                end else begin
                    rv_reg_we = `YX_WriteDisable;
                    rv_reg_waddr = `YX_ZeroReg;
                end
            end
            `YX_INST_TYPE_L: begin
                rv_mem_req = `YX_RIB_REQ;
                rv_mem_raddr = add_res;
                case (funct3)
                    `YX_INST_LB: begin
                        case (mem_raddr_index)
                            2'b00: rv_reg_wdata = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                            2'b01: rv_reg_wdata = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                            2'b10: rv_reg_wdata = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                            default: rv_reg_wdata = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                        endcase
                    end
                    `YX_INST_LH: rv_reg_wdata = (mem_raddr_index == 2'b00) ? {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]} : {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
                    `YX_INST_LW: rv_reg_wdata = mem_rdata_i;
                    `YX_INST_LBU: begin
                        case (mem_raddr_index)
                            2'b00: rv_reg_wdata = {24'h0, mem_rdata_i[7:0]};
                            2'b01: rv_reg_wdata = {24'h0, mem_rdata_i[15:8]};
                            2'b10: rv_reg_wdata = {24'h0, mem_rdata_i[23:16]};
                            default: rv_reg_wdata = {24'h0, mem_rdata_i[31:24]};
                        endcase
                    end
                    `YX_INST_LHU: rv_reg_wdata = (mem_raddr_index == 2'b00) ? {16'h0, mem_rdata_i[15:0]} : {16'h0, mem_rdata_i[31:16]};
                    default: begin
                        rv_mem_req = `YX_RIB_NREQ;
                        rv_reg_we = `YX_WriteDisable;
                        rv_reg_waddr = `YX_ZeroReg;
                    end
                endcase
            end
            `YX_INST_TYPE_S: begin
                rv_mem_we = `YX_WriteEnable;
                rv_mem_req = `YX_RIB_REQ;
                rv_mem_waddr = add_res;
                rv_mem_raddr = add_res;
                rv_reg_we = `YX_WriteDisable;
                rv_reg_waddr = `YX_ZeroReg;
                case (funct3)
                    `YX_INST_SB: begin
                        case (mem_waddr_index)
                            2'b00: rv_mem_wdata = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                            2'b01: rv_mem_wdata = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                            2'b10: rv_mem_wdata = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                            default: rv_mem_wdata = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                        endcase
                    end
                    `YX_INST_SH: rv_mem_wdata = (mem_waddr_index == 2'b00) ? {mem_rdata_i[31:16], reg2_rdata_i[15:0]} : {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
                    `YX_INST_SW: rv_mem_wdata = reg2_rdata_i;
                    default: begin
                        rv_mem_we = `YX_WriteDisable;
                        rv_mem_req = `YX_RIB_NREQ;
                    end
                endcase
            end
            `YX_INST_TYPE_B: begin
                rv_reg_we = `YX_WriteDisable;
                rv_reg_waddr = `YX_ZeroReg;
                case (funct3)
                    `YX_INST_BEQ: begin rv_jump_flag = op1_eq_op2; rv_jump_addr = op1_eq_op2 ? jump_add_res : `YX_ZeroWord; end
                    `YX_INST_BNE: begin rv_jump_flag = ~op1_eq_op2; rv_jump_addr = (~op1_eq_op2) ? jump_add_res : `YX_ZeroWord; end
                    `YX_INST_BLT: begin rv_jump_flag = ~op1_ge_op2_signed; rv_jump_addr = (~op1_ge_op2_signed) ? jump_add_res : `YX_ZeroWord; end
                    `YX_INST_BGE: begin rv_jump_flag = op1_ge_op2_signed; rv_jump_addr = op1_ge_op2_signed ? jump_add_res : `YX_ZeroWord; end
                    `YX_INST_BLTU: begin rv_jump_flag = ~op1_ge_op2_unsigned; rv_jump_addr = (~op1_ge_op2_unsigned) ? jump_add_res : `YX_ZeroWord; end
                    `YX_INST_BGEU: begin rv_jump_flag = op1_ge_op2_unsigned; rv_jump_addr = op1_ge_op2_unsigned ? jump_add_res : `YX_ZeroWord; end
                    default: begin end
                endcase
            end
            `YX_INST_JAL, `YX_INST_JALR: begin
                rv_jump_flag = `YX_JumpEnable;
                rv_jump_addr = jump_add_res;
                rv_reg_wdata = add_res;
            end
            `YX_INST_LUI: begin
                rv_reg_wdata = op1_i;
            end
            `YX_INST_AUIPC: begin
                rv_reg_wdata = add_res;
            end
            `YX_INST_FENCE: begin
                rv_reg_we = `YX_WriteDisable;
                rv_reg_waddr = `YX_ZeroReg;
                rv_jump_flag = `YX_JumpEnable;
                rv_jump_addr = jump_add_res;
            end
            `YX_INST_SID: begin
                if (funct3 == `YX_INST_IF_F3) begin
                    if (inst_i[31:20] != 12'h0) begin
                        rv_reg_wdata = add_res;
                    end else if (reg1_rdata_i < reg2_rdata_i) begin
                        rv_reg_wdata = reg1_rdata_i;
                    end else begin
                        rv_reg_we = `YX_WriteDisable;
                        rv_reg_waddr = `YX_ZeroReg;
                    end
                end else begin
                    rv_reg_we = `YX_WriteDisable;
                    rv_reg_waddr = `YX_ZeroReg;
                end
            end
            default: begin
                rv_reg_we = `YX_WriteDisable;
                rv_reg_waddr = `YX_ZeroReg;
            end
        endcase
        end
    end

endmodule

module yx_if_ext(
    input wire clk,
    input wire rst,
    input wire if_req_i,
    input wire[`YX_InstAddrBus] inst_addr_i,
    input wire[`YX_RegAddrBus] reg_waddr_i,
    input wire[`YX_RegBus] reg1_rdata_i,
    input wire[`YX_MemBus] mem_rdata_i,
    output reg[`YX_RegBus] reg_wdata_o,
    output reg reg_we_o,
    output reg[`YX_RegAddrBus] reg_waddr_o,
    output reg[`YX_MemBus] mem_wdata_o,
    output reg[`YX_MemAddrBus] mem_raddr_o,
    output reg[`YX_MemAddrBus] mem_waddr_o,
    output reg mem_we_o,
    output reg mem_req_o,
    output wire hold_flag_o
    );

    localparam UART_STATUS = 32'h30000004;
    localparam UART_TXDATA = 32'h3000000c;
    localparam S_IDLE = 2'b00;
    localparam S_READ_STATUS = 2'b01;
    localparam S_WRITE_DATA = 2'b10;
    localparam S_DONE = 2'b11;

    reg[1:0] state;
    reg if_sent;
    reg[`YX_RegAddrBus] saved_reg_waddr;
    reg[7:0] saved_tx_data;

    wire tx_idle = (mem_rdata_i[0] == 1'b0);
    wire start_req = if_req_i & ~if_sent;
    assign hold_flag_o = (state != S_IDLE) | start_req;

    always @ (*) begin
        mem_wdata_o = {24'h0, saved_tx_data};
        mem_raddr_o = UART_STATUS;
        mem_waddr_o = UART_TXDATA;
        mem_we_o = `YX_WriteDisable;
        mem_req_o = `YX_RIB_NREQ;
        reg_wdata_o = `YX_ZeroWord;
        reg_we_o = `YX_WriteDisable;
        reg_waddr_o = `YX_ZeroReg;
        case (state)
            S_IDLE: if (start_req) mem_req_o = `YX_RIB_REQ;
            S_READ_STATUS: mem_req_o = `YX_RIB_REQ;
            S_WRITE_DATA: begin
                mem_req_o = `YX_RIB_REQ;
                mem_we_o = `YX_WriteEnable;
            end
            S_DONE: begin
                reg_we_o = `YX_WriteEnable;
                reg_waddr_o = saved_reg_waddr;
            end
            default: begin
            end
        endcase
    end

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            state <= S_IDLE;
            if_sent <= 1'b0;
            saved_reg_waddr <= `YX_ZeroReg;
            saved_tx_data <= 8'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start_req) begin
                        saved_reg_waddr <= reg_waddr_i;
                        saved_tx_data <= reg1_rdata_i[7:0];
                        state <= S_READ_STATUS;
                    end
                end
                S_READ_STATUS: if (tx_idle) state <= S_WRITE_DATA;
                S_WRITE_DATA: state <= S_DONE;
                S_DONE: begin
                    if_sent <= 1'b1;
                    state <= S_IDLE;
                end
                default: state <= S_IDLE;
            endcase
        end
    end

endmodule


