module vga (	
		input vga_clock,
		input ppu_clock,
		input rendering,
		input rst,
		//Input bus for CPU -> OAM/PPU
		//Write to oam during VBlank when no rendering will be happening
		input wire oam_wr,
		input wire [31:0] OAMDATA,
		input wire [5:0] OAMADDR,
		input wire [1:0] PPUCTRL,
		output wire [7:0] oam_out,
		output[7:0] vga_r,
		output[7:0] vga_g,
		output[7:0] vga_b,
		output hSync,
		output vSync,
		output bright,
		output reg loading); 

	//hardcode startup animation using loading? 
	wire [9:0] hCount, vCount;
	wire [7:0] color;
	
	//rrr ggg bb
	assign vga_r = color[7:5];
	assign vga_g = color[4:2];
	assign vga_b = color[1:0];
	
	//writtenaddresses somewhere pc
	
	wire wr, vga_frame_end;
	wire[15:0] wr_addr;
	wire vga_frame_end_boot, ppu_frame_end_boot;
	reg [26:0] boot_count; // count until rendering enabled
	reg boot_count_done;

	initial begin
		boot_count <= 27'h0000000;
		boot_count_done <= 0;
		loading <= 1;
	end
	//Can be used to have screen be white initially or loading screen
	always @(posedge vga_clock, negedge rst) begin
		if (!rst) begin
			boot_count <= 27'h0000000;
			boot_count_done <= 0;
		end
		else begin
			boot_count <= boot_count + 1;
			if (boot_count == 27'h7FFFFFF)
				boot_count_done <= 1;
			if (boot_count == 27'h4FFFFFF)
				loading <= 0;
		end
	end
	

	//Computes pixel coordinates (hCount, vCount), h-sync, v-sync and bright (whether or not the pizel is on).
	vga_controller ctrl(
						.clk(vga_clock),
						.reset(rst),
						.vSync(vSync),
						.hSync(hSync),
						.bright(bright),
						.hCount(hCount),
						.vCount(vCount)
						);
						
	// RGB output - pixel color generator					
	ppu PictureProcessingUnit (
						.clk(ppu_clock),
						.OAMDATA(OAMDATA),
						.OAMADDR(OAMADDR),
						.PPUCTRL(PPUCTRL),
						.rw(oam_rw), 		 // 0 = read, 1 = write (CPU->PPU)
						.hCount(hCount), 
						.vCount(vCount),  		 //inputs from vga saying horizontal and vertical locations of current pixel
						.rgb(color),    	 //color to be displayed by vga
	               .oam_out(oam_out)           //Data from OAM requested to be read by CPU
	
					);
	
	

endmodule