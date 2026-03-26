#!/bin/bash
#SBATCH --job-name=sim3
#SBATCH --output=sim3.out
#SBATCH --error=sim3.err
#SBATCH --partition=ib-linuxlab    # high-memory nodes
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH -A engr-class-any

set -e

# ----------------------------
# Self-submit to SLURM if not already running
# ----------------------------
if [ -z "$SLURM_JOB_ID" ]; then
    echo "📤 Submitting SLURM job..."
    sbatch "$0"
    exit 0
fi

# ----------------------------
# Local Miniconda path and environment
# ----------------------------
CONDA_DIR="$HOME/miniconda3"
ENV_NAME="yosys_env"

# Install Miniconda locally if not present
if [ ! -d "$CONDA_DIR" ]; then
    echo "📥 Installing Miniconda locally..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi

export PATH="$CONDA_DIR/bin:$PATH"

# Load conda functions
source "$CONDA_DIR/etc/profile.d/conda.sh"

# Create environment if it doesn't exist
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "🛠 Creating Conda environment with Yosys, NextPNR, IceStorm..."
    conda create -y -n "$ENV_NAME" -c conda-forge yosys nextpnr-ice40 icestorm python
fi

# Activate environment
echo "⚡ Activating Conda environment..."
conda activate "$ENV_NAME"

# ----------------------------
# Tool binaries
# ----------------------------
YOSYS_BIN=$(which yosys)
NEXTPNR_BIN=$(which nextpnr-ice40)
ICEPACK_BIN=$(which icepack)

echo "✅ Tools ready:"
echo "   Yosys: $YOSYS_BIN"
echo "   NextPNR: $NEXTPNR_BIN"
echo "   IcePack: $ICEPACK_BIN"

# ----------------------------
# Synthesis / P&R / Bitstream
# ----------------------------
TOP=top
PCF=upduino.pcf

# Find all SystemVerilog files up to 3 levels deep
SRCS=$(find . -maxdepth 3 -name "*.sv" -print0 | xargs -0)

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
echo "⚠️ Note: iceprog is not installed. To flash your FPGA, build iceprog locally."
