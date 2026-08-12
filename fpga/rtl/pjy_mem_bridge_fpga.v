`include "pjy_defines.vh"
module pjy_mem_bridge_fpga(
 input wire clk,input wire rst,input wire[7:0] ext_mem_data_i,
 output reg[7:0] ext_mem_data_o,
 output reg rom_we_o,output reg[7:0] rom_addr_o,
 output reg[31:0] rom_data_o,input wire[31:0] rom_data_i,
 output reg ram_we_o,output reg[3:0] ram_addr_o,
 output reg[31:0] ram_data_o,input wire[31:0] ram_data_i);
 localparam RR=8'ha0,AR=8'ha1,AW=8'ha2,RW=8'ha3;
 localparam I=3'd0,A=3'd1,D0=3'd2,D1=3'd3,D2=3'd4,D3=3'd5,W=3'd6;
 reg[2:0] state;reg[7:0]cmd;reg[31:0]wdata;
 wire is_rom=(cmd==RR)||(cmd==RW);wire is_read=(cmd==RR)||(cmd==AR);
 wire[31:0]rdata=is_rom?rom_data_i:ram_data_i;
 always @(*) case(state) D0:ext_mem_data_o=is_read?rdata[7:0]:0;
  D1:ext_mem_data_o=is_read?rdata[15:8]:0;D2:ext_mem_data_o=is_read?rdata[23:16]:0;
  D3:ext_mem_data_o=is_read?rdata[31:24]:0;default:ext_mem_data_o=0;endcase
 always @(negedge clk) begin
  if(rst==`PJY_RstEnable)begin state<=I;cmd<=0;wdata<=0;rom_we_o<=0;rom_addr_o<=0;
   rom_data_o<=0;ram_we_o<=0;ram_addr_o<=0;ram_data_o<=0;end else begin
   rom_we_o<=0;ram_we_o<=0;
   case(state)
    I:if(ext_mem_data_i==RR||ext_mem_data_i==AR||ext_mem_data_i==AW||ext_mem_data_i==RW)begin cmd<=ext_mem_data_i;state<=A;end
    A:begin if(ext_mem_data_i==ext_mem_data_i)begin
      if(cmd==RR||cmd==RW)rom_addr_o<=ext_mem_data_i;else ram_addr_o<=ext_mem_data_i[3:0];state<=D0;end end
    D0:begin wdata[7:0]<=ext_mem_data_i;state<=D1;end
    D1:begin wdata[15:8]<=ext_mem_data_i;state<=D2;end
    D2:begin wdata[23:16]<=ext_mem_data_i;state<=D3;end
    D3:begin wdata[31:24]<=ext_mem_data_i;state<=is_read?I:W;end
    W:begin if(cmd==RW)begin rom_data_o<=wdata;rom_we_o<=1;end
      else if(cmd==AW)begin ram_data_o<=wdata;ram_we_o<=1;end state<=I;end
    default:state<=I;
   endcase
  end
 end
endmodule
