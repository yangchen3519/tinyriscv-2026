module lm75_model_rt #(
 parameter [7:0] TEMP=8'h1a,
 parameter [7:0] FRAC=8'h80
)(input wire io_scl,inout wire io_sda);
 localparam IDLE=3'd0,AW=3'd1,REG=3'd2,AR=3'd3,TX=3'd4,NACK=3'd5,TX2=3'd6,ACK2=3'd7;
 localparam ADDR=7'h48;
 reg sda_low;reg[2:0]phase,after_ack;reg[3:0]bit_cnt;reg[2:0]tx_bit;
 reg[7:0]shift,got_byte,reg_ptr;reg reg_ptr_seen,ack_pending,ack_active;
 integer addr_write_count,addr_read_count;
 assign io_sda=sda_low?1'b0:1'bz;
 initial begin sda_low=0;phase=IDLE;after_ack=IDLE;bit_cnt=0;tx_bit=7;
  shift=0;got_byte=0;reg_ptr=0;reg_ptr_seen=0;ack_pending=0;ack_active=0;
  addr_write_count=0;addr_read_count=0;end
 always @(negedge io_sda)if(io_scl)begin sda_low<=0;ack_pending<=0;ack_active<=0;
  bit_cnt<=0;shift<=0;phase<=reg_ptr_seen?AR:AW;end
 always @(posedge io_sda)if(io_scl)begin sda_low<=0;phase<=IDLE;ack_pending<=0;
  ack_active<=0;reg_ptr_seen<=0;end
 always @(posedge io_scl)if(phase==AW||phase==REG||phase==AR)
  if(!ack_pending&&!ack_active)begin got_byte={shift[6:0],io_sda};shift<={shift[6:0],io_sda};
   if(bit_cnt==7)begin bit_cnt<=0;shift<=0;ack_pending<=1;
    case(phase)
     AW:begin
      if(got_byte=={ADDR,1'b0})begin addr_write_count=addr_write_count+1;after_ack<=REG;end
      else if(got_byte=={ADDR,1'b1})begin addr_read_count=addr_read_count+1;after_ack<=TX;end
      else after_ack<=IDLE;
     end
     REG:begin reg_ptr<=got_byte;reg_ptr_seen<=1;after_ack<=IDLE;end
     default:begin if(got_byte=={ADDR,1'b1})addr_read_count=addr_read_count+1;after_ack<=TX;end
    endcase
   end else bit_cnt<=bit_cnt+1'b1;
  end
 always @(negedge io_scl)begin
  if(ack_pending)begin sda_low<=1;ack_pending<=0;ack_active<=1;end
  else if(ack_active)begin ack_active<=0;phase<=after_ack;
   if(after_ack==TX)begin sda_low<=~TEMP[7];tx_bit<=6;end else sda_low<=0;end
  else if(phase==TX)begin sda_low<=~TEMP[tx_bit];if(tx_bit==0)phase<=ACK2;else tx_bit<=tx_bit-1'b1;end
  else if(phase==ACK2)begin sda_low<=~FRAC[7];tx_bit<=6;phase<=TX2;end
  else if(phase==TX2)begin sda_low<=~FRAC[tx_bit];if(tx_bit==0)phase<=NACK;else tx_bit<=tx_bit-1'b1;end
  else if(phase==NACK)begin sda_low<=0;phase<=IDLE;end
 end
endmodule
