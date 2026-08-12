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


// clk = 50MHz时对应的波特率分频系数
`define UART_BAUD_115200        32'h1B8

// 串口寄存器地址
`define UART_CTRL_REG           32'h30000000
`define UART_STATUS_REG         32'h30000004
`define UART_BAUD_REG           32'h30000008
`define UART_TX_REG             32'h3000000c
`define UART_RX_REG             32'h30000010

`define UART_TX_BUSY_FLAG       32'h1
`define UART_RX_OVER_FLAG       32'h2

// 第一个包的大小
`define UART_FIRST_PACKET_LEN   8'd35
// 其他包的大小(每次烧写的字节数)
`define UART_REMAIN_PACKET_LEN  8'd35

`define UART_RESP_ACK           32'h6
`define UART_RESP_NAK           32'h15

// 烧写起始地址
`define ROM_START_ADDR          32'h0


// 串口更新固件模块
module yc_uart_debug(

    input wire clk,                // 时钟信号
    input wire rst,                // 复位信号

    input wire debug_en_i,         // 模块使能信号

    output wire req_o,
    output reg mem_we_o,
    output reg[31:0] mem_addr_o,
    output reg[31:0] mem_wdata_o,
    input wire mem_ack_i,
    input wire[31:0] mem_rdata_i

    );


    // 状态
    localparam [4:0] S_IDLE                    = 5'd0;
    localparam [4:0] S_INIT_UART_CTRL_REQ      = 5'd1;
    localparam [4:0] S_INIT_UART_CTRL_WAIT     = 5'd2;
    localparam [4:0] S_INIT_UART_BAUD_REQ      = 5'd3;
    localparam [4:0] S_INIT_UART_BAUD_WAIT     = 5'd4;
    localparam [4:0] S_REC_FIRST_PACKET        = 5'd5;
    localparam [4:0] S_REC_REMAIN_PACKET       = 5'd6;
    localparam [4:0] S_CLEAR_UART_RX_OVER_REQ  = 5'd7;
    localparam [4:0] S_CLEAR_UART_RX_OVER_WAIT = 5'd8;
    localparam [4:0] S_READ_UART_STATUS_REQ    = 5'd9;
    localparam [4:0] S_READ_UART_STATUS_WAIT   = 5'd10;
    localparam [4:0] S_READ_UART_RX_REQ        = 5'd11;
    localparam [4:0] S_READ_UART_RX_WAIT       = 5'd12;
    localparam [4:0] S_CRC_START               = 5'd13;
    localparam [4:0] S_CRC_CALC                = 5'd14;
    localparam [4:0] S_CRC_END                 = 5'd15;
    localparam [4:0] S_WRITE_MEM_REQ           = 5'd16;
    localparam [4:0] S_WRITE_MEM_WAIT          = 5'd17;
    localparam [4:0] S_SEND_ACK_REQ            = 5'd18;
    localparam [4:0] S_SEND_ACK_WAIT           = 5'd19;
    localparam [4:0] S_SEND_NAK_REQ            = 5'd20;
    localparam [4:0] S_SEND_NAK_WAIT           = 5'd21;

    reg[4:0] state;
    reg mem_req_r;

    // 存放串口接收到的数据
    reg[7:0] rec_bytes_index;
    reg[7:0] need_to_rec_bytes;
    reg[15:0] remain_packet_count;
    reg[31:0] fw_file_size;
    reg[31:0] write_mem_addr;
    reg[31:0] write_mem_data;
    reg[7:0] write_mem_byte_index0;
    reg[7:0] write_mem_byte_index1;
    reg[7:0] write_mem_byte_index2;
    reg[7:0] write_mem_byte_index3;

    reg[7:0] rx_data[0:34];

    reg[15:0] crc_result;
    reg[3:0] crc_bit_index;
    reg[7:0] crc_byte_index;

    wire uart_rx_ready = ((mem_rdata_i & `UART_RX_OVER_FLAG) == `UART_RX_OVER_FLAG);
    wire write_word_is_last = (write_mem_byte_index0 == (need_to_rec_bytes - 2));

    // 向总线请求信号
    assign req_o = mem_req_r;


    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            mem_req_r <= 1'b0;
            mem_addr_o <= 32'h0;
            mem_we_o <= 1'b0;
            mem_wdata_o <= 32'h0;
            state <= S_IDLE;
            remain_packet_count <= 16'h0;
        end else begin
            case (state)
                S_IDLE: begin
                    mem_req_r <= 1'b0;
                    mem_addr_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_INIT_UART_CTRL_REQ;
                end
                S_INIT_UART_CTRL_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_CTRL_REG;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= 32'h3;
                    state <= S_INIT_UART_CTRL_WAIT;
                end
                S_INIT_UART_CTRL_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        state <= S_INIT_UART_BAUD_REQ;
                    end
                end
                S_INIT_UART_BAUD_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_BAUD_REG;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= `UART_BAUD_115200;
                    state <= S_INIT_UART_BAUD_WAIT;
                end
                S_INIT_UART_BAUD_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        state <= S_REC_FIRST_PACKET;
                    end
                end
                S_REC_FIRST_PACKET: begin
                    remain_packet_count <= 16'h0;
                    mem_req_r <= 1'b0;
                    mem_addr_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_CLEAR_UART_RX_OVER_REQ;
                end
                S_REC_REMAIN_PACKET: begin
                    mem_req_r <= 1'b0;
                    mem_addr_o <= 32'h0;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_CLEAR_UART_RX_OVER_REQ;
                end
                S_CLEAR_UART_RX_OVER_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_STATUS_REG;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= 32'h0;
                    state <= S_CLEAR_UART_RX_OVER_WAIT;
                end
                S_CLEAR_UART_RX_OVER_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        state <= S_READ_UART_STATUS_REQ;
                    end
                end
                S_READ_UART_STATUS_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_STATUS_REG;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_READ_UART_STATUS_WAIT;
                end
                S_READ_UART_STATUS_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        if (uart_rx_ready) begin
                            state <= S_READ_UART_RX_REQ;
                        end else begin
                            state <= S_READ_UART_STATUS_REQ;
                        end
                    end
                end
                S_READ_UART_RX_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_RX_REG;
                    mem_we_o <= 1'b0;
                    mem_wdata_o <= 32'h0;
                    state <= S_READ_UART_RX_WAIT;
                end
                S_READ_UART_RX_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        if (rec_bytes_index == (need_to_rec_bytes - 1'b1)) begin
                            state <= S_CRC_START;
                        end else begin
                            state <= S_CLEAR_UART_RX_OVER_REQ;
                        end
                    end
                end
                S_CRC_START: begin
                    state <= S_CRC_CALC;
                end
                S_CRC_CALC: begin
                    if ((crc_byte_index == need_to_rec_bytes - 2) && crc_bit_index == 4'h8) begin
                        state <= S_CRC_END;
                    end
                end
                S_CRC_END: begin
                    if (crc_result == {rx_data[need_to_rec_bytes - 1], rx_data[need_to_rec_bytes - 2]}) begin
                        if (need_to_rec_bytes == `UART_FIRST_PACKET_LEN && remain_packet_count == 16'h0) begin
                            remain_packet_count <= (fw_file_size >> 5) + 1'b1;
                            state <= S_SEND_ACK_REQ;
                        end else begin
                            remain_packet_count <= remain_packet_count - 1'b1;
                            state <= S_WRITE_MEM_REQ;
                        end
                    end else begin
                        state <= S_SEND_NAK_REQ;
                    end
                end
                S_WRITE_MEM_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= write_mem_addr;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= write_mem_data;
                    state <= S_WRITE_MEM_WAIT;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        if (write_word_is_last) begin
                            state <= S_SEND_ACK_REQ;
                        end else begin
                            state <= S_WRITE_MEM_REQ;
                        end
                    end
                end
                S_SEND_ACK_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_TX_REG;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= `UART_RESP_ACK;
                    state <= S_SEND_ACK_WAIT;
                end
                S_SEND_ACK_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        if (remain_packet_count > 0) begin
                            state <= S_REC_REMAIN_PACKET;
                        end else begin
                            state <= S_REC_FIRST_PACKET;
                        end
                    end
                end
                S_SEND_NAK_REQ: begin
                    mem_req_r <= 1'b1;
                    mem_addr_o <= `UART_TX_REG;
                    mem_we_o <= 1'b1;
                    mem_wdata_o <= `UART_RESP_NAK;
                    state <= S_SEND_NAK_WAIT;
                end
                S_SEND_NAK_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        mem_req_r <= 1'b0;
                        mem_we_o <= 1'b0;
                        if (remain_packet_count > 0) begin
                            state <= S_REC_REMAIN_PACKET;
                        end else begin
                            state <= S_REC_FIRST_PACKET;
                        end
                    end
                end
                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

    // 数据包的大小
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            need_to_rec_bytes <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    need_to_rec_bytes <= `UART_FIRST_PACKET_LEN;
                end
                S_REC_REMAIN_PACKET: begin
                    need_to_rec_bytes <= `UART_REMAIN_PACKET_LEN;
                end
            endcase
        end
    end

    // 读取接收到的串口数据
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            rec_bytes_index <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    rec_bytes_index <= 8'h0;
                end
                S_REC_REMAIN_PACKET: begin
                    rec_bytes_index <= 8'h0;
                end
                S_READ_UART_RX_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        rx_data[rec_bytes_index] <= mem_rdata_i[7:0];
                        rec_bytes_index <= rec_bytes_index + 1'b1;
                    end
                end
            endcase
        end
    end

    // 固件大小
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            fw_file_size <= 32'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    fw_file_size <= {rx_data[25], rx_data[26], rx_data[27], rx_data[28]};
                end
            endcase
        end
    end

    // 烧写固件
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_addr <= 32'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_addr <= `ROM_START_ADDR;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_addr <= write_mem_addr + 4;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_data <= 32'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_data <= 32'h0;
                end
                S_CRC_END: begin
                    write_mem_data <= {rx_data[4], rx_data[3], rx_data[2], rx_data[1]};
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_data <= {rx_data[write_mem_byte_index3], rx_data[write_mem_byte_index2], rx_data[write_mem_byte_index1], rx_data[write_mem_byte_index0]};
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index0 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index0 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index0 <= 8'h5;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_byte_index0 <= write_mem_byte_index0 + 4;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index1 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index1 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index1 <= 8'h6;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_byte_index1 <= write_mem_byte_index1 + 4;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index2 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index2 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index2 <= 8'h7;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_byte_index2 <= write_mem_byte_index2 + 4;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            write_mem_byte_index3 <= 8'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    write_mem_byte_index3 <= 8'h0;
                end
                S_CRC_END: begin
                    write_mem_byte_index3 <= 8'h8;
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        write_mem_byte_index3 <= write_mem_byte_index3 + 4;
                    end
                end
            endcase
        end
    end

    // CRC计算
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_result <= 16'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_result <= 16'hffff;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index == 4'h0) begin
                        crc_result <= crc_result ^ rx_data[crc_byte_index];
                    end else begin
                        if (crc_bit_index < 4'h9) begin
                            if (crc_result[0] == 1'b1) begin
                                crc_result <= {1'b0, crc_result[15:1]} ^ 16'ha001;
                            end else begin
                                crc_result <= {1'b0, crc_result[15:1]};
                            end
                        end
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_bit_index <= 4'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_bit_index <= 4'h0;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index < 4'h9) begin
                        crc_bit_index <= crc_bit_index + 1'b1;
                    end else begin
                        crc_bit_index <= 4'h0;
                    end
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_byte_index <= 8'h0;
        end else begin
            case (state)
                S_CRC_START: begin
                    crc_byte_index <= 8'h1;
                end
                S_CRC_CALC: begin
                    if (crc_bit_index == 4'h0) begin
                        crc_byte_index <= crc_byte_index + 1'b1;
                    end
                end
            endcase
        end
    end

endmodule
