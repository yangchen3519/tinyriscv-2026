`include "pjy_defines.vh"

// PJY private chip-side bridge restored from the original PJY project.
module pjy_mem_bridge_chip(
    input wire clk, input wire rst,
    input wire s0_req_i, input wire s0_we_i,
    input wire [`PJY_MemAddrBus] s0_addr_i,
    input wire [`PJY_MemBus] s0_data_i,
    output reg [`PJY_MemBus] s0_data_o,
    input wire s1_req_i, input wire s1_we_i,
    input wire [`PJY_MemAddrBus] s1_addr_i,
    input wire [`PJY_MemBus] s1_data_i,
    output reg [`PJY_MemBus] s1_data_o,
    output wire hold_flag_o,
    output reg [7:0] ext_mem_data_o,
    input wire [7:0] ext_mem_data_i
);
    localparam CMD_ROM_READ=8'ha0, CMD_RAM_READ=8'ha1,
               CMD_RAM_WRITE=8'ha2, CMD_ROM_WRITE=8'ha3;
    localparam TARGET_ROM=1'b0, TARGET_RAM=1'b1;
    localparam S_IDLE=5'd0, S_SEND_CMD=5'd1, S_SEND_ADDR=5'd2,
               S_RECV_0=5'd4, S_RECV_1=5'd5, S_RECV_2=5'd6,
               S_RECV_3=5'd7, S_PREP_WRITE=5'd8,
               S_SEND_WCMD=5'd9, S_SEND_WADDR=5'd10,
               S_SEND_W0=5'd11, S_SEND_W1=5'd12,
               S_SEND_W2=5'd13, S_SEND_W3=5'd14,
               S_WRITE_WAIT=5'd15, S_DONE=5'd16;
    reg [4:0] state;
    reg target, target_we, ram_write_after_read;
    reg [7:0] req_cmd, req_index;
    reg [`PJY_MemAddrBus] req_addr;
    reg [`PJY_MemBus] req_wdata, read_data;
    reg served_valid, served_target, served_we;
    reg [`PJY_MemAddrBus] served_addr;
    reg [`PJY_MemBus] served_wdata;

    wire rom_req_new = (s0_req_i == `PJY_RIB_REQ) &&
        !(served_valid && served_target == TARGET_ROM &&
          served_we == s0_we_i && served_addr == s0_addr_i &&
          (!s0_we_i || served_wdata == s0_data_i));
    wire ram_req_new = (s1_req_i == `PJY_RIB_REQ) &&
        !(served_valid && served_target == TARGET_RAM &&
          served_we == s1_we_i && served_addr == s1_addr_i &&
          (!s1_we_i || served_wdata == s1_data_i));
    assign hold_flag_o = ((state != S_IDLE && state != S_DONE) ||
                          rom_req_new || ram_req_new) ?
                         `PJY_HoldEnable : `PJY_HoldDisable;

    always @(posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            state<=S_IDLE; target<=TARGET_ROM; target_we<=`PJY_WriteDisable;
            ram_write_after_read<=`PJY_False; req_cmd<=0; req_index<=0;
            req_addr<=`PJY_ZeroWord; req_wdata<=`PJY_ZeroWord;
            read_data<=`PJY_ZeroWord; s0_data_o<=`PJY_ZeroWord;
            s1_data_o<=`PJY_ZeroWord; ext_mem_data_o<=0;
            served_valid<=`PJY_False; served_target<=TARGET_ROM;
            served_we<=`PJY_WriteDisable; served_addr<=`PJY_ZeroWord;
            served_wdata<=`PJY_ZeroWord;
        end else begin
            case (state)
                S_IDLE: begin
                    ext_mem_data_o<=0;
                    if (rom_req_new) begin
                        target<=TARGET_ROM; target_we<=s0_we_i;
                        ram_write_after_read<=`PJY_False;
                        req_cmd<=s0_we_i ? CMD_ROM_WRITE : CMD_ROM_READ;
                        req_index<=s0_addr_i[9:2]; req_addr<=s0_addr_i;
                        req_wdata<=s0_data_i; served_valid<=`PJY_False;
                        state<=S_SEND_CMD;
                    end else if (ram_req_new) begin
                        target<=TARGET_RAM; target_we<=s1_we_i;
                        ram_write_after_read<=s1_we_i; req_cmd<=CMD_RAM_READ;
                        req_index<={4'h0,s1_addr_i[5:2]}; req_addr<=s1_addr_i;
                        req_wdata<=s1_data_i; served_valid<=`PJY_False;
                        state<=S_SEND_CMD;
                    end
                end
                S_SEND_CMD: begin ext_mem_data_o<=req_cmd; state<=S_SEND_ADDR; end
                S_SEND_ADDR: begin
                    ext_mem_data_o<=req_index;
                    state <= (req_cmd==CMD_ROM_READ || req_cmd==CMD_RAM_READ) ?
                             S_RECV_0 : S_SEND_W0;
                end
                S_RECV_0: begin ext_mem_data_o<=0; read_data[7:0]<=ext_mem_data_i; state<=S_RECV_1; end
                S_RECV_1: begin read_data[15:8]<=ext_mem_data_i; state<=S_RECV_2; end
                S_RECV_2: begin read_data[23:16]<=ext_mem_data_i; state<=S_RECV_3; end
                S_RECV_3: begin
                    read_data[31:24]<=ext_mem_data_i;
                    if (target==TARGET_ROM) s0_data_o<={ext_mem_data_i,read_data[23:0]};
                    else s1_data_o<={ext_mem_data_i,read_data[23:0]};
                    state<=ram_write_after_read ? S_PREP_WRITE : S_DONE;
                end
                S_PREP_WRITE: begin req_cmd<=CMD_RAM_WRITE; req_wdata<=s1_data_i; state<=S_SEND_WCMD; end
                S_SEND_WCMD: begin ext_mem_data_o<=req_cmd; state<=S_SEND_WADDR; end
                S_SEND_WADDR: begin ext_mem_data_o<=req_index; state<=S_SEND_W0; end
                S_SEND_W0: begin ext_mem_data_o<=req_wdata[7:0]; state<=S_SEND_W1; end
                S_SEND_W1: begin ext_mem_data_o<=req_wdata[15:8]; state<=S_SEND_W2; end
                S_SEND_W2: begin ext_mem_data_o<=req_wdata[23:16]; state<=S_SEND_W3; end
                S_SEND_W3: begin ext_mem_data_o<=req_wdata[31:24]; state<=S_WRITE_WAIT; end
                S_WRITE_WAIT: begin ext_mem_data_o<=0; state<=S_DONE; end
                S_DONE: begin
                    ext_mem_data_o<=0; served_valid<=`PJY_True;
                    served_target<=target; served_we<=target_we;
                    served_addr<=req_addr; served_wdata<=req_wdata; state<=S_IDLE;
                end
                default: state<=S_IDLE;
            endcase
            if (s0_req_i==`PJY_RIB_NREQ && s1_req_i==`PJY_RIB_NREQ)
                served_valid<=`PJY_False;
        end
    end
endmodule
