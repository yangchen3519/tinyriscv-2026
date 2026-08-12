`include "yx_defines.vh"

module yx_fpga_bridge(
    input wire clk, input wire rst,
    output reg [7:0] fpga_o, input wire [7:0] fpga_i,
    output wire rom_we_o, output wire [7:0] rom_addr_o,
    output wire [31:0] rom_data_o, input wire [31:0] rom_data_i,
    output wire ram_we_o, output wire [3:0] ram_addr_o,
    output wire [31:0] ram_data_o, input wire [31:0] ram_data_i
);
    localparam IDLE=5'd0, RD_A3=5'd1, RD_A2=5'd2, RD_A1=5'd3,
      RD_A0=5'd4, RD_M1=5'd5, RD_M2=5'd6, RD_D3=5'd7,
      RD_D2=5'd8, RD_D1=5'd9, RD_D0=5'd10, WR_A3=5'd11,
      WR_A2=5'd12, WR_A1=5'd13, WR_A0=5'd14, WR_D3=5'd15,
      WR_D2=5'd16, WR_D1=5'd17, WR_D0=5'd18, WR_MEM=5'd19;
    reg [4:0] state;
    reg [31:0] addr_reg, data_reg;
    wire is_ram=(addr_reg[31:28]==4'h1)||(addr_reg[31:28]==4'hf);
    assign rom_we_o=(state==WR_MEM)&&(addr_reg[31:28]==4'h0);
    assign ram_we_o=(state==WR_MEM)&&is_ram;
    assign rom_addr_o=addr_reg[9:2];
    assign ram_addr_o=addr_reg[5:2];
    assign rom_data_o=data_reg;
    assign ram_data_o=data_reg;
    always @(posedge clk) begin
      if(rst==`YX_RstEnable) begin state<=IDLE;fpga_o<=0;addr_reg<=0;data_reg<=0;end
      else case(state)
        IDLE:begin fpga_o<=0;if(fpga_i==8'haa)state<=RD_A3;else if(fpga_i==8'h55)state<=WR_A3;end
        RD_A3:begin addr_reg[31:24]<=fpga_i;state<=RD_A2;end
        RD_A2:begin addr_reg[23:16]<=fpga_i;state<=RD_A1;end
        RD_A1:begin addr_reg[15:8]<=fpga_i;state<=RD_A0;end
        RD_A0:begin addr_reg[7:0]<=fpga_i;state<=RD_M1;end
        RD_M1:state<=RD_M2;
        RD_M2:begin fpga_o<=is_ram?ram_data_i[31:24]:rom_data_i[31:24];state<=RD_D3;end
        RD_D3:begin fpga_o<=is_ram?ram_data_i[23:16]:rom_data_i[23:16];state<=RD_D2;end
        RD_D2:begin fpga_o<=is_ram?ram_data_i[15:8]:rom_data_i[15:8];state<=RD_D1;end
        RD_D1:begin fpga_o<=is_ram?ram_data_i[7:0]:rom_data_i[7:0];state<=RD_D0;end
        RD_D0:state<=IDLE;
        WR_A3:begin addr_reg[31:24]<=fpga_i;state<=WR_A2;end
        WR_A2:begin addr_reg[23:16]<=fpga_i;state<=WR_A1;end
        WR_A1:begin addr_reg[15:8]<=fpga_i;state<=WR_A0;end
        WR_A0:begin addr_reg[7:0]<=fpga_i;state<=WR_D3;end
        WR_D3:begin data_reg[31:24]<=fpga_i;state<=WR_D2;end
        WR_D2:begin data_reg[23:16]<=fpga_i;state<=WR_D1;end
        WR_D1:begin data_reg[15:8]<=fpga_i;state<=WR_D0;end
        WR_D0:begin data_reg[7:0]<=fpga_i;state<=WR_MEM;end
        WR_MEM:state<=IDLE;
        default:state<=IDLE;
      endcase
    end
endmodule
