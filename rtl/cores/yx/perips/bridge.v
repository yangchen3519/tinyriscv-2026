`include "yx_defines.vh"

// YX private chip-side 8-bit memory bridge.  This is the protocol used by
// the original YX submission; ROM/RAM storage remains outside the chip.
module yx_bridge(
    input  wire        clk,
    input  wire        rst,
    input  wire        req_i,
    input  wire        we_i,
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,
    input  wire [7:0]  fpga_i,
    output reg  [7:0]  fpga_o,
    output wire        bridge_hold
);
    localparam IDLE=5'd0, RD_HDR=5'd1, RD_A3=5'd2, RD_A2=5'd3,
               RD_A1=5'd4, RD_A0=5'd5, RD_W1=5'd6, RD_W2=5'd7,
               RD_D3=5'd9, RD_D2=5'd10, RD_D1=5'd11, RD_D0=5'd12,
               WR_HDR=5'd13, WR_A3=5'd14, WR_A2=5'd15,
               WR_A1=5'd16, WR_A0=5'd17, WR_D3=5'd18,
               WR_D2=5'd19, WR_D1=5'd20, WR_D0=5'd21,
               WR_WAIT=5'd22, DONE=5'd23;

    reg [4:0] state;
    reg [31:0] curr_addr;
    reg [31:0] latch_data_w;
    reg latch_we;
    reg req_d;
    // All operands are reset flops or primary request inputs in hardware, so
    // ordinary two-state comparisons preserve the intended edge/address
    // detection while remaining synthesizable by Design Compiler.
    wire trigger = req_i && ((req_d == 1'b0) || (addr_i != curr_addr));
    assign bridge_hold = (state != IDLE) || (state == IDLE && trigger);

    always @(posedge clk) begin
        if (rst == `YX_RstEnable) begin
            state <= IDLE;
            curr_addr <= 32'hffff_ffff;
            latch_data_w <= 32'b0;
            latch_we <= 1'b0;
            data_o <= 32'b0;
            fpga_o <= 8'b0;
            req_d <= 1'b0;
        end else begin
            req_d <= req_i;
            case (state)
                IDLE: if (trigger) begin
                    curr_addr <= addr_i;
                    latch_data_w <= data_i;
                    latch_we <= we_i;
                    fpga_o <= 8'haa;
                    state <= RD_HDR;
                end
                RD_HDR: begin fpga_o<=curr_addr[31:24]; state<=RD_A3; end
                RD_A3:  begin fpga_o<=curr_addr[23:16]; state<=RD_A2; end
                RD_A2:  begin fpga_o<=curr_addr[15:8];  state<=RD_A1; end
                RD_A1:  begin fpga_o<=curr_addr[7:0];   state<=RD_A0; end
                RD_A0:  begin fpga_o<=8'b0; state<=RD_W1; end
                RD_W1:  state<=RD_W2;
                RD_W2:  state<=RD_D3;
                RD_D3:  begin data_o[31:24]<=fpga_i; state<=RD_D2; end
                RD_D2:  begin data_o[23:16]<=fpga_i; state<=RD_D1; end
                RD_D1:  begin data_o[15:8] <=fpga_i; state<=RD_D0; end
                RD_D0: begin
                    data_o[7:0] <= fpga_i;
                    if (latch_we) begin fpga_o<=8'h55; state<=WR_HDR; end
                    else state<=DONE;
                end
                WR_HDR: begin fpga_o<=curr_addr[31:24]; state<=WR_A3; end
                WR_A3:  begin fpga_o<=curr_addr[23:16]; state<=WR_A2; end
                WR_A2:  begin fpga_o<=curr_addr[15:8];  state<=WR_A1; end
                WR_A1:  begin fpga_o<=curr_addr[7:0];   state<=WR_A0; end
                WR_A0:  begin fpga_o<=latch_data_w[31:24]; state<=WR_D3; end
                WR_D3:  begin fpga_o<=latch_data_w[23:16]; state<=WR_D2; end
                WR_D2:  begin fpga_o<=latch_data_w[15:8];  state<=WR_D1; end
                WR_D1:  begin fpga_o<=latch_data_w[7:0];   state<=WR_D0; end
                WR_D0:  begin fpga_o<=8'b0; state<=WR_WAIT; end
                WR_WAIT: begin data_o<=latch_data_w; state<=DONE; end
                DONE: state<=IDLE;
                default: state<=IDLE;
            endcase
        end
    end
endmodule
