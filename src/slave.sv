`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2024 02:42:59 PM
// Design Name: 
// Module Name: slave
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
// This is simple slave module for the testing main master module 
// Work opposite to Master
// Set new MISO values on SCLK falling edges and receive MOSI input bits on the rising edges of SCLK.
// For the testing, I assume that slave module transfer/receive same the number of bits and SCLK.
// The slave send test_data to Master through MISO get the data through MOSI and store it.
//////////////////////////////////////////////////////////////////////////////////

module slave #(
    parameter integer               CLK_DIVIDE  = 100, // Clock divider to indicate frequency of SCLK
    parameter integer               SPI_MAXLEN  = 32   // Maximum SPI transfer length
) (
    input SCLK,
    input MOSI,
    output logic MISO,
    input SS_N,
    input logic [SPI_MAXLEN-1:0] test_data,
    input [$clog2(SPI_MAXLEN):0] n_clks // assume slave transmit the same the number of bits
    );

logic [SPI_MAXLEN-1:0] MOSI_reg;
logic [SPI_MAXLEN-1:0] MISO_reg;
logic [$clog2(SPI_MAXLEN):0] n_clks_reg_counter;

assign MISO_reg = SS_N ? test_data : MISO_reg;

initial begin
    n_clks_reg_counter = 0;
    MOSI_reg = 0;
end

always @(posedge SCLK) begin
    if (!SS_N) begin 
        MOSI_reg[n_clks_reg_counter] <= MOSI;
        if (n_clks_reg_counter != 0) begin
            n_clks_reg_counter <= n_clks_reg_counter - 1;
        end
    end
end

always @(negedge SCLK or negedge SS_N) begin
    if (!SS_N) begin 
        MISO <= MISO_reg[n_clks_reg_counter];
    end
end

always @(SS_N) begin
    n_clks_reg_counter = n_clks-1;
end


    
    
    
endmodule
