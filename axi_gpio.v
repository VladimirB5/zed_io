 /*
   LED      - address 0 R/W (8 bit lsb)
   SWITCHES - address 4 R   (8 bit lsb)
   BUTTONS  - address 8 R   (5 bit lsb)
 */
 
 `timescale 1ns/1ps
module axi_gpio( // AXI4-LITE slave
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
  
  // LED
  output [7:0] led,
  // switches
  input  [7:0] switch,
  // buttons
  input  [4:0] button
);

  // input synchronizers
  synchro#(8) 
  synchro_switch( //synchro for switches
    .clk     (ACLK),
    .resetn  (ARESETn),
    .data_in (switch),
    .data_out(switch_c)
  );
  
  synchro#(5) 
  synchro_button( //synchro for buttons
    .clk     (ACLK),
    .resetn  (ARESETn),
    .data_in (button),
    .data_out(button_c)
  );  

  // output registers
  reg  arready_c, arready_s; 
  reg  rvalid_c, rvalid_s;
  reg  awready_c, awready_s;
  reg  wready_c, wready_s;
  reg  bvalid_c, bvalid_s;
  reg  [1:0]  rresp_c, rresp_s; // read response
  reg  [1:0]  bresp_c, bresp_s; // write resonse
  reg  [7:0]  led_c, led_s;
  reg  [7:0]  switch_s;
  wire [7:0]  switch_c; // for synchronization
  reg  [4:0]  button_s;
  wire [4:0]  button_c;
  reg  [7:0]  rdata_c, rdata_s;

  
  // fsm read declaration
  parameter R_IDLE   = 2'b00;
  parameter R_AREADY = 2'b01;
  parameter R_VDATA  = 2'b10;

  reg [1:0] fsm_read_c, fsm_read_s;
  
  // fsm write declaration
  parameter W_IDLE     = 2'b00;
  parameter W_ADDR_DAT = 2'b01;
  parameter W_RESP     = 2'b10;
  
  reg [1:0] fsm_write_c, fsm_write_s;
  
  // responses
  parameter OKAY   = 2'b00;
  parameter EXOKAY = 2'b01;
  parameter SLVERR = 2'b10;
  parameter DECERR = 2'b11;
    
  // sequential 
  always @(posedge ACLK or negedge ARESETn) begin
    if (~ARESETn) begin
      arready_s   <= 1'b0;
      rvalid_s    <= 1'b0;
      awready_s   <= 1'b0;
      wready_s    <= 1'b0;
      bvalid_s    <= 1'b0;
      rresp_s     <= 2'b0;
      bresp_s     <= 2'b0;
      led_s       <= 8'b0;
      switch_s    <= 8'b0;
      button_s    <= 5'b0;
      rdata_s     <= 8'h00;
      fsm_read_s  <= R_IDLE; // init state after reset
      fsm_write_s <= W_IDLE;
    end
    else begin
      arready_s   <= arready_c;
      rvalid_s    <= rvalid_c;
      awready_s   <= awready_c;
      wready_s    <= wready_c;
      bvalid_s    <= bvalid_c;
      rresp_s     <= rresp_c;
      bresp_s     <= bresp_c;
      led_s       <= led_c; 
      switch_s    <= switch_c;
      button_s    <= button_c;
      rdata_s     <= rdata_c;
      fsm_read_s  <= fsm_read_c; // next fsm state
      fsm_write_s <= fsm_write_c;
      
    end
  end
  
  // combinational parts 
  // read processes ---------------------------------------------------------------------------
  always @(*) begin // read process
    fsm_read_c = fsm_read_s;
    case (fsm_read_s)
      R_IDLE: begin
        fsm_read_c = R_AREADY;
      end
      
      R_AREADY: begin
        if (ARVALID == 1'b1) 
          fsm_read_c = R_VDATA;
        else
          fsm_read_c = R_AREADY;
      end
            
      R_VDATA: begin
        if (RREADY == 1'b1) begin
          fsm_read_c = R_IDLE;
        end else
          fsm_read_c = R_VDATA;
      end
    endcase
  end
    
  // ouput combinational logic
  always @(*) begin // read process
    rvalid_c  = 1'b0;
    arready_c = 1'b0; 
    case (fsm_read_c)
      R_IDLE: begin
        arready_c = 1'b0;
      end
      
      R_AREADY: begin
        arready_c = 1'b1;
      end
             
      R_VDATA: begin
        rvalid_c = 1'b1;
      end
    endcase
  end 
  
  // output read mux
  always @(*) begin
    rdata_c = 8'h00;
    rresp_c = OKAY;
    if (ARVALID == 1'b1 && fsm_read_s === R_AREADY) begin
        case (ARADDR[3:0])
        4'b0000: begin // led values 0
          rdata_c = led_s;
        end

        4'b0001: begin // led values 1
          rdata_c = led_s;
        end

        4'b0010: begin // led values 2
          rdata_c = led_s;
        end      

        4'b0011: begin // led values 3
          rdata_c = led_s;
        end
        
        4'b0100: begin // sw values 4
          rdata_c = switch_s;
        end
        
        4'b0101: begin // sw values 5
          rdata_c = switch_s;
        end
        
        4'b0110: begin // sw values 6
          rdata_c = switch_s;
        end
        
        4'b0111: begin // sw values 7
          rdata_c = switch_s;
        end      
      
        4'b1000: begin // buttons values 8
          rdata_c = {3'b0, button_s};
        end

        4'b1001: begin // buttons values 9
          rdata_c = {3'b0, button_s};
        end

        4'b1010: begin // buttons values 10
          rdata_c = {3'b0, button_s};
        end      

        4'b1011: begin // buttons values 11
          rdata_c = {3'b0, button_s};
        end      
      
        default: begin
          rresp_c = DECERR;
        end
      endcase
    end else if (fsm_read_s === R_VDATA) begin
      rdata_c = rdata_s;
      rresp_c = rresp_s;
    end else begin
      rdata_c = 8'h00;
    end
  end  
  
// write processes ------------------------------------------------------------------------  
  always @(*) begin // write process
    fsm_write_c = fsm_write_s;
    case (fsm_write_s)
      W_IDLE: begin
        if (AWVALID == 1'b1 && WVALID == 1'b1) 
          fsm_write_c = W_ADDR_DAT;
      end
            
      W_ADDR_DAT: begin
        fsm_write_c = W_RESP;
      end
      
      W_RESP: begin
        if (BREADY == 1'b1) 
          fsm_write_c = W_IDLE;
      end
    endcase
  end
  
  always @(*) begin // generating outputs for write
    awready_c = 1'b0;
    wready_c  = 1'b0;
    bvalid_c  = 1'b0;
    bresp_c = bresp_s;
    led_c = led_s;
    case (fsm_write_c)
      W_IDLE: begin
        bresp_c = OKAY;
        awready_c = 1'b0;
        wready_c  = 1'b0;
        bvalid_c  = 1'b0;
      end
            
      W_ADDR_DAT: begin
        if (AWADDR[4:2] == 3'b000 && WSTRB[0] == 1'b1) begin
          led_c = WDATA[7:0];
          bresp_c = OKAY;
        end else begin
          bresp_c = DECERR;
        end      
        awready_c = 1'b1;
        wready_c  = 1'b1;
        bvalid_c  = 1'b0;        
      end
      
      W_RESP: begin
        awready_c = 1'b0;
        wready_c  = 1'b0;
        bvalid_c  = 1'b1;      
      end
    endcase
  end  
  
  // output assigment
  // read channels
  assign ARREADY = arready_s;
  assign RVALID  = rvalid_s;
  assign RDATA   = {24'b0, rdata_s};
  assign RRESP   = rresp_s;
  // write channels
  assign AWREADY = awready_s;
  assign WREADY  = wready_s;
  assign BVALID  = bvalid_s;
  assign BRESP   = bresp_s;
  // led
  assign led     = led_s;
endmodule // axi_gpio
