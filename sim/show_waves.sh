#!/usr/bin/env bash
# Run the simulation, then open the waveform in Surfer with the key signals loaded.
#   Install once:  brew install surfer
set -euo pipefail
cd "$(dirname "$0")"
./run.sh | tail -3
surfer wb_cache.vcd -c waves.sucl
