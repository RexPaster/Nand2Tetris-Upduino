#!/bin/bash
#SBATCH --job-name=sim3
#SBATCH --output=sim3.out
#SBATCH --error=sim3.err
#SBATCH --partition=ib-linuxlab    # high-memory nodes
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --time=02:00:00
#SBATCH -A engr-class-any

set -e

# ----------------------------
# Ensure local binaries are in PATH
# ----------------------------
export PATH="$HOME/.local/bin:$PATH"

# ----------------------------
# Tool binaries (assume already installed)
# ----------------------------
YOSYS_BIN="$HOME/.local/bin/yosys"
NEXTPNR_BIN="$HOME/.local/bin/nextpnr-ice40"
ICEPACK_BIN="$HOME/.local/bin/icepack"

# ----------------------------
# Synthesis / P&R / Bitstream
# ----------------------------
TOP=top
PCF=upduino.pcf

# Find all SystemVerilog files up to 3 levels deep
SRCS=$(find . -maxdepth 3 -name "*.sv" -print0 | xargs -0)

echo "📦 Synthesizing design with Yosys (flattened)..."
"$YOSYS_BIN" -p "read_verilog -sv $SRCS; synth_ice40 -top $TOP -flatten -json top.json"

echo "📐 Running place & route with nextpnr..."
"$NEXTPNR_BIN" \
    --up5k \
    --package sg48 \
    --json top.json \
    --pcf "$PCF" \
    --asc top.asc

echo "🔧 Packing bitstream..."
"$ICEPACK_BIN" top.asc top.bin

echo "✅ Bitstream ready: top.bin"
echo "⚠️ Note: iceprog is not installed. To flash your FPGA, build iceprog locally."
