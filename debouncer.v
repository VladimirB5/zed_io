 `timescale 1ns/1ps
module debouncer( // debouncer
  input        clk, // 100 Mhz clock expected
  input        res_n,
  input        ena,      // enable
  input  [4:0] deb_time, // debounce time * 100us
  input        data_in, // input to debouncer
  output       data_out // output to debouncer     
);
  // parameters
  parameter TIME_TICK = 10000;
  
  // registers
  reg unsigned [4:0]  time_c, time_s;
  reg unsigned [15:0] tick_c, tick_s; // clk tick
  reg val_s; // input value previous value
  wire val_c;
  reg fil_val_c, fil_val_s; // filtered value
 
  // sequential logic
  always @(posedge clk or negedge res_n) begin
    if (~res_n) begin
      tick_s    <= 16'h0000;
      time_s    <= 5'h00;
      val_s     <= 1'b0;
      fil_val_s <= 1'b0;
    end
    else begin
      tick_s    <= tick_c;
      time_s    <= time_s;
      val_s     <= val_c;
      fil_val_s <= fil_val_c;
    end
  end 
 
  // asynchronous logic
  assign val_c = (ena == 1'b1) ? data_in : 1'b0; // save input to register
  
  always @(*) begin
    fil_val_c = fil_val_s;
    if (ena == 1'b1 && fil_val_s != data_in) begin
      if (tick_s == TIME_TICK) begin
        tick_c = 16'h0000;
        if (time_s == deb_time) begin
          time_c = 5'h00;
          fil_val_c = data_in;
        end else begin
          time_c = time_s + 1;
        end
      end else begin
        tick_c = tick_s + 1; 
      end
    end else begin
      tick_c = 16'h0000;
      time_c = 5'h00;      
    end
  end
  
  // output assigment
  assign data_out = (ena == 1'b1) ? fil_val_s : data_in;
endmodule // debouncer
 
