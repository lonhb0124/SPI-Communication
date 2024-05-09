// SPI Master Module
//
//  This module is used to implement a SPI master. The host will want to transmit a certain number
// of SCLK pulses. This number will be placed in the n_clks port. It will always be less than or
// equal to SPI_MAXLEN.
//
// SPI bus timing
// --------------
// This SPI clock frequency should be the host clock frequency divided by CLK_DIVIDE. This value is
// guaranteed to be even and >= 4. SCLK should have a 50% duty cycle. The slave will expect to clock
// in data on the rising edge of SCLK; therefore this module should output new MOSI values on SCLK
// falling edges. Similarly, you should latch MISO input bits on the rising edges of SCLK.
//
//  Example timing diagram for n_clks = 4:
//  SCLK        ________/-\_/-\_/-\_/-\______ 
//  MOSI        ======= 3 | 2 | 1 | 0 =======
//  MISO        ======= 3 | 2 | 1 | 0 =======
//  SS_N        ------\_______________/------
//
// Command Interface
// -----------------
// The data to be transmitted on MOSI will be placed on the tx_data port. The first bit of data to
// be transmitted will be bit tx_data[n_clks-1] and the last bit transmitted will be tx_data[0].
//  On completion of the SPI transaction, rx_miso should hold the data clocked in from MISO on each
// positive edge of SCLK. rx_miso[n_clks-1] should hold the first bit and rx_miso[0] will be the last.
//
//  When the host wants to issue a SPI transaction, the host will hold the start_cmd pin high. While
// start_cmd is asserted, the host guarantees that n_clks and tx_data are valid and stable. This
// module acknowledges receipt of the command by issuing a transition on spi_drv_rdy from 1 to 0.
// This module should then being performing the SPI transaction on the SPI lines. This module indicates
// completion of the command by transitioning spi_drv_rdy from 0 to 1. rx_miso must contain valid data
// when this transition happens, and the data must remain stable until the next command starts.
//
//////////////////////////////////////////////////////////////////////////////////
// SPI module has 3 state and updated in every positive edge of clk
// 1. STATE_IDLE: 
// Check if cmd is ready or not (cmd is ready if both start_cmd and spi_drv_rdy are 1). 
// When cmd is ready, store n_clks and tx_data in register and go to next state.
// 
// 2. STATE_CMD: 
// Set the counter for n_clks (the number of SCLK pulse) and check if both n_clks and tx_data are stable.
// If they are stable, start SPI (set spi_drv_rdy and SS_N as 0), set first MOSI, and go to next state.
// 
// 3. STATE_SPI
// When SCLK falling edge, set new MOSI data.
// When SCLK rising edge, get MISO from Slave and check the number of SCLK pulse remains. 
// If there is no SCLK pulse remained, set data_transfer_done as 1.
// When SPI_done is 1, it goes to STATE_IDLE and finish SPI with setting SS_N as 1 and spi_drv_rdy as 1 to get new data  
//
//
// * Clock Divider
// Clock divider only enable during SPI transaction (when SS_N is 0)
// It count 100 and set SCLK (0 or 1). To determine SCLK rising and falling edge, I used SCLK_previous variable.
// When data_transfer_done, set SPI_done 1 to finish SPI.
//////////////////////////////////////////////////////////////////////////////////

module spi_drv #(
    parameter integer               CLK_DIVIDE  = 100, // Clock divider to indicate frequency of SCLK
    parameter integer               SPI_MAXLEN  = 32   // Maximum SPI transfer length
) (
    input                           clk,
    input                           sresetn,        // active low reset, synchronous to clk
    
    // Command interface 
    input                           start_cmd,     // Start SPI transfer
    output logic                         spi_drv_rdy,   // Ready to begin a transfer
    input  [$clog2(SPI_MAXLEN):0]   n_clks,        // Number of bits (SCLK pulses) for the SPI transaction
    input  [SPI_MAXLEN-1:0]         tx_data,       // Data to be transmitted out on MOSI
    output logic [SPI_MAXLEN-1:0]         rx_miso,       // Data read in from MISO
    
    // SPI pins
    output logic                         SCLK,          // SPI clock sent to the slave
    output logic                          MOSI,          // Master out slave in pin (data output to the slave)
    input                            MISO,          // Master in slave out pin (data input from the slave)
    output logic                         SS_N           // Slave select, will be 0 during a SPI transaction
);

