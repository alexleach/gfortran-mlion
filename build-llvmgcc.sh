#!/bin/bash

. $PWD/CONFIG
. $PWD/build-macros.sh

# 3 - Apple's LLVM GCC compiler
#=================================

# a - Download, extract, enter build dir
#---------------------------------

if [ ! -d "${LLVM_VERSION}" ]; then
    echo "Downloading ${LLVM_VERSION} from http://opensource.apple.com/tarballs/llvmgcc42/${LLVM_VERSION}.tar.gz"
    curl -OL "http://opensource.apple.com/tarballs/llvmgcc42/${LLVM_VERSION}.tar.gz"
    tar xzf ${LLVM_VERSION}.tar.gz
    rm ${LLVM_VERSION}.tar.gz
fi

SRC_DIR="${PWD}/${LLVM_VERSION}"

# Fake install prefixes.
#BUILT32_PREFIX="${PWD}/install-i386/usr/local"
#BUILT64_PREFIX="${PWD}/install-x86_64/usr/local"
BUILT_PREFIX="${PWD}/install${PREFIX}"
#mkdir -p $BUILT32_PREFIX $BUILT64_PREFIX $BUILT_PREFIX

# Compiled object directory
BUILD_DIR=${SRC_DIR}/build
mkdir -p ${BUILD_DIR}

# Debug symbol directory
DSYMDIR="${SRC_DIR}/debug"
mkdir -p ${DSYMDIR}

TRIPLE="${BUILD_ARCH}-apple-darwin${DARWIN_VERS}"



# b - Build LLVM, then GCC, if make.checked doesn't exist
#--------------------------------------------------------

if [ ! -f make.checked ] ; then

    cd ${BUILD_DIR}

    if [ -f Makefile ] ; then
        echo "Cleaning build directory"
        #run make clean
        # `make clean` isn't enough. Why?
        #rm -rf ./*
    fi


# c - Apply patches
#---------------------------------

    # Patch gthr.h to properly include <bits/gthr-*.h>
    # This then breaks the gcc build... Added the include below..
    # sed -i -e 's|^#include "gthr\-\(.*\)\.h"$|#include \<bits/gthr\-\1.h\>|g' ${SRC_DIR}/gcc/gthr.h

# d - Build LLVM the Apple way. ffs...
#---------------------------------

    # (Follow the code, and get what we want, modifying as necessary...)
    # From ${LLVM_VERSION}/GNUMakefile:-
    #
    #	  $(SRC)/llvmCore/utils/buildit/build_llvm 
    #       "$(RC_ARCHS)" "$(TARGETS)" \
    #	    $(SRC)/llvmCore 
    #       /usr/local 
    #       $(DSTROOT) 
    #       $(SYMROOT) \
    #	    $(ENABLE_ASSERTIONS) $(LLVM_OPTIMIZED) $(INSTALL_LIBLTO) \
    #	    $(RC_ProjectSourceVersion) $(RC_ProjectSourceSubversion) 

    # How nice would it be if this command actually worked to compile gfortran?
    #    DEVELOPER_DIR=Developer \
    #        ${SRC_DIR}/llvmCore/utils/buildit/build_llvm \
    #        "i386 x86_64"   "i386 x86_64" \
    #        ${SRC_DIR}/llvmCore \
    #        /usr/local \
    #        ${PWD}/x86_64/llvmCore/dst \
    #        ${PWD}/x86_64/llvmCore/sym \
    #        no yes no \
    #        9999 00


# d - Build LLVM the FSF way.
#---------------------------------
# This is mostly modified code from llvmCore/utils/buildit/build_llvm

#  From ${LLVM_VERSION}/build_gcc :-
#      $SRC_DIR/configure --prefix=$DT_HOME/local \
#          --enable-targets=arm,x86,cbe \
#          --enable-assertions=$LLVM_ASSERTIONS \
#          --enable-optimized=$LLVM_OPTIMIZED \
#          --disable-bindings \
#          || exit 1

    if [ ! -f Makefile.config ] ; then
    CC="clang" \
        CXX="clang++" \
        CPPFLAGS="-I/usr/include -I/usr/include/c++/4.2.1 -I${SRC_DIR}/gcc" \
        ${SRC_DIR}/llvmCore/configure \
            --prefix="${BUILT_PREFIX}" \
            --enable-targets=arm,x86,cbe \
            --enable-assertions=no \
            --enable-optimized=yes \
            --disable-bindings \
            --with-gmp=$BUILT_DIR \
            --with-mpfr=$BUILT_DIR  || exit 1

