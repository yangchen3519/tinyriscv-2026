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
    reg[2:0] write_word_index;

    // Only packet bytes 1..32 are written to memory.  Store them as a
    // sequential shift queue instead of a randomly indexed 35-byte array.
    // This removes the large read multiplexers and write decoder that the
    // variable array indices otherwise synthesize into.
    reg[255:0] payload_shift;
    reg[7:0] packet_crc_lo;
    reg[7:0] packet_crc_hi;

    reg[15:0] crc_result;

    function [15:0] crc16_next_byte;
        input [15:0] crc_in;
        input [7:0] data_in;
        integer bit_index;
        reg [15:0] crc_work;
        begin
            crc_work = crc_in ^ data_in;
            for (bit_index = 0; bit_index < 8; bit_index = bit_index + 1) begin
                if (crc_work[0] == 1'b1)
                    crc_work = {1'b0, crc_work[15:1]} ^ 16'ha001;
                else
                    crc_work = {1'b0, crc_work[15:1]};
            end
            crc16_next_byte = crc_work;
        end
    endfunction

    wire uart_rx_ready = ((mem_rdata_i & `UART_RX_OVER_FLAG) == `UART_RX_OVER_FLAG);
    wire write_word_is_last = (write_word_index == 3'd7);

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
                    // CRC is accumulated while the 32 payload bytes arrive.
                    state <= S_CRC_END;
                end
                S_CRC_END: begin
                    if (crc_result == {packet_crc_hi, packet_crc_lo}) begin
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
                    mem_wdata_o <= payload_shift[31:0];
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

    // Receive packet data.  Bytes 1..32 are shifted into a word queue whose
    // low word is {byte4,byte3,byte2,byte1}; bytes 33/34 carry the CRC.
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            rec_bytes_index <= 8'h0;
            payload_shift <= 256'h0;
            packet_crc_lo <= 8'h0;
            packet_crc_hi <= 8'h0;
            write_word_index <= 3'h0;
        end else begin
            case (state)
                S_REC_FIRST_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    payload_shift <= 256'h0;
                    packet_crc_lo <= 8'h0;
                    packet_crc_hi <= 8'h0;
                    write_word_index <= 3'h0;
                end
                S_REC_REMAIN_PACKET: begin
                    rec_bytes_index <= 8'h0;
                    payload_shift <= 256'h0;
                    packet_crc_lo <= 8'h0;
                    packet_crc_hi <= 8'h0;
                    write_word_index <= 3'h0;
                end
                S_READ_UART_RX_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        if ((rec_bytes_index >= 8'd1) && (rec_bytes_index <= 8'd32))
                            payload_shift <= {mem_rdata_i[7:0], payload_shift[255:8]};
                        else if (rec_bytes_index == 8'd33)
                            packet_crc_lo <= mem_rdata_i[7:0];
                        else if (rec_bytes_index == 8'd34)
                            packet_crc_hi <= mem_rdata_i[7:0];
                        rec_bytes_index <= rec_bytes_index + 1'b1;
                    end
                end
                S_WRITE_MEM_WAIT: begin
                    if (mem_ack_i == 1'b1) begin
                        payload_shift <= {32'h0, payload_shift[255:32]};
                        write_word_index <= write_word_index + 1'b1;
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
            if (state == S_REC_FIRST_PACKET) begin
                fw_file_size <= 32'h0;
            end else if ((state == S_READ_UART_RX_WAIT) && (mem_ack_i == 1'b1)) begin
                case (rec_bytes_index)
                    8'd25: fw_file_size[31:24] <= mem_rdata_i[7:0];
                    8'd26: fw_file_size[23:16] <= mem_rdata_i[7:0];
                    8'd27: fw_file_size[15:8] <= mem_rdata_i[7:0];
                    8'd28: fw_file_size[7:0] <= mem_rdata_i[7:0];
                endcase
            end
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

    // Calculate the packet CRC while bytes 1..32 are accepted.  This avoids
    // rereading the whole packet through a 35:1 byte multiplexer.
    always @ (posedge clk) begin
        if (rst == 1'b0 || debug_en_i == 1'b0) begin
            crc_result <= 16'h0;
        end else begin
            if ((state == S_REC_FIRST_PACKET) || (state == S_REC_REMAIN_PACKET)) begin
                crc_result <= 16'hffff;
            end else if ((state == S_READ_UART_RX_WAIT) && (mem_ack_i == 1'b1) &&
                         (rec_bytes_index >= 8'd1) && (rec_bytes_index <= 8'd32)) begin
                crc_result <= crc16_next_byte(crc_result, mem_rdata_i[7:0]);
            end
        end
    end

endmodule
