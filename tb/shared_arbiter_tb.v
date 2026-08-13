`timescale 1ns/1ps

module shared_arbiter_tb;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/shared_arbiter.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,shared_arbiter_tb);
    end
`endif
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg [1:0] chip_sel = 2'b00;
    reg uart_debug_en = 1'b0;
    reg uart_rx = 1'b1;
    reg [7:0] ext_mem_data_i = 8'b0;
    wire uart_tx, i2c_scl, i2c_sda, over, succ;
    wire [3:0] PWM_o;
    wire [7:0] ext_mem_data_o;
    integer errors = 0;
    integer core;
    integer high_count;

    pullup(i2c_scl);
    pullup(i2c_sda);
    always #5 clk = ~clk;

    tinyriscv_4core_top dut(
        .clk(clk), .rst(rst), .chip_sel(chip_sel),
        .uart_debug_en(uart_debug_en), .uart_rx(uart_rx), .uart_tx(uart_tx),
        .PWM_o(PWM_o), .i2c_scl(i2c_scl), .i2c_sda(i2c_sda),
        .ext_mem_data_i(ext_mem_data_i), .ext_mem_data_o(ext_mem_data_o),
        .over(over), .succ(succ)
    );

    task select_core;
        input [1:0] value;
        begin
            @(negedge clk); rst = 1'b0; chip_sel = value;
            repeat (3) @(posedge clk);
            @(negedge clk); rst = 1'b1;
            @(posedge clk); #1;
            if (dut.selected !== value) begin
                $display("FAIL select expected=%b got=%b", value, dut.selected);
                errors = errors + 1;
            end
        end
    endtask

    task force_pwm_write;
        input integer owner;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            case (owner)
                0: begin force dut.yc_pwm_we=1'b1; force dut.yc_pwm_addr=addr; force dut.yc_pwm_wdata=data; end
                1: begin force dut.yx_pwm_we=1'b1; force dut.yx_pwm_addr=addr; force dut.yx_pwm_wdata=data; end
                2: begin force dut.pjy_pwm_we=1'b1; force dut.pjy_pwm_addr=addr; force dut.pjy_pwm_wdata=data; end
                3: begin force dut.kh_pwm_we=1'b1; force dut.kh_pwm_addr=addr; force dut.kh_pwm_wdata=data; end
            endcase
            @(posedge clk); #1;
            @(negedge clk);
            case (owner)
                0: begin release dut.yc_pwm_we; release dut.yc_pwm_addr; release dut.yc_pwm_wdata; end
                1: begin release dut.yx_pwm_we; release dut.yx_pwm_addr; release dut.yx_pwm_wdata; end
                2: begin release dut.pjy_pwm_we; release dut.pjy_pwm_addr; release dut.pjy_pwm_wdata; end
                3: begin release dut.kh_pwm_we; release dut.kh_pwm_addr; release dut.kh_pwm_wdata; end
            endcase
        end
    endtask

    task force_reg26_write;
        input integer owner;
        input [31:0] data;
        begin
            @(negedge clk);
            case (owner)
                0: begin force dut.yc_rf_we=1'b1; force dut.yc_rf_wa=5'd26; force dut.yc_rf_wd=data; end
                1: begin force dut.yx_rf_we=1'b1; force dut.yx_rf_wa=5'd26; force dut.yx_rf_wd=data; end
                2: begin force dut.pjy_rf_we=1'b1; force dut.pjy_rf_wa=5'd26; force dut.pjy_rf_wd=data; end
                3: begin force dut.kh_rf_we=1'b1; force dut.kh_rf_wa=5'd26; force dut.kh_rf_wd=data; end
            endcase
            @(posedge clk); #1;
            @(negedge clk);
            case (owner)
                0: begin release dut.yc_rf_we; release dut.yc_rf_wa; release dut.yc_rf_wd; end
                1: begin release dut.yx_rf_we; release dut.yx_rf_wa; release dut.yx_rf_wd; end
                2: begin release dut.pjy_rf_we; release dut.pjy_rf_wa; release dut.pjy_rf_wd; end
                3: begin release dut.kh_rf_we; release dut.kh_rf_wa; release dut.kh_rf_wd; end
            endcase
        end
    endtask

    initial begin
        // Each selected core can write the one shared register file and PWM.
        for (core = 0; core < 4; core = core + 1) begin
            select_core(core[1:0]);
            force_reg26_write(core, 32'h1000_0000 + core);
            if (dut.status_x26 !== (32'h1000_0000 + core)) begin
                $display("FAIL core %0d shared-reg write", core); errors = errors + 1;
            end
            force_pwm_write(core, 32'h6000_0000, 32'd8 + core);
            if (dut.u_shared_pwm.pwm_a0 !== (32'd8 + core)) begin
                $display("FAIL core %0d shared-PWM write", core); errors = errors + 1;
            end

            // chip_sel changes outside reset must not switch ownership.
            chip_sel = (core + 1) & 3;
            repeat (2) @(posedge clk); #1;
            if (dut.selected !== core[1:0]) begin
                $display("FAIL live chip_sel switch was accepted"); errors = errors + 1;
            end
        end

        // An unselected request cannot alter shared resources.
        select_core(2'b00);
        force_pwm_write(1, 32'h6000_0000, 32'hdead_beef);
        if (dut.u_shared_pwm.pwm_a0 !== 32'b0) begin
            $display("FAIL unselected PWM request was accepted"); errors = errors + 1;
        end
        force_reg26_write(1, 32'hdead_beef);
        if (dut.status_x26 === 32'hdead_beef) begin
            $display("FAIL unselected register write was accepted"); errors = errors + 1;
        end

        // Representative period/duty/enable waveform on the shared YC PWM.
        select_core(2'b10);
        force_pwm_write(2, 32'h6000_0000, 32'd8);
        force_pwm_write(2, 32'h6010_0000, 32'd3);
        force_pwm_write(2, 32'h6004_0000, 32'd1);
        high_count = 0;
        repeat (8) begin @(posedge clk); #1; if (PWM_o[0]) high_count = high_count + 1; end
        if (high_count != 3) begin
            $display("FAIL PWM duty expected=3 got=%0d", high_count); errors = errors + 1;
        end

        if (errors == 0) $display("TEST_PASS shared_arbiter");
        else $display("TEST_FAIL shared_arbiter errors=%0d", errors);
        $finish;
    end

    initial begin
        #20000;
        $display("TEST_FAIL shared_arbiter timeout");
        $finish;
    end
endmodule
