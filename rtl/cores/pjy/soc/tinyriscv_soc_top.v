 /*                                                                      
 Copyright 2020 Blue Liang, liangkangnan@163.com
                                                                         
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

// tinyriscv soc顶层模块
module pjy_tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg over,         // 测试是否完成信号
    output reg succ,         // 测试是否成功信号

    output wire halted_ind,  // jtag是否已经halt住CPU信号

    input wire uart_debug_pin, // 串口下载使能引脚

    output wire uart_tx_pin, // UART发�?�引�?
    input wire uart_rx_pin,  // UART接收引脚
    // TASK0_REMOVE_PERIPS_BEGIN: GPIO外设删除，保留原端口声明作为注释
    // inout wire[1:0] gpio,    // GPIO引脚
    // TASK0_REMOVE_PERIPS_END

    output wire mem_req_o,
    output wire mem_we_o,
    output wire[31:0] mem_addr_o,
    output wire[31:0] mem_wdata_o,
    input wire[31:0] mem_rdata_i,
    input wire mem_ack_i,
    input wire mem_hold_i,
    // TASK2_PWM_BEGIN: PWM外设输出
    output wire[3:0] PWM_o,
    // TASK2_PWM_END
    // TASK3_I2C_BEGIN: I2C外设引脚
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
    output wire debug_ack_o
    // TASK3_I2C_END
    // TASK0_REMOVE_PERIPS_BEGIN: SPI外设删除，保留原端口声明作为注释
    // ,
    // input wire spi_miso,     // SPI MISO引脚
    // output wire spi_mosi,    // SPI MOSI引脚
    // output wire spi_ss,      // SPI SS引脚
    // output wire spi_clk      // SPI CLK引脚
    // TASK0_REMOVE_PERIPS_END

    );


    // master 0 interface
    wire[`PJY_MemAddrBus] m0_addr_i;
    wire[`PJY_MemBus] m0_data_i;
    wire[`PJY_MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;

    // master 1 interface
    wire[`PJY_MemAddrBus] m1_addr_i;
    wire[`PJY_MemBus] m1_data_i;
    wire[`PJY_MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // master 2 interface
    wire[`PJY_MemAddrBus] m2_addr_i;
    wire[`PJY_MemBus] m2_data_i;
    wire[`PJY_MemBus] m2_data_o;
    wire m2_req_i;
    wire m2_we_i;

    // master 3 interface
    wire[`PJY_MemAddrBus] m3_addr_i;
    wire[`PJY_MemBus] m3_data_i;
    wire[`PJY_MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    // slave 0 interface
    wire[`PJY_MemAddrBus] s0_addr_o;
    wire[`PJY_MemBus] s0_data_o;
    wire[`PJY_MemBus] s0_data_i;
    wire s0_we_o;
    // TASK1_EXT_MEM_BEGIN: ROM slave访问请求
    wire s0_req_o;
    // TASK1_EXT_MEM_END

    // slave 1 interface
    wire[`PJY_MemAddrBus] s1_addr_o;
    wire[`PJY_MemBus] s1_data_o;
    wire[`PJY_MemBus] s1_data_i;
    wire s1_we_o;
    // TASK1_EXT_MEM_BEGIN: RAM slave访问请求
    wire s1_req_o;
    // TASK1_EXT_MEM_END

    // slave 2 interface
    wire[`PJY_MemAddrBus] s2_addr_o;
    wire[`PJY_MemBus] s2_data_o;
    wire[`PJY_MemBus] s2_data_i;
    wire s2_we_o;

    // slave 3 interface
    wire[`PJY_MemAddrBus] s3_addr_o;
    wire[`PJY_MemBus] s3_data_o;
    wire[`PJY_MemBus] s3_data_i;
    wire s3_we_o;

    // slave 4 interface
    wire[`PJY_MemAddrBus] s4_addr_o;
    wire[`PJY_MemBus] s4_data_o;
    wire[`PJY_MemBus] s4_data_i;
    wire s4_we_o;

    // slave 5 interface
    wire[`PJY_MemAddrBus] s5_addr_o;
    wire[`PJY_MemBus] s5_data_o;
    wire[`PJY_MemBus] s5_data_i;
    wire s5_we_o;

    // TASK2_PWM_BEGIN: PWM slave6 interface
    wire[`PJY_MemAddrBus] s6_addr_o;
    wire[`PJY_MemBus] s6_data_o;
    wire[`PJY_MemBus] s6_data_i;
    wire s6_we_o;
    // TASK2_PWM_END

    // TASK3_I2C_BEGIN: I2C slave7 interface
    wire[`PJY_MemAddrBus] s7_addr_o;
    wire[`PJY_MemBus] s7_data_o;
    wire[`PJY_MemBus] s7_data_i;
    wire s7_we_o;
    // TASK3_I2C_END

    // TASK4_SID_BEGIN: Send ID instruction UART sender debug signals
    wire sid_start;
    wire sid_busy;
    wire sid_done;
    wire sid_tx_valid;
    wire[7:0] sid_tx_data;
    wire[3:0] sid_index;
    wire uart_tx_busy;
    wire uart_we;
    wire[`PJY_MemBus] uart_wdata;
    // TASK4_SID_END

    // TASK5_RT_BEGIN: Read Temperature instruction debug/control signals
    wire rt_start;
    wire[`PJY_RegAddrBus] rt_reg_waddr;
    wire rt_busy;
    wire rt_done;
    wire[7:0] rt_data;
    wire rt_reg_we;
    reg[`PJY_RegAddrBus] rt_reg_waddr_r;
    reg rt_done_hold;
    reg rt_done_release;
    reg[7:0] rt_data_r;
    reg rt_uart_pending;
    reg rt_uart_sent_once;
    // TASK5_RT_END

    // TASK6_IF_BEGIN: Integrated-and-Fire instruction debug/control signals
    wire if_start;
    wire[`PJY_RegAddrBus] if_reg_waddr;
    wire if_busy;
    wire if_done;
    wire if_tx_valid;
    wire[7:0] if_tx_data;
    wire[7:0] if_uart_tx_data;
    wire if_reg_we;
    reg[`PJY_RegAddrBus] if_reg_waddr_r;
    reg if_done_hold;
    // TASK6_IF_END

    // rib
    wire rib_hold_flag_o;
    // TASK1_EXT_MEM_BEGIN: 片外ROM/RAM桥接器暂停信�?
    wire mem_hold_flag_o;
    // TASK1_EXT_MEM_END

    // jtag
    wire jtag_halt_req_o;
    wire jtag_reset_req_o;
    wire[`PJY_RegAddrBus] jtag_reg_addr_o;
    wire[`PJY_RegBus] jtag_reg_data_o;
    wire jtag_reg_we_o;
    wire[`PJY_RegBus] jtag_reg_data_i;
    assign jtag_halt_req_o = 1'b0;
    assign jtag_reset_req_o = 1'b0;
    assign jtag_reg_addr_o = 5'b0;
    assign jtag_reg_data_o = 32'b0;
    assign jtag_reg_we_o = 1'b0;
    assign m2_addr_i = 32'b0;
    assign m2_data_i = 32'b0;
    assign m2_req_i = 1'b0;
    assign m2_we_i = 1'b0;

    assign PWM_o = 4'b0000;
    assign pwm_we_o = s6_we_o;
    assign pwm_addr_o = s6_addr_o;
    assign pwm_wdata_o = s6_data_o;
    assign s6_data_i = pwm_rdata_i;
    assign m3_req_i = debug_req_i;
    assign m3_we_i = debug_we_i;
    assign m3_addr_i = debug_addr_i;
    assign m3_data_i = debug_wdata_i;
    assign debug_rdata_o = m3_data_o;
    // UART/peripheral cycles complete immediately; only off-chip ROM/RAM
    // cycles wait for the byte-wide bridge transaction to finish.
    assign debug_ack_o = debug_req_i &&
                         (((debug_addr_i[31:28] != 4'h0) && (debug_addr_i[31:28] != 4'h1)) ||
                          !mem_hold_flag_o);

    // tinyriscv
    wire[`PJY_INT_BUS] int_flag;

    // TASK0_REMOVE_PERIPS_BEGIN: Timer外设删除，保留原中断线声明作为注�?
    // timer0
    // wire timer0_int;
    // TASK0_REMOVE_PERIPS_END

    // TASK0_REMOVE_PERIPS_BEGIN: GPIO外设删除，保留原内部连线作为注释
    // gpio
    // wire[1:0] io_in;
    // wire[31:0] gpio_ctrl;
    // wire[31:0] gpio_data;
    // TASK0_REMOVE_PERIPS_END

    // TASK0_REMOVE_PERIPS_BEGIN: Timer外设删除后不再产生中�?
    // assign int_flag = {7'h0, timer0_int};
    assign int_flag = `PJY_INT_NONE;
    assign s2_data_i = `PJY_ZeroWord;
    assign s4_data_i = `PJY_ZeroWord;
    assign s5_data_i = `PJY_ZeroWord;
    // TASK0_REMOVE_PERIPS_END

    // 低电平点亮LED
    // 低电平表示已经halt住CPU
    assign halted_ind = ~jtag_halt_req_o;


    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~status_x26_i[0];
            succ <= ~status_x27_i[0];
        end
    end

    // tinyriscv处理器核模块例化
    pjy_tinyriscv u_tinyriscv(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_i(m0_data_o),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),

        .rib_pc_addr_o(m1_addr_i),
        .rib_pc_data_i(m1_data_o),

        .jtag_reg_addr_i(jtag_reg_addr_o),
        .jtag_reg_data_i(jtag_reg_data_o),
        .jtag_reg_we_i(jtag_reg_we_o),
        .jtag_reg_data_o(jtag_reg_data_i),

        .rib_hold_flag_i(rib_hold_flag_o),
        // TASK1_EXT_MEM_BEGIN: 片外ROM/RAM访问期间冻结流水�?
        .mem_hold_flag_i(mem_hold_flag_o),
        // TASK1_EXT_MEM_END
        .jtag_halt_flag_i(jtag_halt_req_o | uart_debug_pin),
        .jtag_reset_flag_i(jtag_reset_req_o),

        .int_i(int_flag),
        // TASK4_SID_BEGIN: Send ID extension handshake
        .sid_start_o(sid_start),
        .sid_busy_i(sid_busy),
        .sid_done_i(sid_done),
        // TASK4_SID_END
        // TASK5_RT_BEGIN
        .rt_start_o(rt_start),
        .rt_reg_waddr_o(rt_reg_waddr),
        .rt_busy_i(rt_busy),
        .rt_done_i(rt_done),
        .rt_data_i(rt_data),
        .rt_reg_we_i(rt_reg_we),
        .rt_reg_waddr_i(rt_reg_waddr_r),
        .rt_reg_wdata_i({24'h0, rt_data_r}),
        // TASK5_RT_END
        // TASK6_IF_BEGIN
        .if_start_o(if_start),
        .if_tx_data_o(if_tx_data),
        .if_reg_waddr_o(if_reg_waddr),
        .if_busy_i(if_busy),
        .if_done_i(if_done),
        .if_reg_we_i(if_reg_we),
        .if_reg_waddr_i(if_reg_waddr_r),
        .if_reg_wdata_i(`PJY_ZeroWord),
        .custom_hold_flag_i(rt_start | rt_busy | rt_done | rt_done_hold | rt_done_release |
                            if_start | if_busy | if_done | if_done_hold),
        .regfile_we_o(regfile_we_o),
        .regfile_waddr_o(regfile_waddr_o),
        .regfile_wdata_o(regfile_wdata_o),
        .regfile_raddr1_o(regfile_raddr1_o),
        .regfile_raddr2_o(regfile_raddr2_o),
        .regfile_rdata1_i(regfile_rdata1_i),
        .regfile_rdata2_i(regfile_rdata2_i)
        // TASK6_IF_END
    );

    // TASK1_EXT_MEM_BEGIN: 删除片内ROM/RAM实例，改由芯片侧桥接器访问FPGA外部存储
    // // rom模块例化
    // rom u_rom(
    //     .clk(clk),
    //     .rst(rst),
    //     .we_i(s0_we_o),
    //     .addr_i(s0_addr_o),
    //     .data_i(s0_data_o),
    //     .data_o(s0_data_i)
    // );
    //
    // // ram模块例化
    // ram u_ram(
    //     .clk(clk),
    //     .rst(rst),
    //     .we_i(s1_we_o),
    //     .addr_i(s1_addr_o),
    //     .data_i(s1_data_o),
    //     .data_o(s1_data_i)
    // );

    // Shared YC memory bridge is instantiated once in tinyriscv_4core_top.
    // Data RAM has priority over the instruction ROM request.
    assign mem_req_o = s1_req_o | s0_req_o;
    assign mem_we_o = s1_req_o ? s1_we_o : s0_we_o;
    assign mem_addr_o = s1_req_o ? {4'h1, s1_addr_o[27:0]} :
                                     {4'h0, s0_addr_o[27:0]};
    assign mem_wdata_o = s1_req_o ? s1_data_o : s0_data_o;
    assign s0_data_i = mem_rdata_i;
    assign s1_data_i = mem_rdata_i;
    assign mem_hold_flag_o = mem_hold_i;
    // TASK1_EXT_MEM_END

    // TASK0_REMOVE_PERIPS_BEGIN: 删除Timer外设实例，RIB slave2读数据固定为0
    // // timer模块例化
    // timer timer_0(
    //     .clk(clk),
    //     .rst(rst),
    //     .data_i(s2_data_o),
    //     .addr_i(s2_addr_o),
    //     .we_i(s2_we_o),
    //     .data_o(s2_data_i),
    //     .int_sig_o(timer0_int)
    // );
    // TASK0_REMOVE_PERIPS_END

    // uart模块例化
    // TASK5_RT_BEGIN: 原Temp.data�?16-word RAM下会循环写TXDATA；rT后只允许�?次温度字节输�?
    assign uart_we = (rt_uart_sent_once == `PJY_True && s3_addr_o[7:0] == 8'h0c) ? `PJY_WriteDisable : s3_we_o;
    assign uart_wdata = (rt_uart_pending == `PJY_True && s3_addr_o[7:0] == 8'h0c) ? {24'h0, rt_data_r} : s3_data_o;
    // TASK5_RT_END

    pjy_uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(uart_we),
        .addr_i(s3_addr_o),
        .data_i(uart_wdata),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin),
        // TASK4_SID_BEGIN: Send ID internal UART TX path
        .sid_tx_valid_i(sid_tx_valid),
        .sid_tx_data_i(sid_tx_data),
        // TASK6_IF_BEGIN: Integrated-and-Fire internal UART TX path
        .if_tx_valid_i(if_tx_valid),
        .if_tx_data_i(if_uart_tx_data),
        // TASK6_IF_END
        .tx_busy_o(uart_tx_busy)
        // TASK4_SID_END
    );

    // TASK4_SID_BEGIN: Send ID instruction byte sequencer
    pjy_sid_uart_sender u_sid_uart_sender(
        .clk(clk),
        .rst(rst),
        .start_i(sid_start),
        .uart_tx_busy_i(uart_tx_busy),
        .busy_o(sid_busy),
        .done_o(sid_done),
        .tx_valid_o(sid_tx_valid),
        .tx_data_o(sid_tx_data),
        .sid_index_o(sid_index)
    );
    // TASK4_SID_END

    // TASK6_IF_BEGIN: Integrated-and-Fire one-byte UART sender
    pjy_if_uart_sender u_if_uart_sender(
        .clk(clk),
        .rst(rst),
        .start_i(if_start),
        .data_i(if_tx_data),
        .uart_tx_busy_i(uart_tx_busy),
        .busy_o(if_busy),
        .done_o(if_done),
        .tx_valid_o(if_tx_valid),
        .tx_data_o(if_uart_tx_data)
    );
    // TASK6_IF_END

    // TASK5_RT_BEGIN: latch rT destination, then write back in the done cycle
    assign rt_reg_we = rt_done_hold;

    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            rt_reg_waddr_r <= `PJY_ZeroReg;
            rt_done_hold <= `PJY_False;
            rt_done_release <= `PJY_False;
            rt_data_r <= 8'h0;
            rt_uart_pending <= `PJY_False;
            rt_uart_sent_once <= `PJY_False;
        end else begin
            rt_done_hold <= rt_done;
            rt_done_release <= rt_done_hold;
            if (rt_start == `PJY_True) begin
                rt_reg_waddr_r <= rt_reg_waddr;
            end
            if (rt_done == `PJY_True) begin
                rt_data_r <= rt_data;
                if (rt_uart_sent_once == `PJY_False) begin
                    rt_uart_pending <= `PJY_True;
                end
            end
            if (s3_we_o == `PJY_WriteEnable && s3_addr_o[7:0] == 8'h0c && rt_uart_pending == `PJY_True) begin
                rt_uart_pending <= `PJY_False;
                rt_uart_sent_once <= `PJY_True;
            end
        end
    end
    // TASK5_RT_END

    // TASK6_IF_BEGIN: IF firing writes rd=0 in the same cycle the UART byte finishes
    assign if_reg_we = if_done;

    always @ (posedge clk) begin
        if (rst == `PJY_RstEnable) begin
            if_reg_waddr_r <= `PJY_ZeroReg;
            if_done_hold <= `PJY_False;
        end else begin
            if_done_hold <= if_done;
            if (if_start == `PJY_True) begin
                if_reg_waddr_r <= if_reg_waddr;
            end
        end
    end
    // TASK6_IF_END

    // TASK5_RT_BEGIN
    // TASK6_IF_BEGIN: ILA probes for rT and IF board debug
//    ila_0 u_ila_0 (
//        .clk(clk),

//        .probe0(rt_start),
//        .probe1(rt_busy),
//        .probe2(rt_done),
//        .probe3(rt_data[3:0]),
//        .probe4(if_start),
//        .probe5(rt_data),
//        .probe6(if_busy),
//        .probe7(uart_tx_pin),
//        .probe8({io_scl, io_sda, if_done, if_tx_valid}),
//        .probe9(if_tx_valid),
//        .probe10({24'h0, if_uart_tx_data}),
//        .probe11({30'h0, io_scl, io_sda})
//    );
    // TASK6_IF_END
    // TASK5_RT_END

    // TASK2_PWM_BEGIN: PWM模块例化，地�?�?0x6000_0000
    // TASK2_PWM_END

    // TASK3_I2C_BEGIN: I2C模块例化，地�?�?0x7000_0000
    pjy_i2c i2c_0(
        .clk(clk),
        .rst(rst),
        .we_i(s7_we_o),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .io_scl(io_scl),
        .io_sda_i(io_sda_i),
        .io_sda_drive_low_o(io_sda_drive_low_o),
        // TASK5_RT_BEGIN: direct rT instruction path
        .rt_start_i(rt_start),
        .rt_busy_o(rt_busy),
        .rt_done_o(rt_done),
        .rt_data_o(rt_data)
        // TASK5_RT_END
    );
    // TASK3_I2C_END

    // TASK0_REMOVE_PERIPS_BEGIN: 删除GPIO外设实例，RIB slave4读数据固定为0
    // // io0
    // assign gpio[0] = (gpio_ctrl[1:0] == 2'b01)? gpio_data[0]: 1'bz;
    // assign io_in[0] = gpio[0];
    // // io1
    // assign gpio[1] = (gpio_ctrl[3:2] == 2'b01)? gpio_data[1]: 1'bz;
    // assign io_in[1] = gpio[1];
    //
    // // gpio模块例化
    // gpio gpio_0(
    //     .clk(clk),
    //     .rst(rst),
    //     .we_i(s4_we_o),
    //     .addr_i(s4_addr_o),
    //     .data_i(s4_data_o),
    //     .data_o(s4_data_i),
    //     .io_pin_i(io_in),
    //     .reg_ctrl(gpio_ctrl),
    //     .reg_data(gpio_data)
    // );
    // TASK0_REMOVE_PERIPS_END

    // TASK0_REMOVE_PERIPS_BEGIN: 删除SPI外设实例，RIB slave5读数据固定为0
    // // spi模块例化
    // spi spi_0(
    //     .clk(clk),
    //     .rst(rst),
    //     .data_i(s5_data_o),
    //     .addr_i(s5_addr_o),
    //     .we_i(s5_we_o),
    //     .data_o(s5_data_i),
    //     .spi_mosi(spi_mosi),
    //     .spi_miso(spi_miso),
    //     .spi_ss(spi_ss),
    //     .spi_clk(spi_clk)
    // );
    // TASK0_REMOVE_PERIPS_END

    // rib模块例化
    pjy_rib u_rib(
        .clk(clk),
        .rst(rst),

        // master 0 interface
        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),

        // master 1 interface
        .m1_addr_i(m1_addr_i),
        .m1_data_i(`PJY_ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`PJY_RIB_REQ),
        .m1_we_i(`PJY_WriteDisable),

        // master 2 interface
        .m2_addr_i(m2_addr_i),
        .m2_data_i(m2_data_i),
        .m2_data_o(m2_data_o),
        .m2_req_i(m2_req_i),
        .m2_we_i(m2_we_i),

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
        // TASK1_EXT_MEM_BEGIN: ROM slave访问请求
        .s0_req_o(s0_req_o),
        // TASK1_EXT_MEM_END

        // slave 1 interface
        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        // TASK1_EXT_MEM_BEGIN: RAM slave访问请求
        .s1_req_o(s1_req_o),
        // TASK1_EXT_MEM_END

        // slave 2 interface
        .s2_addr_o(s2_addr_o),
        .s2_data_o(s2_data_o),
        .s2_data_i(s2_data_i),
        .s2_we_o(s2_we_o),

        // slave 3 interface
        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        // slave 4 interface
        .s4_addr_o(s4_addr_o),
        .s4_data_o(s4_data_o),
        .s4_data_i(s4_data_i),
        .s4_we_o(s4_we_o),

        // slave 5 interface
        .s5_addr_o(s5_addr_o),
        .s5_data_o(s5_data_o),
        .s5_data_i(s5_data_i),
        .s5_we_o(s5_we_o),

        // TASK2_PWM_BEGIN: PWM slave6 interface
        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),
        // TASK2_PWM_END

        // TASK3_I2C_BEGIN: I2C slave7 interface
        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),
        // TASK3_I2C_END

        .hold_flag_o(rib_hold_flag_o)
    );

endmodule
