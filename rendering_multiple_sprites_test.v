// Tests multiple Sprites rendering and moving down the screen

module ppu_vga_test (
    input  CLOCK_50,       // 50 MHz from Cyclone V
    input  reset,          // ACTIVE-LOW reset button on FPGA
    output hsync,  
    output vsync,
    output [7:0] red,
    output [7:0] green,
    output [7:0] blue,
    output clock_25,
    output VGA_BLANK_N
);

    // Treat 'reset' as ACTIVE-LOW everywhere
    wire reset_n = reset;      // 0 = reset asserted
    wire reset_h = ~reset_n;   // 1 = reset asserted

    wire [9:0] h, v;
    wire [23:0] color;

    // Clock generators generates clock_25 from CLOCK_50
    wire ppu_clk_dummy;
    wire clk_2_dummy;

    clock_generators clks (
        .clk_50(CLOCK_50),
        .clk_25(clock_25),
        .clk_5(ppu_clk_dummy),
        .clk_2(clk_2_dummy)
    );
  
    // VGA Controller
    vga_controller vga_c (
        .clk(clock_25),
        .reset(reset_h),       // active-high reset for VGA !!! REMEMBER THIS, fix or nah
        .hSync(hsync),
        .vSync(vsync),
        .bright(VGA_BLANK_N),  // 1 = visible, 0 = blank
        .hCount(h),
        .vCount(v)
    );

    // Fake CPU that moves sprite 0 from top to bottom
    // Sprite layout in OAM: [X, Y, PatternIndex, PaletteIndex]
    localparam [7:0] SPR_X     = 8'd100;  // fixed X position
    // **UPDATE**: Use Tile Index 1
    localparam [7:0] SPR_TILE  = 8'd5;    
    // **UPDATE**: Use Palette Index 0
    localparam [7:0] SPR_PAL   = 8'd1;  

	     // Sprite layout in OAM: [X, Y, PatternIndex, PaletteIndex]
    localparam [7:0] SPR2_X     = 8'd240;  // fixed X position
    // **UPDATE**: Use Tile Index 1
    localparam [7:0] SPR2_TILE  = 8'd5;    
    // **UPDATE**: Use Palette Index 0
    localparam [7:0] SPR2_PAL   = 8'd1; 

    reg  [7:0] sprite_y;
	 
	 reg  [7:0] sprite2_y;
	 
	 reg  [5:0] sprite_oam_index;
    // Counter for slow movement at 50 MHz
    reg [23:0] move_counter; 
    localparam [23:0] SPR1_MOVE_DIVISOR = 24'd1000000; // Move 1 pixel every 1,000,000 cycles (0.02s)
	 localparam [23:0] SPR2_MOVE_DIVISOR = 24'd500000; // Move 1 pixel every 1,000,000 cycles (0.02s) //a number the other diversor will never be
    reg         cpu_write_r;
    reg         initialized;

    // OAM data word: [31:24]=PaletteIndex, [23:16]=PatternIndex, [15:8]=Y, [7:0]=X
	 reg  [7:0] current_x, current_y;
    wire [31:0] cpu_oam_data_word = { SPR_PAL, SPR_TILE, current_y, current_x };
	 wire [5:0] oam_index = sprite_oam_index;

    // Use CLOCK_50 for the CPU/Control logic
    always @(posedge CLOCK_50 or negedge reset_n) begin
        if (!reset_n) begin
            // ACTIVE-LOW reset: restart animation and clear state
            sprite_y     <= 8'd0;
				sprite2_y     <= 8'd0;
            move_counter <= 24'd0;
            cpu_write_r  <= 1'b0;
            initialized  <= 1'b0;
        end else begin
            // Default: no write this cycle
            cpu_write_r <= 1'b0;

            if (!initialized) begin
                // Initialize state and perform first OAM write
                initialized <= 1'b1;
                sprite_y    <= 8'd0;
                cpu_write_r <= 1'b1;    
            end else begin
                // Slow movement
                move_counter <= move_counter + 1'b1;

                if (move_counter == SPR1_MOVE_DIVISOR) begin
                    move_counter <= 24'd0; // Reset counter
                    
                    // Move down; max Y to stay visible on 240px screen is 224 (240 - 16)
                    if (sprite_y < 8'd224) 
                        sprite_y <= sprite_y + 1'b1;
                    else
                        sprite_y <= 8'd0;
						  current_y <= sprite_y;
						  current_x <= SPR_X;
                    cpu_write_r <= 1'b1;          // one-cycle write to OAM
						  sprite_oam_index <= 6'b0;
                end else if (move_counter == SPR2_MOVE_DIVISOR) begin

						  if (sprite2_y < 8'd224) 
                        sprite2_y <= sprite2_y + 1'b1;
                    else
                        sprite2_y <= 8'd0;
						  
						  current_y <= sprite2_y;
						  current_x <= SPR2_X;
                    cpu_write_r <= 1'b1;          // one-cycle write to OAM
						  sprite_oam_index <= 6'b1;
                end
				  
            end
        end
    end

    // PPU instance
    ppu test_ppu (
        .clk(clock_25),
        .reset(reset_n),       // PPU reset is ACTIVE-LOW
        .rendering(VGA_BLANK_N), // 1 when VGA is in visible area

        .cpu_oam_data(cpu_oam_data_word),
        .cpu_oam_addr(sprite_oam_index),   // sprite index 0
        .cpu_write(cpu_write_r), // one-cycle write strobe

        .oam_out(),            // unused in this test
        .PPUCTRL(8'b0),        // background palette base 0 (using same base)
        .hCount(h),
        .vCount(v),
        .rgb(color)
    );

    // RGB output
    assign red   = VGA_BLANK_N ? color[23:16] : 8'b0;
    assign green = VGA_BLANK_N ? color[15:8]  : 8'b0;
    assign blue  = VGA_BLANK_N ? color[7:0]   : 8'b0;

endmodule
