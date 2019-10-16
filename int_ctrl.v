 `timescale 1ns/1ps
module int_ctrl(
  input        clk,
  input        res_n,
  input  [7:0] switch,         // switch
  input  [4:0] button,         // buttons
  
  // register map input output
  output [7:0] int_switch_sts, // switch status
  input  [7:0] int_switch_ena, // switch interrupt enable
  input  [7:0] int_switch_clr, // interrupt switch clear
  output [4:0] int_button_sts, // buttons status
  input  [4:0] int_button_ena, // buttons interrupt enable
  input  [4:0] int_button_clr, // interrupt button clear
  input  [4:0] button_posedge, // positive edge for interrupt
  input  [4:0] button_negedge, // negative edge for interrupt 
  input        invoke_int,     // invoke all enabled interrupts (test purpose)
  
  // interrupt output
  output       interrupt
);
 
 // registers 
 reg  [7:0] switch_sts_c, switch_sts_s;
 reg  [4:0] button_sts_c, button_sts_s;
 wire [7:0] switch_val_c;
 reg  [7:0] switch_val_s; // previous value of switch
 wire [4:0] button_val_c;
 reg  [4:0] button_val_s; // previous value
 reg  interrupt_s;
 wire interrupt_c;
 
 //variables
 integer i,j;
 
 // sequential logic
 always @(posedge clk or negedge res_n) begin
    if (~res_n) begin
      switch_sts_s <= 8'h00;
      button_sts_s <= 5'h00;
      switch_val_s <= 8'h00;
      button_val_s <= 5'h00;
      interrupt_s  <= 1'b0;
    end
    else begin
      switch_sts_s <= switch_sts_c;
      button_sts_s <= button_sts_c;
      switch_val_s <= switch_val_c;
      button_val_s <= button_val_c;
      interrupt_s  <= interrupt_c;
    end
 end
  
 // asynchronous logic
 assign button_val_c = button; // assign button to button_val_C
 assign switch_val_c = switch; // 
 
 // generate interrupt for buttons
 always @(*) begin
   button_sts_c = button_sts_s;
   for (i = 0; i < 5 ; i = i + 1) begin
       button_sts_c[i] = button_sts_s[i];
     if (int_button_ena[i] == 0) begin
       button_sts_c[i] = 1'b0;
     end else begin
       if (invoke_int == 1'b1) begin // invoking interrupt
         button_sts_c[i] = 1'b1;
       end else if (button[i] != button_val_s[i]) begin
         if (button[i] == 1'b1 && button_posedge[i] == 1'b1 || button[i] == 1'b0 && button_negedge[i] == 1'b1) begin
           button_sts_c[i] = 1'b1; // posedge or negedge on button
         end 
       end else if (int_button_clr[i] == 1'b1) begin
         button_sts_c[i] = 1'b0;
       end
     end
   end
 end
 
 // generate interrupt for switches
 always @(*) begin
   switch_sts_c = switch_sts_s;
   for (j = 0; j < 8 ; j = j + 1) begin 
     if (int_switch_ena[j] == 0) begin
       switch_sts_c[j] = 1'b0;
     end else begin
       if (switch[j] != switch_val_s[j] || invoke_int == 1'b1) begin
         switch_sts_c[j] = 1'b1;
       end else if (int_switch_clr[j] == 1'b1) begin
         switch_sts_c[j] = 1'b0;
       end
     end
   end
 end 
 
 // ored all statuses
 assign interrupt_c = switch_sts_s[7] | switch_sts_s[6] | switch_sts_s[5] | switch_sts_s[4] | switch_sts_s[3] | switch_sts_s[2] | switch_sts_s[1] | switch_sts_s[0] | button_sts_s[4] | button_sts_s[3] | button_sts_s[2] | button_sts_s[1] | button_sts_s[0];  
 
 // output assigment
 assign interrupt      = interrupt_s;
 assign int_switch_sts = switch_sts_s;
 assign int_button_sts = button_sts_s;
endmodule // int_ctrl
