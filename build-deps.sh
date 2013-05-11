#!/bin/sh

# Load configuration settings
. $PWD/CONFIG

# Import functions from build_macros.sh
. $PWD/build-macros.sh

ORIG_DIR="$PWD"


# 1 - GMP.
#==================================

    # a. Download
    #----------------------------------
    echo "GMP"

    GMP_ARCHIVE="gmp-${GMP_VERSION}.tar.bz2" 
    if [ ! -e "gmp-${GMP_VERSION}" ] ; then 
        echo "Downloading ${GMP_ARCHIVE} from ftp://ftp.gmplib.org/pub/gmp-${GMP_VERSION}/"
        run curl -OL ftp://ftp.gmplib.org/pub/gmp-${GMP_VERSION}/${GMP_ARCHIVE} 
        run tar xjf ${GMP_ARCHIVE}
        run rm ${GMP_ARCHIVE}
    fi

    # BUILD AND TEMP INSTALL DIRECTORIES
    # ----------------------------------

    SRC_DIR="${PWD}/gmp-${GMP_VERSION}"

    # Fake install prefixes.
    BUILT_PREFIX="${PWD}/install/usr/local"
    mkdir -p $BUILT_PREFIX/lib $BUILT_PREFIX/include $BUILT_PREFIX/bin $BUILT_PREFIX/share

    TRIPLE="${GCC_BUILD}-apple-darwin${DARWIN_VERS}"

    # b. Build i386 binary
    #----------------------------------

    cd $SRC_DIR
    BUILT32_PREFIX="${SRC_DIR}/install-i386"
    mkdir -p ${BUILT32_PREFIX}
    mkdir -p build-i386
    cd    build-i386/

    if [ ! -e make.checked ] ; then
        CC="gcc" CXX="g++" \
        CFLAGS="-arch i386 -O2 -fexceptions -fPIC -ftrapv -Wl,-pie" \
        CXXFLAGS="-arch i386 -O2 -fexceptions -fPIC -ftrapv -Wl,-pie" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include \
                      -fexceptions" \
            LDFLAGS="-arch i386 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -O2 " \
            ABI=32 \
            ARCHFLAGS="-arch i386" \
            ../configure \
                --enable-assert \
                --enable-cxx \
                --enable-pic \
                --enable-werror \
                --prefix=${PREFIX} \
                --build=i686-apple-darwin$DARWIN_VERS \
                --host=i686-apple-darwin$DARWIN_VERS \
                || exit $?
        run make clean
        run make -j${N_MAKE}
        check
    fi
    make install DESTDIR="${BUILT32_PREFIX}" || exit 1

    # c. Build x86_64 binary
    #----------------------------------

    cd $SRC_DIR
    BUILT64_PREFIX="$SRC_DIR/install-x86_64"
    mkdir -p ${BUILT64_PREFIX}
    mkdir build-x86_64
    cd build-x86_64

    if [ ! -e make.checked ] ; then
        CC="gcc" CXX="g++" \
        CFLAGS="-arch x86_64 -O2 -fexceptions -fno-strict-aliasing -fPIC -Wl,-pie" \
        CXXFLAGS="-arch x86_64 -O2 -fexceptions -fno-strict-aliasing -fPIC -Wl,-pie" \
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                      -I/usr/include \
                      -fexceptions" \
            LDFLAGS="-arch x86_64 \
                     -O2 \
                     -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
                     -L/usr/lib" \
            ABI=64 \
            ARCHFLAGS="-arch x86_64" \
            ../configure \
                --enable-cxx \
                --enable-pic \
                --enable-werror \
                --prefix=${PREFIX} \
                --build=$TRIPLE \
                --host=x86_64-apple-darwin$DARWIN_VERS \
                || exit 1

        run make -j${N_MAKE}
        check
    fi
    make install DESTDIR="${BUILT64_PREFIX}" || exit 1
    cd ..

    # d. Link with lipo
    #----------------------------------

    echo "\nMaking GMP fat binary...\n"
    libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libgmp.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
    linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libgmp.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libversion $BUILT_PREFIX/lib/$libversion \
        $BUILT64_PREFIX$PREFIX/lib/$libversion
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libversion $BUILT_PREFIX/lib/$libversion \
        $BUILT32_PREFIX$PREFIX/lib/$libversion
    run lipo  -output $BUILT_PREFIX/lib/${libversion} \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/${libversion} ${BUILT64_PREFIX}${PREFIX}/lib/${libversion} || exit 1
    run lipo -output $BUILT_PREFIX/lib/libgmp.a \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/libgmp.a ${BUILT64_PREFIX}${PREFIX}/lib/libgmp.a || exit 1
    libgmpversion="$libversion"

    cd $BUILT_PREFIX/lib
    for tolink in $linkversions ; do
        ln -sf $libversion $tolink
    done
    libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libgmpxx.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
    linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libgmpxx.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
    echo -e "\nRunning install_name_tool on $libversion...\n"
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libversion $BUILT_PREFIX/lib/$libversion \
        $BUILT64_PREFIX$PREFIX/lib/$libversion
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libversion $BUILT_PREFIX/lib/$libversion \
        $BUILT32_PREFIX$PREFIX/lib/$libversion
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libgmpversion $BUILT_PREFIX/lib/$libgmpversion \
        $BUILT64_PREFIX$PREFIX/lib/$libversion
    install_name_tool -id $BUILT_PREFIX/lib/${libversion} -change $PREFIX/lib/$libgmpversion $BUILT_PREFIX/lib/$libgmpversion \
        $BUILT32_PREFIX$PREFIX/lib/$libversion

    echo -e "\nMaking GMP C++ fat binary...\n"

    run lipo  -output $BUILT_PREFIX/lib/${libversion} \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/${libversion} ${BUILT64_PREFIX}${PREFIX}/lib/${libversion} || exit 1
    run lipo -output $BUILT_PREFIX/lib/libgmpxx.a \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/libgmpxx.a ${BUILT64_PREFIX}${PREFIX}/lib/libgmpxx.a || exit 1

    cd $BUILT_PREFIX/lib
    for tolink in $linkversions ; do
        ln -sf $libversion $tolink
    done
    cd ${SRC_DIR}/

    # e. Patch header and libtool file, as per 
    #    http://gmplib.org/list-archives/gmp-discuss/2010-September/004312.html
    #----------------------------------

    # Patch gmp.h header
    cp  ${BUILT64_PREFIX}${PREFIX}/include/gmp.h $BUILT_PREFIX/include/
    cp  ${BUILT64_PREFIX}${PREFIX}/include/gmpxx.h $BUILT_PREFIX/include/
    run patch -u $BUILT_PREFIX/include/gmp.h ../patch/gmp.h.diff

    # edit libgmp.la file
    run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libgmp.la > $BUILT_PREFIX/lib/libgmp.la || exit 1
    #run sed -e "'s|^\(dependency_libs.*\) $PREFIX\(.*\)$|\1 $BUILT_PREFIX\2|'" -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libgmpxx.la > $BUILT_PREFIX/lib/libgmpxx.la || exit 1
    run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libgmpxx.la > $BUILT_PREFIX/lib/libgmpxx.la || exit 1

    # f. Install to /usr/local
    #--------------------------

    if [ "`id`" = "`id root`" ] ; then
        echo "\nInstalling $libversion to ${PREFIX}\n"
        run cp -v $BUILT_PREFIX/include/* ${PREFIX}/include/
        run cp -v $BUILT_PREFIX/lib/*     ${PREFIX}/lib/
    fi

    echo "gmp done"
    # z. Leave gmp directory
    cd ${ORIG_DIR}


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
        CC=$CC CXX=$CXX \
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
            ${SRC_DIR}/configure \
                --prefix="${PREFIX}" || exit 1

        echo "configured. Cleaning"

        make clean > /dev/null 2&>1 
        run make -j${N_MAKE}
        check
        make install DESTDIR="${BUILT32_PREFIX}" || exit 1
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
        CC="$CC" CXX="$CXX" \
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
            $SRC_DIR/configure \
                --prefix="${PREFIX}" \
                || exit 1

        make clean > /dev/null 2&>1 
        run make -j${N_MAKE}
        check
        make install DESTDIR="${BUILT64_PREFIX}" || exit 1
    fi
    cd  ..

    # d. Link with lipo
    #----------------------------------

    echo "\nMaking MPFR fat binary...\n"
    libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libmpfr.la | sed -e "s|^.*=\'||" -e "s|\'$||" || exit 1`
    linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libmpfr.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||" || exit 1`
    run lipo -output ${BUILT_PREFIX}/lib/$libversion \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/$libversion ${BUILT64_PREFIX}${PREFIX}/lib/$libversion  || exit 1
    run lipo -output ${BUILT_PREFIX}/lib/libmpfr.a  \
        -create ${BUILT32_PREFIX}${PREFIX}/lib/libmpfr.a ${BUILT64_PREFIX}${PREFIX}/lib/libmpfr.a || exit 1


    cd $BUILT_PREFIX/lib
    for tolink in $linkversions ; do
        ln -sf $libversion $tolink
    done
    cd ../..


    # d. Copy over headers (diff -r shows that i386 build uses same headers as x86 build)
    #----------------------------------

    cp -p  $BUILT32_PREFIX${PREFIX}/include/*.h $BUILT_PREFIX/include/
    cp -pr $BUILT32_PREFIX${PREFIX}/share       $BUILT_PREFIX/

    # patch libmpfr.la file for temp installation directory
    run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libmpfr.la > ${BUILT_PREFIX}/lib/libmpfr.la

    # e. Install
    #----------------------------------

    # If we are the sudo user, then install to ${PREFIX}
    #  Otherwise, we'll prompt the user later to run `ditto ${BUILT_PREFIX} ${PREFIX}`
    if [ "`id`" = "`id root`" ] ; then
        # patch libmpfr.la file for installation directory
        run sed -e "s|^libdir.*$|libdir='${PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libmpfr.la > ${PREFIX}/lib/libmpfr.la
        echo "\nInstalling ${libversion} to ${PREFIX}\n"
        run cp -v  ${BUILT_PREFIX}/include/* ${PREFIX}/include/
        run cp -v  ${BUILT_PREFIX}/lib/*     ${PREFIX}/lib/
        run cp -rv ${BUILT_PREFIX}/share     ${PREFIX}/
    fi

    cd ${ORIG_DIR}

    echo "\nMade MPFR fat binary. W00t!\n"



    # Extra stuff added in GNU versions newer than Apple's.
    #   for GCC versions > Apple's GCC-4.2.1. Testing on GCC-4.7.2
    if [ "$GNU_NEW" = "1" ] ; then
        # 3. PPL 
        ###########################################################################

        echo -e "\nPPL\n---\n"


        # a. Download
        #----------------------------------
#           ftp://gcc.gnu.org/pub/gcc/infrastructure/ppl-0.11.tar.gz
        PPL_ARCHIVE="ppl-${PPL_VERSION}.tar.gz"

        if [ ! -e "ppl-${PPL_VERSION}" ] ; then 
            echo "Downloading ${PPL_ARCHIVE} from ftp://gcc.gnu.org/pub/gcc/infrastructure/${PPL_ARCHIVE}"
            run curl -OL ftp://gcc.gnu.org/pub/gcc/infrastructure/${PPL_ARCHIVE} 
            run tar xzf ${PPL_ARCHIVE}
            run rm ${PPL_ARCHIVE}
        fi

        # BUILD AND TEMP INSTALL DIRECTORIES
        # ----------------------------------

        SRC_DIR="${PWD}/ppl-${PPL_VERSION}"

        # b. Build i386 binary
        #----------------------------------

        cd $SRC_DIR
        BUILT32_PREFIX="${SRC_DIR}/install-i386"
        mkdir -p ${BUILT32_PREFIX}
        mkdir -p build-i386
        cd    build-i386/

        if [ ! -e make.checked ] ; then
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                          -I/usr/include" \
                LD="ld -arch i386" \
                LDFLAGS="-arch i386 \
                         -O2 \
                         -L/usr/lib" \
                ARCHFLAGS="-arch i386" \
                ../configure \
                    --enable-arch=i386 \
                    --enable-fpmath=sse \
                    --enable-interfaces=c,cxx \
                    --enable-optimization=speed \
                    --enable-werror \
                    --with-cc="clang -arch i386" \
                    --with-cxx="clang++ -arch i386"\
                    --with-cflags="-g -O3 -msse3" \
                    --with-cxxflags="-g -O3 -msse3" \
                    --prefix=${PREFIX} \
                    --build=$TRIPLE \
                    --host=$TRIPLE \
                    --with-gmp-prefix="$BUILT_PREFIX" \
                    || exit 1

            run make -j${N_MAKE}
            check
        fi
        make install DESTDIR="${BUILT32_PREFIX}" || exit 1

        # c. Build x86_64 binary
        #----------------------------------

        cd $SRC_DIR
        BUILT64_PREFIX="$SRC_DIR/install-x86_64"
        mkdir -p ${BUILT64_PREFIX}
        mkdir build-x86_64
        cd build-x86_64

        if [ ! -e make.checked ] ; then
            CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
                          -I/usr/include" \
                LD="ld -arch x86_64" \
                LDFLAGS="-arch x86_64 \
                         -O2 \
                         -L/usr/lib" \
                ARCHFLAGS="-arch x86_64" \
                ../configure \
                    --enable-arch=x86_64 \
                    --enable-fpmath=sse \
                    --enable-interfaces=c,cxx \
                    --enable-optimization=speed \
                    --enable-werror \
                    --with-cc="clang -arch x86_64" \
                    --with-cxx="clang++ -arch x86_64" \
                    --with-cflags="-g -O3" \
                    --with-cxxflags="-g -O3" \
                    --prefix=${PREFIX} \
                    --build=$TRIPLE \
                    --host=x86_64-apple-darwin$DARWIN_VERS \
                    --with-gmp-prefix="$BUILT_PREFIX" \
                    || exit 1

            run make -j${N_MAKE}
            check
        fi
        make install DESTDIR="${BUILT64_PREFIX}" || exit 1
        cd ..

        # d. Link with lipo
        #----------------------------------

        echo "\nMaking PPL fat binary...\n"
        libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libppl.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
        linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libppl.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
        run lipo  -output $BUILT_PREFIX/lib/${libversion} \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/${libversion} ${BUILT64_PREFIX}${PREFIX}/lib/${libversion} || exit 1
        run lipo -output $BUILT_PREFIX/lib/libppl.a \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/libppl.a ${BUILT64_PREFIX}${PREFIX}/lib/libppl.a || exit 1

        cd $BUILT_PREFIX/lib
        for tolink in $linkversions ; do
            ln -sf $libversion $tolink
        done
        cd ${SRC_DIR}/

        # edit libppl.la file
        run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libppl.la > $BUILT_PREFIX/lib/libppl.la

        # z. Leave ppl directory
        cd ${ORIG_DIR}






        #       CLOOG
        #---------------------------------

        # a. Download
        #----------------------------------
#           ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.17.0.tar.gz
        CLOOG_ARCHIVE="cloog-${CLOOG_VERSION}.tar.gz"

        if [ ! -e "cloog-${CLOOG_VERSION}" ] ; then 
            echo "Downloading ${CLOOG_ARCHIVE} from ftp://gcc.gnu.org/pub/gcc/infrastructure/${CLOOG_ARCHIVE}"
            run curl -OL ftp://gcc.gnu.org/pub/gcc/infrastructure/${CLOOG_ARCHIVE} 
            run tar xzf ${CLOOG_ARCHIVE}
            run rm ${CLOOG_ARCHIVE}
        fi

        # BUILD AND TEMP INSTALL DIRECTORIES
        # ----------------------------------

        SRC_DIR="${PWD}/cloog-${CLOOG_VERSION}"

        # b. Build i386 binary
        #----------------------------------

        cd $SRC_DIR
        BUILT32_PREFIX="${SRC_DIR}/install-i386"
        mkdir -p ${BUILT32_PREFIX}
        mkdir -p build-i386
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
                ../configure \
                    --enable-werror \
                    --prefix=${PREFIX} \
                    --build=$TRIPLE \
                    --host=$TRIPLE \
                    --with-gmp-prefix="$BUILT_PREFIX" \
                    --with-isl-prefix="$BUILT_PREFIX" \
                    --with-ppl="$BUILT_PREFIX" \
                    || exit 1

            run make -j${N_MAKE}
            check
        fi
        make install DESTDIR="${BUILT32_PREFIX}" || exit 1

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
                ../configure \
                    --enable-werror \
                    --prefix=${PREFIX} \
                    --build=$TRIPLE \
                    --host=x86_64-apple-darwin$DARWIN_VERS \
                    --with-gmp-prefix="$BUILT_PREFIX" \
                    --with-isl-prefix="$BUILT_PREFIX" \
                    --with-ppl="$BUILT_PREFIX" \
                    || exit 1

            run make -j${N_MAKE}
            check
        fi
        make install DESTDIR="${BUILT64_PREFIX}" || exit 1
        cd ..

        # d. Link with lipo
        #----------------------------------
        # d.i libcloog-isl.dylib
        #----------------------------------

        echo "\nMaking libCLOOG-isl fat binary...\n"
        libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libcloog-isl.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
        linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libcloog-isl.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
        run lipo  -output $BUILT_PREFIX/lib/${libversion} \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/${libversion} ${BUILT64_PREFIX}${PREFIX}/lib/${libversion} || exit 1
        run lipo -output $BUILT_PREFIX/lib/libcloog-isl.a \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/libcloog-isl.a ${BUILT64_PREFIX}${PREFIX}/lib/libcloog-isl.a || exit 1

        cd $BUILT_PREFIX/lib
        for tolink in $linkversions ; do
            ln -sf $libversion $tolink
        done
        # d.i libisl.dylib
        #----------------------------------

        echo "\nMaking libisl.dylib fat binary...\n"
        libversion=`grep dlname ${BUILT64_PREFIX}${PREFIX}/lib/libisl.la | sed -e "s|^.*=\'||" -e "s|\'$||"`
        linkversions=`grep "library_names" ${BUILT64_PREFIX}${PREFIX}/lib/libisl.la | sed -e "s|^.*=\'||" -e "s|\'$||" | sed -e "s|$libversion||"`
        run lipo  -output $BUILT_PREFIX/lib/${libversion} \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/${libversion} ${BUILT64_PREFIX}${PREFIX}/lib/${libversion} || exit 1
        run lipo -output $BUILT_PREFIX/lib/libisl.a \
            -create ${BUILT32_PREFIX}${PREFIX}/lib/libisl.a ${BUILT64_PREFIX}${PREFIX}/lib/libisl.a || exit 1

        cd $BUILT_PREFIX/lib
        for tolink in $linkversions ; do
            ln -sf $libversion $tolink
        done
        cd ${SRC_DIR}/

        # edit libcloog.la file
        run sed -e "s|^libdir.*$|libdir='${BUILT_PREFIX}/lib'|" ${BUILT32_PREFIX}${PREFIX}/lib/libcloog-isl.la > $BUILT_PREFIX/lib/libcloog-isl.la

        # z. Leave cloog directory
        cd ${ORIG_DIR}






    fi

