#!/bin/bash
# ========================================
# Self-submitting SLURM job for UPduino 3.1
# ========================================

# If not running inside a SLURM job, submit this script
if [ -z "$SLURM_JOB_ID" ]; then
    echo "📤 Submitting job to SLURM..."
    sbatch "$0"
    exit 0
fi

# --- SLURM directives ---
#SBATCH --job-name=sim3           # Job name
#SBATCH --output=sim3.out         # Standard output
#SBATCH --error=sim3.err          # Standard error
#SBATCH --partition=compute       # Partition / queue
#SBATCH --nodes=1                 # Number of nodes
#SBATCH --ntasks=2                # Number of CPU cores
#SBATCH --mem=64G                 # Total RAM
#SBATCH --time=02:00:00           # Max runtime (HH:MM:SS)

# Exit immediately if a command fails
set -e

# Make sure local bin is in PATH
export PATH=$HOME/.local/bin:$PATH

# --- Design variables ---
TOP=top                   # Top module name
PCF=upduino.pcf           # Constraints file in current folder

# --- Find all SystemVerilog files (up to 3 levels deep) ---
# Safe for filenames with spaces
SRCS=$(find . -maxdepth 3 -name "*.sv" -print0 | xargs -0)

echo "📦 Synthesizing design with Yosys..."
yosys -p "read_verilog -sv $SRCS; synth_ice40 -top $TOP -json top.json"

echo "📐 Running place & route with nextpnr-ice40..."
nextpnr-ice40 \
    --up5k \
    --package sg48 \
    --json top.json \
    --pcf $PCF \
    --asc top.asc

echo "🔧 Packing bitstream with icepack..."
icepack top.asc top.bin

echo "✅ Bitstream ready: top.bin"
