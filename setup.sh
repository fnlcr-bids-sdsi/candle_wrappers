#!/bin/bash

# The point of this script is for it to automatically complete new or even partial installations of CANDLE but to not re-install anything; that must be done explicitly if that's desired
# It should therefore run pretty quickly if everything is already installed, not changing anything significant
# We should be able to run this script without worrying about it overwritting something already there

interactive=0

check_file_before_continuing() {
    file_to_check=$1
    echo -n "Have you thoughly checked '$file_to_check' (y/n)? "
    read -r response
    if [ "x$response" != "xy" ]; then
        echo "Okay, go ahead and thoroughly check '$file_to_check' and re-run this script"
        exit 1
    fi
}

environment_check() {
    echo -e "\n\n---------------- ENVIRONMENT CHECK ----------------"
    echo -e "\nPATH: $PATH"
    echo -e "\nLD_LIBRARY_PATH: $LD_LIBRARY_PATH"
    echo -e "\nLD_RUN_PATH: $LD_RUN_PATH"
    echo -e "\nldd /usr/local/OpenMPI/4.0.4/CUDA-10.2/gcc-9.2.0/lib/libmpi.so:"
    ldd /usr/local/OpenMPI/4.0.4/CUDA-10.2/gcc-9.2.0/lib/libmpi.so
    echo -e "\n---------------------------------------------------\n\n"
}

export OMPI_MCA_btl="^openib"

# Print commands just before execution
set -x

# Exit when any command fails
set -e

environment_check

# Load the best Python module
module load "$DEFAULT_PYTHON_MODULE"

# Create the necessary directories not already created using the instructions in README.md
[ -d "$CANDLE/bin" ] || mkdir "$CANDLE/bin"
[ -d "$CANDLE/builds" ] || mkdir "$CANDLE/builds"

# Check out the necessary software from GitHub
[ -d "$CANDLE/checkouts/Supervisor" ] || git clone --branch develop https://github.com/ECP-CANDLE/Supervisor "$CANDLE/checkouts/Supervisor"
[ -d "$CANDLE/checkouts/Benchmarks" ] || git clone --branch develop https://github.com/ECP-CANDLE/Benchmarks "$CANDLE/checkouts/Benchmarks"
[ -d "$CANDLE/checkouts/swift-t" ] || git clone https://github.com/swift-lang/swift-t "$CANDLE/checkouts/swift-t"

# Create the build subdirectories
[ -d "$CANDLE/builds/R/libs" ] || mkdir -p "$CANDLE/builds/R/libs"
[ -d "$CANDLE/builds/swift-t-install" ] || mkdir "$CANDLE/builds/swift-t-install"

# Create symbolic links in the main CANDLE directory
[ -L "$CANDLE/wrappers" ] || ln -s "$CANDLE/checkouts/wrappers" "$CANDLE/wrappers"
[ -L "$CANDLE/Supervisor" ] || ln -s "$CANDLE/checkouts/Supervisor" "$CANDLE/Supervisor"
[ -L "$CANDLE/Benchmarks" ] || ln -s "$CANDLE/checkouts/Benchmarks" "$CANDLE/Benchmarks"
[ -L "$CANDLE/swift-t" ] || ln -s "$CANDLE/checkouts/swift-t" "$CANDLE/swift-t"
[ -L "$CANDLE/R" ] || ln -s "$CANDLE/builds/R" "$CANDLE/R"
[ -L "$CANDLE/swift-t-install" ] || ln -s "$CANDLE/builds/swift-t-install" "$CANDLE/swift-t-install"

environment_check

# Load the CANDLE environment
if [ "x$interactive" == "x1" ]; then
    check_file_before_continuing "$CANDLE/Supervisor/workflows/common/sh/env-biowulf.sh"
fi
# shellcheck source=/dev/null
source "$CANDLE/Supervisor/workflows/common/sh/env-biowulf.sh"

environment_check

