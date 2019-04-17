 /*
   axi lite
 */
 
 `timescale 1ns/1ps
module axi_lite( // AXI4-LITE slave
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
  
  // register map input output
  output [7:0] led,            // LED
  input  [7:0] switch,         // switch
  input  [4:0] button,         // buttons
  input  [7:0] int_switch_sts, // switch status
  output [7:0] int_switch_ena, // switch interrupt enable
  output [7:0] int_switch_clr, // interrupt switch clear
  input  [4:0] int_button_sts, // buttons status
  output [4:0] int_button_ena, // buttons interrupt enable
  output [4:0] int_button_clr, // interrupt button clear
  output [4:0] button_posedge, // positive edge for interrupt
  output [4:0] button_negedge, // negative edge for interrupt 
  output [7:0] deb_switch_ena, // debouncer ena switch
  output [4:0] deb_button_ena, // debouncer button switch
  output [4:0] deb_time        // debounce time
);

  // internal registers
  reg  arready_c, arready_s; 
  reg  rvalid_c, rvalid_s;
  reg  awready_c, awready_s;
  reg  wready_c, wready_s;
  reg  bvalid_c, bvalid_s;
  reg  [1:0]  rresp_c, rresp_s; // read response
  reg  [1:0]  bresp_c, bresp_s; // write resonse
  reg  [31:0]  rdata_c, rdata_s;
  
  //register map registers
  reg  [7:0] led_c, led_s;
  reg  [7:0] switch_ena_c, switch_ena_s;
  reg  [4:0] button_ena_c, button_ena_s;
  reg  [7:0] switch_clr_c, switch_clr_s;
  reg  [4:0] button_clr_c, button_clr_s;  
  reg  [4:0] button_pos_c, button_pos_s; // interrupt on posedge
  reg  [4:0] button_neg_c, button_neg_s; // interrupt on negedge
  reg  [7:0] deb_switch_ena_c, deb_switch_ena_s;
  reg  [4:0] deb_button_ena_c, deb_button_ena_s;
  reg  [4:0] deb_time_c, deb_time_s; 
    
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
  
  //variables
  integer i;
    
  // sequential 
  always @(posedge ACLK or negedge ARESETn) begin
    if (~ARESETn) begin
      arready_s    <= 1'b0;
      rvalid_s     <= 1'b0;
      awready_s    <= 1'b0;
      wready_s     <= 1'b0;
      bvalid_s     <= 1'b0;
      rresp_s      <= 2'b0;
      bresp_s      <= 2'b0;
      rdata_s      <= 32'h00000000;
      fsm_read_s   <= R_IDLE; // init state after reset
      fsm_write_s  <= W_IDLE;
      // reg map registers
      led_s            <= 8'b0;
      switch_ena_s     <= 8'h00;
      button_ena_s     <= 5'b0;
      switch_clr_s     <= 8'h00;
      button_clr_s     <= 5'h00;
      button_pos_s     <= 5'b0;
      button_neg_s     <= 5'b0;
      deb_switch_ena_s <= 8'hff;
      deb_button_ena_s <= 5'h1f;
      deb_time_s       <= 5'b0;
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
      rdata_s     <= rdata_c;
      fsm_read_s  <= fsm_read_c; // next fsm state
      fsm_write_s <= fsm_write_c;
      // reg map registers
      led_s            <= led_c;
      switch_ena_s     <= switch_ena_c;
      button_ena_s     <= button_ena_c;
      switch_clr_s     <= switch_clr_c;
      button_clr_s     <= button_clr_c;      
      button_pos_s     <= button_pos_c;
      button_neg_s     <= button_neg_c;
      deb_switch_ena_s <= deb_switch_ena_c;
      deb_button_ena_s <= deb_button_ena_c;
      deb_time_s       <= deb_time_c;      
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
    rdata_c = 32'h00000000;
    rresp_c = OKAY;
    if (ARVALID == 1'b1 && fsm_read_s == R_AREADY) begin
        case (ARADDR[5:2])
        4'b0000: begin // 0x00
          rdata_c = {24'h000000, led_s};
        end

        4'b0001: begin // 0x04
          rdata_c = {16'h0000, 3'b000, button, switch};
        end

        4'b0010: begin // 0x08
          rdata_c = {16'h0000, 3'b000, int_button_sts, int_switch_sts};
        end      

        4'b0011: begin // 0x0C
          rdata_c = {16'h0000, 3'b000, button_ena_s, switch_ena_s};
        end
        
        4'b0100: begin // 0x10
          rdata_c = {16'h0000, 3'b000, button_ena_s, switch_ena_s};
        end
        
        4'b0101: begin // 0x14
          rdata_c = {16'h0000, 3'b000, button_neg_s, 3'b000, button_pos_s};
        end
        
        4'b0110: begin // 0x18
          rdata_c = 32'h00000000;
        end
        
        4'b0111: begin // 0x1C
          rdata_c = 32'h00000000;
        end      
      
        4'b1000: begin // 0x20
          rdata_c = {16'h0000, 3'b000, deb_button_ena_s, deb_switch_ena_s};
        end

        4'b1001: begin // 0x24
          rdata_c = {24'h000000, 3'b000, deb_time_s};
        end

        4'b1010: begin // 0x28
          rdata_c = 32'h7e8155aa;
        end      
           
        default: begin
          rresp_c = DECERR;
        end
      endcase
    end else if (fsm_read_s == R_VDATA) begin
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
    case (fsm_write_c)
      W_IDLE: begin
        awready_c = 1'b0;
        wready_c  = 1'b0;
        bvalid_c  = 1'b0;
      end
            
      W_ADDR_DAT: begin  
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
  
  // write mux
  always @(*) begin
    bresp_c = bresp_s;
    // reg map
    led_c            = led_s;
    switch_ena_c     = switch_ena_s;
    button_ena_c     = button_ena_s;
    button_pos_c     = button_pos_s;
    button_neg_c     = button_neg_s;
    deb_switch_ena_c = deb_switch_ena_s;
    deb_button_ena_c = deb_button_ena_s;
    deb_time_c       = deb_time_s;
    if (switch_clr_s != 8'h00) begin
      switch_clr_c = 8'h00;
    end else begin
      switch_clr_c = switch_clr_s;
    end
    if (button_clr_s != 5'h00) begin
      button_clr_c = 5'h00;
    end else begin
      button_clr_c = button_clr_s;
    end
    if (fsm_write_s == W_ADDR_DAT) begin
      bresp_c = OKAY;
      case(AWADDR[5:2])
        4'b0000: begin
          if (WSTRB[0] == 1'b1) begin
            led_c = WDATA[7:0];
          end
        end
        
        4'b0001: begin //switches and buttons - only read
        end
        
        4'b0010: begin // interupt clear
          if (WSTRB[0] == 1'b1) begin
            for (i=0; i < 8; i=i+1) begin
              if (WDATA[i] == 1) begin 
                switch_clr_c[i] = 1'b1;
              end
            end
          end
          if (WSTRB[1] == 1'b1) begin
            for (i=0; i < 5; i=i+1) begin
              if (WDATA[i+8] == 1) begin 
                button_clr_c[i] = 1'b1;
              end
            end
          end
        end
        
        4'b0011: begin // interupt enable
          if (WSTRB[0] == 1'b1) begin
            for (i=0; i < 8; i=i+1) begin
              if (WDATA[i] == 1) begin 
                switch_ena_c[i] = 1'b1;
              end
            end
          end
          if (WSTRB[1] == 1'b1) begin
            for (i=0; i < 5; i=i+1) begin
              if (WDATA[i+8] == 1) begin 
                button_ena_c[i] = 1'b1;
              end
            end
          end          
        end        
        
        4'b0100: begin // interrupt disable
          if (WSTRB[0] == 1'b1) begin
            for (i=0; i < 8; i=i+1) begin
              if (WDATA[i] == 1) begin 
                switch_ena_c[i] = 1'b0;
              end
            end
          end
          if (WSTRB[1] == 1'b1) begin
            for (i=0; i < 5; i=i+1) begin
              if (WDATA[i+8] == 1) begin 
                button_ena_c[i] = 1'b0;
              end
            end
          end         
        end
        
        4'b0101: begin
          if (WSTRB[0] == 1'b1) begin
            button_pos_c = WDATA[4:0];
          end
          if (WSTRB[1] == 1'b1) begin
            button_neg_c = WDATA[12:8];
          end
        end
        
        4'b0110: begin // all interrupts enable
          if (WSTRB[0] == 1'b1 && WDATA[0] == 1'b1) begin
            switch_ena_c = 8'hff;
            button_ena_c = 5'h1f;
            button_pos_c = 5'h1f;
            button_neg_c = 5'h1f;
          end
        end
        
        4'b0111: begin // al interrupt disable
          if (WSTRB[0] == 1'b1 && WDATA[0] == 1'b1) begin
            switch_ena_c = 8'h00;
            button_ena_c = 5'h00;
          end
        end
        
        4'b1000: begin
          if (WSTRB[0] == 1'b1) begin
            deb_switch_ena_c = WDATA[7:0];
          end 
          if (WSTRB[1] == 1'b1) begin
            deb_button_ena_c = WDATA[12:8];
          end           
        end
        
        4'b1001: begin
          if (WSTRB[0] == 1'b1) begin
            deb_time_c = WDATA[4:0];
          end           
        end
        
        4'b1010: begin
        end        
        
        default: begin
          bresp_c = DECERR;
        end        
      endcase
    end
  end
  
  // output assigment
  // read channels
  assign ARREADY = arready_s;
  assign RVALID  = rvalid_s;
  assign RDATA   = rdata_s;
  assign RRESP   = rresp_s;
  // write channels
  assign AWREADY = awready_s;
  assign WREADY  = wready_s;
  assign BVALID  = bvalid_s;
  assign BRESP   = bresp_s;
  // output from register map 
  assign led            = led_s; // LED
  assign int_switch_ena = switch_ena_s;
  assign int_button_ena = button_ena_s; 
  assign int_switch_clr = switch_clr_s;
  assign int_button_clr = button_clr_s;
  assign button_posedge = button_pos_s;
  assign button_negedge = button_neg_s;
  assign deb_switch_ena = deb_switch_ena_s;
  assign deb_button_ena = deb_button_ena_s;
  assign deb_time       = deb_time_s;
endmodule // axi_lite
