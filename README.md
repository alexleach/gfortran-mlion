#========================================================================

This is the README for gfortran-mlion, shared for your convenience, at 
    https://github.com/alexleach/gfortran-mlion


PROJECT DESCRIPTION
#========================================================================
Apple have stopped distributing a Fortran compiler with Xcode, so there 
is a need to get a working Fortran cross-compiler on Mountain Lion. In
the advent of an installer or binary, this project just aims to share 
a script I'm (still) writing, in order to build a multi-architecture 
version of llvm-gfortran-4.2.

For more info, see my stackoverflow question at:
     http://stackoverflow.com/questions/12316780

This is currently a work in progress, as I'm still learning about Apple's
nuances.

The goal then, (for me) is to get this script to build a universal binary
(i386, x86\_64) of llvm-gfortran-4.2. I am unable to test or compile a
powerpc compatible version, as I don't have the necessary hardware, or
software, with which to do so. If anyone wants to help with that, please
get in touch!

Any comments, help or feedback are completely welcome, at:-
    beamesleach <at> gmail <dot> com


PACKAGE CONTENTS
#========================================================================

This project contains the following files:-
    CONFIG
    build-gfortran.sh 
    patch/gmp.h.patch

File Descriptions
#========================================================================

    CONFIG
#------------------------------------------------------------------------
Any easily customisable configuration settings, like installation prefix,
have been put into this file. The file is read as a bash script by
build-gfortran.sh


    build-gfortran.sh
#------------------------------------------------------------------------
This does everything. Just run it from the command line, and this will 
download, build and install everything you need for a working fortran 
compiler on your system.


    Anything else.
#------------------------------------------------------------------------
Don't worry about it, build-gfortran.sh should do all the work for you.


TODO
#========================================================================

10th Sep 2012
-------------
Actually get it to work...


