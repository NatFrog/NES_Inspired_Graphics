module BongoTron(

	// Clock 50 MHz input
   input 		          		CLOCK_50,

	// Bongo drum signals
	input 		     [1:0]		right,   //right drum
	input 		     [1:0]		left,    //left drum
	
	//FPGA button input for reset?
	input 		          		KEY,

	//VGA output signals
	output		          		VGA_BLANK_N,
	output		     [7:0]		VGA_B,   //Blue
	output		          		VGA_CLK, // clk 25 mHz
	output		     [7:0]		VGA_G,   //Green
	output		          		VGA_HS,  // hSync
	output		     [7:0]		VGA_R,   //RED
	//output		          		VGA_SYNC_N,     //need?
	output		          		VGA_VS   // vSync
	
	//APU output
);

	// The CPU databus sent to PPU
	wire[ 7:0 ] CPUdata;


	wire write_cpu; // write signal from cpu
	wire[ 15:0 ] addr_cpu; // address from cpu
	wire clk_cpu, clk_ppu, clk_vga, rst_n; // clk for each modules, active low rst

	assign rst_n = KEY;

	wire[2:0] ppu_addr; // $0 - $7 for $1000-$1007 in Memory
	wire[15:0] mem_addr;

	
	
	
	//PPU Signals
	wire[7:0] color; // the 8 bit color to draw to the screen
	wire[13:0] PPUram_addr; // The address that the sprite/background renderer specifies
	wire PPUram_rw_sel; // 0 = read, 1 = write
	wire[7:0] PPUram_data_out; // The data to write to PPUram from PPUDATA
	

	wire [7:0] PPUram_data_in; // Data input from PPUram reads
	wire rw; // PPU register read/write toggle 0 = read, 1 = write
	//assign rw = write_cpu ? 1'b1 : 1'b0;

	
	//VGA
	wire [7:0] vga_r, vga_g, vga_b;
	wire loading_n;
	
	assign VGA_R = ~VGA_BLANK_N ? 8'h00 : vga_r;
	assign VGA_G = ~VGA_BLANK_N ? 8'h00 : vga_g;
	assign VGA_B = ~VGA_BLANK_N ? 8'h00 : vga_b;
	//assign VGA_SYNC_N = 1'b0;
	assign VGA_CLK = clk_vga;

	//Memory should be timed with PPU for PPU to read PPu registers accurately 
	//assign clk_mem = clk_ppu;
	
	clock_generators clocks (CLOCK_50, clk_vga, clk_ppu, clk_cpu);
	

	/*Writes data out for APU and GPU. Preloaded with program. Accepts reset signal.
	*/
	//cpu Bongo_CPU ();
	
	
	//vga VideoGraphicsArray ();
	
	//apu AudioProcesingUnit ();
	
	

endmodule