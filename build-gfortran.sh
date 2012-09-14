#!/bin/sh

#==============================================================================
#
# File: build-gfortran.sh
#
# Description: Download and build gfortran and its dependencies for 
#      Mac OS X Mountain Lion.
#      The llvm-gfortran compiler additionally depends on GNU's GMP and
#      MPFR libraries. These each need to be built twice and then libraries 
#      linked with `lipo'.
#
#
#==============================================================================

## BUILD STEPS
##  1 - Download, build and 'lipo' GMP
##  2 - Download, build and 'lipo' MPFR
##  3 - Download, build and 'lipo' LLVM, which comes with Apple's gcc.
##  4 - Download, build and 'lipo' GCC.

# LOAD CONFIGURATION VARIABLES
#========================
. CONFIG
. build-macros.sh


run ./build-deps.sh 
run ./build-llvmgcc.sh
run ./build-gcc.sh 

