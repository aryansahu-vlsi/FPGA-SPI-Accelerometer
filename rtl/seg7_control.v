`timescale 1ns / 1ps

module seg7_control(
    input wire CLK100MHZ,
    input wire [14:0] acl_data,
    output reg [6:0] seg,
    output reg dp,
    output wire [7:0] an
);

    // 1. Extract Data (0-15 max per axis)
    wire [3:0] x_data = acl_data[13:10];
    wire [3:0] y_data = acl_data[8:5];
    wire [3:0] z_data = acl_data[3:0];

    // 2. Refresh Counter (1ms tick per digit)
    reg [2:0] anode_select = 3'b0;
    reg [16:0] anode_timer = 17'b0;

    always @(posedge CLK100MHZ) begin
        if (anode_timer == 17'd99_999) begin
            anode_timer <= 0;
            anode_select <= anode_select + 1;
        end else begin
            anode_timer <= anode_timer + 1;
        end
    end

    // 3. Shift Register for Anodes (Walking Zero)
    // This perfectly replaces the 8-case block for the 'an' output
    assign an = ~(8'b00000001 << anode_select);

    // 4. Multiplex the Data and Signs
    reg [3:0] current_digit;

    always @(*) begin
        // Default states for inactive or blank digits
        dp = 1'b1;              // DP OFF (Active Low)
        current_digit = 4'hA;   // 'A' will be used as our "Turn OFF" code in the decoder

        case(anode_select)
            3'b000: begin current_digit = z_data % 10; dp = ~acl_data[4];  end // Z Ones & Sign
            3'b001: begin current_digit = z_data / 10;                     end // Z Tens
            3'b010: begin current_digit = 4'hA;                            end // Blank
            3'b011: begin current_digit = y_data % 10; dp = ~acl_data[9];  end // Y Ones & Sign
            3'b100: begin current_digit = y_data / 10;                     end // Y Tens
            3'b101: begin current_digit = 4'hA;                            end // Blank
            3'b110: begin current_digit = x_data % 10; dp = ~acl_data[14]; end // X Ones & Sign
            3'b111: begin current_digit = x_data / 10;                     end // X Tens
        endcase
    end

    // 5. Single 7-Segment Decoder
    always @(*) begin
        case(current_digit)
            //                GFEDCBA
            4'd0: seg = 7'b100_0000; // 0
            4'd1: seg = 7'b111_1001; // 1
            4'd2: seg = 7'b010_0100; // 2 
            4'd3: seg = 7'b011_0000; // 3
            4'd4: seg = 7'b001_1001; // 4
            4'd5: seg = 7'b001_0010; // 5
            4'd6: seg = 7'b000_0010; // 6
            4'd7: seg = 7'b111_1000; // 7
            4'd8: seg = 7'b000_0000; // 8
            4'd9: seg = 7'b001_0000; // 9
            default: seg = 7'b111_1111; // All OFF (Used for blanks like 4'hA)
        endcase
    end

endmodule