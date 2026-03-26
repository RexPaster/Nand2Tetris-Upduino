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
ICESTORM_DIR="$WORKDIR/icestorm"
NEXTPNR_DIR="$WORKDIR/nextpnr"

# ----------------------------
# Install Miniconda if missing
# ----------------------------
if [ ! -d "$CONDA_DIR" ]; then
    echo "📥 Installing Miniconda locally..."
    curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o miniconda.sh
    bash miniconda.sh -b -p "$CONDA_DIR"
    rm miniconda.sh
fi

export PATH="$CONDA_DIR/bin:$PATH"
source "$CONDA_DIR/etc/profile.d/conda.sh"

# ----------------------------
# Accept Conda TOS automatically
# ----------------------------
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

# ----------------------------
# Install Mamba in base if missing
# ----------------------------
if ! command -v mamba &> /dev/null; then
    echo "⚡ Installing Mamba in base environment..."
    conda install -y -n base -c conda-forge mamba
fi

# ----------------------------
# Create Conda environment if missing
# ----------------------------
if ! conda info --envs | grep -q "$ENV_NAME"; then
    echo "🛠 Creating Mamba environment..."
    mamba create -y -n "$ENV_NAME" -c conda-forge \
        python=3.10 \
        cmake make ninja git pkg-config bison flex \
        gxx_linux-64 gcc_linux-64 \
        readline zlib ncurses libffi eigen boost boost-cpp tbb yosys libftdi
fi

# Activate environment
conda activate "$ENV_NAME"

# ----------------------------
# Install IceStorm locally if missing
# ----------------------------
if [ ! -f "$PREFIX/bin/icepack" ]; then
    echo "📂 Installing IceStorm locally..."
    if [ ! -d "$ICESTORM_DIR" ]; then
        git clone https://github.com/YosysHQ/icestorm.git "$ICESTORM_DIR"
    fi
    cd "$ICESTORM_DIR"

    make -j$(nproc) -C icebram all
    make -j$(nproc) -C icetime all
    make -j$(nproc) -C icepack all

    make PREFIX=$PREFIX -C icebram install
    make PREFIX=$PREFIX -C icetime install
    make PREFIX=$PREFIX -C icepack install

    # Ensure cells_sim.v exists in environment share directory
    mkdir -p "$CONDA_PREFIX/share/ice40"
    cp ice40/cells_sim.v "$CONDA_PREFIX/share/ice40/"

    cd "$WORKDIR"
fi

# ----------------------------
# Install NextPNR-ice40 locally if missing
# ----------------------------
if [ ! -f "$PREFIX/bin/nextpnr-ice40" ]; then
    echo "📂 Installing NextPNR-ice40 locally..."
    if [ ! -d "$NEXTPNR_DIR" ]; then
        git clone https://github.com/YosysHQ/nextpnr.git "$NEXTPNR_DIR"
    fi
    cd "$NEXTPNR_DIR"
    mkdir -p build
    cd build
    export CMAKE_PREFIX_PATH="$CONDA_PREFIX"
    cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=$PREFIX ..
    make -j$(nproc)
    make install
    cd "$WORKDIR"
fi

# ----------------------------
# Add local bin to PATH
# ----------------------------
export PATH="$PREFIX/bin:$PATH"

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
echo -e "\n# Local build artifacts\n$ENV_NAME/\nicestorm/\nnextpnr/\n*.o\n*.json\n*.asc\n*.bin" >> .gitignore || true
