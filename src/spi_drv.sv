
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
