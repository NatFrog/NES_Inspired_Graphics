// ppu.v -- Background + sprite renderer with 20x15 tiles, 2 planes.
// -Currently sprites can move and are rendered without stretch.

module ppu (
    input  wire        clk,
    input  wire        reset,          // ACTIVE-LOW reset
    input  wire        rendering,      // 1 = VGA actively rendering

    // CPU/OAM interface
    input  wire [31:0] cpu_oam_data,
    input  wire [5:0]  cpu_oam_addr,   // object index 0..63
    input  wire        cpu_write,      // 1=write, 0=read
    output wire [31:0] oam_out,

    input  wire [7:0]  PPUCTRL,        // bits [1:0]=nametable (ignored), [7:2]=palette base

    // VGA scan counters
    input  wire [9:0]  hCount,
    input  wire [9:0]  vCount,

    // Declared as 'reg' because it is driven in an always block
    output reg  [23:0] rgb
);

    // PPU pattern RAM (background patterns only)
	 // Can be written to in order to add more backgrounds background tile patterns without changing
	 // the sprite data in the ROMS.
    reg  [11:0] ram_addr_a, ram_addr_b;
    wire [15:0] ram_q_a, ram_q_b; // Pattern data from PPU RAM

    ppu_ram PPU_RAM (
        .data_a(16'b0),
        .data_b(16'b0),
        .addr_a(ram_addr_a),
        .addr_b(ram_addr_b),
        .we_a(1'b0),
        .we_b(1'b0),
        .clk(clk),
        .q_a(ram_q_a),
        .q_b(ram_q_b)
    );

    // Nametable ROM
	 // Used by sprites for fast rendering
    reg [15:0] nt_mem [0:4095];

    integer nt_i;
    initial begin
        for (nt_i = 0; nt_i < 4096; nt_i = nt_i + 1)
            nt_mem[nt_i] = 16'h0000;
        $readmemh("ppu_ram_data.hex", nt_mem, 2000);
    end

    // OAM storage and CPU interface
	 // Would classically be external- Future improvement.
    reg  [7:0]  OAM [0:255];
    reg  [31:0] oam_read_data;
    wire [7:0]  cpu_byte_index = { cpu_oam_addr, 2'b00 }; // object index * 4

    assign oam_out = oam_read_data;

    integer i;
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            for (i = 0; i < 256; i = i + 1)
                OAM[i] <= 8'd0;
            oam_read_data <= 32'h00000000;
        end else begin
            // CPU writes OAM
            if (cpu_write) begin
                OAM[cpu_byte_index + 0] <= cpu_oam_data[7:0];
                OAM[cpu_byte_index + 1] <= cpu_oam_data[15:8];
                OAM[cpu_byte_index + 2] <= cpu_oam_data[23:16];
                OAM[cpu_byte_index + 3] <= cpu_oam_data[31:24];
            end
            // OAM Read (combinatorial read of OAM for CPU access)
            oam_read_data <= { OAM[cpu_byte_index+3],
                               OAM[cpu_byte_index+2],
                               OAM[cpu_byte_index+1],
                               OAM[cpu_byte_index+0] };
        end
    end

    // Palette Interface
    reg  [4:0] back_pal_index;
    reg  [4:0] spr_pal_index;
    wire [23:0] spr_pal_color;
    wire [23:0] back_pal_color;

    ppu_palette PAL (
        .clk(clk),
        .pal_addr_a(spr_pal_index),
        .pal_addr_b(back_pal_index),
        .palette_en(1'b1),
        .color_out_a(spr_pal_color),
        .color_out_b(back_pal_color)
    );

    // Coordinate / tile math
    wire [9:0] x2, y2;
    wire [4:0] tile_x, tile_y;
    wire [3:0] pixel_x, pixel_y;

	 
	 /*  To acheive a pixelated style reminiscent of the NES, we downscale the VGA's
	 *  minimum resolution of 640x480 . Making it so our PPU interprets pixel h/vCounts
	 *  within the range of 320x240. Thus, with 16x16 pixel tiles we have 20 horixonal
	 *  tiles (tile_x) and 15 vertical tiles (tile_y).
	 */
    assign x2      = hCount >> 1;
    assign y2      = vCount >> 1;
    assign tile_x  = x2[8:4];    // 0..19 (320 / 16)
    assign tile_y  = y2[8:4];    // 0..14 (240 / 16)
    assign pixel_x = x2[3:0];    // 0..15 (Pixel within tile)
    assign pixel_y = y2[3:0];    // 0..15 (Row within tile)

    localparam integer ROWS_PER_TILE = 16;
    localparam integer PLANE0_BASE   = 12'd0;
    localparam integer PLANE1_BASE   = 12'd1000;

    // Sprite pattern ROMs
	 // ***CAN MAKE SMALLER **
    reg [15:0] spr_plane0_rom [0:4095];
    reg [15:0] spr_plane1_rom [0:4095];

    integer k;
    initial begin
        for (k = 0; k < 4096; k = k + 1) begin
            spr_plane0_rom[k] = 16'h0000;
            spr_plane1_rom[k] = 16'h0000;
        end
        $readmemh("plane0.hex", spr_plane0_rom, 0);
        $readmemh("plane1.hex", spr_plane1_rom, 0);
    end

    // Pipeline registers
    reg v0, v1, v2;

    // Stage 0 -> Latch to S1 inputs
    reg [9:0] s0_x2, s0_y2;
    reg [3:0] s0_pixel_x, s0_pixel_y;
    reg [7:0] s1_tile_index_latch; // Latch for the tile index from NT

    // Stage 1 -> Latch to S2 inputs
    reg [9:0] s1_x2, s1_y2;
    reg [3:0] s1_pixel_x;
    reg       s2_spr_has_color;

    // Stage 2 -> Output latch (The output 'rgb' is already the final latch)
    
    // Intermediate Variables
    integer bit_idx_bg;
    integer spr_addr_rom;
    integer row_addr_ram;
    integer bit_idx_spr;        

    reg [1:0] back_pattern_now; // The calculated 2-bit background pattern
    reg [1:0] spr_pattern_now;  // The calculated 2-bit sprite pattern
    reg        spr_has_color_now;
    reg [4:0]  spr_pal_index_next;

    reg [7:0]  spr_x, spr_y;
    reg [3:0]  spr_row, spr_col;
    
    reg [15:0] spr_row0;         
    reg [15:0] spr_row1;         
    reg [7:0]  spr_pal_base_now; 

    // Combinatorial Calculation Wires
    reg [11:0] nt_addr_calc;
    reg [15:0] nt_word_data;
    reg [7:0]  tile_idx_calc;

    // **NEW WIRE**: Combinatorial output of the S2 color MUX (Verilog-2001 compatible)
    wire [23:0] final_color_mux;


    // Combinatorial Logic Block (Final Color MUX)
    // Assigns the final color based on the registered state of Stage 2 (v2 and s2_spr_has_color)
    assign final_color_mux = v2 ?
                              // If S2 is valid: use sprite color if non-transparent, else use background color
                              (s2_spr_has_color ? spr_pal_color : back_pal_color) :
                              // If S2 is not valid (border/blanking), output black
                              24'h000000;


    // Main Pipeline Logic
    always @(*) begin // Combinatorial block for address calculations
        // Nametable address for S0
        nt_addr_calc = 12'd2000 + (tile_y * 10) + (tile_x >> 1);
        nt_word_data = nt_mem[nt_addr_calc];
        
        // Determine which of the two tile indices in nt_word_data to use
        if (tile_x[0]) // odd tile_x (right half of word)
            tile_idx_calc = nt_word_data[15:8];
        else           // even tile_x (left half of word)
            tile_idx_calc = nt_word_data[7:0];
    end

    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            v0 <= 1'b0;
            v1 <= 1'b0;
            v2 <= 1'b0;

            rgb <= 24'h000000;

            ram_addr_a <= 12'd0;
            ram_addr_b <= 12'd0;

            s0_x2 <= 10'd0;
            s0_y2 <= 10'd0;
            s0_pixel_x <= 4'd0;
            s0_pixel_y <= 4'd0;
            s1_tile_index_latch <= 8'd0;

            back_pal_index <= 5'd0;
            spr_pal_index  <= 5'd0;

            s2_spr_has_color <= 1'b0;

        end else begin

            // Stage 2: Final Color Latch (RGB)
            v2 <= v1;
            rgb <= final_color_mux; // Latch the combinatorial final MUX output
            
            // Stage 1: Pattern Fetch & Sprite Overlay
            // Reads from RAM, determines 2-bit patterns, calculates 5-bit palette indices.
            v1 <= v0;
            s1_x2      <= s0_x2;
            s1_y2      <= s0_y2;
            s1_pixel_x <= s0_pixel_x;

            // **BACKGROUND LOGIC**
            
            // Calculate bit index (15 for left-most pixel)
            bit_idx_bg = 15 - s1_pixel_x;

            // Extract the 2-bit background pattern from the PPU RAM
            back_pattern_now[0] <= ram_q_a[bit_idx_bg];
            back_pattern_now[1] <= ram_q_b[bit_idx_bg];

            // Latch 5-bit background palette index for S2
            // PPUCTRL[7:2] = Palette Base + back_pattern_now
            back_pal_index <= (PPUCTRL[7:2] << 2) | back_pattern_now;
            
            
            // **SPRITE LOGIC**

            // Sprite rendering logic (simplified for single sprite 0)
            spr_x <= OAM[4*0 + 0]; // X coordinate
            spr_y <= OAM[4*0 + 1]; // Y coordinate
            
            // OAM[4*0 + 2] is Pattern Index
            // OAM[4*0 + 3] is Attribute Byte (contains palette base)
            
            // Check if current pixel is inside the 16x16 sprite area
            if (s1_x2 >= spr_x && s1_x2 < spr_x + 16 && 
                s1_y2 >= spr_y && s1_y2 < spr_y + 16) 
            begin
                // Calculate position within sprite tile (0..15)
                spr_col = s1_x2 - spr_x;
                spr_row = s1_y2 - spr_y;
                
                // Address offset for 16x16 sprite
                spr_addr_rom = OAM[4*0 + 2] * ROWS_PER_TILE + spr_row;
                
                // Get bit index (15 for left-most pixel)
                bit_idx_spr = 15 - spr_col;

                // Sprite Pattern Fetch (combinatorial from ROMs)
                spr_row0 <= spr_plane0_rom[spr_addr_rom];
                spr_row1 <= spr_plane1_rom[spr_addr_rom];

                // Extract pattern bits: {Plane 1, Plane 0}
                spr_pattern_now[0] <= spr_row0[bit_idx_spr];
                spr_pattern_now[1] <= spr_row1[bit_idx_spr];

                // Check for transparency (pattern 00 is transparent)
                spr_has_color_now <= (spr_pattern_now != 2'b00);
                
                // Calculate the 5-bit sprite palette index
                spr_pal_base_now <= OAM[4*0 + 3]; 
                spr_pal_index_next <= (spr_pal_base_now << 2) +spr_pattern_now; // Using bits [4:2] as palette base
                
            end else begin
                // No sprite hit
                spr_has_color_now <= 1'b0;
                spr_pal_index_next <= 5'd0; 
            end

            // Latch sprite collision state and palette index for S2
            s2_spr_has_color <= spr_has_color_now;
            spr_pal_index <= spr_pal_index_next;
            
            
            // Stage 0: Latch Coordinates & Address Calculation
            // Calculates nametable address and loads Pattern RAM addresses for S1.
            v0 <= rendering;

            s0_x2      <= x2;
            s0_y2      <= y2;
            s0_pixel_x <= pixel_x;
            s0_pixel_y <= pixel_y;
            
            // Latch the calculated tile index
            s1_tile_index_latch <= tile_idx_calc;

            // Background Pattern address calculation
            // This uses the *current* coordinate's tile index and row-in-tile (pixel_y)
            row_addr_ram = tile_idx_calc * ROWS_PER_TILE + pixel_y;
            
            // Latch pattern RAM addresses for S1
            ram_addr_a <= PLANE0_BASE + row_addr_ram;
            ram_addr_b <= PLANE1_BASE + row_addr_ram;
        end
    end

endmodule
