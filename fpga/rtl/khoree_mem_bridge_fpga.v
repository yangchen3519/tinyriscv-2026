`include "khoree_defines.vh"
module khoree_mem_bridge_fpga(
 input wire clk,input wire rst,
 input wire[7:0] c2f_data_i,input wire c2f_valid_i,output reg c2f_ready_o,
 output reg[7:0] f2c_data_o,output reg f2c_valid_o,input wire f2c_ready_i,
 output reg rom_we_o,output reg[7:0] rom_addr_o,
 output reg[31:0] rom_data_o,input wire[31:0] rom_data_i,
 output reg ram_we_o,output reg[3:0] ram_addr_o,
 output reg[31:0] ram_data_o,input wire[31:0] ram_data_i);
 localparam RR=8'h01,AR=8'h02,AW=8'h03,RW=8'h04,OK=8'ha5;
 localparam I=3'd0,R=3'd1,M=3'd2,A=3'd3,L=3'd4,S=3'd5;
 reg[2:0]state;reg[3:0]rx_index,rx_len;reg[2:0]tx_index;
 reg[7:0]cmd;reg[31:0]addr,wdata,rdata;
 wire write_packet=(cmd==RW)||(cmd==AW);
 always @(*) begin
  if(write_packet)f2c_data_o=OK;else case(tx_index)
   0:f2c_data_o=rdata[31:24];1:f2c_data_o=rdata[23:16];
   2:f2c_data_o=rdata[15:8];default:f2c_data_o=rdata[7:0];endcase
 end
 always @(posedge clk)begin
  if(rst==`KHOREE_RstEnable)begin state<=I;rx_index<=0;rx_len<=5;tx_index<=0;
   cmd<=RR;addr<=0;wdata<=0;rdata<=0;c2f_ready_o<=1;f2c_valid_o<=0;
   rom_we_o<=0;ram_we_o<=0;rom_addr_o<=0;ram_addr_o<=0;rom_data_o<=0;ram_data_o<=0;
  end else begin
   f2c_valid_o<=0;c2f_ready_o<=(state==I||state==R);rom_we_o<=0;ram_we_o<=0;
   case(state)
    I:begin rx_index<=0;tx_index<=0;if(c2f_valid_i)begin cmd<=c2f_data_i;
      rx_len<=(c2f_data_i==RW||c2f_data_i==AW)?9:5;addr<=0;wdata<=0;rx_index<=1;state<=R;end end
    R:if(c2f_valid_i)begin case(rx_index)1:addr[31:24]<=c2f_data_i;
      2:addr[23:16]<=c2f_data_i;3:addr[15:8]<=c2f_data_i;4:addr[7:0]<=c2f_data_i;
      5:wdata[31:24]<=c2f_data_i;6:wdata[23:16]<=c2f_data_i;
      7:wdata[15:8]<=c2f_data_i;8:wdata[7:0]<=c2f_data_i;endcase
      if(rx_index==rx_len-1)state<=M;else rx_index<=rx_index+1'b1;end
    M:begin rom_addr_o<=addr[9:2];ram_addr_o<=addr[5:2];rom_data_o<=wdata;ram_data_o<=wdata;state<=A;end
    A:begin if(cmd==RW)rom_we_o<=1;else if(cmd==AW)ram_we_o<=1;state<=L;end
    L:begin if(cmd==RR)rdata<=rom_data_i;else if(cmd==AR)rdata<=ram_data_i;else rdata<=0;state<=S;end
    S:begin f2c_valid_o<=1;if(f2c_valid_o&&f2c_ready_i)begin
      if(write_packet||tx_index==3)begin state<=I;tx_index<=0;end else tx_index<=tx_index+1'b1;end end
    default:state<=I;
   endcase
  end
 end
endmodule
