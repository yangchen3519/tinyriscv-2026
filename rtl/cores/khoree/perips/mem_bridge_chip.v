`include "khoree_defines.vh"

// The corrected Khoree archive did not contain its board bridge.  This
// namespaced integration adapter implements the packet format used by the
// Khoree memory-side model while keeping all storage outside the chip RTL.
module khoree_mem_bridge_chip(
    input wire clk, input wire rst,
    input wire rom_req_i, input wire [`KHOREE_MemAddrBus] rom_addr_i,
    input wire rom_we_i, input wire [`KHOREE_MemBus] rom_wdata_i,
    output reg [`KHOREE_MemBus] rom_rdata_o,
    input wire ram_req_i, input wire [`KHOREE_MemAddrBus] ram_addr_i,
    input wire ram_we_i, input wire [`KHOREE_MemBus] ram_wdata_i,
    output reg [`KHOREE_MemBus] ram_rdata_o,
    output wire busy_o, output reg done_o,
    output reg rom_done_o, output reg ram_done_o,
    output reg [7:0] c2f_data_o, output reg c2f_valid_o,
    input wire c2f_ready_i,
    input wire [7:0] f2c_data_i, input wire f2c_valid_i,
    output reg f2c_ready_o,
    output reg saw_rom_write_o, output reg saw_rom_read_o,
    output reg saw_ram_write_o, output reg saw_ram_read_o,
    output reg [7:0] last_cmd_o, output reg [7:0] last_addr_o
);
    localparam CMD_ROM_READ=8'h01, CMD_RAM_READ=8'h02,
               CMD_RAM_WRITE=8'h03, CMD_ROM_WRITE=8'h04;
    localparam S_IDLE=3'd0, S_SEND=3'd1, S_WAIT=3'd2,
               S_RECV=3'd3, S_DONE=3'd4;
    reg [2:0] state;
    reg target_rom, target_write;
    reg [3:0] tx_index;
    reg [2:0] rx_index;
    reg [7:0] cmd_latched;
    reg [`KHOREE_MemAddrBus] addr_latched, served_addr;
    reg [`KHOREE_MemBus] wdata_latched, rdata_shift, served_wdata;
    reg served_valid, served_rom, served_we;
    wire rom_new = rom_req_i && !(served_valid && served_rom &&
        served_we==rom_we_i && served_addr==rom_addr_i &&
        (!rom_we_i || served_wdata==rom_wdata_i));
    wire ram_new = ram_req_i && !(served_valid && !served_rom &&
        served_we==ram_we_i && served_addr==ram_addr_i &&
        (!ram_we_i || served_wdata==ram_wdata_i));
    wire write_packet=(cmd_latched==CMD_ROM_WRITE)||(cmd_latched==CMD_RAM_WRITE);
    wire [3:0] packet_len=write_packet ? 4'd9 : 4'd5;
    assign busy_o=(state!=S_IDLE)||rom_new||ram_new;

    always @(*) begin
        c2f_valid_o=(state==S_SEND);
        f2c_ready_o=(state==S_WAIT)||(state==S_RECV);
        case(tx_index)
            0:c2f_data_o=cmd_latched; 1:c2f_data_o=addr_latched[31:24];
            2:c2f_data_o=addr_latched[23:16]; 3:c2f_data_o=addr_latched[15:8];
            4:c2f_data_o=addr_latched[7:0]; 5:c2f_data_o=wdata_latched[31:24];
            6:c2f_data_o=wdata_latched[23:16]; 7:c2f_data_o=wdata_latched[15:8];
            default:c2f_data_o=wdata_latched[7:0];
        endcase
    end

    always @(posedge clk) begin
        if (rst==`KHOREE_RstEnable) begin
            state<=S_IDLE; target_rom<=1; target_write<=0; tx_index<=0; rx_index<=0;
            cmd_latched<=CMD_ROM_READ; addr_latched<=0; wdata_latched<=0;
            rdata_shift<=0; rom_rdata_o<=`KHOREE_INST_NOP; ram_rdata_o<=0;
            done_o<=0; rom_done_o<=0; ram_done_o<=0;
            saw_rom_write_o<=0; saw_rom_read_o<=0; saw_ram_write_o<=0;
            saw_ram_read_o<=0; last_cmd_o<=0; last_addr_o<=0;
            served_valid<=0; served_rom<=1; served_we<=0; served_addr<=0; served_wdata<=0;
        end else begin
            done_o<=0; rom_done_o<=0; ram_done_o<=0;
            case(state)
                S_IDLE: begin
                    tx_index<=0; rx_index<=0; rdata_shift<=0;
                    if (ram_new) begin
                        target_rom<=0; target_write<=ram_we_i;
                        cmd_latched<=ram_we_i?CMD_RAM_WRITE:CMD_RAM_READ;
                        addr_latched<=ram_addr_i; wdata_latched<=ram_wdata_i;
                        last_cmd_o<=ram_we_i?CMD_RAM_WRITE:CMD_RAM_READ;
                        last_addr_o<=ram_addr_i[5:2];
                        if(ram_we_i)saw_ram_write_o<=1;else saw_ram_read_o<=1;
                        served_valid<=0; state<=S_SEND;
                    end else if (rom_new) begin
                        target_rom<=1; target_write<=rom_we_i;
                        cmd_latched<=rom_we_i?CMD_ROM_WRITE:CMD_ROM_READ;
                        addr_latched<=rom_addr_i; wdata_latched<=rom_wdata_i;
                        last_cmd_o<=rom_we_i?CMD_ROM_WRITE:CMD_ROM_READ;
                        last_addr_o<=rom_addr_i[9:2];
                        if(rom_we_i)saw_rom_write_o<=1;else saw_rom_read_o<=1;
                        served_valid<=0; state<=S_SEND;
                    end
                end
                S_SEND: if(c2f_ready_i) begin
                    if(tx_index==packet_len-1) begin tx_index<=0; state<=S_WAIT; end
                    else tx_index<=tx_index+1'b1;
                end
                S_WAIT: if(f2c_valid_i) begin
                    if(target_write) state<=S_DONE;
                    else begin rdata_shift[31:24]<=f2c_data_i; rx_index<=1; state<=S_RECV; end
                end
                S_RECV: if(f2c_valid_i) begin
                    case(rx_index)
                        1:rdata_shift[23:16]<=f2c_data_i;
                        2:rdata_shift[15:8]<=f2c_data_i;
                        3:rdata_shift[7:0]<=f2c_data_i;
                    endcase
                    if(rx_index==3) begin
                        if(target_rom)rom_rdata_o<={rdata_shift[31:8],f2c_data_i};
                        else ram_rdata_o<={rdata_shift[31:8],f2c_data_i};
                        state<=S_DONE;
                    end else rx_index<=rx_index+1'b1;
                end
                S_DONE: begin
                    done_o<=1; rom_done_o<=target_rom; ram_done_o<=!target_rom;
                    served_valid<=1; served_rom<=target_rom; served_we<=target_write;
                    served_addr<=addr_latched; served_wdata<=wdata_latched; state<=S_IDLE;
                end
                default: state<=S_IDLE;
            endcase
            if(!rom_req_i && !ram_req_i) served_valid<=0;
        end
    end
endmodule
