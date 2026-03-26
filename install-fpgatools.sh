#!/bin/bash
set -e

# Local installation prefix
PREFIX=$HOME/.local
export PATH=$PREFIX/bin:$PATH

# Current directory is where you run the script
WORKDIR=$(pwd)

echo "Installing icestorm..."
git clone https://github.com/YosysHQ/icestorm.git "$WORKDIR/icestorm"
cd "$WORKDIR/icestorm"
make -j$(nproc) PREFIX=$PREFIX
make install PREFIX=$PREFIX
cd "$WORKDIR"

echo "Installing yosys..."
git clone https://github.com/YosysHQ/yosys.git "$WORKDIR/yosys"
cd "$WORKDIR/yosys"
make -j$(nproc) PREFIX=$PREFIX
make install PREFIX=$PREFIX
cd "$WORKDIR"

echo "Installing nextpnr..."
git clone https://github.com/YosysHQ/nextpnr.git "$WORKDIR/nextpnr"
cd "$WORKDIR/nextpnr"
cmake -DARCH=ice40 -DCMAKE_INSTALL_PREFIX=$PREFIX .
make -j$(nproc)
make install
cd "$WORKDIR"

echo "✅ FPGA toolchain installed locally in $PREFIX"
echo "Ensure PATH includes: $PREFIX/bin"
