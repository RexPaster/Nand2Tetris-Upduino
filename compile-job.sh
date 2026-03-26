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
# SLURM self-submit if not already running
# ----------------------------
if [ -z "$SLURM_JOB_ID" ]; then
    echo "📤 Submitting SLURM job..."
    sbatch "$0"
    exit 0
fi

# ----------------------------
# Local installation variables
# ----------------------------
PREFIX=$HOME/.local
WORKDIR=$(pwd)

# ----------------------------
# IceStorm
# ----------------------------
if [ ! -f "$PREFIX/bin/icepack" ]; then
    echo "📂 Installing icestorm..."
    git clone https://github.com/YosysHQ/icestorm.git "$WORKDIR/icestorm"
    cd "$WORKDIR/icestorm"
    make -C icebram all
    make -C icetime all
    make -C icepack all
    make PREFIX=$PREFIX install
    cd "$WORKDIR"
else
    echo "✅ IceStorm already installed, skipping."
fi
ICEBRAM_BIN="$PREFIX/bin/icebram"
ICETIME_BIN="$PREFIX/bin/icetime"
ICEPACK_BIN="$PREFIX/bin/icepack"

# ----------------------------
# Yosys
# ----------------------------
if [ ! -f "$PREFIX/bin/yosys" ]; then
    echo "🔧 Installing yosys..."
    git clone https://github.com/YosysHQ/yosys.git "$WORKDIR/yosys"
    cd "$WORKDIR/yosys"
    make -j$(nproc) PREFIX=$PREFIX
    make install PREFIX=$PREFIX
    cd "$WORKDIR"
else
    echo "✅ Yosys already installed, skipping."
fi
YOSYS_BIN="$PREFIX/bin/yosys"

# ----------------------------
# NextPNR
# ----------------------------
if [ ! -f "$PREFIX/bin/nextpnr-ice40" ]; then
    echo "🛠 Installing nextpnr..."
    git clone https://github.com/YosysHQ/nextpnr.git "$WORKDIR/nextpnr"
    cd "$WORKDIR/nextpnr"
    cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=$PREFIX .
    make -j$(nproc)
    make install
    cd "$WORKDIR"
else
    echo "✅ nextpnr already installed, skipping."
fi
NEXTPNR_BIN="$PREFIX/bin/nextpnr-ice40"

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
