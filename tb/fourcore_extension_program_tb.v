`timescale 1ns/1ps
// TEST_KIND: 0=sID, 1=IF, 2=Temp/rT.  CORE: 0=YC,1=YX,2=PJY,3=Khoree.
module fourcore_extension_program_tb;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="fourcore_extension.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,fourcore_extension_program_tb);
    end
`endif
    reg clk=0,rst=0;
    reg[2:0]chip_sel=0;
    wire uart_tx,i2c_scl,i2c_sda,over,succ;
    wire[3:0]PWM_o;
    integer core=0,test_kind=0,errors=0,i;
    integer baud_cycles=441;
    reg[1023:0]inst_file;
    reg[7:0]rx_byte;
    always #10 clk=~clk;
    pullup(i2c_scl);pullup(i2c_sda);

    function[7:0]sid_expected;
        input integer owner;
        input integer index;
        begin
            case(owner)
                0: case(index) 0:sid_expected="2";1:sid_expected="0";2:sid_expected="2";3:sid_expected="5";4:sid_expected="2";5:sid_expected="1";6:sid_expected="0";7:sid_expected="8";8:sid_expected="8";default:sid_expected="7";endcase
                1: case(index) 0:sid_expected="2";1:sid_expected="0";2:sid_expected="2";3:sid_expected="5";4:sid_expected="2";5:sid_expected="1";6:sid_expected="0";7:sid_expected="8";8:sid_expected="9";default:sid_expected="5";endcase
                2: case(index) 0:sid_expected="2";1:sid_expected="0";2:sid_expected="2";3:sid_expected="5";4:sid_expected="2";5:sid_expected="1";6:sid_expected="0";7:sid_expected="9";8:sid_expected="0";default:sid_expected="2";endcase
                default: case(index) 0:sid_expected="2";1:sid_expected="0";2:sid_expected="2";3:sid_expected="5";4:sid_expected="2";5:sid_expected="8";6:sid_expected="0";7:sid_expected="0";8:sid_expected="5";default:sid_expected="8";endcase
            endcase
        end
    endfunction

    task wait_uart_byte;
        output[7:0]data;
        integer bitno;
        begin
            @(negedge uart_tx);
            #(baud_cycles*10); #(baud_cycles*20);
            for(bitno=0;bitno<8;bitno=bitno+1) begin
                data[bitno]=uart_tx; #(baud_cycles*20);
            end
            if(uart_tx!==1'b1)errors=errors+1;
        end
    endtask

    initial begin
        if(!$value$plusargs("CORE=%d",core))core=0;
        if(!$value$plusargs("TEST_KIND=%d",test_kind))test_kind=0;
        if(!$value$plusargs("INST_FILE=%s",inst_file))
            inst_file="../firmware/test_command/Extend_Inst_Example/sID/sID_inst.data";
        chip_sel=core[2:0];
        $readmemh(inst_file,dut.u_rom._rom);
        repeat(8)@(posedge clk);@(negedge clk);rst=1;
        case(test_kind)
            0: begin
                for(i=0;i<10;i=i+1)begin
                    wait_uart_byte(rx_byte);
                    if(rx_byte!==sid_expected(core,i))begin
                        $display("EXT_DETAIL sID core=%0d index=%0d got=%02h expected=%02h",core,i,rx_byte,sid_expected(core,i));
                        errors=errors+1;
                    end
                end
                if(errors==0)$display("TEST_PASS extension_sID core=%0d",core);
                else $display("TEST_FAIL extension_sID core=%0d errors=%0d",core,errors);
            end
            1: begin
                wait_uart_byte(rx_byte);
                repeat(100)@(posedge clk);#1;
                if(rx_byte!==8'h8a)begin
                    errors=errors+1;
                    $display("TEST_FAIL extension_IF core=%0d byte=%02h x30=%08h",core,rx_byte,dut.u_chip.u_shared_regs.regs[30]);
                end else $display("TEST_PASS extension_IF core=%0d byte=8a x30=%08h",core,dut.u_chip.u_shared_regs.regs[30]);
            end
            default: begin
                wait_uart_byte(rx_byte);
                if(rx_byte!==8'h1a)begin errors=errors+1;$display("TEST_FAIL extension_Temp core=%0d byte=%02h",core,rx_byte);end
                else $display("TEST_PASS extension_Temp core=%0d byte=1a",core);
            end
        endcase
        $finish;
    end
    initial begin #10000000;$display("TEST_FAIL extension timeout core=%0d kind=%0d",core,test_kind);$finish;end

    tinyriscv_4core_fpga_top dut(.clk(clk),.rst(rst),.chip_sel(chip_sel),
      .uart_debug_en(1'b0),.uart_rx(1'b1),.uart_tx(uart_tx),.PWM_o(PWM_o),
      .i2c_scl(i2c_scl),.i2c_sda(i2c_sda),.over(over),.succ(succ));
    lm75_model_rt u_lm75(.io_scl(i2c_scl),.io_sda(i2c_sda));
endmodule
