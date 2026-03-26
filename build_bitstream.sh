#!/bin/bash
set -e

# Make sure local bin is in PATH
export PATH=$HOME/.local/bin:$PATH

TOP=top          # Change to your top module name
PCF=upduino.pcf  # Constraints file in current folder

# Find all SystemVerilog files up to 3 levels deep in current directory
SRCS=$(find . -maxdepth 3 -name "*.sv")

echo "📦 Synthesizing design with Yosys..."
yosys -p "read_verilog -sv $SRCS; synth_ice40 -top $TOP -json top.json"

echo "📐 Running place & route with nextpnr..."
nextpnr-ice40 \
    --up5k \
    --package sg48 \
    --json top.json \
    --pcf $PCF \
    --asc top.asc

echo "🔧 Packing bitstream..."
icepack top.asc top.bin

echo "✅ Bitstream ready: top.bin"
