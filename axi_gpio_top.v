 /*
   led, switch and butons connected to AXI-lite
 */
 
 `timescale 1ns/1ps
module axi_gpio_top( // AXI4-LITE slave
  // Global signals
  input ACLK,
  input ARESETn,
  // write adress channel
  input        AWVALID,
  output       AWREADY,
  input [31:0] AWADDR,
  input [2 :0] AWPROT,
  // write data channel
  input        WVALID,
  output       WREADY,
  input [31:0] WDATA,
  input [3 :0] WSTRB, // C_S_AXI_DATA_WIDTH/8)-1 : 0
  // write response channel
  output       BVALID,
  input        BREADY,
  output[1 :0] BRESP,
  // read address channel
  input        ARVALID,
  output       ARREADY,
  input [31:0] ARADDR,
  input [2 :0] ARPROT,
  // read data channel
  output       RVALID,
  input        RREADY,
  output[31:0] RDATA,
  output[1 :0] RRESP,
  
  // inout and outputs
  output [7:0] led,     // LED
  input  [7:0] switch,  // switch
  input  [4:0] button,   // buttons
  
  // interrupt
  output interrupt
);
  // interconnect signals
  wire [7:0] int_switch_sts;
  wire [7:0] int_switch_ena;
  wire [7:0] int_switch_clr;
  wire [4:0] int_button_sts;
  wire [4:0] int_button_ena;
  wire [4:0] int_button_clr;
  wire [4:0] button_posedge;
  wire [4:0] button_negedge;
  wire [7:0] deb_switch_ena;
  wire [4:0] deb_button_ena;
  wire [7:0] switch_synch;
  wire [4:0] button_synch;
  wire [7:0] switch_deb;
  wire [4:0] button_deb;  
  wire [4:0] deb_time;
  wire       invoke_int;
  
  // input synchronizers
  synchro#(8) 
  synchro_switch( //synchro for switches
    .clk     (ACLK),
    .resetn  (ARESETn),
    .data_in (switch),
    .data_out(switch_synch)
  );
  
  synchro#(5) 
  synchro_button( //synchro for buttons
    .clk     (ACLK),
    .resetn  (ARESETn),
    .data_in (button),
    .data_out(button_synch)
  ); 
  
 genvar i;
 generate
    for (i=0; i<=7; i=i+1) begin : switch_debouncers 
    debouncer i_debouncer( // debouncer
     .clk(ACLK), 
     .res_n(ARESETn),
     .ena(deb_switch_ena[i]),
     .deb_time(deb_time),
     .data_in(switch_synch[i]), 
     .data_out(switch_deb[i])      
 );
 end 
 endgenerate

 genvar j;
 generate
    for (j=0; j<=4; j=j+1) begin : buttton_debouncers
    debouncer j_debouncer( // debouncer
     .clk(ACLK), 
     .res_n(ARESETn),
     .ena(deb_button_ena[j]),
     .deb_time(deb_time),
     .data_in(button_synch[j]), 
     .data_out(button_deb[j])      
 );
 end 
 endgenerate
 
 // interrupt controller
 int_ctrl i_int_ctrl( // interrupt controller
   .clk(ACLK),
   .res_n(ARESETn),
   .switch(switch_deb),         // switch
   .button(button_deb),         // buttons
   // register map input output
   .int_switch_sts(int_switch_sts),
   .int_switch_ena(int_switch_ena), 
   .int_switch_clr(int_switch_clr),
   .int_button_sts(int_button_sts),
   .int_button_ena(int_button_ena),
   .int_button_clr(int_button_clr),
   .button_posedge(button_posedge),
   .button_negedge(button_negedge), 
   .invoke_int(invoke_int),
   
   // interrupt output
   .interrupt(interrupt)
);
  
 // AXI4-LITE slave 
 axi_lite i_axi_lite( // AXI4-LITE slave
   // Global signals
   .ACLK(ACLK),
   .ARESETn(ARESETn),
   // write adress channel
   .AWVALID(AWVALID),
   .AWREADY(AWREADY),
   .AWADDR(AWADDR),
   .AWPROT(AWPROT),
   // write data channel
   .WVALID(WVALID),
   .WREADY(WREADY),
   .WDATA(WDATA),
   .WSTRB(WSTRB), // C_S_AXI_DATA_WIDTH/8)-1 : 0
   // write response channel
   .BVALID(BVALID),
   .BREADY(BREADY),
   .BRESP(BRESP),
   // read address channel
   .ARVALID(ARVALID),
   .ARREADY(ARREADY),
   .ARADDR(ARADDR),
   .ARPROT(ARPROT),
   // read data channel
   .RVALID(RVALID),
   .RREADY(RREADY),
   .RDATA(RDATA),
   .RRESP(RRESP),
   
   // register map input output
   .led(led),            
   .switch(switch_deb),         
   .button(button_deb),         
   .int_switch_sts(int_switch_sts), 
   .int_switch_ena(int_switch_ena), 
   .int_switch_clr(int_switch_clr), 
   .int_button_sts(int_button_sts), 
   .int_button_ena(int_button_ena),
   .int_button_clr(int_button_clr),
   .button_posedge(button_posedge),
   .button_negedge(button_negedge), 
   .deb_switch_ena(deb_switch_ena),
   .deb_button_ena(deb_button_ena),
   .deb_time(deb_time),
   .invoke_int_test(invoke_int)
);  

endmodule // axi_gpio_top
 
