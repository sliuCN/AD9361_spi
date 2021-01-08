module SPI_configure
#(     parameter CLKS_PER_HALF_BIT = 2) 
( 
 // Control/Data Signals, 
 input        i_Rst_L,     // FPGA Reset 
 input        i_Clk,       // FPGA Clock 
  
 // TX (MOSI) Signals 
 input [23:0]  i_TX_Byte,        // Byte to transmit on MOSI 
 input         i_TX_DV,          // Data Valid Pulse with i_TX_Byte 
 output reg     o_TX_Ready,       // Transmit Ready for next byte 
 
 
 
 // RX (MISO) Signals 
 output reg       o_RX_DV,     // Data Valid pulse (1 clock cycle) 
 output reg [7:0] o_RX_Byte,   // Byte received on MISO 


 // SPI Interface 
 output reg o_SPI_Clk, 
 output reg o_SPI_CS_n, 
 input      i_SPI_MISO, 
 output reg o_SPI_MOSI 
 ); 


// SPI Interface (All Runs at SPI Clock Domain) 
reg       r_RX_DV;     // Data Valid pulse (1 clock cycle) 
reg [7:0] r_RX_Byte;   // Byte received on MISO 


reg [$clog2(CLKS_PER_HALF_BIT)-1:0] r_SPI_Clk_Count; 
reg r_SPI_Clk; 
reg r_SPI_Clk_d;
reg [5:0] r_SPI_Clk_Edges; 
wire w_Leading_Edge; 
wire w_Trailing_Edge; 
reg       r_TX_DV; 
reg [23:0] r_TX_Byte; 





///////////////////////
reg r_rd_wr_flag;
reg r_SPI_CS;
reg [(CLKS_PER_HALF_BIT-1):0] r_SPI_CS_d;





always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L)  
    begin
        r_SPI_Clk<=1'b0;
        r_SPI_Clk_Edges <= 6'd48;// 3byte
        r_SPI_Clk_Count<=0;
        r_SPI_CS<=0;
    end
    else
    begin
        if(i_TX_DV)
        begin
            r_SPI_CS<=1'b1;
            r_SPI_Clk_Edges <= 6'd48; 
            r_SPI_Clk_Count<=0;
            r_SPI_Clk<=0;
        end
        else
        begin
            r_SPI_CS<=((r_SPI_Clk_Edges==0)&&(r_SPI_Clk_Count==CLKS_PER_HALF_BIT-2))?1'b0:r_SPI_CS;
        
            r_SPI_Clk<=((r_SPI_Clk_Count == CLKS_PER_HALF_BIT-1)&&r_SPI_CS)?(~r_SPI_Clk):r_SPI_Clk;
            if(r_SPI_CS)
            begin                
                if (r_SPI_Clk_Count == CLKS_PER_HALF_BIT-1 )
                begin
                    r_SPI_Clk_Count <= 0;
                    r_SPI_Clk_Edges <= r_SPI_Clk_Edges - 6'b1;
                end
                else
                begin
                    r_SPI_Clk_Count <= r_SPI_Clk_Count + 1;
                    r_SPI_Clk_Edges <= r_SPI_Clk_Edges;
                end
            end
            else
            begin
                r_SPI_Clk_Count <= r_SPI_Clk_Count;
                r_SPI_Clk_Edges <= r_SPI_Clk_Edges;
            end
        end
    end
end
always @(posedge i_Clk or negedge i_Rst_L) 
begin
    if (~i_Rst_L) 
        r_SPI_Clk_d<=0;
    else
        r_SPI_Clk_d<=r_SPI_Clk;
end
assign w_Leading_Edge=r_SPI_Clk&&~r_SPI_Clk_d;
assign w_Trailing_Edge=~r_SPI_Clk&&r_SPI_Clk_d;
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L) 
        r_SPI_CS_d<=0;
    else
        r_SPI_CS_d<={r_SPI_CS_d[(CLKS_PER_HALF_BIT-2):0],r_SPI_CS};
