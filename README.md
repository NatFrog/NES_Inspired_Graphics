NES Inspired Graphics on FPGA

Model NES graphics hardware on an FPGA — VGA output, NES-like PPU, sprite & tile support. Built on the Intel Cyclone V DE1-SOC development board, this project implements core video-generation hardware inspired by the NES’s picture processing unit (PPU).

Overview

This repository contains a hardware design that replicates key parts of the classic Nintendo Entertainment System’s graphics pipeline in Verilog. Instead of emulating the NES in software, it builds a hardware-level graphics engine that mimics how the NES PPU operates, interfacing with a VGA display.

At its heart, the design includes:

A VGA controller that generates standard timing signals and pixel data for VGA displays.

A custom Picture Processing Unit (PPU) module that manages background and sprite scanning.

On-chip RAM blocks for pattern tables, palette data, and object attribute memory.

Sample test benches and Verilog modules to exercise and verify graphics output.

This approach gives hands-on experience with video timing, memory organization, and sprite rendering logic in pure hardware — great for learning how classic consoles worked under the hood.

Features

VGA Output: Hardware logic to produce VGA-compatible video signals for 640×480 or similar timing displays.

NES-Style Graphics Pipeline: PPU-like pipeline with tile fetching, palette lookup, and sprite handling.

Memory Blocks: Dedicated RAM for pattern data, palettes, and object attributes.

Test Patterns and Examples: Sample Verilog test modules to verify rendering behavior on real hardware or simulation.

Project Structure

vga_controller.v: Generates horizontal and vertical sync signals and pixel clocks for VGA.

vga.v: Top-level VGA interface tying together pixel timing and frame buffers.

ppu.v: Picture Processing Unit core that drives graphics generation.

ppu_ram.v, ppu_palette.v, oam.v: RAM modules for pattern tables, palettes, and sprite OAM (object attribute memory).

.hex files: Example tile and palette data for testing graphics output.

test modules: Verilog test harnesses to simulate and verify specific rendering behaviors before hardware deployment.

Getting Started
Requirements

Intel FPGA tools (Quartus Prime) capable of synthesizing for the Cyclone V DE1-SOC board.

VGA display with standard 640×480 (or compatible) input.

JTAG or USB blaster for programming the FPGA.

Build & Flash

Open the provided Quartus project (*.qpf / *.qsf) in Quartus Prime.

Compile the project to generate a .sof bitstream.

Program the DE1-SOC via Quartus Programmer or equivalent toolchain.

Once flashed, connect the VGA output from the board to a monitor to see the test pattern or graphics engine in action.

Usage & Interaction

At present this project focuses on graphics rendering hardware. There are no CPU, input, or audio modules implemented — only the graphic pipeline driven by hard-coded test patterns or data loaded into the pattern RAM.

You can iterate on the design by:

Adding a soft CPU (Nios II or RISC-V) to feed sprite and tile data.

Expanding palette and tile memory for richer scenes.

Implementing scrolling and advanced sprite priorities.

Contributing

Contributions are welcome, especially for expanding:

PPU functionality and NES-accurate features.

Tooling for converting classic NES assets into on-chip memory formats.

Integration with CPU cores or game logic.
