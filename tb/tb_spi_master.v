`timescale 1ns / 1ps

module tb_spi_master();

    // 1. Signals to connect to the Unit Under Test (UUT)
    reg iclk;
    reg miso;
    
    wire sclk;
    wire mosi;
    wire cs;
    wire [14:0] acl_data;

    // 2. Instantiate the SPI Master
    spi_master uut (
        .iclk(iclk),
        .miso(miso),
        .sclk(sclk),
        .mosi(mosi),
        .cs(cs),
        .acl_data(acl_data)
    );

    // 3. Generate the 4MHz Clock (250ns period -> 125ns high, 125ns low)
    always #125 iclk = ~iclk;

    // 4. Mock Sensor Data (What the "sensor" will reply with)
    // We will send a distinct pattern so you can easily spot it in the waveform.
    // X-Axis = 0x1A2, Y-Axis = 0x3B4, Z-Axis = 0x5C6
    reg [47:0] dummy_sensor_data = 48'h1A_22_3B_44_5C_66;
    integer bit_idx;

    // 5. Main Simulation Sequence
    initial begin
        // Initialize everything to zero
        iclk = 0;
        miso = 0;
        bit_idx = 47;

        $display("--- SIMULATION STARTED ---");

        // Wait for POWER_UP to finish (6ms real time)
        // Note: In simulation, this will take about 24,000 clock cycles.
        $display("Waiting for Power Up Phase...");
        wait(cs == 0); 
        $display("Sensor woken up! SPI_WRITE phase started.");

        // Wait for SPI_WRITE to finish
        wait(cs == 1);
        $display("Write Command Finished. Waiting for Measurement (WAIT_MEAS)...");

        // Wait for WAIT_MEAS to finish and SPI_READ to begin
        wait(cs == 0);
        $display("Read Command Started! Master is talking...");

        // 6. The "Mock Sensor" Logic
        // The master sends 16 bits of command first. We ignore those in this simple TB.
        // We wait for 16 SPI clock cycles to pass.
        repeat(16) @(negedge sclk);
        
        $display("Master finished asking. Sensor (Testbench) is now sending data on MISO...");

        // Now, we blast the 48 bits of fake data back to the master on the MISO line.
        // A real SPI sensor changes data on the falling edge of the clock.
        for (bit_idx = 47; bit_idx >= 0; bit_idx = bit_idx - 1) begin
            miso = dummy_sensor_data[bit_idx];
            @(negedge sclk); // Wait for the next falling edge to send the next bit
        end

        // Ensure MISO goes back to 0 after transmission
        miso = 0;

        // Wait for the master to process the data and update the final output
        wait(cs == 1);
        $display("Read Cycle Complete.");
        
        // Wait a few more clock cycles so the waveform captures the final `acl_data` update
        #1000;
        
        $display("Final Extracted Data (acl_data): %b", acl_data);
        $display("--- SIMULATION FINISHED ---");
        
        $stop; // Stop the simulator
    end

endmodule