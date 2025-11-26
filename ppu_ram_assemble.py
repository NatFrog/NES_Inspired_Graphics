

import sys

# This assembler translates pattern and name table data into a .hex file
# that can be loaded into PPU RAM.
# PPU RAM contains 4096 addresses with a 16-bit word size.
# Organization of the RAM:
#       -$0000 stores plane0 pattern table information (Bit 0 of pixel).
#           *Each address here contains 16-bits representing the value of the
#            16 plane0 pixels of a row of a sprite.
#           *Thus, each sprite takes up 16 addresses in plane0 or 32-bytes.
#       -$1000 stores plane1 of pattern table information (Bit 1 of pixel).
#           *Has the same organization as plane0.
#           *Making sprites stored as a total of 64-bytes between both planes.
#       -$2000 stores pattern table information (The backgrounds)
#           *Every background is 20x15 tiles wide (where each tile is a 16x16 sprite
#            reference). For a total of 300 sprites.
#           *Each name table (background) stored in this address space contains 1-byte
#            per each tile that represents the tile's pattern table index, to find the sprite
#            data that makes up the tile.
#           *PPU RAM has 16-bit words so two tile pattern table indexes (2-bytes) can be stored
#            at each address.


# Creating sprites if you guys wanna:
# Draw your sprites at https://www.piskelapp.com/p/create/sprite/
# 1) Resize it to 16x16 pixels, then use 4 different colors to draw your sprite.
# 2) Save the colors as a palette to be added to palette ram.
# 3) Download the sprite as a .png
# 4) Utilize this site to convert the sprite image into digits 0-3: https://www.dcode.fr/digits-image
# (With image width set to 16 and level of grey set to 4)
# NOTE: 16x16 is a small area to create detailed sprites. Making bigger sprites involves
#      storing multiple 16x16 sprites that line up together. I.g. create a 32x32 sprite via 4 stored sprites.
# 5) Insert the sprite's decoded pixel data into the input file in the needed area. Change any
# pattern table (background) references to the sprite to the index of your sprite in the pattern table.

# TO USE:
# In your input file:
#   -Insert the pattern table data (decoded pixel data) for each sprite at the start of the file. Leave no
#     spaces between the sprites. So, the number of sprites stored is equal to the number of lines of pattern
#     table data divided by 16.
#   -After finishing inputting the pattern table data, write a line that just says "nametables."
#   -After that line, you can input the name table data for each background:
#          *Each name table is represented by 20 digits separated by spaces on 15 lines.
#          *I.g. each digit is represented one of the tiles of the background 20x15 (300) tiles.
#          *No spaces inbetween backgrounds. So, number of backgrounds stored = number of lines
#           in name table section divided by 15.
#   -Ts all you need.

SPRITE_SIZE = 16

PLANE0_ADDRESS = 0        # 0x0000
PLANE1_ADDRESS = "3E8"    # 1000
NAMETABLE_ADDRESS = "7D0" # 2000


def _parse_pattern_line(raw):
    """
    Parse a pattern line consisting of exactly 16 digits with no spaces.
    Each character must be '0', '1', '2', or '3'.
    """
    raw = raw.strip()
    if not raw:
        return None

    if len(raw) != 16:
        raise ValueError(f"Pattern line must be exactly 16 digits, got {len(raw)}: {raw!r}")

    values = []
    for ch in raw:
        if ch < '0' or ch > '3':
            raise ValueError(
                f"Invalid pixel value {ch!r} in pattern line (must be 0–3). Line: {raw!r}"
            )
        values.append(int(ch))

    return values


def encode_plane0(lines):
    out = []
    for raw in lines:
        values = _parse_pattern_line(raw)
        if values is None:
            continue

        word_val = 0
        for i, v in enumerate(values):
            low_bit = v & 1
            # leftmost pixel -> bit 15, rightmost -> bit 0 hmm
            word_val |= (low_bit << (15 - i))

        out.append(f"{word_val:04X}")
    return out


def encode_plane1(lines):
    out = []
    for raw in lines:
        values = _parse_pattern_line(raw)
        if values is None:
            continue

        word_val = 0
        for i, v in enumerate(values):
            high_bit = (v >> 1) & 1
            word_val |= (high_bit << (15 - i))

        out.append(f"{word_val:04X}")
    return out


def encode_NameTables(lines):
    """
    Each nametable line contains **20 tile indices**, separated by spaces.
    Example:
        0 0 0 0 0 0 0 0 0 0  1 1 1 1 1 1 2 2 2 2

    - Each index is parsed as an integer (0–255).
    - Output logic: pack two indices per 16-bit word:
        high byte = left index, low byte = right index.
    - So each line (20 indices) produces 10 words,
        and this is printed as 2 bytes in hex or 4 hex
        digits on each line of the pattern table output
        section.
    """
    out = []
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue

        vals = raw.split()
        if len(vals) != 20:
            raise ValueError(
                f"Each name table line must have exactly 20 indices, got {len(vals)}: {raw!r}"
            )

        indices = []
        for v in vals:
            idx = int(v)
            if not (0 <= idx <= 255):
                raise ValueError(f"Name table index out of range (0–255): {idx}")
            indices.append(idx)

        # Pack pairs of indices into 16-bit words
        for i in range(0, 20, 2):
            a = indices[i]
            b = indices[i + 1]
            word_val = (a << 8) | b  # a in high byte, b in low byte
            out.append(f"{word_val:04X}")

    return out



with open("ppu_ram_patterns.asm", 'r') as f:
    all_lines = [l.rstrip("\n") for l in f]

pattern_lines = []
nametable_lines = []
reading_nametable = False

for line in all_lines:
    stripped = line.strip().lower()

    if stripped == "nametables":
        reading_nametable = True
        continue

    if reading_nametable:
        nametable_lines.append(line)
    else:
        pattern_lines.append(line)

# Encode data in pattern tables and then in the name tables
plane0_bytes = encode_plane0(pattern_lines)
plane1_bytes = encode_plane1(pattern_lines)
name_table_bytes = encode_NameTables(nametable_lines)

# Write .hex output
with open("C:/College/3710/ppu_ram_data.hex", 'w') as out:
    out.write(f"@{PLANE0_ADDRESS}\n")
    for v in plane0_bytes:
        out.write(v + "\n")

    out.write(f"@{PLANE1_ADDRESS}\n")
    for v in plane1_bytes:
        out.write(v + "\n")

    out.write(f"@{NAMETABLE_ADDRESS}\n")
    for v in name_table_bytes:
        out.write(v + "\n")
