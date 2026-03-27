#!/bin/bash
#SBATCH --job-name=FPGA_SYNTHESIS
#SBATCH --output=main-log.out
#SBATCH --error=main-log.err
#SBATCH --partition=general-cpu
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH -A engr-class-any

# ----------------------------
# Clean up old logs
# ----------------------------
rm -f yosys.log nextpnr.log icepack.log
> main-log.out
> main-log.err

set -e

# ----------------------------
# Self-submit if not running under SLURM
# ----------------------------
if [ -z "$SLURM_JOB_ID" ]; then
    echo "📤 Selecting best idle node with highest CPUs..."

    # pick the idle node with the most CPUs
    BEST_NODE=$(sinfo -h -o "%N %c %m %t" | awk '$4=="idle"{print $0}' | sort -k2,2nr | head -n1 | awk '{print $1}')

    if [ -z "$BEST_NODE" ]; then
        echo "❌ No idle nodes available. Exiting."
        exit 1
    fi

    echo "Selected node: $BEST_NODE"

    # submit job to that node using all other variables already set in the script
    sbatch --nodelist="$BEST_NODE" \
           --job-name="$SLURM_JOB_NAME" \
           --output="$SLURM_OUTPUT" \
           --error="$SLURM_ERROR" \
           --partition="$SLURM_PARTITION" \
           --nodes="$SLURM_NODES" \
           --ntasks="$SLURM_NTASKS" \
           --cpus-per-task="$SLURM_CPUS_PER_TASK" \
           --mem="$SLURM_MEM" \
           --time="$SLURM_TIME" \
           -A "$SLURM_ACCOUNT" \
           "$0"
    exit 0
fi


echo "Running on $(hostname)"
echo "Using $SLURM_CPUS_PER_TASK CPUs"


# ----------------------------
# Paths
# ----------------------------
WORKDIR=$(pwd)
OSSCAD_DIR="$(dirname "$WORKDIR")/oss-cad-suite"
OSSCAD_URL="https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-03-26/oss-cad-suite-linux-x64-20260326.tgz"


# ----------------------------
# Install oss-cad-suite if missing
# ----------------------------
if [ ! -d "$OSSCAD_DIR" ]; then
	echo "📥 Downloading oss-cad-suite to $OSSCAD_DIR..."
	mkdir -p "$OSSCAD_DIR"
	curl -L -o "$OSSCAD_DIR/oss-cad-suite.tgz" "$OSSCAD_URL"
	tar -xzf "$OSSCAD_DIR/oss-cad-suite.tgz" -C "$(dirname "$OSSCAD_DIR")"
	rm "$OSSCAD_DIR/oss-cad-suite.tgz"
fi


source "$OSSCAD_DIR/environment"


# ----------------------------
# Tool binaries
# ----------------------------
YOSYS_BIN=$(which yosys)
NEXTPNR_BIN=$(which nextpnr-ice40)
ICEPACK_BIN=$(which icepack)

echo "✅ Tools ready"
echo "Yosys: $YOSYS_BIN"
echo "NextPNR: $NEXTPNR_BIN"


# ----------------------------
# Synthesis / P&R / Bitstream
# ----------------------------
TOP=top
PCF=top.pcf

SRCS=$(find . -maxdepth 3 -name "*.sv" ! -name "*_tb.sv" -not -path "*/.*")

# Start resource usage logging in background
STATS_LOG=stats.log
rm -f "$STATS_LOG"
(
	while true; do
		echo "--- $(date) ---" >> "$STATS_LOG"
		free -h >> "$STATS_LOG"
		top -b -n 1 | head -20 >> "$STATS_LOG"
		echo >> "$STATS_LOG"
		sleep 300
	done
) &
STATS_PID=$!

echo "📦 Synthesizing design with Yosys..."
"$YOSYS_BIN" -p "read_verilog -sv $SRCS; synth_ice40 -top $TOP -flatten -json top.json" | tee yosys.log
YOSYS_STATUS=${PIPESTATUS[0]}
if [ $YOSYS_STATUS -ne 0 ]; then
	kill $STATS_PID 2>/dev/null
	echo "❌ Yosys failed with exit code $YOSYS_STATUS. See yosys.log for details."
	exit $YOSYS_STATUS
fi

echo "📐 Running place & route with NextPNR..."
"$NEXTPNR_BIN" \
	--up5k \
	--package sg48 \
	--threads $SLURM_CPUS_PER_TASK \
	--json top.json \
	--pcf "$PCF" \
	--asc top.asc | tee nextpnr.log
NEXTPNR_STATUS=${PIPESTATUS[0]}
if [ $NEXTPNR_STATUS -ne 0 ]; then
	kill $STATS_PID 2>/dev/null
	echo "❌ NextPNR failed with exit code $NEXTPNR_STATUS. See nextpnr.log for details."
	exit $NEXTPNR_STATUS
fi

echo "🔧 Packing bitstream..."
"$ICEPACK_BIN" top.asc top.bin | tee icepack.log
ICEPACK_STATUS=${PIPESTATUS[0]}
if [ $ICEPACK_STATUS -ne 0 ]; then
	kill $STATS_PID 2>/dev/null
	echo "❌ IcePack failed with exit code $ICEPACK_STATUS. See icepack.log for details."
	exit $ICEPACK_STATUS
fi

# Stop resource usage logging
kill $STATS_PID 2>/dev/null

echo "✅ Bitstream ready: top.bin"

echo "--- Output summary ---"
ls -lh top.json top.asc top.bin yosys.log nextpnr.log icepack.log "$STATS_LOG" 2>/dev/null || true
