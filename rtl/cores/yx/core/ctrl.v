`include "yx_defines.vh"

module yx_ctrl(
    input wire rst,
    input wire fsm_hold_flag_i,
    input wire jump_flag_i,
    input wire[`YX_InstAddrBus] jump_addr_i,
    input wire hold_flag_ex_i,
    input wire hold_flag_rib_i,
    input wire hold_flag_bridge_i,
    output reg[`YX_Hold_Flag_Bus] hold_flag_o,
    output reg jump_flag_o,
    output reg[`YX_InstAddrBus] jump_addr_o
    );

    always @ (*) begin
        jump_addr_o = jump_addr_i;
        jump_flag_o = jump_flag_i;
        hold_flag_o = `YX_Hold_None;
        if (fsm_hold_flag_i == `YX_HoldEnable || hold_flag_ex_i == `YX_HoldEnable) begin
            hold_flag_o = `YX_Hold_Id;
        end else if (hold_flag_rib_i == `YX_HoldEnable || hold_flag_bridge_i == `YX_HoldEnable) begin
            hold_flag_o = `YX_Hold_Pc;
        end
    end

endmodule