# Test MPI communications
mpicc -o "$CANDLE/wrappers/test_files/hello" "$CANDLE/wrappers/test_files/hello.c"
srun --mpi=pmix --ntasks="$SLURM_NTASKS" --cpus-per-task="$SLURM_CPUS_PER_TASK" --mem=0 "$CANDLE/wrappers/test_files/hello"

# Set and enter the local scratch directory
LOCAL_DIR="/lscratch/$SLURM_JOB_ID"
cd "$LOCAL_DIR"

# Install the R packages needed for the Supervisor workflows
if [ "$(find "$CANDLE/builds/R/libs" -maxdepth 1 | wc -l)" -eq 1 ]; then # if the directory is empty...
    environment_check
    "$CANDLE/Supervisor/workflows/common/R/install-candle.sh" |& tee -a "$LOCAL_DIR/candle-r_installation_out_and_err.txt"
    mv "$LOCAL_DIR/candle-r_installation_out_and_err.txt" "$CANDLE/wrappers/log_files"
fi

# Build Swift/T
if [ "$(find "$CANDLE/swift-t-install/" -maxdepth 1 | wc -l)" -eq 1 ]; then # if the directory is empty...

    environment_check

    # Set up the settings file
    cp -i "$CANDLE/wrappers/swift-t_setup/swift-t-settings-biowulf.sh" "$CANDLE/swift-t/dev/build/swift-t-settings.sh"
    echo "Now edit $CANDLE/swift-t/dev/build/swift-t-settings.sh as appropriate (or the \$CANDLE_... variables in $CANDLE/Supervisor/workflows/common/sh/env-biowulf.sh), comparing with $CANDLE/swift-t/dev/build/swift-t-settings.sh.template (or comparing that template with $CANDLE/wrappers/swift-t_setup/swift-t-settings.sh.template), if needed"
    check_file_before_continuing "$CANDLE/swift-t/dev/build/swift-t-settings.sh"

    # Do the build
    export NICE_CMD=""
    "$CANDLE/swift-t/dev/build/build-swift-t.sh" -v |& tee -a "$LOCAL_DIR/swift-t_installation_out_and_err.txt"
    mv "$LOCAL_DIR/swift-t_installation_out_and_err.txt" "$CANDLE/wrappers/log_files"
fi

# Build EQ-R
if [ "$(find "$CANDLE/Supervisor/workflows/common/ext/EQ-R/" -maxdepth 1 | wc -l)" -eq 3 ]; then # if the directory is essentially empty (only containing the eqr directory and EQR.swift file)...

    environment_check

    # Set up the settings file
    cp -i "$CANDLE/wrappers/swift-t_setup/eqr_settings-biowulf.sh" "$CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/settings.sh"
    echo "Now edit $CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/settings.sh as appropriate (or the \$CANDLE_... variables in $CANDLE/Supervisor/workflows/common/sh/env-biowulf.sh), comparing with $CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/settings.template.sh (or comparing that template with $CANDLE/wrappers/swift-t_setup/eqr_settings.sh.template), if needed"
    check_file_before_continuing "$CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/settings.sh"

    # Do the build
    (
        cd "$CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr"
        # shellcheck source=/dev/null
        source ./settings.sh
        ./bootstrap # this runs ``autoconf`` and generates ``./configure``
        ./configure --prefix="$PWD/.."
        make install
    ) |& tee -a "$CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/eqr_installation_out_and_err.txt"
    mv "$CANDLE/Supervisor/workflows/common/ext/EQ-R/eqr/eqr_installation_out_and_err.txt" "$CANDLE/wrappers/log_files"

fi

environment_check

# Optionally run a CANDLE benchmark just to see if that would work
echo -n "Would you like to try running a CANDLE benchmark using Python on a single node? (y/n)? "
if [ "x$interactive" == "x1" ]; then
    read -r response
else
    response="n"
fi
if [ "x$response" == "xy" ]; then
    echo "Okay, running the benchmark now; hit Ctrl+C to kill the process; then re-run this script"
    srun --mpi=pmix --ntasks=1 --mem=0 python "$CANDLE/Benchmarks/Pilot1/P1B3/p1b3_baseline_keras2.py"
