#!/bin/bash

# Create simulation directory
mkdir -p sim

# Clean up previous runs
rm -rf sim/*

# Change to simulation directory
cd sim

# Set environment variables
export DISPLAY=${DISPLAY:-:0.0}
export DVE_STARTUP_NO_LC_WARN=1

# Compile with VCS
echo "Compiling design..."
vcs -sverilog \
    -debug_access+all \
    -debug_region+cell+encrypt \
    -debug_pp \
    -full64 \
    +v2k \
    -timescale=1ns/1ps \
    +lint=all \
    +warn=all \
    -kdb \
    -lca \
    +memcbk \
    -debug_acc+dmptf \
    -debug_region+cell \
    -debug_region+encrypt \
    -debug_region+class \
    -debug_region+sva \
    -debug_region+fsm \
    -debug_region+array \
    -debug_region+array2d \
    -debug_region+array3d \
    -debug_region+memory \
    -debug_access+r \
    -debug_access+w \
    -debug_access+nomemcbk \
    ../grayscale.sv \
    ../gaussian_blur.sv \
    ../sobel_edge.sv \
    ../nonmax_supress.sv \
    ../double_treshold.sv \
    ../hyst_treshold.sv \
    ../canny.sv \
    ../test_canny.sv \
    -o simv \
    -l compile.log

# Check if compilation was successful
if [ $? -eq 0 ]; then
    echo "Compilation successful. Starting simulation..."
    
    # Run simulation
    ./simv \
        -l sim.log \
        +lint=all \
        +warn=all \
        +vpdfile+waves.vpd \
        +vpdports \
        +vpdfile+strength=1 \
        +vcs+dumpvars+test_canny.vpd \
        -dbgRuntimeDir=dbg \
        +memcbk
    
    # Check simulation status
    if [ $? -eq 0 ]; then
        echo "Simulation completed successfully. Opening waveform viewer..."
        exit 1
    fi
else
    echo "Compilation failed. Check sim/compile.log for errors"
    exit 1
fi

# Return to original directory
cd ..