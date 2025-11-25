
module vga_test (
	input CLOCK_50,      // from Cyclone V
	input reset,           //button on FPGA
	input [7:0] sw,       // 12 bits for color - set by switches on FPGA
	output hsync, 
	output vsync,
	//output [7:0] rgb,     // 12 FPGA pins for RGB(4 per color)
	output [7:0] red,
	output [7:0] green,
	output [7:0] blue,
	output clock_25,
	output VGA_BLANK_N
	);
	
	wire reset_btn = ~reset;  // if reset_btn is active-low
	
	// Signal Declaration
	reg [7:0] rgb_reg;    // register for 12-bit RGB DAC 
	//wire bright;         // Same signal as in controller
	//wire clock_25;

	 // Clock generators; creating 25MHz VGA input clock
	 clock_generators clks (.clk_50(CLOCK_50), .clk_25(clock_25), .clk_5(), .clk_2());
  
    // Instantiate VGA Controller
    vga_controller vga_c(.clk(clock_25), .reset(reset_btn), .hSync(hsync), .vSync(vsync),
                         .bright(VGA_BLANK_N), .hCount(), .vCount());
    // RGB Buffer
    always @(posedge CLOCK_50 or posedge reset)
    if (reset)
       rgb_reg <= 0;
    else
       rgb_reg <= sw;
    
    // Output
    //assign rgb = (VGA_BLANK_N) ? rgb_reg : 12'b0;   // while in display area RGB color = sw, else all OFF
	 assign red = (VGA_BLANK_N) ? 8'b00101011 : 8'b0; //5'b0, sw[7:5]} : 8'b0;
	 assign green = (VGA_BLANK_N) ? 8'b00001011 : 8'b0;//{5'b0, sw[4:2]} : 8'b0;
	 assign blue = (VGA_BLANK_N) ? 8'b00000111 : 8'b0; //{6'b0, sw[1:0]} : 8'b0;
	
endmodule