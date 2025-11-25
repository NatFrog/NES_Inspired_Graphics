// ppu.v  -- Background + sprite renderer with 16x16 tiles, 2 planes.
// plane0 base = 0, plane1 base = 1000 (decimal) in ppu_ram.
// Each 16-bit word = one 16-pixel row for a single plane.
//
// Background:
//   * nametable in nt_mem (ROM), loaded from ppu_ram_data.hex (offset 2000)
//   * pattern planes in ppu_ram (plane0 at 0, plane1 at 1000)
//   * background uses palette port B
//
// Sprites:
//   * OAM format per sprite: [X, Y, PatternIndex, PaletteIndex]
//   * sprite patterns come from spr_plane0_rom / spr_plane1_rom
//   * first sprite in OAM that hits wins
//   * nonzero sprite pattern overrides background color

module ppu (
    input  wire        clk,
    input  wire        reset,          // active-high reset
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

    output reg  [23:0] rgb
);

    // ================================================================
    // PPU pattern RAM (background patterns only)
    // ================================================================
    reg  [11:0] ram_addr_a, ram_addr_b;
    wire [15:0] ram_q_a, ram_q_b;

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

    // ================================================================
    // Nametable ROM (separate from ppu_ram, loaded from same hex)
    // ================================================================
    reg [15:0] nt_mem [0:4095];

    integer nt_i;
    initial begin
        for (nt_i = 0; nt_i < 4096; nt_i = nt_i + 1)
            nt_mem[nt_i] = 16'h0000;
        $readmemh("ppu_ram_data.hex", nt_mem, 2000);
    end

    // ================================================================
    // OAM storage (64 sprites × 4 bytes)
    // ================================================================
    reg  [7:0]  OAM [0:255];
    reg  [31:0] oam_read_data;
    wire [7:0]  cpu_byte_index = { cpu_oam_addr, 2'b00 }; // object index * 4

    assign oam_out = oam_read_data;

    integer i;
    always @(posedge clk or negedge reset) begin
        if (~reset) begin
            for (i = 0; i < 256; i = i + 1)
                OAM[i] <= 8'd0;
            oam_read_data <= 32'h00000000;
        end else begin
            if (cpu_write && ~rendering) begin
                OAM[cpu_byte_index + 0] <= cpu_oam_data[7:0];
                OAM[cpu_byte_index + 1] <= cpu_oam_data[15:8];
                OAM[cpu_byte_index + 2] <= cpu_oam_data[23:16];
                OAM[cpu_byte_index + 3] <= cpu_oam_data[31:24];
            end
            oam_read_data <= { OAM[cpu_byte_index+3],
                               OAM[cpu_byte_index+2],
                               OAM[cpu_byte_index+1],
                               OAM[cpu_byte_index+0] };
        end
    end

    // ================================================================
    // Palette
    // ================================================================
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

    // ================================================================
    // Coordinate / tile math (320x240 from 640x480)
    // ================================================================
    wire [9:0] x2, y2;
    wire [4:0] tile_x, tile_y;
    wire [3:0] pixel_x, pixel_y;

    assign x2      = hCount >> 1;
    assign y2      = vCount >> 1;
    assign tile_x  = x2[8:4];
    assign tile_y  = y2[8:4];
    assign pixel_x = x2[3:0];
    assign pixel_y = y2[3:0];

    // Nametable address (2 tiles per word)
    wire [11:0] nt_addr;
    assign nt_addr = 12'd2000 + (tile_y * 10) + (tile_x >> 1);

    localparam integer PLANE0_BASE   = 12'd0;
    localparam integer PLANE1_BASE   = 12'd1000;
    localparam integer ROWS_PER_TILE = 16;

    // ================================================================
    // Sprite pattern ROMs
    // ================================================================
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

    // ================================================================
    // Pipeline registers
    // ================================================================
    reg v0, v1, v2, v3;

    // Stage 0
    reg [9:0] s0_x2, s0_y2;
    reg [4:0] s0_tile_x, s0_tile_y;
    reg [3:0] s0_pixel_x, s0_pixel_y;

    // Stage 1
    reg [9:0] s1_x2, s1_y2;
    reg [3:0] s1_pixel_x, s1_pixel_y;
    reg [7:0] s1_tile_index;

    // Stage 2
    reg [9:0] s2_x2, s2_y2;
    reg [3:0] s2_pixel_x;
    reg       s2_spr_has_color;

    // Stage 3
    reg       s3_spr_has_color;

    // -------- temporaries declared at module scope (Verilog-2001 style) -----
    integer bit_idx_bg;
    integer si;
    integer base_idx;
    integer spr_addr;
    integer bit_idx_spr;

    reg [15:0] spr_row0, spr_row1;
    reg [7:0]  spr_x, spr_y, spr_tile;
    reg [3:0]  spr_row, spr_col;
    reg [1:0]  spr_pattern_now;
    reg        spr_has_color_now;
    reg [4:0]  spr_pal_base_now;
    reg [4:0]  spr_pal_index_next;

    reg [11:0] nt_addr_s0;
    reg [15:0] nt_word;
    reg [7:0]  tile_idx_now;
    integer    row_addr;

    // ================================================================
    // Main pipeline
    // ================================================================
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            v0 <= 1'b0; v1 <= 1'b0; v2 <= 1'b0; v3 <= 1'b0;

            ram_addr_a <= 12'd0;
            ram_addr_b <= 12'd0;

            s0_x2 <= 10'd0; s0_y2 <= 10'd0;
            s0_tile_x <= 5'd0; s0_tile_y <= 5'd0;
            s0_pixel_x <= 4'd0; s0_pixel_y <= 4'd0;

            s1_x2 <= 10'd0; s1_y2 <= 10'd0;
            s1_pixel_x <= 4'd0; s1_pixel_y <= 4'd0;
            s1_tile_index <= 8'd0;

            s2_x2 <= 10'd0; s2_y2 <= 10'd0;
            s2_pixel_x <= 4'd0;
            s2_spr_has_color <= 1'b0;

            s3_spr_has_color <= 1'b0;

            back_pal_index <= 5'd0;
            spr_pal_index  <= 5'd0;
            rgb            <= 24'h000000;
        end else begin
            // --------------------------------------------------------
            // Stage 3: final color from palette
            // --------------------------------------------------------
            v3 <= v2;
            s3_spr_has_color <= s2_spr_has_color;

            if (v3) begin
                rgb <= s3_spr_has_color ? spr_pal_color : back_pal_color;
            end else begin
                rgb <= 24'h000000;
            end

            // --------------------------------------------------------
            // Stage 2: pattern rows -> background + sprite overlay
            // --------------------------------------------------------
            v2 <= v1;
            s2_spr_has_color <= 1'b0;

            if (v1) begin
                s2_x2      <= s1_x2;
                s2_y2      <= s1_y2;
                s2_pixel_x <= s1_pixel_x;

                // *** Background bits directly from current RAM outputs ***
                bit_idx_bg = 15 - s1_pixel_x;
                back_pal_index <= (PPUCTRL[7:2] << 2) +
                                  { ram_q_a[bit_idx_bg], ram_q_b[bit_idx_bg] };

                // -------- Sprites over this pixel ----------
                spr_has_color_now  <= 1'b0;
                spr_pal_index_next <= 5'd0;

                for (si = 0; si < 64; si = si + 1) begin
                    base_idx = si << 2;

                    spr_x = OAM[base_idx + 0];
                    spr_y = OAM[base_idx + 1];

                    if (!spr_has_color_now &&
                        ((spr_x != 8'd0) || (spr_y != 8'd0)) &&
                        (s1_x2 >= spr_x) && (s1_x2 <= spr_x + 8'd15) &&
                        (s1_y2 >= spr_y) && (s1_y2 <= spr_y + 8'd15)) begin

                        spr_tile         = OAM[base_idx + 2];
                        spr_pal_base_now = OAM[base_idx + 3][4:0];

                        spr_row = s1_y2 - spr_y;
                        spr_col = s1_x2 - spr_x;

                        spr_addr = (spr_tile << 4) + spr_row;
                        spr_row0 = spr_plane0_rom[spr_addr];
                        spr_row1 = spr_plane1_rom[spr_addr];

                        bit_idx_spr       = spr_col; // LSB = leftmost
                        spr_pattern_now[0] = spr_row0[bit_idx_spr];
                        spr_pattern_now[1] = spr_row1[bit_idx_spr];

                        if (spr_pattern_now != 2'b00) begin
                            spr_has_color_now  <= 1'b1;
                            spr_pal_index_next <= (spr_pal_base_now << 2) + spr_pattern_now;
                        end
                    end
                end

                s2_spr_has_color <= spr_has_color_now;
                spr_pal_index    <= spr_pal_index_next;
            end

            // --------------------------------------------------------
            // Stage 1: tile index + pattern row address
            // --------------------------------------------------------
            v1 <= v0;

            if (v0) begin
                s1_x2       <= s0_x2;
                s1_y2       <= s0_y2;
                s1_pixel_x  <= s0_pixel_x;
                s1_pixel_y  <= s0_pixel_y;

                // compute nametable word and tile index
                nt_addr_s0 = 12'd2000 +
                             (s0_tile_y * 10) +
                             (s0_tile_x >> 1);
                nt_word = nt_mem[nt_addr_s0];

                if (s0_tile_x[0])
                    tile_idx_now = nt_word[7:0];
                else
                    tile_idx_now = nt_word[15:8];

                s1_tile_index <= tile_idx_now;

                // row address for both planes
                row_addr   = (tile_idx_now << 4) + s0_pixel_y;
                ram_addr_b <= PLANE0_BASE + row_addr;   // plane0
                ram_addr_a <= PLANE1_BASE + row_addr;   // plane1
            end

            // --------------------------------------------------------
            // Stage 0: latch coords
            // --------------------------------------------------------
            v0 <= rendering;
            if (rendering) begin
                s0_x2      <= x2;
                s0_y2      <= y2;
                s0_tile_x  <= tile_x;
                s0_tile_y  <= tile_y;
                s0_pixel_x <= pixel_x;
                s0_pixel_y <= pixel_y;
            end
        end
    end

endmodule
