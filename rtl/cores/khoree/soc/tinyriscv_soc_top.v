 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the ecific language governing permissions and     
 limitations under the License.                                          
 */

`include "khoree_defines.vh"

// tinyriscv soc?????-
module khoree_tinyriscv_soc_top(

    input wire clk,
    input wire rst,
    //input wire baud_update_en,
    output reg succ,         // ?????????????
    input wire uart_debug_pin, // ??????????
    output wire uart_tx_pin, // UART??'????
    input wire uart_rx_pin,  // UART??"???
    output wire [2:0] PWM_o,     // compatibility only; shared PWM drives chip output
    output wire io_scl,
    input wire io_sda_i,
    output wire io_sda_drive_low_o,
    output wire regfile_we_o,
    output wire[4:0] regfile_waddr_o,
    output wire[31:0] regfile_wdata_o,
    output wire[4:0] regfile_raddr1_o,
    output wire[4:0] regfile_raddr2_o,
    input wire[31:0] regfile_rdata1_i,
    input wire[31:0] regfile_rdata2_i,
    input wire[31:0] status_x26_i,
    input wire[31:0] status_x27_i,
    output wire pwm_we_o,
    output wire[31:0] pwm_addr_o,
    output wire[31:0] pwm_wdata_o,
    input wire[31:0] pwm_rdata_i,
    input wire debug_req_i,
    input wire debug_we_i,
    input wire[31:0] debug_addr_i,
    input wire[31:0] debug_wdata_i,
    output wire[31:0] debug_rdata_o,
    output wire debug_ack_o,
    output wire mem_req_o,
    output wire mem_we_o,
    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i,
    input wire mem_ack_i,
    input wire mem_hold_i
    );
    


//    assign PWM_o[0] = saw_rom_write;
//    assign PWM_o[1] = saw_rom_read;
//    assign PWM_o[2] = bridge_busy;

    wire saw_rom_write;
    wire saw_rom_read;
    wire saw_ram_write;
    wire saw_ram_read;
    wire [7:0] last_cmd;
    wire [7:0] last_addr;

    //c2f = chip bridge to FPGA bridge
    //f2c = FPGA bridge to chip bridge
    wire bridge_busy;
    wire bridge_done;
    wire bridge_rom_done;
    wire bridge_ram_done;

    // make external signals internal
    reg over;               // ?????????????
    // master 0 interface
    wire[`KHOREE_MemAddrBus] m0_addr_i;
    wire[`KHOREE_MemBus] m0_data_i;
    wire[`KHOREE_MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;
    wire m0_ack_o;

    // master 1 interface
    wire[`KHOREE_MemAddrBus] m1_addr_i;
    wire[`KHOREE_MemBus] m1_data_i;
    wire[`KHOREE_MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // master 2 interface
    wire[`KHOREE_MemAddrBus] m2_addr_i;
    wire[`KHOREE_MemBus] m2_data_i;
    wire[`KHOREE_MemBus] m2_data_o;
    wire m2_req_i;
    wire m2_we_i;

    // master 3 interface
    wire[`KHOREE_MemAddrBus] m3_addr_i;
    wire[`KHOREE_MemBus] m3_data_i;
    wire[`KHOREE_MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    // slave 0 interface
    wire[`KHOREE_MemAddrBus] s0_addr_o;
    wire[`KHOREE_MemBus] s0_data_o;
    wire[`KHOREE_MemBus] s0_data_i;
    wire s0_we_o;

    // slave 1 interface
    wire[`KHOREE_MemAddrBus] s1_addr_o;
    wire[`KHOREE_MemBus] s1_data_o;
    wire[`KHOREE_MemBus] s1_data_i;
    wire s1_we_o;

    // slave 2 interface
    wire[`KHOREE_MemAddrBus] s2_addr_o;
    wire[`KHOREE_MemBus] s2_data_o;
    //wire[`KHOREE_MemBus] s2_data_i;
    wire s2_we_o;

    // slave 3 interface
    wire[`KHOREE_MemAddrBus] s3_addr_o;
    wire[`KHOREE_MemBus] s3_data_o;
    wire[`KHOREE_MemBus] s3_data_i;
    wire s3_we_o;

    // slave 4 interface
    wire[`KHOREE_MemAddrBus] s4_addr_o;
    wire[`KHOREE_MemBus] s4_data_o;
    //wire[`KHOREE_MemBus] s4_data_i;
    wire s4_we_o;

    // slave 5 interface
    wire[`KHOREE_MemAddrBus] s5_addr_o;
    wire[`KHOREE_MemBus] s5_data_o;
    wire s5_we_o;

    // slave 6 interface: pwm
    wire[`KHOREE_MemAddrBus] s6_addr_o;
    wire[`KHOREE_MemBus] s6_data_o;
    wire[`KHOREE_MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface: i2c
    wire[`KHOREE_MemAddrBus] s7_addr_o;
    wire[`KHOREE_MemBus] s7_data_o;
    wire[`KHOREE_MemBus] s7_data_i;
    wire s7_we_o;
    wire s7_ack_i;
    wire s7_req_o;

    // rib
    wire rib_hold_flag_raw;
    wire rib_hold_flag_to_cpu;

    // Keep the CPU frozen while the shared UART downloader owns the bus.
    // Without this term Khoree can fetch/execute between download packets.
    assign rib_hold_flag_to_cpu = rib_hold_flag_raw | bridge_busy | uart_debug_pin;

    // Shared resources are instantiated once in tinyriscv_4core_top.
    assign PWM_o = 3'b000;
    assign pwm_we_o = s6_we_o;
    assign pwm_addr_o = s6_addr_o;
    assign pwm_wdata_o = s6_data_o;
    assign s6_data_i = pwm_rdata_i;
    assign m3_req_i = debug_req_i;
    assign m3_we_i = debug_we_i;
    assign m3_addr_i = debug_addr_i;
    assign m3_data_i = debug_wdata_i;
    assign debug_rdata_o = m3_data_o;

    wire debug_mem_access;
    assign debug_mem_access = debug_req_i &&
                              ((debug_addr_i[31:28] == 4'h0) ||
                               (debug_addr_i[31:28] == 4'h1));

    // UART/PWM/I2C accesses complete locally. ROM/RAM accesses acknowledge
    // only after the shared external-memory bridge has completed the cycle.
    assign debug_ack_o = debug_req_i &&
                         (!debug_mem_access || mem_ack_i);

    wire ram_access;
    assign ram_access = m0_req_i && (m0_addr_i[31:28] == 4'h1); 
    assign mem_req_o = debug_mem_access | ram_access | ~uart_debug_pin;
    assign mem_we_o = (debug_mem_access && debug_addr_i[31:28] == 4'h1) ? s1_we_o :
                      (debug_mem_access && debug_addr_i[31:28] == 4'h0) ? s0_we_o :
                      ram_access ? s1_we_o : s0_we_o;
    assign mem_addr_o = (debug_mem_access && debug_addr_i[31:28] == 4'h1) ?
                            {4'h1, s1_addr_o[27:0]} :
                        (debug_mem_access && debug_addr_i[31:28] == 4'h0) ?
                            {4'h0, s0_addr_o[27:0]} :
                        ram_access ? {4'h1, s1_addr_o[27:0]} :
                                     {4'h0, s0_addr_o[27:0]};
    assign mem_wdata_o = (debug_mem_access && debug_addr_i[31:28] == 4'h1) ? s1_data_o :
                         (debug_mem_access && debug_addr_i[31:28] == 4'h0) ? s0_data_o :
                         ram_access ? s1_data_o : s0_data_o;
    assign s0_data_i = mem_rdata_i;
    assign s1_data_i = mem_rdata_i;
    assign bridge_busy = mem_hold_i;
    assign bridge_done = mem_ack_i;
    assign bridge_rom_done = mem_ack_i & ~ram_access;
    assign bridge_ram_done = mem_ack_i & ram_access;

    always @ (posedge clk) begin
        if (rst == `KHOREE_RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~status_x26_i[0];  // when = 1, run over
            succ <= ~status_x27_i[0];  // when = 1, run succ, otherwise fail
        end
    end

    // tinyriscv?????? ????-??-
    khoree_tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_ex_ack_i(m0_ack_o),

        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),

        .rib_hold_flag_i(rib_hold_flag_to_cpu),
        .regfile_we_o(regfile_we_o),
        .regfile_waddr_o(regfile_waddr_o),
        .regfile_wdata_o(regfile_wdata_o),
        .regfile_raddr1_o(regfile_raddr1_o),
        .regfile_raddr2_o(regfile_raddr2_o),
        .regfile_rdata1_i(regfile_rdata1_i),
        .regfile_rdata2_i(regfile_rdata2_i)
    );

    // uart???-??-
    khoree_uart uart_0(
        .clk(clk),
        .rst(rst),
        .baud_update_en(1'b0),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );




    // i2c???-??-
    khoree_i2c i2c_0(
        .clk(clk),
        .rst_n(rst),
        .data_i(s7_data_o),
        .addr_i(s7_addr_o),
        .we_i(s7_we_o),
        .data_o(s7_data_i),
        .scl(io_scl),
        .sda_i(io_sda_i),
        .sda_drive_low_o(io_sda_drive_low_o),
        .read_data_ready_o(s7_ack_i),
        .req_i(s7_req_o)
    );

    // rib???-??-
    khoree_rib u_rib(
        .clk(clk),
        .rst(rst),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),
        .m0_ack_o(m0_ack_o),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`KHOREE_ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`KHOREE_RIB_REQ),
        .m1_we_i(`KHOREE_WriteDisable),

        // master 2 interface
        .m2_addr_i(`KHOREE_ZeroWord),
        .m2_data_i(`KHOREE_ZeroWord),
        .m2_data_o(m2_data_o),
        .m2_req_i(`KHOREE_RIB_NREQ),
        .m2_we_i(`KHOREE_WriteDisable),

        // master 3 interface
        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),

        // slave 0 interface
        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_we_o(s0_we_o),
        .s0_ack_i(bridge_rom_done),

        // slave 1 interface
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        .s1_ack_i(bridge_ram_done),

        // slave 2 interface
        .s2_addr_o(s2_addr_o),
        .s2_data_o(s2_data_o),
        .s2_data_i(`KHOREE_ZeroWord),
        .s2_we_o(s2_we_o),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        // slave 4 interface
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_data_i(`KHOREE_ZeroWord),
        .s4_we_o(s4_we_o),

        // slave 5 interface
        .s5_addr_o(s5_addr_o),
        .s5_data_o(s5_data_o),
        .s5_data_i(`KHOREE_ZeroWord),
        .s5_we_o(s5_we_o),

        // slave 6 interface
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),

        // slave 7 interface
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        .s7_req_o(s7_req_o),
        .s7_ack_i(s7_ack_i),

        .hold_flag_o(rib_hold_flag_raw)
    );

endmodule
