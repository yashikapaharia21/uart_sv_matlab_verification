#!/bin/bash
# =============================================================================
# Project : UART TX Verification
# File    : run_sim.sh
# Usage   : bash sim/run_sim.sh [iverilog|questa|vcs]
#
# Default simulator is Icarus Verilog (free, open-source, works on any OS).
# =============================================================================

SIM=${1:-iverilog}
mkdir -p sim

echo "============================================"
echo "  UART TX Simulation  |  Simulator: $SIM"
echo "============================================"

# Run from the project root regardless of where the script is called from
cd "$(dirname "$0")/.."

if [ "$SIM" = "iverilog" ]; then
    echo "[1/2] Compiling..."
    iverilog -g2012 \
        -o sim/uart_sim \
        rtl/uart_tx.sv \
        tb/uart_tx_tb.sv || { echo "Compile failed"; exit 1; }

    echo "[2/2] Running simulation..."
    cd sim && vvp uart_sim
    echo ""
    echo "Done. Open sim/uart_tx_waves.vcd in GTKWave to view the waveform."

elif [ "$SIM" = "questa" ]; then
    vlog -sv rtl/uart_tx.sv tb/uart_tx_tb.sv
    vopt uart_tx_tb -o uart_tx_tb_opt +acc
    vsim uart_tx_tb_opt -do "run -all; quit -f"

elif [ "$SIM" = "vcs" ]; then
    vcs -sverilog rtl/uart_tx.sv tb/uart_tx_tb.sv -o sim/uart_simv
    sim/uart_simv

else
    echo "Unknown simulator '$SIM'. Use: iverilog, questa, or vcs"
    exit 1
fi
