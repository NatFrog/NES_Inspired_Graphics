// Quartus Prime Verilog Template
// True Dual Port RAM with single clock

//VERIFY: RESOURCE MAPPING, should see only 2MK10 blocks //4MK10
//

module ppu_ram
#(parameter DATA_WIDTH=16, parameter ADDR_WIDTH=12)	//16 data width for 16 bit words, 2^12 = 4096 address locations
(
	input [(DATA_WIDTH-1):0] data_a, data_b,
	input [(ADDR_WIDTH-1):0] addr_a, addr_b,
	input wire we_a, we_b, clk,		//write enable a/b and clk
	output reg [(DATA_WIDTH-1):0] q_a, q_b
);

	reg [DATA_WIDTH-1:0] ram[2**ADDR_WIDTH-1:0];	
	
	// FOR QUESTA SIMULATION ONLY
	initial begin
		$readmemh("ppu_ram_data.hex", ram, 2000);
		$readmemh("plane0.hex", ram, 0);
		$readmemh("plane1.hex", ram, 1000);
	end

	// Port A 
	always @ (posedge clk)
	begin
		if (we_a) 
		begin
			ram[addr_a] <= data_a;	//write
			q_a <= data_a;	
		end
		else begin
			q_a <= ram[addr_a];		//read
		end 
	end 

	// Port B 
	always @ (posedge clk)
	begin
		if (we_b) 
		begin
			ram[addr_b] <= data_b;	//write
			q_b <= data_b;
		end
		else begin
			q_b <= ram[addr_b];	//read
		end 
	end

endmodule