localparam STATE_IDLE = 2'd0;
localparam STATE_CMD = 2'd1;
localparam STATE_SPI = 2'd2;


logic [1:0] state_reg, state_next;
logic cmd_ready;
logic data_check;
logic data_transfer_done;
logic SCLK_rise;
logic SCLK_fall; 
logic SPI_done; 

logic [SPI_MAXLEN-1:0] tx_data_reg;
logic [$clog2(SPI_MAXLEN):0] n_clks_reg;


assign cmd_ready = start_cmd && spi_drv_rdy;
assign data_check = (tx_data == tx_data_reg) || (n_clks_reg == n_clks); // valid and stable check

logic [$clog2(CLK_DIVIDE):0] CLK_DIVIDE_counter;
logic SCLK_previous;
logic [$clog2(SPI_MAXLEN):0] n_clks_reg_counter;

// state 
always @(posedge clk) begin
    if (sresetn) begin state_reg <= STATE_IDLE; end
    else begin state_reg <= state_next; end 
end 

// clock divider
always @(posedge clk) begin
    //$display("CLK_DIVIDE_counter %d", CLK_DIVIDE_counter);
    if (!SS_N) begin
        if (CLK_DIVIDE_counter == CLK_DIVIDE) begin
            if (data_transfer_done) begin
                SPI_done <= 1;
            end 
            SCLK <= ~SCLK;
            CLK_DIVIDE_counter <= 1;
        end
        
        else begin
            CLK_DIVIDE_counter <= CLK_DIVIDE_counter + 1;
        end
    end
        
    else begin 
        SCLK <= 0;
        SPI_done <= 0;
        CLK_DIVIDE_counter <= 1;
    end 
    
    SCLK_previous <= SCLK;
end 

// check rising or falling edge of SCLK
assign SCLK_rise = SCLK && !SCLK_previous;
assign SCLK_fall = !SCLK && SCLK_previous;

// state transition
always @(*) begin
    //$display("state_reg %d", state_reg);
    state_next = state_reg;
    case (state_reg)
        STATE_IDLE: if (cmd_ready) begin state_next = STATE_CMD; end
        STATE_CMD : if (!SS_N) begin state_next = STATE_SPI; end 
        STATE_SPI : if (SPI_done) begin state_next = STATE_IDLE; end
        
    
    endcase

end 

// main datapath
always @(*) begin
    case (state_reg)
        STATE_IDLE: if (cmd_ready) begin 
                       tx_data_reg = tx_data; 
                       n_clks_reg = n_clks; // store number of SCLK pulse
                       rx_miso = 0;
                    end
                    
                    else begin
                       spi_drv_rdy = 1;
                       SS_N = 1;
                       data_transfer_done = 0;
                    end
                    
        STATE_CMD: begin 
                   if (data_check) begin 
                        spi_drv_rdy = 0;
                        SS_N = 0; 
                        MOSI = tx_data[n_clks_reg_counter];
                        end
                   n_clks_reg_counter = n_clks_reg - 1;
                   end
                    
        
        STATE_SPI : if (SCLK_fall) begin // write falling edge
                        MOSI = tx_data[n_clks_reg_counter];
                        //$display("tx_data[n_clks_reg_counter] %d, n_clks_reg_counter%d, MOSI %d", tx_data[n_clks_reg_counter-1], n_clks_reg_counter, MOSI);
                    end 
                    
                    else if (SCLK_rise) begin // read rising edge
                        rx_miso[n_clks_reg_counter] = MISO;
                        if (n_clks_reg_counter == 0) begin
                            data_transfer_done = 1;
                        end 
                        else if (n_clks_reg_counter != 0) begin
                            n_clks_reg_counter = n_clks_reg_counter - 1;
                        end 
                       // $display("rx_miso[n_clks_reg_counter] %d, n_clks_reg_counter%d, MISO %d", rx_miso[n_clks_reg_counter-1], n_clks_reg_counter, MISO); 
                    end
        default : begin
                    spi_drv_rdy = 1;
                    SS_N = 1;
                    data_transfer_done = 0;
                    rx_miso = 0;
                    tx_data_reg = 0;
                    n_clks_reg = 0;
                    n_clks_reg_counter = 0;
                  end
    endcase

end 


endmodule