else
    echo "Okay, skipping the benchmark run"
fi


#/usr/local/slurm/bin/srun -n 1 '--mpi=pmix' '--mem=0' /usr/local/Tcl_Tk/8.6.8/gcc_7.2.0/bin/tclsh8.6 /data/BIDS-HPC/public/software/distributions/candle/dev_2/wrappers/test_files/swift-t-mytest2.1kr.tic
# export TURBINE_HOME=/data/BIDS-HPC/public/software/distributions/candle/dev_2/swift-t-install/turbine
# TCLLIBPATH+=/data/BIDS-HPC/public/software/distributions/candle/dev_2/swift-t-install/turbine/lib
# srun --mpi=pmix --ntasks=1 --mem=0 /usr/local/Tcl_Tk/8.6.8/gcc_7.2.0/bin/tclsh8.6 /data/BIDS-HPC/public/software/distributions/candle/dev_2/wrappers/test_files/swift-t-mytest2-andrew.adt.tic

# Test 1: output is a single line saying hello
#export TURBINE_LAUNCH_OPTIONS="--mpi=pmix --mem=0"
#export TURBINE_LAUNCH_OPTIONS="--mem=0"

# # RUN THIS IN BATCH
# #export TURBINE_LAUNCH_OPTIONS="--mpi=pmix" # SET THIS IF SWIFT-T DOESN'T WORK IN BATCH MODE!!!!
# export TURBINE_LAUNCH_OPTIONS="--mpi=pmix --mem=0"
# swift-t -VV -n 3 "$CANDLE/wrappers/test_files/mytest2.swift"

#/usr/local/slurm/bin/srun -n 3 '--mpi=pmix' '--mem=0' /usr/local/Tcl_Tk/8.6.8/gcc_7.2.0/bin/tclsh8.6 /data/BIDS-HPC/public/software/distributions/candle/dev_2/wrappers/test_files/swift-t-mytest2-andrew.adt.tic
# cd /data/BIDS-HPC/public/software/distributions/candle/dev_2/swift-t-install/turbine/lib
# /usr/local/slurm/bin/srun -n 3 --mpi=pmix --mem=0 /usr/local/Tcl_Tk/8.6.8/gcc_7.2.0/bin/tclsh8.6 /data/BIDS-HPC/public/software/distributions/candle/dev_2/wrappers/test_files/swift-t-mytest2-andrew.adt.tic

# Make sure the command looks like "srun --mpi=pmix --ntasks=3 --cpus-per-task=16 ./a.out"
#/usr/local/slurm/bin/srun -n 1 '--mpi=pmix' /usr/local/Tcl_Tk/8.6.8/gcc_7.2.0/bin/tclsh8.6 /data/BIDS-HPC/public/software/distributions/candle/dev_2/wrappers/test_files/swift-t-mytest2.ATe.tic

    # # Test 2: time-delayed printouts of some numbers
    # swift-t -n 3 -r $BUILD_SCRIPTS_DIR $BUILD_SCRIPTS_DIR/myextension.swift



environment_check

# Setup
BUILD_SCRIPTS_DIR="/home/weismanal/candle/wrappers/build"

# Test 1: output is a single line saying hello
export TURBINE_LAUNCH_OPTIONS="--mpi=pmix --mem=0"
swift-t -VV -n 3 $BUILD_SCRIPTS_DIR/mytest2.swift

# # Test 2: time-delayed printouts of some numbers
# swift-t -VV -n 3 -r $BUILD_SCRIPTS_DIR $BUILD_SCRIPTS_DIR/myextension.swift



# Ensure permissions are correct
echo -n "Would you like to recursively set the correct permissions on the \$CANDLE directory? (y/n)? "
if [ "x$interactive" == "x1" ]; then
    read -r response
else
    response="n"
fi
if [ "x$response" == "xy" ]; then
    echo "Okay, setting permissions..."
    chmod -R g=u,o=u-w "$CANDLE"
else
    echo "Okay, skipping the permissions setting"
fi

# Print whether the previous commands were successful
set +x
echo "Probably success"
