#!/bin/sh

# Load configuration settings
. $PWD/CONFIG

# Import functions from build_macros.sh
. $PWD/build-macros.sh


# 1 - GMP.
#==================================

    # a. Download
    #----------------------------------

    GMP_ARCHIVE="gmp-${GMP_VERSION}.tar.gz"

    if [ ! -e "gmp-${GMP_VERSION}" ] ; then 
        echo "Downloading ${GMP_ARCHIVE} from ftp://ftp.gmplib.org/pub/gmp-${GMP_VERSION}/"
        run curl -OL ftp://ftp.gmplib.org/pub/gmp-${GMP_VERSION}/${GMP_ARCHIVE} 
        run tar xzf ${GMP_ARCHIVE}
        run rm ${GMP_ARCHIVE}
    fi

    # BUILD AND TEMP INSTALL DIRECTORIES
    # ----------------------------------

    SRC_DIR="${PWD}/gmp-${GMP_VERSION}"

    # Fake install prefixes.
    BUILT_PREFIX="${PWD}/install/usr/local"
    mkdir -p $BUILT_PREFIX/lib $BUILT_PREFIX/include $BUILT_PREFIX/bin $BUILT_PREFIX/share

    # Compiled object directory
    BUILD_DIR=${PWD}/build
    mkdir -p ${BUILD_DIR}

    # Debug symbol directory
    DSYMDIR="${PWD}/debug"
    mkdir -p ${DSYMDIR}

    TRIPLE="${BUILD_ARCH}-apple-darwin${DARWIN_VERS}"

    # b. Build i386 binary
    #----------------------------------

    cd $SRC_DIR
    BUILT32_PREFIX="${SRC_DIR}/install-i386"
    mkdir -p ${BUILT32_PREFIX}
    mkdir build-i386
    cd    build-i386/

    if [ ! -e make.checked ] ; then
        CFLAGS="-arch i386 -O2" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include" \
            LDFLAGS="-arch i386 \
                     -O2 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -L/usr/lib" \
            ARCHFLAGS="-arch i386" \
            FFLAGS="-arch i386" \
            ../configure --enable-werror --prefix=${BUILT32_PREFIX} --build=i686-apple-darwin11 --host=i386-apple-darwin11 \
                || exit 1

        run make -j${N_MAKE}
        check
    fi
    run make install

    # c. Build x86_64 binary
    #----------------------------------

    cd $SRC_DIR
    BUILT64_PREFIX="$SRC_DIR/install-x86_64"
    mkdir -p ${BUILT64_PREFIX}
    mkdir build-x86_64
    cd build-x86_64

    if [ ! -e make.checked ] ; then
        CFLAGS="-arch x86_64 -O2" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include" \
            LDFLAGS="-arch x86_64 \
                     -O2 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -L/usr/lib" \
            ARCHFLAGS="-arch x86_64" \
            FFLAGS="-arch x86_64" \
            ../configure --enable-werror --prefix=${BUILT64_PREFIX} --build=i686-apple-darwin11 --host=x86_64-apple-darwin11 \
                || exit 1

        run make -j${N_MAKE}
        check
    fi
    run make install
    cd ..

    # d. Link with lipo
    #----------------------------------

    echo "\nMaking GMP fat binary...\n"
    libversion=`grep dlname ${BUILT64_PREFIX}/lib/libgmp.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
    linkversions=`grep "library_names" ${BUILT64_PREFIX}/lib/libgmp.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
    if [ ! -e $BUILT_PREFIX/lib/${libversion} ] ; then
        run lipo -create ${BUILT32_PREFIX}/lib/${libversion} -create ${BUILT64_PREFIX}/lib/${libversion} \
            -output $BUILT_PREFIX/lib/${libversion} || exit 1
    fi
    if [ ! -e $BUILT_PREFIX/lib/libgmp.a ] ; then
        run lipo -create ${BUILT32_PREFIX}/lib/libgmp.a      -create ${BUILT64_PREFIX}/lib/libgmp.a \
            -output $BUILT_PREFIX/lib/libgmp.a || exit 1
    fi

    cd $BUILT_PREFIX/lib
    for tolink in $linkversions ; do
        ln -sf $libversion $tolink
    done
    cd ${SRC_DIR}/

    # e. Patch header and libtool file, as per 
    #    http://gmplib.org/list-archives/gmp-discuss/2010-September/004312.html
    #----------------------------------

    # Patch gmp.h header
    cp  ${BUILT64_PREFIX}/include/gmp.h $BUILT_PREFIX/include/
    run patch -u $BUILT_PREFIX/include/gmp.h ../patch/gmp.h.diff

    # edit libgmp.la file
    run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}/lib/libgmp.la > $BUILT_PREFIX/lib/libgmp.la

    # f. Install to /usr/local
    #--------------------------

    if [ "`id`" = "`id root`" ] ; then
        echo "\nInstalling $libversion to ${PREFIX}\n"
        run cp -v $BUILT_PREFIX/include/* ${PREFIX}/include/
        run cp -v $BUILT_PREFIX/lib/*     ${PREFIX}/lib/
    fi

    # z. Leave gmp directory
    cd ${SRC_DIR}/..


# 2 - MPFR
#=================================

    # a. Download
    #----------------------------------
    echo "\nMPFR\n====\n"

    if [ ! -e "mpfr-${MPFR_VERSION}" ] ; then
        echo "Downloading mpfr-${MPFR_VERSION} from http://www.mpfr.org/mpfr-${MPFR_VERSION}"
        curl -OL "http://www.mpfr.org/mpfr-${MPFR_VERSION}/mpfr-${MPFR_VERSION}.tar.gz" || exit 1
        tar xzf mpfr-${MPFR_VERSION}.tar.gz || exit 1
        rm mpfr-${MPFR_VERSION}.tar.gz || exit 1
    fi

    cd mpfr-${MPFR_VERSION}
    SRC_DIR=${PWD}

    # b. Build i386 binary
    #----------------------------------

    BUILT32_PREFIX="${SRC_DIR}/install-i386"
    if [ ! -e build-i386 ] ; then
        mkdir -p build-i386 $BUILT32_PREFIX
    fi
    cd build-i386

    if [ ! -e make.checked ] ; then
        echo "Configuring mpfr-i386"
        CFLAGS="-arch i386 -O2" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include \
                      -I$BUILT_PREFIX/include" \
            LDFLAGS="-arch i386 \
                     -O2 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -L/usr/lib \
                     -L$BUILT_PREFIX/lib" \
            ARCHFLAGS="-arch i386" \
            FFLAGS="-arch i386" \
            ${SRC_DIR}/configure --prefix="${BUILT32_PREFIX}" || exit 1

        echo "configured. Cleaning"

        make clean > /dev/null 2&>1 
        run make -j${N_MAKE}
        check
        run make install
    fi
    cd  ..

    # c. Build x86_64 binary
    #----------------------------------

    BUILT64_PREFIX="${SRC_DIR}/install-x86_64"
    if [ ! -e build-x86_64 ] ; then
        mkdir -p build-x86_64 $BUILT64_PREFIX
    fi
    cd build-x86_64

    if [ ! -e make.checked ] ; then
        echo "Configuring mpfr-x86_64"
        echo "-----------------------"
        CFLAGS="-arch x86_64 -O2" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include \
                      -I$BUILT_PREFIX/include" \
            LDFLAGS="-arch x86_64 \
                     -O2 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -L/usr/lib \
                     -L$BUILT_PREFIX/lib" \
            ARCHFLAGS="-arch x86_64" \
            FFLAGS="-arch x86_64" \
            $SRC_DIR/configure --prefix="${BUILT64_PREFIX}" \
                || exit 1

        make clean > /dev/null 2&>1 
        run make -j${N_MAKE}
        check
        run make install
    fi
    cd  ..

    # d. Link with lipo
    #----------------------------------

    echo "\nMaking MPFR fat binary...\n"
    libversion=`grep dlname ${BUILT64_PREFIX}/lib/libmpfr.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
    linkversions=`grep "library_names" ${BUILT64_PREFIX}/lib/libmpfr.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
    if [ ! -e $BUILT_PREFIX/lib/$libversion ] ; then
        run lipo -create ${BUILT32_PREFIX}/lib/$libversion -create ${BUILT64_PREFIX}/lib/$libversion \
            -output ${BUILT_PREFIX}/lib/$libversion || exit 1
    fi
    if [ ! -e $BUILT_PREFIX/lib/libmpfr.a ] ; then
        run lipo -create ${BUILT32_PREFIX}/lib/libmpfr.a   -create ${BUILT64_PREFIX}/lib/libmpfr.a   \
            -output ${BUILT_PREFIX}/lib/libmpfr.a   || exit 1
    fi

    cd $BUILT_PREFIX/lib
    for tolink in $linkversions ; do
        ln -sf $libversion $tolink
    done
    cd ../..


    # d. Copy over headers (diff -r shows that i386 build uses same headers as x86 build)
    #----------------------------------

    cp -p  $BUILT32_PREFIX/include/*.h $BUILT_PREFIX/include/
    cp -pr $BUILT32_PREFIX/share       $BUILT_PREFIX/

    # patch libmpfr.la file for temp installation directory
    run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}/lib/libmpfr.la > ${BUILT_PREFIX}/lib/libmpfr.la

    # e. Install
    #----------------------------------

    # If we are the sudo user, then install to ${PREFIX}
    #  Otherwise, we'll prompt the user later to run `ditto ${BUILT_PREFIX} ${PREFIX}`
    if [ "`id`" = "`id root`" ] ; then
        # patch libmpfr.la file for installation directory
        run sed -e "s|^libdir.*$|libdir='${PREFIX}/lib'|" ${BUILT32_PREFIX}/lib/libmpfr.la > ${PREFIX}/lib/libmpfr.la
        echo "\nInstalling ${libversion} to ${PREFIX}\n"
        run cp -v  ${BUILT_PREFIX}/include/* ${PREFIX}/include/
        run cp -v  ${BUILT_PREFIX}/lib/*     ${PREFIX}/lib/
        run cp -rv ${BUILT_PREFIX}/share     ${PREFIX}/
    fi

    cd ..

    echo "\nMade MPFR fat binary. W00t!\n"
