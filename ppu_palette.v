module ppu_palette(
    input        clk,
    input  [4:0] pal_addr_a, 
    input  [4:0] pal_addr_b,
    input        palette_en,
    output [23:0] color_out_a, 
    output [23:0] color_out_b
);

    // 32 entries of 24-bit RGB
    reg [23:0] palette_mem [0:31];
    reg [23:0] color_a, color_b;

    initial begin
        // You can adjust these, but at least they’re valid 24-bit colors now.
        palette_mem[0]  = 24'h9df732;  // pink!
        palette_mem[1]  = 24'h000000;  // sandswept hair
        palette_mem[2]  = 24'h6CC6D4;  // ManCity blue
        palette_mem[3]  = 24'hf23535;  // flesh

        // the rest just some gradients so you see *something*
        palette_mem[4]  = 24'hA152D9;
        palette_mem[5]  = 24'h37B046;
        palette_mem[6]  = 24'h303030;
        palette_mem[7]  = 24'h404040;
        palette_mem[8]  = 24'h505050;
        palette_mem[9]  = 24'h606060;
        palette_mem[10] = 24'h707070;
        palette_mem[11] = 24'h808080;
        palette_mem[12] = 24'h909090;
        palette_mem[13] = 24'hA0A0A0;
        palette_mem[14] = 24'hB0B0B0;
        palette_mem[15] = 24'hC0C0C0;
        palette_mem[16] = 24'h00FF00;
        palette_mem[17] = 24'h0000FF;
        palette_mem[18] = 24'hFFFF00;
        palette_mem[19] = 24'hFF00FF;
        palette_mem[20] = 24'h00FFFF;
        palette_mem[21] = 24'h884400;
        palette_mem[22] = 24'h448800;
        palette_mem[23] = 24'h004488;
        palette_mem[24] = 24'h888888;
        palette_mem[25] = 24'hAA0000;
        palette_mem[26] = 24'h00AA00;
        palette_mem[27] = 24'h0000AA;
        palette_mem[28] = 24'hAAAA00;
        palette_mem[29] = 24'hAA00AA;
        palette_mem[30] = 24'h00AAAA;
        palette_mem[31] = 24'hFFFFFF;
    end

    always @(posedge clk) begin
        if (palette_en) begin
            color_a <= palette_mem[pal_addr_a];
            color_b <= palette_mem[pal_addr_b];
        end else begin
            color_a <= palette_mem[0];
            color_b <= palette_mem[0];
        end
    end

    assign color_out_a = palette_en ? color_a : 24'h000000;
    assign color_out_b = palette_en ? color_b : 24'h000000;

endmodule
