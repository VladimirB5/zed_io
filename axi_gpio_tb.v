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
  
  initial begin
    rready = 0; // read from address 4
    araddr = 0;
    arvalid = 0;
    # 200;
    @(negedge clk);
    araddr = 4;    
    arvalid = 1; 
    rready = 1;
    @(posedge clk);
    # 1;
    araddr = 0;    
    arvalid = 0;
    wait(rvalid == 1);
    @(negedge clk);
    @(negedge rvalid);
    #(1);
    rready = 0;
    
    #(100); // second transaction - read from address 8
    rready = 0;
    araddr = 0;
    arvalid = 0;
    # 200;
    @(negedge clk);
    araddr = 8;    
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
    
    #(100); // third transaction - read from address 0
    rready = 0;
    araddr = 0;
    arvalid = 0;
    # 200;
    @(negedge clk);
    araddr = 0;    
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
    
    #(100); // fourth transaction - read from address 12
    rready = 0;
    araddr = 0;
    arvalid = 0;
    # 200;
    @(negedge clk);
    araddr = 12;    
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
  
  initial begin // write transaction
    bready = 0;     
    awvalid = 0;
    wvalid  = 0;
    wdata   = 32'h00000000;
    awaddr  = 32'hffffffff;
    wstrb   = 'b0;
    #(250); // first transaction
    awvalid = 1;
    awaddr  = 'b0;
    #(10);
    wvalid = 1;
    wstrb   = 'b1;
    wdata   = 32'h000000ff;
    @(negedge awready);
    #(1);
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 'b1;
    wstrb   = 'b0;   
    @(posedge clk);
    #(1);
    bready = 1;
    @(posedge clk);
    #(1);
    bready = 0;    

    #(50); // second transaction
    awvalid = 1;
    awaddr  = 'b0;
    #(10);
    wvalid = 1;
    wstrb   = 'b1;
    wdata   = 32'h000000AA;
    @(negedge awready);
    #(1);
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 'b1;
    wstrb   = 'b0;   
    @(posedge clk);
    #(1);
    bready = 1;
    @(posedge clk);
    #(1);
    bready = 0;     
    
    #(1350); // third transaction -- 
    awvalid = 1;
    awaddr  = 'b1;
    #(10);
    wvalid = 1;
    wstrb   = 'b1;
    wdata   = 32'h0000000A;
    @(negedge awready);
    #(1);
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 'b1;
    wstrb   = 'b0;   
    @(posedge clk);
    #(1);
    bready = 1;
    @(posedge clk);
    #(1);
    bready = 0; 
    
    #(100); // fourt transaction -- write to bad address
    awvalid = 1;
    awaddr  = 4;
    #(10);
    wvalid = 1;
    wstrb   = 'b1;
    wdata   = 32'h000000ff;
    @(negedge awready);
    #(1);
    awvalid = 0;
    wvalid  = 0;
    awaddr  = 'b1;
    wstrb   = 'b0;   
    @(posedge clk);
    #(1);
    bready = 1;
    @(posedge clk);
    #(1);
    bready = 0;    
  end
  
  axi_gpio axi_gpio_1( // AXI4-LITE slave
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
    .ARPROT('b0),
    // read data channel
    .RVALID(rvalid),
    .RREADY(rready),
    .RDATA(),
    .RRESP(),
  
  // LED
    .led(),
  // switches
    .switch(8'h55),
  // buttons
    .button(5'b00111)
  );

   
   
endmodule // test