`timescale 1ns/1ps
module pjy_removed_features_tb;
    reg rst=1'b1;
    reg[31:0] inst;
    wire[4:0] raddr1,raddr2,waddr;
    wire[31:0] csr_raddr,op1,op2,op1j,op2j,inst_o,inst_addr_o,rdata1_o,rdata2_o,csr_rdata_o,csr_waddr;
    wire reg_we,csr_we;
    integer errors=0;
`ifdef FSDB
    reg[1023:0] fsdb_file;
    initial begin
        if(!$value$plusargs("FSDB_FILE=%s",fsdb_file)) fsdb_file="../results/vcs/pjy_removed_features.fsdb";
        $fsdbDumpfile(fsdb_file); $fsdbDumpvars(0,pjy_removed_features_tb);
    end
`endif
    task rejected; input[31:0] code; input[127:0] name; begin
        inst=code; #1;
        if(reg_we!==1'b0 || csr_we!==1'b0) begin
            $display("FAIL removed feature %0s reg_we=%b csr_we=%b",name,reg_we,csr_we); errors=errors+1;
        end
    end endtask
    initial begin
        rejected(32'h022081b3,"MUL"); rejected(32'h0220c1b3,"DIV");
        rejected(32'h0220e1b3,"REM"); rejected(32'h300091f3,"CSRRW");
        if(errors==0) $display("TEST_PASS PJY_M_CSR_decode_removed");
        else $display("TEST_FAIL PJY_removed_features errors=%0d",errors);
        $finish;
    end
    pjy_id dut(.rst(rst),.inst_i(inst),.inst_addr_i(32'b0),.reg1_rdata_i(32'h11),.reg2_rdata_i(32'h22),
        .csr_rdata_i(32'h33),.ex_jump_flag_i(1'b0),.reg1_raddr_o(raddr1),.reg2_raddr_o(raddr2),
        .csr_raddr_o(csr_raddr),.op1_o(op1),.op2_o(op2),.op1_jump_o(op1j),.op2_jump_o(op2j),
        .inst_o(inst_o),.inst_addr_o(inst_addr_o),.reg1_rdata_o(rdata1_o),.reg2_rdata_o(rdata2_o),
        .reg_we_o(reg_we),.reg_waddr_o(waddr),.csr_we_o(csr_we),.csr_rdata_o(csr_rdata_o),.csr_waddr_o(csr_waddr));
endmodule
