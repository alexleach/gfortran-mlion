#!/bin/bash

#==============================================================================
# File: install-gfortran.sh
# Description: After building, we need to make some changes to the dynamic
#    libraries and static archives. 
#  Two things to do, really: 
#    1) change `libdir' in any .la files.
#    2) Run `ranlib -install_name ...' on any dylibs and archives.
#
#==============================================================================

. CONFIG

BUILT_PREFIX="${PWD}/install${PREFIX}"


#==============================================================================
#  a)     libgmp and libmpfr

    ## Need to clean up the libgmp.la and libmpfr.la files.

    sed -e "s,^libdir=.*$,libdir=\\'${PREFIX}/lib\\'," -i '' "${BUILT_PREFIX}/lib/libgmp.la"
    sed -e "s,^libdir=.*$,libdir=\\'${PREFIX}/lib\\'," -i '' "${BUILT_PREFIX}/lib/libmpfr.la"


    gmpversion="`grep dlname ${BUILT_PREFIX}/lib/libgmp.la  | sed -e s/^.*=\'// -e s/\'$//`"
    mpfversion="`grep dlname ${BUILT_PREFIX}/lib/libmpfr.la | sed -e s/^.*=\'// -e s/\'$//`"

    #echo install_name_tool -change "${BUILT_PREFIX}/lib/x86_64/$gmpversion" ${PREFIX}/lib/$gmpversion \
    #    "${BUILT_PREFIX}/lib/$gmpversion" || exit 1
    #install_name_tool -id ${PREFIX}/lib/$gmpversion \
    #    -change "${BUILT_PREFIX}/lib/x86_64/$gmpversion" ${PREFIX}/lib/$gmpversion \
    #    "${BUILT_PREFIX}/lib/$gmpversion" || exit 1
    #echo install_name_tool -change "${BUILT_PREFIX}/lib/x86_64/$mpfversion" ${PREFIX}/lib/$mpfversion \
    #    "${BUILT_PREFIX}/lib/$mpfversion" || exit 1
    #install_name_tool  -id ${PREFIX}/lib/$mpfversion \
    #    -change "${BUILT_PREFIX}/lib/x86_64/$mpfversion" ${PREFIX}/lib/$mpfversion \
    #    "${BUILT_PREFIX}/lib/$mpfversion" || exit 1


#==============================================================================
#  a)     libgfortran

    gfrversion="`grep dlname ${BUILT_PREFIX}/lib/libgfortran.la | sed -e s/^.*=\'// -e s/\'$//`"

    install_name_tool -id "${PREFIX}/lib/$gfrversion" \
        -change "${PREFIX}/lib/x86_64/$gfrversion" "${PREFIX}/lib/$gfrversion" \
        "${BUILT_PREFIX}/lib/$gfrversion" || exit 1


    echo "We're now ready to install! "
    echo "Installing into ${PREFIX}"

    ditto -v "${BUILT_PREFIX}" "${PREFIX}" 
    retcode="$?"
    if [ "$retcode" = "1" ] ; then # no permissions
        echo "Error! Error code: $retcode!"
        echo "If there are a load of permission errors above, run the following command:-"
        echo sudo ditto -v "${BUILT_PREFIX}" "$PREFIX"
    fi

exit 0

