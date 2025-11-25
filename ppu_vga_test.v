
module ppu_vga_test (
	input CLOCK_50,      // from Cyclone V
	input reset,           //button on FPGA
	//input [7:0] sw,       // 12 bits for color - set by switches on FPGA
	output hsync, 
	output vsync,
	//output [7:0] rgb,     // 12 FPGA pins for RGB(4 per color)
	output [7:0] red,
	output [7:0] green,
	output [7:0] blue,
	output clock_25,
	output VGA_BLANK_N
	);




	//wire reset_btn = reset;  // if reset_btn is active-low
	wire ppu_clk;
	wire [9:0] h, v;
	wire [23:0] color;
	
	// Signal Declaration
	reg [7:0] rgb_reg;    // register for 12-bit RGB DAC 
	//wire bright;         // Same signal as in controller
	//wire clock_25;

	 // Clock generators; creating 25MHz VGA input clock
	 clock_generators clks (.clk_50(CLOCK_50), .clk_25(clock_25), .clk_5(ppu_clk), .clk_2());
  
    // Instantiate VGA Controller
    vga_controller vga_c(.clk(clock_25), .reset(~reset), .hSync(hsync), .vSync(vsync),
                         .bright(VGA_BLANK_N), .hCount(h), .vCount(v));

		/*
		ppu test_ppu (
			 .clk(ppu_clk),
			 .reset(reset_btn),
			 .rendering(VGA_BLANK_N),
			 .cpu_oam_data(32'b0),           // Add default values
			 .cpu_oam_addr(6'b0),            // Add default values  
			 .cpu_write(1'b0),
			 .oam_out(),                     // Leave unconnected if not needed
			 .PPUCTRL(8'b0),
			 .hCount(h),
			 .vCount(v),
			 .rgb(color)
		);
		
		*/
		
		// Hold writes until reset has been low (released) for several clocks
		reg [7:0] init_cnt;
		always @(posedge clock_25 or negedge reset) begin
			 if (!reset)
				  init_cnt <= 8'd0;
			 else if (init_cnt != 8'd100)
				  init_cnt <= init_cnt + 1'b1;
		end

		// Assert write during counts 20–40 after reset is released
		wire cpu_write_enable = (init_cnt >= 8'd20 && init_cnt <= 8'd40);

    // Sprite 0 at (100,100), tile 0, palette base 1
    localparam [31:0] SPRITE0_DATA = 32'h01_00_64_64;

    ppu test_ppu (
        .clk(clock_25),
        .reset(reset),
        .rendering(VGA_BLANK_N),            // 1 in visible area

        .cpu_oam_data(SPRITE0_DATA),
        .cpu_oam_addr(6'd0),                // sprite index 0
        .cpu_write(cpu_write_enable),             // single write at startup

        .oam_out(),
        .PPUCTRL(8'b0),                     // background palette base 0
        .hCount(h),
        .vCount(v),
        .rgb(color)
    );

    // CPU/OAM interface to be tested still 

    
    // Output
	 assign red = (VGA_BLANK_N) ? color[23:16] : 8'b0; //5'b0, sw[7:5]} : 8'b0;
	 assign green = (VGA_BLANK_N) ? color[15:8] : 8'b0;//{5'b0, sw[4:2]} : 8'b0;
	 assign blue = (VGA_BLANK_N) ? color[7:0] : 8'b0; //{6'b0, sw[1:0]} : 8'b0;
	 
	 
endmodule