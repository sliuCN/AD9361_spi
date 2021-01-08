module SPI_command_test(
    input i_Clk_n,
    input i_Clk_p,
    input i_Rst,//default low
    output SPI_CS,
    input SPI_MISO,
    output SPI_MOSI,
    output SPI_CLK,
    output RESETB,
    output reg [3:0] LED_SHOW
    );
assign RESETB = 1'b1;
parameter HALF_BIT=4;
wire Tx_ready;
reg [11:0] address = 12'h002;
reg [23:0] Tx_Byte;
reg Tx_DV;
wire Rx_DV;
wire [7:0] Rx_Byte;
reg [7:0] DATA_SHOW;
wire i_Clk;
wire test_clk;
wire i_Rst_n;
assign i_Rst_n = ~i_Rst;


//ip core 
//input lvds 200MHz
//clk_out1 = 200MHz
//clk_out2 = 50MHz
clk_wiz_0 clk_inst 
 (
  // Clock out ports
  .clk_out1(i_Clk),
  .clk_out2(test_clk),
 // Clock in ports
  .clk_in1_p(i_Clk_p),
  .clk_in1_n(i_Clk_n)
 );

//breathing led count
reg [22:0] test_count=0;
always @ (posedge test_clk or negedge i_Rst_n)
begin
    if(~i_Rst_n)
        test_count <= 23'd0;
    else
        test_count <= test_count + 23'd1;
end

//spi 
SPI_configure
#(.CLKS_PER_HALF_BIT(HALF_BIT))  spi1
( 
 // Control/Data Signals, 
 .i_Rst_L(i_Rst_n),     // FPGA Reset 
 .i_Clk(i_Clk),       // FPGA Clock 
  
 // TX (MOSI) Signals 
 .i_TX_Byte(Tx_Byte),        // Byte to transmit on MOSI 
 .i_TX_DV(Tx_DV),          // Data Valid Pulse with i_TX_Byte 
 .o_TX_Ready(Tx_ready),       // Transmit Ready for next byte 
 
 // RX (MISO) Signals 
 .o_RX_DV(Rx_DV),     // Data Valid pulse (1 clock cycle) 
 .o_RX_Byte(Rx_Byte),   // Byte received on MISO 

 // SPI Interface 
.o_SPI_Clk(SPI_CLK), 
.o_SPI_CS_n(SPI_CS), 
.i_SPI_MISO(SPI_MISO), 
.o_SPI_MOSI(SPI_MOSI) 
 );
  
//data show control
reg [31:0] step_count;
always @(negedge i_Clk or negedge i_Rst_n) 
begin
    if(~i_Rst_n)
    begin
        step_count <= 32'b0;
        DATA_SHOW <= 8'b0;
        LED_SHOW <= 4'b0001;
    end
    else
    begin
        if(step_count <= 32'd2_000_000_000)
        begin
             step_count <= step_count + 32'd1; 
        end
        else
        begin
              step_count <= step_count;
              LED_SHOW <=  {test_count[22],test_count[21],test_count[22],test_count[21]};
        end
        case (step_count)
            32'd100_000_000: 
            begin 
                Tx_Byte <= {4'd0,address,8'd0};//read 
                Tx_DV <= 1'b1;
            end
            32'd100_000_002:
            begin
                Tx_DV <= 1'b0;
            end
            32'd400_000_000:
            begin
                LED_SHOW <= DATA_SHOW[3:0];
            end
            32'd800_000_000:
            begin
                LED_SHOW <= 4'b0;
            end
            32'd1_000_000_000:
            begin
                LED_SHOW <= 4'b1111;
            end
            32'd1_200_000_000:
            begin
                LED_SHOW <= 4'b0;
            end
            32'd1_400_000_000:
            begin
                LED_SHOW <= DATA_SHOW[7:4];
            end
            default:
            begin
                if(Rx_DV)
                    DATA_SHOW <= Rx_Byte;
                else
                    DATA_SHOW <= DATA_SHOW;
            end 
        endcase
    end
end
endmodule
