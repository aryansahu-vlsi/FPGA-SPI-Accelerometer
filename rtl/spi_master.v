`timescale 1ns / 1ps

module spi_master(
    input wire iclk,            // 4MHz Input Clock (from iclk_gen)
    input wire miso,            // Master In Slave Out (from sensor)
    output wire sclk,           // 1MHz SPI Clock
    output reg mosi = 1'b0,     // Master Out Slave In (to sensor)
    output reg cs = 1'b1,       // Slave Chip Select (active low)
    output wire [14:0] acl_data // 15-bit final output to Top Module
);

    // --------------------------------------------------------
    // State Machine & Timers
    // --------------------------------------------------------
    localparam POWER_UP   = 3'd0,
               SPI_WRITE  = 3'd1,
               WAIT_MEAS  = 3'd2,
               SPI_READ   = 3'd3,
               END_SPI    = 3'd4;

    reg [2:0] state = POWER_UP;
    reg [31:0] timer = 32'b0;
    reg [7:0]  bit_count = 8'b0;

    // ADXL362 Commands: Write 0x02 to Register 0x2D to begin measurement
    reg [23:0] tx_write_data = {8'h0A, 8'h2D, 8'h02}; 
    // ADXL362 Commands: Read starting at Register 0x0E (X-axis LSB)
    reg [15:0] tx_read_cmd   = {8'h0B, 8'h0E};        
    reg [47:0] rx_read_data  = 48'b0;                 

    reg [14:0] final_data = 15'b0;
    assign acl_data = final_data;

    // Clock phase tracker for CPOL=0, CPHA=0
    reg [1:0] clk_phase = 2'b0;
    reg sclk_reg = 1'b0;
    assign sclk = sclk_reg;

    // --------------------------------------------------------
    // Main 4-Phase SPI Logic
    // --------------------------------------------------------
    always @(posedge iclk) begin
        case (state)
            POWER_UP: begin
                cs <= 1'b1;
                sclk_reg <= 1'b0;
                if (timer >= 32'd24000) begin // 6ms delay at 4MHz
                    state <= SPI_WRITE;
                    timer <= 0;
                    bit_count <= 24; 
                    cs <= 1'b0;       // Pull CS low to wake sensor
                    clk_phase <= 2'b0;
                end else begin
                    timer <= timer + 1;
                end
            end

            SPI_WRITE: begin
                clk_phase <= clk_phase + 1;
                
                if (clk_phase == 2'b00) begin
                    mosi <= tx_write_data[bit_count - 1]; // Setup MOSI on falling edge
                    sclk_reg <= 1'b0;
                end
                else if (clk_phase == 2'b01) begin
                    sclk_reg <= 1'b1; // Rising edge
                end
                else if (clk_phase == 2'b10) begin
                    sclk_reg <= 1'b1; // Hold High
                end
                else if (clk_phase == 2'b11) begin
                    sclk_reg <= 1'b0; // Falling edge
                    
                    if (bit_count > 1) begin
                        bit_count <= bit_count - 1;
                    end else begin
                        state <= WAIT_MEAS;
                        cs <= 1'b1;   // Bring CS high to execute the write command
                        mosi <= 1'b0;
                    end
                end
            end

            WAIT_MEAS: begin
                if (timer >= 32'd160000) begin // 40ms delay for first valid reading
                    state <= SPI_READ;
                    timer <= 0;
                    bit_count <= 64;  // 16 bits of command + 48 bits of data
                    cs <= 1'b0;       // Pull CS low to start read
                    clk_phase <= 2'b0;
                end else begin
                    timer <= timer + 1;
                end
            end

            SPI_READ: begin
                clk_phase <= clk_phase + 1;
                
                if (clk_phase == 2'b00) begin
                    sclk_reg <= 1'b0;
                    // Setup MOSI while sending the 16-bit command
                    if (bit_count > 48) mosi <= tx_read_cmd[bit_count - 49]; 
                    else mosi <= 1'b0;
                end
                else if (clk_phase == 2'b01) begin
                    sclk_reg <= 1'b1; // Rising edge
                end
                else if (clk_phase == 2'b10) begin
                    sclk_reg <= 1'b1;
                    // Sample MISO securely in the middle of the HIGH pulse
                    if (bit_count <= 48) rx_read_data[bit_count - 1] <= miso;
                end
                else if (clk_phase == 2'b11) begin
                    sclk_reg <= 1'b0; // Falling edge
                    if (bit_count > 1) begin
                        bit_count <= bit_count - 1;
                    end else begin
                        state <= END_SPI;
                        cs <= 1'b1;  // End read transmission
                    end
                end
            end

            END_SPI: begin
                // Latch the data using the correct byte order AND correct bit order for seg7_control
                final_data <= { 
                    rx_read_data[47], rx_read_data[35:32], // X Sign, X Magnitude [14:10]
                    rx_read_data[31], rx_read_data[19:16], // Y Sign, Y Magnitude [9:5]
                    rx_read_data[15], rx_read_data[3:0]    // Z Sign, Z Magnitude [4:0]
                };
                
                if (timer >= 32'd40000) begin // 10ms wait before next read
                    state <= SPI_READ;
                    timer <= 0;
                    bit_count <= 64;
                    cs <= 1'b0;
                    clk_phase <= 2'b0;
                end else begin
                    timer <= timer + 1;
                end
            end
        endcase
    end
endmodule