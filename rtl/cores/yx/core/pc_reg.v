`include "yx_defines.vh"

module yx_pc_reg(
    input wire clk,
    input wire rst,
    input wire jump_flag_i,
    input wire[`YX_InstAddrBus] jump_addr_i,
    input wire[`YX_Hold_Flag_Bus] hold_flag_i,
    input wire pc_update_en_i,
    output reg[`YX_InstAddrBus] pc_o
    );

    reg jump_flag_r;
    reg[`YX_InstAddrBus] jump_addr_r;

    always @ (posedge clk) begin
        if (rst == `YX_RstEnable) begin
            pc_o <= `YX_CpuResetAddr;
            jump_flag_r <= `YX_JumpDisable;
            jump_addr_r <= `YX_ZeroWord;
        end else begin
            if (jump_flag_i == `YX_JumpEnable) begin
                jump_flag_r <= `YX_JumpEnable;
                jump_addr_r <= jump_addr_i;
            end

            if (hold_flag_i >= `YX_Hold_Pc) begin
                pc_o <= pc_o;
            end else if (pc_update_en_i == 1'b1) begin
                pc_o <= (jump_flag_i == `YX_JumpEnable) ? jump_addr_i :
                        (jump_flag_r == `YX_JumpEnable) ? jump_addr_r :
                        pc_o + 4'h4;
                jump_flag_r <= `YX_JumpDisable;
            end else begin
                pc_o <= pc_o;
            end
        end
    end

endmodule
