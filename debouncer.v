 `timescale 1ns/1ps
module debouncer( // debouncer
  input        clk, // 100 Mhz clock expected
  input        res_n,
  input        ena,      // enable
  input  [4:0] deb_time, // debounce time * 100us
  input        data_in, // input to debouncer
  output       data_out // output to debouncer     
);
  
  // registers
  reg unsigned [17:0]  cnt_c, cnt_s; // 13 + 5 bits
  reg fil_val_c, fil_val_s; // filtered value

  wire limit_reached;
 
  // sequential logic
  always @(posedge clk or negedge res_n) begin
    if (~res_n) begin
      cnt_s    <= 18'h00000;
      fil_val_s <= 1'b0;
    end
    else begin
      if (ena == 1'b1) begin
        cnt_s     <= cnt_c;
        fil_val_s <= fil_val_c;
      end
    end
  end 
 
  // asynchronous logic  
  always @(*) begin
    fil_val_c <= fil_val_s;
    if (data_in != fil_val_s && (deb_time + 1) == cnt_s[17:13]) begin
      fil_val_c <= data_in;
    end
  end

  always @(*) begin
    cnt_c = cnt_s;
    if (ena == 1'b1 && data_in != fil_val_s) begin
      cnt_c = cnt_s + 1;
    end else begin
      cnt_c = 18'h00000;
    end
  end

  // output assigment
  assign data_out = (ena == 1'b1) ? fil_val_s : data_in;
endmodule // debouncer
 
