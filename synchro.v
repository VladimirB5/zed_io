 `timescale 1ns/1ps
module synchro( 
  input clk,
  input resetn,
  input  [width-1 : 0]  data_in,
  output [width-1 : 0]  data_out
);
  parameter width = 1; 
  
  reg  [width-1 : 0] reg_a_s;
  reg  [width-1 : 0] reg_b_s;
  wire [width-1 : 0] reg_b_c;
  
  // sequential 
  always @(posedge clk or negedge resetn) begin
    if (~resetn) begin
      reg_a_s <= 0;
      reg_b_s <= 0;
    end
    else begin
      reg_a_s <= data_in;
      reg_b_s <= reg_b_c;
    end
  end
  
  
  assign reg_b_c = reg_a_s;
  
  // output assigment
  assign data_out = reg_b_s;
  
  endmodule // synchro