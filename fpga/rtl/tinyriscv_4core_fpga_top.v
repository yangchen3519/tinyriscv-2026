`timescale 1ns/1ps
`include "yc_defines.vh"

// FPGA/simulation-only wrapper.  The chip contains four private chip-side
// bridges; their matching FPGA protocol decoders arbitrate one YC ROM/RAM.
module tinyriscv_4core_fpga_top(
 input wire clk,input wire rst,input wire[2:0]chip_sel,
 input wire uart_debug_en,input wire uart_rx,output wire uart_tx,
 output wire[3:0]PWM_o,inout wire i2c_scl,inout wire i2c_sda,
 output wire over,output wire succ);
 localparam YC=3'b000,YX=3'b001,PJY=3'b010,KH=3'b011;
 reg[2:0]selected;
 always @(posedge clk)if(!rst)selected<=chip_sel;
 wire syc=selected==YC,syx=selected==YX,spjy=selected==PJY,skh=selected==KH;
 wire[7:0]chip_out,chip_in;
 wire chip_valid,chip_ready,chip_rx_valid,chip_rx_ready;

 wire yc_rwe,yc_awe,yx_rwe,yx_awe,pj_rwe,pj_awe,kh_rwe,kh_awe;
 wire[7:0]yc_ra,yx_ra,pj_ra,kh_ra; wire[3:0]yc_aa,yx_aa,pj_aa,kh_aa;
 wire[31:0]yc_rd,yc_ad,yx_rd,yx_ad,pj_rd,pj_ad,kh_rd,kh_ad;
 wire[31:0]rom_rdata,ram_rdata; wire rom_we,ram_we;
 wire[7:0]rom_addr;wire[3:0]ram_addr;wire[31:0]rom_wdata,ram_wdata;

 tinyriscv_4core_top u_chip(.clk(clk),.rst(rst),.chip_sel(chip_sel),
  .uart_debug_en(uart_debug_en),.uart_rx(uart_rx),.uart_tx(uart_tx),
  .PWM_o(PWM_o),.i2c_scl(i2c_scl),.i2c_sda(i2c_sda),
  .ext_mem_data_i(chip_in),.ext_mem_data_o(chip_out),
  .ext_mem_tx_valid_o(chip_valid),.ext_mem_tx_ready_i(chip_ready),
  .ext_mem_rx_valid_i(chip_rx_valid),.ext_mem_rx_ready_o(chip_rx_ready),
  .over(over),.succ(succ));

 wire[7:0]yc_back,yx_back,pj_back,kh_back;wire kh_ready,kh_back_valid;
 wire yc_back_valid;
 yc_bridge_FPGA u_yc_bridge_fpga(.clk(clk),.rst(rst&syc),
  .rx_valid_i(chip_valid&syc),.rx_data_i(chip_out),.tx_data_o(yc_back),
  .tx_valid_o(yc_back_valid),.rom_we_o(yc_rwe),.rom_addr_o(yc_ra),
  .rom_data_o(yc_rd),.rom_data_i(rom_rdata),.ram_we_o(yc_awe),
  .ram_addr_o(yc_aa),.ram_data_o(yc_ad),.ram_data_i(ram_rdata));
 yx_fpga_bridge u_yx_bridge_fpga(.clk(clk),.rst(rst&syx),
  .fpga_o(yx_back),.fpga_i(chip_out),.rom_we_o(yx_rwe),.rom_addr_o(yx_ra),
  .rom_data_o(yx_rd),.rom_data_i(rom_rdata),.ram_we_o(yx_awe),
  .ram_addr_o(yx_aa),.ram_data_o(yx_ad),.ram_data_i(ram_rdata));
 pjy_mem_bridge_fpga u_pjy_bridge_fpga(.clk(clk),.rst(rst&spjy),
  .ext_mem_data_i(chip_out),.ext_mem_data_o(pj_back),
  .rom_we_o(pj_rwe),.rom_addr_o(pj_ra),.rom_data_o(pj_rd),.rom_data_i(rom_rdata),
  .ram_we_o(pj_awe),.ram_addr_o(pj_aa),.ram_data_o(pj_ad),.ram_data_i(ram_rdata));
 khoree_mem_bridge_fpga u_kh_bridge_fpga(.clk(clk),.rst(rst&skh),
  .c2f_data_i(chip_out),.c2f_valid_i(chip_valid&skh),.c2f_ready_o(kh_ready),
  .f2c_data_o(kh_back),.f2c_valid_o(kh_back_valid),.f2c_ready_i(chip_rx_ready),
  .rom_we_o(kh_rwe),.rom_addr_o(kh_ra),.rom_data_o(kh_rd),.rom_data_i(rom_rdata),
  .ram_we_o(kh_awe),.ram_addr_o(kh_aa),.ram_data_o(kh_ad),.ram_data_i(ram_rdata));

 assign chip_in=syc?yc_back:syx?yx_back:spjy?pj_back:skh?kh_back:8'b0;
 assign chip_ready=skh?kh_ready:1'b1;
 assign chip_rx_valid=skh?kh_back_valid:1'b0;
 assign rom_we=syc?yc_rwe:syx?yx_rwe:spjy?pj_rwe:skh?kh_rwe:1'b0;
 assign rom_addr=syc?yc_ra:syx?yx_ra:spjy?pj_ra:skh?kh_ra:8'b0;
 assign rom_wdata=syc?yc_rd:syx?yx_rd:spjy?pj_rd:skh?kh_rd:32'b0;
 assign ram_we=syc?yc_awe:syx?yx_awe:spjy?pj_awe:skh?kh_awe:1'b0;
 assign ram_addr=syc?yc_aa:syx?yx_aa:spjy?pj_aa:skh?kh_aa:4'b0;
 assign ram_wdata=syc?yc_ad:syx?yx_ad:spjy?pj_ad:skh?kh_ad:32'b0;

 yc_rom u_rom(.clk(clk),.rst(rst),.we_i(rom_we),.addr_i(rom_addr),
  .data_i(rom_wdata),.data_o(rom_rdata));
 yc_ram u_ram(.clk(clk),.rst(rst),.we_i(ram_we),.addr_i(ram_addr),
  .data_i(ram_wdata),.data_o(ram_rdata));
endmodule