#            --target=${TRIPLE} \
#            --host=${TRIPLE} \
#            --build=${TRIPLE} \
    fi

    echo sed -i "" -e '/[Aa]pple-style/d' -e '/include.*GNUmakefile/d' "${SRC_DIR}/llvmCore/Makefile" || exit 1
    sed -i "" -e '/[Aa]pple-style/d' -e '/include.*GNUmakefile/d' "${SRC_DIR}/llvmCore/Makefile" || exit 1

    make -j${N_MAKE} UNIVERSAL=1 UNIVERSAL_ARCH="i386 x86_64" \
        UNIVERSAL_SDK_PATH=$SDKROOT \
        NO_RUNTIME_LIBS=1 \
        REQUIRES_RTTI=1 \
        DISABLE_EDIS=1 \
        DEBUG_SYMBOLS=1 \
        LLVM_SUBMIT_VERSION=$LLVM_VERSION_MAJOR \
        LLVM_SUBMIT_SUBVERSION=$LLVM_VERSION_MINOR \
        CXXFLAGS="-DLLVM_VERSION_INFO='\" Apple Build #$LLVM_VERSION_VERSION\"'" \
        VERBOSE=1    || exit 1

    # Install the tree into the (cleaned) destination directory.
    CPPFLAGS="-I/usr/include" \
    CXXFLAGS="-I/usr/include/c++/4.2.1" \
    make -j${N_MAKE} UNIVERSAL=1 UNIVERSAL_ARCH="i386 x86_64" \
        NO_RUNTIME_LIBS=1 \
        DISABLE_EDIS=1 \
        DEBUG_SYMBOLS=1 \
        LLVM_SUBMIT_VERSION=$LLVM_VERSION_MAJOR \
        LLVM_SUBMIT_SUBVERSION=$LLVM_VERSION_MINOR \
        OPTIMIZE_OPTION='-O3' VERBOSE=1 install || exit 1


    # Install Version.h
    RC_ProjectSourceVersion=`printf "%d" $LLVM_VERSION_MAJOR`
    RC_ProjectSourceSubversion=`printf "%d" $LLVM_VERSION_MINOR`
    echo "#define LLVM_VERSION ${RC_ProjectSourceVersion}" > ${BUILT_PREFIX}/include/llvm/Version.h
    echo "#define LLVM_MINOR_VERSION ${RC_ProjectSourceSubversion}" >> ${BUILT_PREFIX}/include/llvm/Version.h

    if [ "x$LLVM_DEBUG" != "x1" ]; then
        # Strip local symbols from llvm libraries.
        #
        # Use '-l' to strip i386 modules. N.B. that flag doesn't work with kext or
        # PPC objects!
        strip -Sl ${BUILT_PREFIX}/lib/*.[oa]
        for f in `ls ${BUILT_PREFIX}/lib/*.so`; do
            strip -Sxl $f
        done
    fi

    # Copy over the tblgen utility.
    cp `find ${BUILD_DIR} -name tblgen` ${BUILT_PREFIX}/bin/

    # Remove .dir files 
    cd ${BUILT_PREFIX}
    rm -f bin/.dir etc/llvm/.dir lib/.dir

    # Remove PPC64 fat slices.
    cd ./bin
    find . -perm 755 -type f \! \( -name '*gccas' -o -name '*gccld' -o -name llvm-config \) \
        -exec lipo -extract i386 -extract x86_64 {} -output {} \;
    cd ..

    # The Hello dylib is an example of how to build a pass. No need to install it.
    rm ${BUILT_PREFIX}/lib/*LLVMHello.dylib

    # Compress manpages
    MDIR=${BUILT_PREFIX}/share/man/man1
    gzip -f $MDIR/*

    ##### CREATE DEBUGGING SYMBOLS

    # Clean out SYM_DIR in case -noclean was passed to buildit.
    cd ${DSYMDIR}
    rm -rf ./* || exit 1

    # Generate .dSYM files
    find $BUILT_PREFIX -perm -0111 -type f \
        ! \( -name '*.la' -o -name gccas -o -name gccld -o -name llvm-config -o -name '*.a' \) \
        -print | xargs -n 1 -P ${N_MAKE} dsymutil

    # Save .dSYM files and .a archives
    cd $BUILT_PREFIX || exit 1
    find . \( -path \*.dSYM/\* -or -name \*.a \) -print \
        | cpio -pdml $DSYMDIR || exit 1

    # Save source files.
    mkdir $DSYMDIR/src || exit 1
    cd $BUILD_DIR || exit 1
    find obj-* -name \*.\[chy\] -o -name \*.cpp -print \
        | cpio -pdml $DSYMDIR/src || exit 1

    ################################################################################
    # Install and strip libLTO.dylib

    cd ${BUILT_PREFIX}
    # This if clause is ignored... Do we need this for gfortran??
    if [ "$INSTALL_LIBLTO" = "yes" ]; then
      mkdir -p $BUILD_DIR/lib
      mv lib/libLTO.dylib $BUILD_DIR/lib/libLTO.dylib

      # Use '-l' to strip i386 modules. N.B. that flag doesn't work with kext or
      # PPC objects!
      strip -arch all -Sl $BUILD_DIR/lib/libLTO.dylib
    fi
    rm -f lib/libLTO.a lib/libLTO.la

    # Omit lto.h from the result.  Clang will supply.
    find ${BUILT_PREFIX} -name lto.h -delete

    ################################################################################
    # Remove debugging information from DEST_DIR.

    cd $BUILD_DIR || exit 1

    find $BUILT_PREFIX -name \*.a -print | xargs ranlib || exit 1
    find $BUILT_PREFIX -name \*.dSYM -print | xargs rm -r || exit 1

    # Strip debugging information from files
    #
    # Use '-l' to strip i386 modules. N.B. that flag doesn't work with kext or
    # PPC objects!
    find $BUILT_PREFIX -perm -0111 -type f \
        ! \( -name '*.la' -o -name gccas -o -name gccld -o -name llvm-config \) \
        -print | xargs -n 1 -P ${N_MAKE} strip -arch all -Sl

    chgrp -h -R staff $BUILT_PREFIX
    chgrp -R staff $BUILT_PREFIX

    ################################################################################
    # Remove tar ball from docs directory

    find $BUILT_PREFIX -name html.tar.gz -delete

    # There's a couple of other things in build_llvm, but whatevs...


fi

exit 0
