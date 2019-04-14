`timescale 1ns/1ps 
module axi_gpio_tb;

  /* Make a reset that pulses once. */
  reg reset = 0;
  initial begin
     $dumpfile("test.vcd");
     $dumpvars(0,axi_gpio_tb);
     # 17 reset = 1;
     # 11 reset = 0;
     # 29 reset = 1;
     # 11 reset = 0;
     # 20 reset = 1;
     # 2000 //$stop;
     $finish;
  end

  /* Make a regular pulsing clock. */
  reg clk = 0;
  always #5 clk = !clk;
  
  reg        arvalid;
  wire       arready;
  reg [31:0] araddr;
  // read data channel
  wire        rvalid;
  reg         rready;
  
  // write channels
  reg        awvalid;
  wire       awready;
  reg [31:0] awaddr;
  reg [2 :0] awprot;
  
  reg        wvalid;
  wire       wready;
  reg [31:0] wdata;
  reg [3 :0] wstrb; // C_S_AXI_DATA_WIDTH/8)-1 : 0
  // write response channel
  wire       bvalid;
  reg        bready;
  wire[1 :0] bresp;
  
  // switch and buttons
  reg [7:0] switch;
  reg [4:0] button;
  
  
  task write;
    input reg [31:0] _addr, _data;
    begin
      awvalid = 1;
      awaddr  = _addr;
      @(posedge clk);
      wvalid = 1;
      wstrb   = 4'b1111;
      wdata   = _data;
      @(negedge awready);
      #(1);
      awvalid = 0;
      wvalid  = 0;
      awaddr  = 'b0;
      wstrb   = 'b0;   
      @(posedge clk);
      #(1);
      bready = 1;
      @(posedge clk);
      #(1);
      bready = 0; 
    end  
  endtask 
  
  task read;
    input reg [31:0] _addr;
    //output reg [31:0] _data
    begin
      rready = 0;
      araddr = 0;
      arvalid = 0;
      # 200;
      @(negedge clk);
      araddr = _addr;    
      arvalid = 1; 
      @(posedge clk);
      # 1;
      araddr = 0;    
      arvalid = 0;
      wait(rvalid == 1);
      # 40;
      @(negedge clk);
      rready = 1;
      @(negedge rvalid);
      #(1);
      rready = 0;   
    end  
  endtask   
    
  initial begin // write and read transaction
    switch = 0;
    button = 0;
    rready = 0; // read from address 4
    araddr = 0;
    arvalid = 0;  
    bready = 0;     
    awvalid = 0;
    wvalid  = 0;
    wdata   = 32'h00000000;
    awaddr  = 32'hffffffff;
    wstrb   = 'b0;
    // transactions
    #(250); // first transaction
    write(0,32'h00000001);
    #(10);
    read(0);
    #(10)
    write(32'h0000000C,32'h00001fff); // enable interrupt
    #(10);
    read(32'h0000000C); // read interrupt set
    #(10);
    read(32'h00000010); // read interrupt clear   
    #(10);
    write(32'h00000010,32'h00000102); //disable interrupt
    #(10);
    write(32'h00000020,32'h00000000); //disable debouncer
    #(10);
    switch[0] = 1'b1;
    #(20);
    read(32'h00000008); // read interrupt status   
    #(10);
    write(32'h00000008,32'h00000002); // clear sts switch 1
    #(10);
    write(32'h00000008,32'h00000001); // clear sts switch 0    
  end
  
  axi_gpio_top i_axi_gpio_top( // AXI4-LITE gpio
    // Global signals
    .ACLK    (clk),
    .ARESETn (reset),
    // write adress channel
    .AWVALID(awvalid),
    .AWREADY(awready),
    .AWADDR(awaddr),
    .AWPROT(awprot),
    // write data channel
    .WVALID(wvalid),
    .WREADY(wready),
    .WDATA(wdata),
    .WSTRB(wstrb), // C_S_AXI_DATA_WIDTH/8)-1 : 0
    // write response channel
    .BVALID(bvalid),
    .BREADY(bready),
    .BRESP(bresp),
    // read address channel
    .ARVALID(arvalid),
    .ARREADY(arready),
    .ARADDR(araddr),
    .ARPROT(3'b000),
    // read data channel
    .RVALID(rvalid),
    .RREADY(rready),
    .RDATA(),
    .RRESP(),
  
  // LED
    .led(),
  // switches
    .switch(switch),
  // buttons
    .button(button),
    .interrupt()
  );

   
   
endmodule // test
