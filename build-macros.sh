#!/bin/sh

# Convenience functions
#==================================

# Run the given arguments as a program. 
#  If the program returns an error code,
#  stop further processing of this file.
run () {
    $*
    retcode="$?"
    if [ "$retcode" != "0" ] ; then
        echo "$1 failed with return code $retcode"
        exit 1
    fi
}

check () {
    run make -j${N_MAKE} check
    # don't get here if make check fails
    touch make.checked
}
