`include "yx_defines.vh"

module yx_tinyriscv_core(
    input wire clk,
    input wire rst,
    output wire[`YX_MemAddrBus] rib_ex_addr_o,
    input wire[`YX_MemBus] rib_ex_data_i,
    output wire[`YX_MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,
    output wire[`YX_MemAddrBus] rib_pc_addr_o,
    output wire rib_pc_req_o,
    input wire[`YX_MemBus] rib_pc_data_i,
    input wire rib_hold_flag_i,
    input wire bridge_hold_flag_i,
    input wire uart_debug_i,
    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i
    );

    wire[`YX_InstAddrBus] pc_pc_o;
    wire pc_update_en;
    wire pc_req;
    wire fsm_hold_flag_o;

    wire[`YX_InstBus] if_inst_o;
    wire[`YX_InstAddrBus] if_inst_addr_o;

    wire[`YX_RegAddrBus] id_reg1_raddr_o;
    wire[`YX_RegAddrBus] id_reg2_raddr_o;
    wire[`YX_InstBus] id_inst_o;
    wire[`YX_InstAddrBus] id_inst_addr_o;
    wire[`YX_RegBus] id_reg1_rdata_o;
    wire[`YX_RegBus] id_reg2_rdata_o;
    wire id_reg_we_o;
    wire[`YX_RegAddrBus] id_reg_waddr_o;
    wire[`YX_MemAddrBus] id_op1_o;
    wire[`YX_MemAddrBus] id_op2_o;
    wire[`YX_MemAddrBus] id_op1_jump_o;
    wire[`YX_MemAddrBus] id_op2_jump_o;

    wire[`YX_InstBus] ie_inst_o;
    wire[`YX_InstAddrBus] ie_inst_addr_o;
    wire ie_reg_we_o;
    wire[`YX_RegAddrBus] ie_reg_waddr_o;
    wire[`YX_RegBus] ie_reg1_rdata_o;
    wire[`YX_RegBus] ie_reg2_rdata_o;
    wire[`YX_MemAddrBus] ie_op1_o;
    wire[`YX_MemAddrBus] ie_op2_o;
    wire[`YX_MemAddrBus] ie_op1_jump_o;
    wire[`YX_MemAddrBus] ie_op2_jump_o;

    wire[`YX_MemBus] ex_mem_wdata_o;
    wire[`YX_MemAddrBus] ex_mem_raddr_o;
    wire[`YX_MemAddrBus] ex_mem_waddr_o;
    wire ex_mem_we_o;
    wire ex_mem_req_o;
    wire[`YX_RegBus] ex_reg_wdata_o;
    wire ex_reg_we_o;
    wire[`YX_RegAddrBus] ex_reg_waddr_o;
    wire ex_hold_flag_o;
    wire ex_jump_flag_o;
    wire[`YX_InstAddrBus] ex_jump_addr_o;

    wire[`YX_RegBus] regs_rdata1_o;
    wire[`YX_RegBus] regs_rdata2_o;
    wire[`YX_Hold_Flag_Bus] ctrl_hold_flag_o;
    wire ctrl_jump_flag_o;
    wire[`YX_InstAddrBus] ctrl_jump_addr_o;

    wire ex_is_load;
    wire mem_start;
    wire mem_done;
    wire ex_mem_to_bridge;
    wire[`YX_MemAddrBus] ex_mem_addr;
    wire load_wb_fire;
    wire normal_reg_we;
    reg mem_pending;
    reg mem_seen_hold;
    reg mem_we_reg;
    reg mem_is_load_reg;
    reg[`YX_MemAddrBus] mem_raddr_reg;
    reg[`YX_MemAddrBus] mem_waddr_reg;
    reg[`YX_MemBus] mem_wdata_reg;
    reg load_ready;
    reg[`YX_RegAddrBus] load_waddr;
    reg[`YX_RegBus] load_rdata;

    assign ex_is_load = (ie_inst_o[6:0] == `YX_INST_TYPE_L);
    assign ex_mem_addr = (ex_mem_we_o == `YX_WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o;
    assign ex_mem_to_bridge = (ex_mem_req_o == `YX_RIB_REQ) &&
                              ((ex_mem_addr[31:28] == 4'h0) ||
                               (ex_mem_addr[31:28] == 4'h1) ||
                               (ex_mem_addr[31:28] == 4'hf));
    assign mem_start = ex_mem_to_bridge && (mem_pending == 1'b0) && (load_ready == 1'b0);
    assign mem_done = mem_pending && mem_seen_hold && (bridge_hold_flag_i == `YX_HoldDisable);
    assign load_wb_fire = load_ready;
    assign normal_reg_we = ex_reg_we_o & ~bridge_hold_flag_i & ~mem_pending &
                           ~load_ready & ~(ex_mem_to_bridge &&
                           (ex_mem_we_o == `YX_WriteDisable) && ex_is_load);

    assign rib_ex_addr_o = (mem_pending == 1'b1) ?
                           ((mem_we_reg == `YX_WriteEnable) ? mem_waddr_reg : mem_raddr_reg) :
                           ((ex_mem_we_o == `YX_WriteEnable) ? ex_mem_waddr_o : ex_mem_raddr_o);
    assign rib_ex_data_o = (mem_pending == 1'b1) ? mem_wdata_reg : ex_mem_wdata_o;
    assign rib_ex_req_o = (mem_pending == 1'b1) ? `YX_RIB_REQ : ex_mem_req_o;
    assign rib_ex_we_o = (mem_pending == 1'b1) ? mem_we_reg : ex_mem_we_o;
    assign rib_pc_addr_o = pc_pc_o;
    assign rib_pc_req_o = pc_req;

    yx_core_fsm u_core_fsm(
        .clk(clk),
        .rst(rst),
        .uart_debug_i(uart_debug_i),
        .bridge_hold_flag_i(bridge_hold_flag_i),
        .ex_mem_req_i(ex_mem_req_o),
        .ex_hold_flag_i(ex_hold_flag_o),
        .pc_update_en_o(pc_update_en),
        .pc_req_o(pc_req),
        .hold_flag_o(fsm_hold_flag_o)
    );

    yx_pc_reg u_pc_reg(
        .clk(clk),
        .rst(rst),
        .pc_o(pc_pc_o),
        .pc_update_en_i(pc_update_en),
        .hold_flag_i(ctrl_hold_flag_o),
        .jump_flag_i(ctrl_jump_flag_o),
        .jump_addr_i(ctrl_jump_addr_o)
    );

    yx_ctrl u_ctrl(
        .rst(rst),
        .jump_flag_i(ex_jump_flag_o),
        .jump_addr_i(ex_jump_addr_o),
        .fsm_hold_flag_i(fsm_hold_flag_o),
        .hold_flag_ex_i(ex_hold_flag_o),
        .hold_flag_rib_i(rib_hold_flag_i),
        .hold_flag_bridge_i(bridge_hold_flag_i),
        .hold_flag_o(ctrl_hold_flag_o),

        .jump_flag_o(ctrl_jump_flag_o),
        .jump_addr_o(ctrl_jump_addr_o)
    );

    assign regfile_we_o = load_wb_fire ? `YX_WriteEnable : normal_reg_we;
    assign regfile_waddr_o = load_wb_fire ? load_waddr : ex_reg_waddr_o;
    assign regfile_wdata_o = load_wb_fire ? load_rdata : ex_reg_wdata_o;
    assign regfile_raddr1_o = id_reg1_raddr_o;
    assign regfile_raddr2_o = id_reg2_raddr_o;
    assign regs_rdata1_o = regfile_rdata1_i;
    assign regs_rdata2_o = regfile_rdata2_i;

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            mem_pending <= 1'b0;
            mem_seen_hold <= 1'b0;
            mem_we_reg <= `YX_WriteDisable;
            mem_is_load_reg <= 1'b0;
            mem_raddr_reg <= `YX_ZeroWord;
            mem_waddr_reg <= `YX_ZeroWord;
            mem_wdata_reg <= `YX_ZeroWord;
            load_ready <= 1'b0;
            load_waddr <= `YX_ZeroReg;
            load_rdata <= `YX_ZeroWord;
        end else begin
            if (mem_start == 1'b1) begin
                mem_pending <= 1'b1;
                mem_seen_hold <= 1'b0;
                mem_we_reg <= ex_mem_we_o;
                mem_is_load_reg <= (ex_mem_we_o == `YX_WriteDisable) && ex_is_load;
                mem_raddr_reg <= ex_mem_raddr_o;
                mem_waddr_reg <= ex_mem_waddr_o;
                mem_wdata_reg <= ex_mem_wdata_o;
                load_waddr <= ex_reg_waddr_o;
            end else if (mem_pending == 1'b1 && bridge_hold_flag_i == `YX_HoldEnable) begin
                mem_seen_hold <= 1'b1;
            end

            if (mem_done == 1'b1) begin
                mem_pending <= 1'b0;
                mem_seen_hold <= 1'b0;
                if (mem_is_load_reg == 1'b1) begin
                    load_ready <= 1'b1;
                    load_rdata <= rib_ex_data_i;
                end
            end else if (load_wb_fire == 1'b1) begin
                load_ready <= 1'b0;
                load_waddr <= `YX_ZeroReg;
                load_rdata <= `YX_ZeroWord;
            end
        end
    end

    yx_if_id u_if_id(
        .clk(clk),
        .rst(rst),
        .inst_i(rib_pc_data_i),
        .inst_addr_i(pc_pc_o),
        .hold_flag_i(ctrl_hold_flag_o),
        .inst_o(if_inst_o),
        .inst_addr_o(if_inst_addr_o)
    );

    yx_id u_id(
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

    yx_id_ex u_id_ex(
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

    yx_ex u_ex(
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
        .reg_wdata_o(ex_reg_wdata_o),
        .reg_we_o(ex_reg_we_o),
        .reg_waddr_o(ex_reg_waddr_o),
        .hold_flag_o(ex_hold_flag_o),
        .jump_flag_o(ex_jump_flag_o),
        .jump_addr_o(ex_jump_addr_o)
    );

endmodule
