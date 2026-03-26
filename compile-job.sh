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
PREFIX="$HOME/.local"
CONDA_DIR="$HOME/miniconda3"
ENV_NAME="yosys_env"
WORKDIR=$(pwd)

# ----------------------------
# Load / install Conda if needed
# ----------------------------
if [ ! -d "$CONDA_DIR" ]; then
    echo "📥 Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi
export PATH="$CONDA_DIR/bin:$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"

# ----------------------------
# Accept Conda Terms of Service
# ----------------------------
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# ----------------------------
# Create Conda environment if missing
# ----------------------------
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "🛠 Creating Conda environment..."
    conda create -y -n "$ENV_NAME" -c conda-forge yosys nextpnr-ice40 python
fi

# Activate environment
conda activate "$ENV_NAME"

# ----------------------------
# Install IceStorm locally if missing
# ----------------------------
if [ ! -f "$PREFIX/bin/icepack" ]; then
    echo "📂 Installing IceStorm locally..."
    git clone https://github.com/YosysHQ/icestorm.git "$WORKDIR/icestorm"
    cd "$WORKDIR/icestorm"
    make -j$(nproc) -C icebram all
    make -j$(nproc) -C icetime all
    make -j$(nproc) -C icepack all
    make PREFIX=$PREFIX install
    cd "$WORKDIR"
fi

# ----------------------------
# Tool binaries
# ----------------------------
YOSYS_BIN=$(which yosys)
NEXTPNR_BIN=$(which nextpnr-ice40)
ICEPACK_BIN="$PREFIX/bin/icepack"
ICETIME_BIN="$PREFIX/bin/icetime"
ICEBRAM_BIN="$PREFIX/bin/icebram"

echo "✅ Tools ready:"
echo "   Yosys: $YOSYS_BIN"
echo "   NextPNR: $NEXTPNR_BIN"
echo "   IcePack: $ICEPACK_BIN"
echo "   IceTime: $ICETIME_BIN"
echo "   IceBRAM: $ICEBRAM_BIN"

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
echo "⚠️ Note: iceprog (flashing) is not installed."
