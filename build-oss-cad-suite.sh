#!/bin/bash
#SBATCH --job-name=sim3
#SBATCH --output=sim3.out
#SBATCH --error=sim3.err
#SBATCH --partition=ib-linuxlab
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH -A engr-class-any

set -e

# ----------------------------
# Self-submit if not running under SLURM
# ----------------------------
if [ -z "$SLURM_JOB_ID" ]; then
    echo "📤 Submitting SLURM job..."
    sbatch "$0"
    exit 0
fi

# ----------------------------
# Paths
# ----------------------------
WORKDIR=$(pwd)
OSSCAD_DIR="$WORKDIR/oss-cad-suite"
OSSCAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-26/oss-cad-suite-linux-x64-20260326.tgz"

# ----------------------------
# Install oss-cad-suite if missing
# ----------------------------

if [ ! -d "$OSSCAD_DIR" ]; then
    echo "📥 Downloading oss-cad-suite..."
    curl -L -o oss-cad-suite.tgz "$OSSCAD_URL"
    if file oss-cad-suite.tgz | grep -q 'gzip compressed data'; then
        tar xzf oss-cad-suite.tgz
        rm oss-cad-suite.tgz
    else
        echo "❌ Download failed or file is not a valid .tgz archive."
        cat oss-cad-suite.tgz
        rm oss-cad-suite.tgz
        exit 1
    fi
fi

# Source oss-cad-suite environment for full toolchain setup
source "$OSSCAD_DIR/environment"

# ----------------------------
# Tool binaries (from oss-cad-suite)
# ----------------------------
YOSYS_BIN=$(which yosys)
NEXTPNR_BIN=$(which nextpnr-ice40)
ICEPACK_BIN=$(which icepack)
ICETIME_BIN=$(which icetime)
ICEBRAM_BIN=$(which icebram)

echo "✅ Tools ready:"
echo "   Yosys: $YOSYS_BIN"
echo "   NextPNR: $NEXTPNR_BIN"
echo "   IcePack: $ICEPACK_BIN"
echo "   IceTime: $ICETIME_BIN"
echo "   IceBRAM: $ICEBRAM_BIN"
echo "   (oss-cad-suite)"

# ----------------------------
# Synthesis / P&R / Bitstream
# ----------------------------
TOP=top
PCF=top.pcf

# Find all SystemVerilog files up to 3 levels deep, excluding testbench files (*_tb.sv)
SRCS=$(find . -maxdepth 3 -name "*.sv" ! -name "*_tb.sv" -not -path "*/.*" -print0 | xargs -0)

echo "📦 Synthesizing design with Yosys..."
"$YOSYS_BIN" -p "read_verilog -sv $SRCS; synth_ice40 -top $TOP -flatten -json top.json"

echo "📐 Running place & route with NextPNR..."
"$NEXTPNR_BIN" \
    --up5k \
    --package sg48 \
    --json top.json \
    --pcf "$PCF" \
    --asc top.asc

echo "🔧 Packing bitstream..."
"$ICEPACK_BIN" top.asc top.bin

echo "✅ Bitstream ready: top.bin"
echo "⚠️ Note: iceprog (flashing) is not installed."

# ----------------------------
# Optional: Add local builds to .gitignore
# ----------------------------
echo -e "\n# Local build artifacts\noss-cad-suite/\n*.o\n*.json\n*.asc\n*.bin" >> .gitignore || true
