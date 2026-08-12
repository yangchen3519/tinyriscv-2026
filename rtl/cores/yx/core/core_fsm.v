`include "yx_defines.vh"

// core状态机
module yx_core_fsm(

    input wire clk,
    input wire rst,
    input wire uart_debug_i,

    input wire bridge_hold_flag_i,
    input wire ex_mem_req_i,
    input wire ex_hold_flag_i,
    output reg pc_update_en_o,
    output reg pc_req_o,
    output reg hold_flag_o

    );

    localparam S_IDLE       = 3'b000;
    localparam S_FETCH_WAIT = 3'b001;
    localparam S_EXEC       = 3'b010;
    localparam S_EXEC2      = 3'b011;
    localparam S_EXEC3      = 3'b111;
    localparam S_MEM_WAIT   = 3'b110;
    localparam S_MEM_DONE   = 3'b101;
    localparam S_PC_NEXT    = 3'b100;


    reg [2:0] core_state;

    always @(posedge clk) begin
        if (rst == `YX_RstEnable || uart_debug_i == 1'b1) begin
            core_state <= S_IDLE;
            pc_update_en_o <= 1'b0;
            pc_req_o       <= `YX_RIB_NREQ;
            hold_flag_o    <= 1'b1;
        end else if (ex_hold_flag_i == `YX_HoldEnable) begin
            pc_update_en_o <= 1'b0;
            pc_req_o       <= `YX_RIB_NREQ;
            hold_flag_o    <= 1'b0;
        end else begin
            case (core_state)
                S_IDLE: begin
                    core_state <= S_FETCH_WAIT;
                    pc_update_en_o <= 1'b0;
                    pc_req_o       <= `YX_RIB_REQ;
                    hold_flag_o    <= 1'b1;
                end
                S_FETCH_WAIT: begin
                    // PC 地址保持不变，等�?bridge 把指令取回来
                    if (bridge_hold_flag_i == `YX_HoldDisable) begin
                        pc_update_en_o <= 1'b0;
                        pc_req_o       <= `YX_RIB_REQ;
                        hold_flag_o    <= 1'b0;
                        core_state <= S_EXEC;
                    end
                end
                S_EXEC: begin
                    pc_update_en_o <= 1'b0;
                    pc_req_o       <= `YX_RIB_NREQ;
                    if (ex_mem_req_i == `YX_RIB_REQ) begin
                        hold_flag_o <= 1'b1;
                        core_state  <= S_MEM_WAIT;
                    end else begin
                        hold_flag_o <= 1'b0;
                        core_state  <= S_EXEC2;
                    end
                end
                S_EXEC2: begin
                    pc_update_en_o <= 1'b0;
                    pc_req_o       <= `YX_RIB_NREQ;
                    if (ex_mem_req_i == `YX_RIB_REQ) begin
                        hold_flag_o <= 1'b1;
                        core_state  <= S_MEM_WAIT;
                    end else begin
                        hold_flag_o <= 1'b0;
                        core_state  <= S_EXEC3;
                    end
                end
                S_EXEC3: begin
                    if (ex_mem_req_i == `YX_RIB_REQ) begin
                        pc_update_en_o <= 1'b0;
                        pc_req_o       <= `YX_RIB_NREQ;
                        hold_flag_o    <= 1'b1;
                        core_state <= S_MEM_WAIT;
                    end else begin
                        pc_update_en_o <= 1'b1;
                        pc_req_o       <= `YX_RIB_NREQ;
                        hold_flag_o    <= 1'b0;
                        core_state <= S_PC_NEXT;
                    end
                end
                S_MEM_WAIT: begin
                    if (bridge_hold_flag_i == `YX_HoldDisable) begin
                        pc_update_en_o <= 1'b0;
                        pc_req_o       <= `YX_RIB_NREQ;
                        hold_flag_o    <= 1'b1;
                        core_state <= S_MEM_DONE;
                    end
                end

                S_MEM_DONE: begin
                    pc_update_en_o <= 1'b1;
                    pc_req_o       <= `YX_RIB_NREQ;
                    hold_flag_o    <= 1'b0;
                    core_state <= S_PC_NEXT;
                end

                S_PC_NEXT: begin
                    pc_update_en_o <= 1'b0;
                    pc_req_o       <= `YX_RIB_REQ;
                    hold_flag_o    <= 1'b1;
                    core_state <= S_FETCH_WAIT;
                end

                default: begin
                    core_state     <= S_IDLE;
                    pc_update_en_o <= 1'b0;
                    pc_req_o       <= `YX_RIB_NREQ;
                    hold_flag_o    <= 1'b1;
                end

            endcase
        end
    end

endmodule
