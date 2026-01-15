# NES-Inspired Graphics on FPGA

> A hardware-based graphics engine inspired by the Nintendo Entertainment System (NES), implemented in Verilog and deployed on an FPGA with VGA output.

This project explores how classic NES-style graphics can be modeled directly in hardware rather than emulated in software. It implements a simplified Picture Processing Unit (PPU)-like pipeline that renders tiled backgrounds and sprites using FPGA logic.

---

## Overview

The goal of this project is to replicate core concepts of the NES graphics subsystem using modern FPGA hardware. Instead of running game code, this design focuses on the **graphics pipeline itself**: video timing, tile fetching, palette lookup, and sprite rendering.

The system outputs to a VGA display and uses on-chip RAM to store pattern data, palettes, and sprite attributes.

---

## Features

- VGA video output generated entirely in hardware  
- NES-style tile and sprite rendering pipeline  
- Pattern table, palette memory, and OAM-style sprite memory  
- Modular Verilog design for easy extension  
- Test patterns and simulation support  

---

## Hardware Target

- **FPGA Board:** Intel Cyclone V DE1-SoC  
- **Display Output:** VGA  
- **Clock Source:** On-board 50 MHz oscillator  

---

## Project Structure

## How It Works

1. The VGA controller generates horizontal and vertical sync signals.
2. The PPU scans through pixel positions in lockstep with the VGA timing.
3. Tile and sprite data are fetched from on-chip RAM.
4. Palette lookup logic converts tile indices into RGB values.
5. Pixel color data is sent directly to the VGA DAC.

This mirrors the high-level behavior of the NES PPU, adapted for VGA timing and FPGA memory primitives.

---

## Building and Running

### Requirements

- Intel Quartus Prime
- DE1-SoC FPGA board
- VGA-compatible monitor
- USB-Blaster or equivalent programmer

