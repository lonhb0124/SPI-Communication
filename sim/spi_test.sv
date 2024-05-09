`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/06/2024 01:41:32 PM
// Design Name: 
// Module Name: spi_test
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
// This is the testbench to test main SPI module.
// I used simple slave module to check if master and slave communicate properly.
// Tested with 8, 12, 20, 32 SCLK pulse. 
// fetch new instruction and data to both Master and Slave
// there is delay SPI end and new SPI start (trace_count)
// trace_count=100 means 200ns delay 
// Check the result if SPI suceed or not
// output master :tx_data
// input master : rx_miso
// output slave : MISO_reg
// input slave : MOSI_reg
// When output master has same value as input slave and 
// input master has same value as output slave test is passed
//////////////////////////////////////////////////////////////////////////////////

module spi_test (

    );
    
    parameter integer CLK_DIVIDE = 100;
    parameter integer SPI_MAXLEN = 32;
    logic clk;
    logic sresetn;
    
    // Command interface 
    logic start_cmd;
    logic spi_drv_rdy;
    logic [$clog2(SPI_MAXLEN):0] n_clks;
    logic [SPI_MAXLEN-1:0] tx_data; // output master
    logic [SPI_MAXLEN-1:0] rx_miso; // input master
    logic [SPI_MAXLEN-1:0] test_data;
    
    // SPI pins
    logic SCLK;
    logic MOSI;
    logic MISO;
    logic SS_N;
    
    spi_drv dut (
        .clk(clk),
        .sresetn(sresetn),
        // Command interface 
        .start_cmd(start_cmd),
        .spi_drv_rdy(spi_drv_rdy),
        .n_clks(n_clks),
        .tx_data(tx_data),
        .rx_miso(rx_miso),
        // SPI pins
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .SS_N(SS_N)
    );
    
    slave slave1 (
        .SCLK(SCLK),
        .MOSI(MOSI),
        .MISO(MISO),
        .SS_N(SS_N),
        .test_data(test_data),
        .n_clks(n_clks)
    );   
    

logic trace_count_en;
logic [63:0] trace_count;
logic cmd_en;
    
    initial begin
        clk = 0;
        sresetn = 1;
        // 8 bits case
        test_data = 32'b11001100;
        tx_data = 32'b11001100;
        n_clks = 8;
        
        // 12 bits case
        /*test_data = 32'b110011001010;
        tx_data = 32'b110011001010;
        n_clks = 12;*/
        
        // 20 bits case
        /*test_data = 32'b11001100101011001100;
        tx_data = 32'b11001100101011001100;
        n_clks = 20;*/
        
        // 32 bits case
        /*test_data = 32'b11001100101011001100110011001010;
        tx_data = 32'b11001100101011001100110011001010;
        n_clks = 32;*/
        
        trace_count = 0;
        trace_count_en = 0;
        cmd_en = 1;
        #20 sresetn = 0;
    end
    
    always #1 clk = ~clk;

    // fetch new instruction and data to both Master and Slave
    // there is delay SPI end and new SPI start (trace_count)
    // trace_count=100 means 200ns delay 
    always @(posedge clk) 
    begin
        if (spi_drv_rdy && cmd_en) begin
            start_cmd <= 1;
            cmd_en <= 0;
            trace_count <= 0;
        end 
        else if (spi_drv.SPI_done && !cmd_en) begin
            trace_count_en <= 1;
            start_cmd <= 0; 
        end 
        else if (trace_count_en && trace_count == 100) begin
            trace_count_en <= 0;
            cmd_en <= 1;
            test_data <= test_data + 1;
            tx_data <= tx_data + 4;
        end 
        else if (trace_count_en && trace_count != 100) begin
            trace_count <= trace_count + 1;
        end   
    end
    
    
    // Check the result if SPI suceed or not
    // output master :tx_data
    // input master : rx_miso
    // output slave : MISO_reg
    // input slave : MOSI_reg
    always @(posedge clk) 
    begin  
        if (spi_drv.SPI_done) begin
            if (tx_data == slave.MOSI_reg && rx_miso == slave.MISO_reg) begin
                $display("[ passed ]");
            end
            else begin
                $display("[ failed ]");
                $display("-------------------------------------");
                $display("tx_data       MOSI_reg       rx_miso       MISO_reg");
                $display("-------------------------------------");
                $display("%h            %h              %h            %h", tx_data, slave.MOSI_reg, rx_miso, slave.MISO_reg);  
            end
        end
    end
    
    
endmodule