end
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L) 
        o_SPI_CS_n<=0;
    else
        o_SPI_CS_n<=~(r_SPI_CS_d[CLKS_PER_HALF_BIT-1]||r_SPI_CS);
end
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L) 
        o_TX_Ready<=1'b1;
    else
        if(i_TX_DV)
            o_TX_Ready<=1'b0;
        else
            o_TX_Ready<=r_SPI_CS_d[CLKS_PER_HALF_BIT-1]&&(~r_SPI_CS_d[CLKS_PER_HALF_BIT-2])?1'b1:o_TX_Ready;
end


  // Purpose: Register i_TX_Byte when Data Valid is pulsed. 
  // Keeps local storage of byte in case higher level module changes the data 
  always @(posedge i_Clk or negedge i_Rst_L) 
  begin 
    if (~i_Rst_L) 
    begin 
      r_TX_Byte <= 24'h00; 
      r_TX_DV   <= 1'b0; 
      o_SPI_MOSI <= 1'b0;
    end 
    else 
      begin 
        r_TX_DV <= i_TX_DV; // 1 clock cycle delay 
        if (i_TX_DV) 
        begin 
           r_TX_Byte <= i_TX_Byte; 
           o_SPI_MOSI<= 1'b0;
        end 
        else
        begin
           if(w_Leading_Edge)
           begin
               r_TX_Byte<={r_TX_Byte[22:0],1'b0};
               o_SPI_MOSI<=r_TX_Byte[23];
           end
           else
           begin
               r_TX_Byte<=r_TX_Byte;
               o_SPI_MOSI<=o_SPI_MOSI;
           end
        end
      end // else: !if(~i_Rst_L) 
  end // always @ (posedge i_Clk or negedge i_Rst_L) 


  // Purpose: Generate MOSI data 
  // Works with both CPHA=0 and CPHA=1 
  


always @(posedge i_Clk or negedge i_Rst_L) 
begin 
  if (~i_Rst_L) 
      r_rd_wr_flag <= 1;
  else
      r_rd_wr_flag<=r_TX_DV?i_TX_Byte[23]:r_rd_wr_flag;
end


  // Purpose: Read in MISO data. 
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L) 
    begin 
      r_RX_Byte      <= 8'h00; 
      r_RX_DV        <= 1'b0; 
    end 
    else 
    begin 
      // Default Assignments  
      if ((~r_SPI_CS)|r_rd_wr_flag) // Check if ready is high, if so reset bit count to default 
      begin 
        r_RX_DV   <= 1'b0;
        r_RX_Byte <= 8'h00;
      end 
      else 
      begin
          r_RX_Byte <= ((w_Trailing_Edge) &&(r_SPI_Clk_Edges<6'd16))?{r_RX_Byte[6:0],i_SPI_MISO}:r_RX_Byte;  // Sample data 
          r_RX_DV <= ((w_Trailing_Edge) &&(r_SPI_Clk_Edges==6'd0));  // Sample data 
      end
    end 
end 
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
    if (~i_Rst_L) 
    begin 
      o_RX_Byte      <= 8'h00; 
      o_RX_DV        <= 1'b0; 
    end 
    else     
    begin 
      o_RX_Byte      <= r_RX_DV?r_RX_Byte:o_RX_Byte; 
      o_RX_DV        <= r_RX_DV; 
    end 
end

// Purpose: Add clock delay to signals for alignment. 
always @(posedge i_Clk or negedge i_Rst_L) 
begin 
  if (~i_Rst_L) 
  begin 
    o_SPI_Clk  <= 1'd0; 
  end 
  else 
  begin 
      o_SPI_Clk <= r_SPI_Clk; 
  end // else: !if(~i_Rst_L) 
end // always @ (posedge i_Clk or negedge i_Rst_L) 




endmodule // SPI_Master 