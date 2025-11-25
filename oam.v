// Object Attribute Memory (OAM)
module oam (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        oam_en,
    input  wire        oam_rw,       // 0 = read, 1 = write
    input  wire [5:0]  address,      // object address/index (0–63)
    input  wire [31:0] data_in,      // 4-byte object input
    output reg  [31:0] data_out      // 4-byte object output
);

    integer i;
    reg [7:0] OAM [0:255];           // NES-style OAM: 256 bytes - enough to store 64 objects

    wire [7:0] base = address * 4;   // starting byte of object / think of address like index

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 256; i = i + 1)
                OAM[i] <= 8'd0;
            data_out <= 32'h00000000;
        end else begin
            if (oam_en) begin
                if (!oam_rw) begin
                    // READ object
                    data_out <= {
                        OAM[base + 3],
                        OAM[base + 2],
                        OAM[base + 1],
                        OAM[base + 0]
                    };
                end else begin
                    // WRITE object
                    OAM[base + 0] <= data_in[7:0];
                    OAM[base + 1] <= data_in[15:8];
                    OAM[base + 2] <= data_in[23:16];
                    OAM[base + 3] <= data_in[31:24];
                end
            end else begin
                data_out <= 32'hzzzzzzzz;  
            end
        end
    end

endmodule
