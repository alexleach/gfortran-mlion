#!/bin/bash

. ./CONFIG
. ./build-macros.sh


# 4 - BUILD A CROSS-COMPILING GCC, WITH THE LLVM WE JUST USED
#---------------------------------

SRC_DIR="${PWD}/${LLVM_VERSION}"

# Fake install prefixes.
#BUILT32_PREFIX="${SRC_DIR}/install/i386/usr/local"
#BUILT64_PREFIX="${SRC_DIR}/install/x86_64/usr/local"
BUILT_PREFIX="${PWD}/install${PREFIX}"
mkdir -p $BUILT_PREFIX  # $BUILT32_PREFIX $BUILT64_PREFIX 

# Compiled object directory
BUILD_DIR=${SRC_DIR}/build
#BUILD32_DIR=${PWD}/build/i386
#BUILD64_DIR=${PWD}/build/x86_64
mkdir -p ${BUILD_DIR}

# Debug symbol directory
DSYMDIR="${BUILD_DIR}/debug"
mkdir -p ${DSYMDIR}

TRIPLE="${GCC_BUILD}-apple-darwin${DARWIN_VERS}"

# e - Build GCC the Apple way
#---------------------------------
# From `GNUMakefile` :-
#
#  $(SRC)/build_gcc "$(RC_ARCHS)" "$(TARGETS)" \
#    $(SRC) $(PREFIX) $(DSTROOT) $(SYMROOT) $(INSTALL_LIBLTO) \
#    $(ENABLE_ASSERTIONS) $(LLVMCORE_PATH) \
#    $(RC_ProjectSourceVersion) $(RC_ProjectSourceSubversion) 

# Invocation from `gnumake` (in GNUMakefile) :-
#  ${SRC_DIR}/../build_gcc "i686 x86_64" "i686 x86_64" \
#    ${SRC_DIR} /usr/local/ ${BUILD_DIR}/dst ${BUILD_DIR}/sym no \
#    no /usr/local \
#    9999 00 

# e - Build GCC the FSF way
#---------------------------------
# Again, the following code will mostly be modified from build_gcc

#  COMMAND LINE FLAGS FROM `/usr/bin/gcc -v`
#     ../configure \
#        --disable-checking \
#        --enable-werror \
#        --prefix=/Applications/Xcode.app/Contents/Developer/usr/llvm-gcc-4.2 \
#        --mandir=/share/man \
#        --enable-languages=c,objc,c++,obj-c++ \
#        --program-prefix=llvm- \
#        --program-transform-name=/^[cg][^.-]*$/s/$/-4.2/ \
#        --with-slibdir=/usr/lib \
#        --build=i686-apple-darwin11 \
#        --enable-llvm=/private/var/tmp/llvmgcc42/llvmgcc42-2336.11~28/dst-llvmCore/Developer/usr/local \
#        --program-prefix=i686-apple-darwin11- \
#        --host=x86_64-apple-darwin11 \
#        --target=i686-apple-darwin11 \
#        --with-gxx-include-dir=/usr/include/c++/4.2.1

    VERS=`cat $SRC_DIR/gcc/BASE-VER`
    MAJ_VERS=`echo $VERS | sed 's/\([0-9]*\.[0-9]*\)[.-].*/\1/'`

    mv $SRC_DIR/libstdc++-v3 $SRC_DIR/libstdc++-v3.bak 2> /dev/null

    CFLAGS="-g -O2 ${RC_NONARCH_CFLAGS/-pipe/}"
    CPPFLAGS="-I/usr/include -I/usr/include/c++/$VERS -I$BUILT_PREFIX/include"
    LDFLAGS="-L/usr/lib -L$BUILT_PREFIX/lib"

    CONFIGFLAGS="--disable-checking \
      --enable-werror \
      --prefix=${PREFIX} \
      --mandir=${PREFIX}/share/man \
      --enable-languages=${LANGUAGES} \
      --program-prefix=llvm- \
      --program-transform-name=/^[cg][^.-]*$/s/$/-$MAJ_VERS/ \
      --with-slibdir=/usr/lib \
      --build=${TRIPLE} \
      --enable-llvm=${BUILT_PREFIX} \
      --with-gmp=${BUILT_PREFIX} \
      --with-mpfr=${BUILT_PREFIX}"

    MAKEFLAGS="-j${N_MAKE} BUILD_LLVM_APPLE_STYLE=1"
    #MAKEFLAGS="BUILD_LLVM_APPLE_STYLE=1"
    # Build llvm-gcc in 'dylib mode'.
    MAKEFLAGS="$MAKEFLAGS BUILD_LLVM_INTO_A_DYLIB=1"
    MAKEFLAGS="$MAKEFLAGS LLVM_VERSION_INFO=$LLVM_VERSION_VERSION"

    unset LANGUAGES

    # Patch gfortranspec.c
    patch -Nu $SRC_DIR/gcc/fortran/gfortranspec.c ${SRC_DIR}/../patch/gfortranspec.c.diff


    # Here, the build_gcc script compiles a native compiler. We'll skip that, 
    # and use Xcode compilers instead. No we won't. Need the llvm- prefix...
    # =======================================================================

    # If the user has set CC or CXX, respect their wishes.  If not,
    # compile with clang/clang++ if available; if LLVM is not
    # available, fall back to usual GCC/G++ default.
    XTMPCC=`xcrun -find clang`
    if [ x$CC  = x -a x$XTMPCC != x ] ; then export CC=$XTMPCC  forcedCC=1  ; fi
    XTMPCC=`xcrun -find clang++`
    if [ x$CXX = x -a x$XTMPCC != x ] ; then export CXX=$XTMPCC forcedCXX=1 ; fi
    unset XTMPCC

    # Build the native GCC.  Do this even if the user didn't ask for it
    # because it'll be needed for the bootstrap.
    mkdir -p $BUILD_DIR/obj-$GCC_BUILD-$GCC_BUILD $BUILD_DIR/dst-$GCC_BUILD-$GCC_BUILD || exit 1
    cd $BUILD_DIR/obj-$GCC_BUILD-$GCC_BUILD || exit 1
    if [ \! -f Makefile ]; then
     $SRC_DIR/configure $CONFIGFLAGS $NON_ARM_CONFIGFLAGS \
       --host=$GCC_BUILD-apple-darwin$DARWIN_VERS \
       --target=$GCC_BUILD-apple-darwin$DARWIN_VERS || exit 1
    fi

    # Unset RC_DEBUG_OPTIONS because it causes the bootstrap to fail.
    # Also keep unset for cross compilers so that the cross built libraries are
    # comparable to the native built libraries.
    unset RC_DEBUG_OPTIONS
    make $MAKEFLAGS CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
    make $MAKEFLAGS html CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
    make $MAKEFLAGS DESTDIR=$BUILD_DIR/dst-$GCC_BUILD-$GCC_BUILD install-gcc install-target \
      CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1

    # Now that we've built a native compiler, un-kludge these so that
    # subsequent cross-hosted compilers can be found normally.
    if [ x$forcedCC  != x ] ; then unset CC  forcedCC  ; fi
    if [ x$forcedCXX != x ] ; then unset CXX forcedCXX ; fi

    # Add the compiler we just built to the path, giving it appropriate names.
    # LLVM LOCAL begin Support for non /usr $PREFIX
    D=$BUILD_DIR/dst-$GCC_BUILD-$GCC_BUILD$PREFIX/bin
    ln -f $D/llvm-gcc $D/gcc || exit 1
    ln -f $D/gcc $D/$GCC_BUILD-apple-darwin$DARWIN_VERS-gcc || exit 1
    PATH=$BUILD_DIR/dst-$GCC_BUILD-$GCC_BUILD$PREFIX/bin:$PATH
    # LLVM LOCAL end Support for non /usr $PREFIX

    # Copy, paste and port from build_gcc
    # -------------------------------------------------------------------------


    # The cross-tools' build process expects to find certain programs
    # under names like 'i386-apple-darwin$DARWIN_VERS-ar'; so make them.
    # Annoyingly, ranlib changes behaviour depending on what you call it,
    # so we have to use a shell script for indirection, grrr.
    rm -rf $BUILD_DIR/bin || exit 1
    mkdir $BUILD_DIR/bin || exit 1
    for prog in ar nm ranlib strip lipo ld ; do
      for t in `echo $GCC_TARGETS $GCC_HOSTS | tr ' ' '\n' | sort -u`; do
        P=$BUILD_DIR/bin/${t}-apple-darwin$DARWIN_VERS-${prog}
        # Use the specified ARM_SDK for arm, but otherwise force the SDK to / for
        # now, since SDKROOT may be set to an SDK that does not include support
        # for all the targets being built (i.e., ppc).
#        if [ "$t" = "arm" -a -n "$ARM_SDK" ]; then
#          sdkoption="-sdk $ARM_SDK"
#        else
          sdkoption="-sdk /"
#        fi
        progpath=`xcrun $sdkoption -find $prog`
        echo '#!/bin/sh' > $P || exit 1
        echo 'exec '${progpath}' "$@"' >> $P || exit 1
        chmod a+x $P || exit 1
      done
    done

    # The "as" script adds a default "-arch" option.  Iterate over the lists of
    # untranslated HOSTS and TARGETS in $1 and $2 so those names can be used as
    # the arguments for "-arch" in the scripts.
    for t in `echo $TARGET_ARCHS $GCC_TARGETS | tr ' ' '\n' | sort -u`; do
      gt=`echo $t | $TRANSLATE_ARCH`
      P=$BUILD_DIR/bin/${gt}-apple-darwin$DARWIN_VERS-as
#      if [ "$gt" = "arm" -a -n "$ARM_SDK" ]; then
#        sdkoption="-sdk $ARM_SDK"
#      else
        sdkoption="-sdk /"
#      fi
      progpath=`xcrun $sdkoption -find as`
      echo '#!/bin/sh' > $P || exit 1
      echo 'for a; do case $a in -arch) exec '${progpath}' "$@";;  esac; done' >> $P || exit 1
      echo 'exec '${progpath}' -arch '${t}' "$@"' >> $P || exit 1
      chmod a+x $P || exit 1
    done
    PATH=${BUILD_DIR}/bin:$PATH


    # Determine which cross-compilers we should build.  If our build architecture is
    # one of our hosts, add all of the targets to the list.
    if echo $GCC_HOSTS | grep $GCC_BUILD
    then
      CROSS_TARGETS=`echo $GCC_TARGETS $GCC_HOSTS | tr ' ' '\n' | sort -u`
    else
      CROSS_TARGETS="$GCC_HOSTS"
    fi

    # Build the cross-compilers, using [Xcode's compiler]
    for t in $CROSS_TARGETS ; do
     if [ $t != $GCC_BUILD ] ; then
      mkdir -p $BUILD_DIR/obj-$GCC_BUILD-$t $BUILD_DIR/dst-$GCC_BUILD-$t || exit 1
       cd $BUILD_DIR/obj-$GCC_BUILD-$t || exit 1
       if [ \! -f Makefile ]; then
        # APPLE LOCAL begin ARM ARM_CONFIGFLAGS
        T_CONFIGFLAGS="$CONFIGFLAGS --enable-werror-always \
          --program-prefix=$t-apple-darwin$DARWIN_VERS- \
          --host=$GCC_BUILD-apple-darwin$DARWIN_VERS \
          --target=$t-apple-darwin$DARWIN_VERS"
#        if [ $t = 'arm' ] ; then
#          # Explicitly set AS_FOR_TARGET and LD_FOR_TARGET to avoid picking up
#          # older versions from the gcc installed in /usr.  Radar 7230843.
#          AS_FOR_TARGET=$BUILD_DIR/bin/${t}-apple-darwin$DARWIN_VERS-as \
#          LD_FOR_TARGET=$BUILD_DIR/bin/${t}-apple-darwin$DARWIN_VERS-ld \
#          $SRC_DIR/configure $T_CONFIGFLAGS $ARM_CONFIGFLAGS || exit 1
#        elif [ $t = 'powerpc' ] ; then
#          $SRC_DIR/configure $T_CONFIGFLAGS $PPC_CONFIGFLAGS || exit 1
#        else
          echo -e "\nConfiguring $t compiler\n-----------------------\n"
#          CC="clang" CXX="clang++" \
          CPPFLAGS="$CPPFLAGS" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
              $SRC_DIR/configure $T_CONFIGFLAGS $NON_ARM_CONFIGFLAGS || exit 1
        fi
        # APPLE LOCAL end ARM ARM_CONFIGFLAGS
#       fi
#       if [ $t = 'arm' ] ; then
#         if [ $ARM_DARWIN_TARGET_IPHONEOS = 'YES' ] ; then
#           DEFAULT_TARGET="-DDEFAULT_TARGET_OS=DARWIN_VERSION_IPHONEOS"
#         else
#            DEFAULT_TARGET="-DDEFAULT_TARGET_OS=DARWIN_VERSION_MACOSX"
#         fi
#       else
         DEFAULT_TARGET=""
#       fi
       echo -e "\nBuilding $t compiler\n--------------------\n"
       make $MAKEFLAGS all CFLAGS="$CFLAGS $DEFAULT_TARGET" \
         CXXFLAGS="$CFLAGS $DEFAULT_TARGET" || exit 1
       echo -e "\nInstalling $t compiler\n----------------------\n"
       make $MAKEFLAGS DESTDIR=$BUILD_DIR/dst-$GCC_BUILD-$t install-gcc install-target \
         CFLAGS="$CFLAGS $DEFAULT_TARGET" \
         CXXFLAGS="$CFLAGS $DEFAULT_TARGET" || exit 1

       # Add the compiler we just built to the path.
       # LLVM LOCAL Support for non /usr $PREFIX
       PATH=$BUILD_DIR/dst-$GCC_BUILD-$t/$PREFIX/bin:$PATH
     fi
    done

    # Rearrange various libraries, for no really good reason.
    for t in $CROSS_TARGETS ; do
      DT=$BUILD_DIR/dst-$GCC_BUILD-$t
      # LLVM LOCAL Support for non /usr $PREFIX
      D=`echo $DT/$PREFIX/lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS`
      mv $D/static/libgcc.a $D/libgcc_static.a || exit 1
      mv $D/kext/libgcc.a $D/libcc_kext.a || exit 1
      rm -r $D/static $D/kext || exit 1
      # glue together kext64 stuff
      if [ -e $D/kext64/libgcc.a ]; then
        libtool -static $D/{kext64/libgcc.a,libcc_kext.a} -o $D/libcc_kext1.a 2>&1 | grep -v 'has no symbols'
        mv $D/libcc_kext1.a $D/libcc_kext.a
        rm -rf $D/kext64
      fi
    done

    echo -e "Building the cross-hosted compilers for platforms: `echo $GCC_TARGETS | sed -e s/$GCC_BUILD// `" || exit 1


    # Build the cross-hosted compilers.
    for h in $GCC_TARGETS ; do
      if [ $h != $GCC_BUILD ] ; then
        for t in $GCC_TARGETS ; do
          mkdir -p $BUILD_DIR/obj-$h-$t $BUILD_DIR/dst-$h-$t || exit 1
          cd $BUILD_DIR/obj-$h-$t || exit 1
          if [ $h = $t ] ; then
            pp=
          else
            pp=$t-apple-darwin$DARWIN_VERS-
          fi
          echo "Building cross-compiler in $BUILD_DIR/obj-$h-$t"
          echo "-----------------------------------------------"

          if [ \! -f Makefile ]; then
        # APPLE LOCAL begin ARM ARM_CONFIGFLAGS
            T_CONFIGFLAGS="$CONFIGFLAGS --program-prefix=$pp \
              --host=$h-apple-darwin$DARWIN_VERS \
              --target=$t-apple-darwin$DARWIN_VERS"
#            if [ $t = 'arm' ] && [ $h != 'arm' ] ; then
#              T_CONFIGFLAGS="$T_CONFIGFLAGS $ARM_CONFIGFLAGS"
#            elif [ $t = 'powerpc' ] && [ $h != 'powerpc' ] ; then
#              T_CONFIGFLAGS="$T_CONFIGFLAGS $PPC_CONFIGFLAGS"
#            else
              T_CONFIGFLAGS="$T_CONFIGFLAGS $NON_ARM_CONFIGFLAGS"
#            fi
          CC="gcc" CXX="g++" \
            CPPFLAGS="$CPPFLAGS" CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" \
            $SRC_DIR/configure $T_CONFIGFLAGS || exit 1
        # APPLE LOCAL end ARM ARM_CONFIGFLAGS
          fi

          # For ARM, we need to make sure it picks up the correct versions
          # of the linker and cctools.
#          if [ $t = 'arm' ] ; then
#            if [ -n "$ARM_SDK" ]; then
#              sdkoption="-sdk $ARM_SDK"
#            else
#              sdkoption="-sdk /"
#            fi
#            progpath=`xcrun $sdkoption -find ld`
#            comppath=`dirname $progpath`
#            ORIG_COMPILER_PATH=$COMPILER_PATH
#            export COMPILER_PATH=$comppath:$COMPILER_PATH
#          fi

          if [ $h = $t ] ; then
              echo "Making all for DESTDIR: $BUILD_DIR/dst-$h-$t"
              echo -e "--------------------------------------------\n"
              make $MAKEFLAGS all CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
              make $MAKEFLAGS DESTDIR=$BUILD_DIR/dst-$h-$t install-gcc install-target \
                  CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
          else
              echo "Making all-gcc for $BUILD_DIR/dst-$h-$t"
              echo -e "--------------------------------------------\n"
              make $MAKEFLAGS all-gcc CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
              echo "Done all-gcc for $BUILD_DIR/dst-$h-$t"
              echo -e "--------------------------------------------\n"
              make $MAKEFLAGS DESTDIR=$BUILD_DIR/dst-$h-$t install-gcc \
                  CFLAGS="$CFLAGS" CXXFLAGS="$CFLAGS" || exit 1
          fi

#          if [ $t = 'arm' ] ; then
#            export COMPILER_PATH=$ORIG_COMPILER_PATH
#            unset ORIG_COMPILER_PATH
#          fi
        done
      fi
    done


    ########################################
    # Construct the actual destination root, by copying stuff from
    # $BUILD_DIR/dst-* to $DEST_DIR, with occasional 'lipo' commands.

    echo Constructing destination root, $BUILD_DIR/dst-* to $BUILT_PREFIX, with occasional 'lipo' commands.
    echo -e "---------------------------------------------------------------------------------------------\n"

    cd $BUILT_PREFIX

    # Manual pages
    mkdir -p ${BUILT_PREFIX}/share || exit 1
    cp -Rp $BUILD_DIR/dst-$GCC_BUILD-*$PREFIX/share/man $BUILT_PREFIX/share/ \
      || exit 1

    # exclude fsf-funding.7 gfdl.7 gpl.7 as they are currently built in
    # the gcc project
    rm -rf $BUILT_PREFIX/share/man/man7

    # libexec # 
    # As we didn't build the native compiler, we don't have dst-$GCC_BUILD-$GCC_BUILD directories.
    # Dirty fix - have been replacing with asterisks. # 
    cd $BUILD_DIR/dst-$GCC_BUILD-$GCC_BUILD$PREFIX/libexec/gcc/$GCC_BUILD-apple-darwin$DARWIN_VERS/$VERS \
      || exit 1
    LIBEXEC_FILES=`find . -type f -print || exit 1`
    LIBEXEC_DIRS=`find . -type d -print || exit 1`
    cd $BUILT_PREFIX || exit 1
    for t in $GCC_TARGETS ; do
      if [ "$t" = "$GCC_BUILD" ] ; then
          continue
      fi
      DL=/libexec/gcc/$t-apple-darwin$DARWIN_VERS/$VERS
      for d in $LIBEXEC_DIRS ; do
        mkdir -p .$DL/$d || exit 1
      done
      for f in $LIBEXEC_FILES ; do
        # LLVM LOCAL
        if file $BUILD_DIR/dst-$GCC_BUILD-$t$DL/$f | grep -q -E 'Mach-O (executable|dynamically linked shared library)' ; then
          echo lipo -output .$DL/$f -create $BUILD_DIR/dst-$GCC_BUILD-$t$DL/$f || exit 1
          lipo -output .$DL/$f -create $BUILD_DIR/dst-$GCC_BUILD-$t$DL/$f || exit 1
        elif file $BUILD_DIR/dst-$t-$GCC_BUILD$DL/$f | grep -q -E 'Mach-O (executable|dynamically linked shared library)' ; then
          echo lipo -output .$DL/$f -create $BUILD_DIR/dst-$t-$GCC_BUILD$DL/$f || exit 1
          lipo -output .$DL/$f -create $BUILD_DIR/dst-$t-$GCC_BUILD$DL/$f || exit 1
        else
          cp -pv $BUILD_DIR/dst-$GCC_BUILD-$t$DL/$f .$DL/$f || exit 1
        fi
      done
      # LLVM LOCAL begin fix broken link
      # Dubious - don't like at all.
      #ln -s ../../../../../bin/as .$DL/as
      #ln -s ../../../../../bin/ld .$DL/ld
      #ln -s ../../../../../bin/dsymutil .$DL/dsymutil
      # LLVM LOCAL end fix broken link
    done



    ## WHERE ARE THESE FILES??????? (llvm-cpp, cpp-4.2.1 )

    # bin
    # The native drivers ('native' is different in different architectures).
    # LLVM LOCAL begin
    mkdir -p $BUILT_PREFIX/bin
    echo ls $BUILD_DIR/dst-*$PREFIX/bin/{llvm-cpp,cpp-$MAJ_VERS} 
    cpp_files=`ls $BUILD_DIR/dst-*$PREFIX/bin/{llvm-cpp,cpp-$MAJ_VERS} 2>/dev/null`

    echo lipo -output $BUILT_PREFIX/bin/llvm-cpp-$MAJ_VERS -create $cpp_files || exit 1
    lipo -output $BUILT_PREFIX/bin/llvm-cpp-$MAJ_VERS -create $cpp_files || exit 1
    # LLVM LOCAL end

    # Do we even need this?? Let's pretend we don't, as Xcode already provides it..

    # gcov, which is special only because it gets built multiple times and lipo
    # will complain if we try to add two architectures into the same output.
#    TARG0=`echo $GCC_TARGETS | cut -d ' ' -f 1`
#    lipo -output .$PREFIX/bin/gcov-$MAJ_VERS -create \
#      $BUILD_DIR/dst-*-$TARG0$PREFIX/bin/*gcov* || exit 1
#    # The fully-named drivers, which have the same target on every host.
#    for t in $GCC_TARGETS ; do
#      # LLVM LOCAL build_gcc bug with non-/usr $PREFIX
#      lipo -output .$PREFIX/bin/$t-apple-darwin$DARWIN_VERS-llvm-gcc-$MAJ_VERS -create \
#        $BUILD_DIR/dst-*-$t/$PREFIX/bin/$t-apple-darwin$DARWIN_VERS-gcc-$VERS || exit 1
#      # LLVM LOCAL build_gcc bug with non-/usr $PREFIX
#      lipo -output .$PREFIX/bin/$t-apple-darwin$DARWIN_VERS-llvm-g++-$MAJ_VERS -create \
#        $BUILD_DIR/dst-*-$t/$PREFIX/bin/$t-apple-darwin$DARWIN_VERS-*g++* || exit 1
#    done

    # lib
    echo "Copying over lib/"
    echo -e "-----------------\n"
    mkdir -p ./lib/gcc || exit 1
    for t in $GCC_TARGETS ; do
      # LLVM LOCAL build_gcc bug with non-/usr $PREFIX
      if [ $t != $GCC_BUILD ] ; then
        cp -vRp $BUILD_DIR/dst-$GCC_BUILD-$t/$PREFIX/lib/gcc/$t-apple-darwin$DARWIN_VERS \
          ./lib/gcc || exit 1
      fi
    done
    echo -e "Done\n----"

    # APPLE LOCAL begin native compiler support
    # libgomp is not built for ARM
    LIBGOMP_TARGETS=`echo $GCC_TARGETS | sed -E -e 's/(^|[[:space:]])arm($|[[:space:]])/ /'`
    LIBGOMP_HOSTS=`echo $GCC_HOSTS | $OMIT_X86_64 | sed -E -e 's/(^|[[:space:]])arm($|[[:space:]])/ /'`

    # And copy libgomp stuff by hand...
    echo "Copying libgomp stuff. PWD = ${PWD}"
    for t in $LIBGOMP_TARGETS ; do
        for h in $LIBGOMP_HOSTS ; do
            if [ $h != $t ] ; then
                mkdir -p ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS
                cp -pv $BUILD_DIR/dst-$h-$t$PREFIX/lib/libgomp.a \
                    ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/ || exit 1
                cp -pv $BUILD_DIR/dst-$h-$t$PREFIX/lib/libgomp.spec \
                    ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/ || exit 1
                if [ $h = 'powerpc' ] ; then
                    cp -vp $BUILD_DIR/dst-$h-$t$PREFIX/lib/ppc64/libgomp.a \
                        ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/ppc64/
                    cp -vp $BUILD_DIR/dst-$h-$t$PREFIX/lib/ppc64/libgomp.spec \
                        ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/ppc64/
                elif [ $h = 'i686' ] ; then
                    cp -vp $BUILD_DIR/dst-$h-$t$PREFIX/lib/x86_64/libgomp.a \
                        ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/x86_64/ || exit 1
                    cp -vp $BUILD_DIR/dst-$h-$t$PREFIX/lib/x86_64/libgomp.spec \
                        ./lib/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/x86_64/ || exit 1
                fi
            fi
        done
    done
    # APPLE LOCAL end native compiler support
    echo -e "Done\n----"

    # include
    HEADERPATH=/include/gcc/darwin/$MAJ_VERS
    mkdir -p .$HEADERPATH || exit 1

    # Some headers are installed from more-hdrs/.  They all share
    # one common feature: they shouldn't be installed here.  Sometimes,
    # they should be part of FSF GCC and installed from there; sometimes,
    # they should be installed by some completely different package; sometimes,
    # they only exist for codewarrior compatibility and codewarrior should provide
    # its own.  We take care not to install the headers if Libc is already
    # providing them.
    cd $SRC_DIR/more-hdrs
    for h in `echo *.h` ; do
      if [ ! -f /usr/include/$h -o -L /usr/include/$h ] ; then
        cp -vR $h $BUILT_PREFIX$HEADERPATH/$h || exit 1
        for t in $GCC_TARGETS ; do
          THEADERPATH=$BUILT_PREFIX/lib/gcc/${t}-apple-darwin$DARWIN_VERS/$VERS/include
          [ -f $THEADERPATH/$h ] || \
            echo ln -sf ${BUILT_DIR}${HEADERPATH}/$h $THEADERPATH/$h || \
            #ln -s ../../../../../include/gcc/darwin/$MAJ_VERS/$h $THEADERPATH/$h || \
            exit 1
        done
      fi
    done


    # Add extra man page symlinks for 'c++' and for arch-specific names.
    # We haven't built these man pages...
    MDIR=$BUILT_PREFIX/share/man/man1
    if [ "$BUILD_CXX" = "1" ]; then
      # LLVM LOCAL
      ln -f $MDIR/llvm-g++.1 $MDIR/llvm-c++.1 || exit 1
    fi
    for t in $GCC_TARGETS ; do
      # LLVM LOCAL begin
      ln -f $SRC_DIR/gcc/doc/llvm-gcc.1 $MDIR/$t-apple-darwin$DARWIN_VERS-llvm-gcc.1 \
          || exit 1
      if [ "$BUILD_CXX" = "1" ]; then
        ln -f $MDIR/gcc/doc/llvm-g++.1 $MDIR/$t-apple-darwin$DARWIN_VERS-llvm-g++.1 \
            || exit 1
      fi
      # LLVM LOCAL end
    done

    # LLVM LOCAL begin
    MAN1_DIR=$BUILT_PREFIX/share/man/man1
    mkdir -p ${MAN1_DIR}
    for i in gcc.1 g++.1 cpp.1 gcov.1 gfortran.1 ; do
        cp $BUILD_DIR/obj-$GCC_BUILD-*/gcc/doc/$i ${MAN1_DIR}/$i
    done
    cp $SRC_DIR/gcc/doc/llvm-gcc.1 ${MAN1_DIR}/llvm-gcc.1
    # llvm-g++ manpage is a dup of llvm-gcc manpage
    cp $SRC_DIR/gcc/doc/llvm-gcc.1 ${MAN1_DIR}/llvm-g++.1
    # Compress manpages
    gzip -f $MDIR/* ${MAN1_DIR}/*
    # LLVM LOCAL end

    # Build driver-driver using fully-named drivers
    for h in $GCC_HOSTS ; do
        # LLVM LOCAL begin
        $h-apple-darwin$DARWIN_VERS-gcc \
        $SRC_DIR/driverdriver.c  \
        -DPDN="\"-apple-darwin$DARWIN_VERS-llvm-gcc-$MAJ_VERS\""  \
        -DIL="\"$PREFIX/bin/\"" -I$SRC_DIR/include \
        -I$SRC_DIR/gcc -I$SRC_DIR/gcc/config \
        -liberty -L$BUILD_DIR/dst-$GCC_BUILD-$h$PREFIX/lib/  \
        -L$BUILD_DIR/dst-$GCC_BUILD-$h$PREFIX/$h-apple-darwin$DARWIN_VERS/lib/ \
            -L$BUILD_DIR/obj-$h-$GCC_BUILD/libiberty/ \
        -o $BUILT_PREFIX/bin/tmp-$h-llvm-gcc-$MAJ_VERS || exit 1

        if [ "$BUILD_CXX" = "1" ]; then
            $h-apple-darwin$DARWIN_VERS-gcc \
            $SRC_DIR/driverdriver.c \
            -DPDN="\"-apple-darwin$DARWIN_VERS-llvm-g++-$MAJ_VERS\"" \
            -DIL="\"$DEST_ROOT/bin/\"" -I$SRC_DIR/include \
            -I$SRC_DIR/gcc -I$SRC_DIR/gcc/config \
            -liberty -L$BUILD_DIR/dst-$GCC_BUILD-$h$DEST_ROOT/lib/ \
            -L$BUILD_DIR/dst-$GCC_BUILD-$h$PREFIX/$h-apple-darwin$DARWIN_VERS/lib/ \
                -L$BUILD_DIR/obj-$h-$GCC_BUILD/libiberty/ \
            -o $BUILT_PREFIX/bin/tmp-$h-llvm-g++-$MAJ_VERS || exit 1
        fi
        # LLVM LOCAL end
    done


    # LLVM LOCAL begin
    lipo -output $BUILT_PREFIX/bin/llvm-gcc-$MAJ_VERS -create \
      $BUILT_PREFIX/bin/tmp-*-llvm-gcc-$MAJ_VERS || exit 1
    rm $BUILT_PREFIX/bin/tmp-*-llvm-gcc-$MAJ_VERS || exit 1

    if [ "$BUILD_CXX" = "1" ]; then
        lipo -output $BUILT_PREFIX/bin/llvm-g++-$MAJ_VERS -create \
            $BUILT_PREFIX/bin/tmp-*-llvm-g++-$MAJ_VERS || exit 1
        ln -f $BUILT_PREFIX/bin/llvm-g++-$MAJ_VERS $BUILT_PREFIX/bin/llvm-c++-$MAJ_VERS || exit 1
        rm $BUILT_PREFIX/bin/tmp-*-llvm-g++-$MAJ_VERS || exit 1
    fi
    # LLVM LOCAL end


    ########################################
    # Create SYM_DIR with information required for debugging.

    cd $DSYMDIR || exit 1

    # Clean out SYM_DIR in case -noclean was passed to buildit.
    rm -rf * || exit 1

    # Generate .dSYM files
    find $BUILT_PREFIX -perm -0111 \! -name fixinc.sh \
        \! -name mkheaders -type f -print | xargs -n 1 -P ${N_MAKE} dsymutil

    # Save .dSYM files and .a archives
    cd $DEST_DIR || exit 1
    find . \( -path \*.dSYM/\* -or -name \*.a \) -print \
      | cpio -pdml $DSYMDIR || exit 1
    # Save source files.
    mkdir $DSYMDIR/src || exit 1
    cd $BUILD_DIR || exit 1
    find ${BUILD_DIR}/obj-* -name \*.\[chy\] -print | cpio -pdml $DSYMDIR/src || exit 1


    ########################################
    # Remove debugging information from DEST_DIR.
    echo "Removing debugging information from $BUILT_PREFIX"
    echo "-----------------------------------"

    if [ "x$LLVM_DEBUG" != "x1" ]; then
        # LLVM LOCAL begin - don't strip dSYM objects
        find $BUILT_PREFIX -perm -0111 \! -path '*DWARF*' \! -name \*.dylib \
            \! -name fixinc.sh \! -name mkheaders \! -name libstdc++.dylib \
            -type f -print \
            | xargs strip || exit 1
        # LLVM LOCAL begin - Strip with -Sx instead of -SX
        find $BUILT_PREFIX \! -path '*DWARF*' \( -name \*.a -or -name \*.dylib \) \
            \! -name libgcc_s.10.*.dylib \! -name libstdc++.dylib -type f \
        -print \
            | xargs strip -SX || exit 1
        # LLVM LOCAL end - Strip with -Sx instead of -SX
        find $BUILT_PREFIX \! -path '*DWARF*' -name \*.a -type f -print \
            | xargs ranlib || exit 1
        # LLVM LOCAL end - don't strip dSYM objects
    fi

    # LLVM LOCAL begin
    # Set up the llvm-gcc/llvm-g++ symlinks.

    # LLVM_BIN_DIR - This is the place where llvm-gcc/llvm-g++ symlinks get installed.
    LLVM_BIN_DIR=$PREFIX/../bin

    mkdir -p $BUILT_PREFIX$LLVM_BIN_DIR
    cd $BUILT_PREFIX$LLVM_BIN_DIR
    ln -s -f   ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/llvm-gcc-$MAJ_VERS   ${PWD}/llvm-gcc-$MAJ_VERS || exit 1
    ln -s -f   ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/llvm-g++-$MAJ_VERS   ${PWD}/llvm-g++-$MAJ_VERS || exit 1
    ln -s -f   ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/llvm-cpp-$MAJ_VERS   ${PWD}/llvm-cpp-$MAJ_VERS || exit 1
    ln -s -f   ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/llvm-gcc-$MAJ_VERS   ${PWD}/llvm-gcc || exit 1
    ln -s -f   ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/llvm-g++-$MAJ_VERS   ${PWD}/llvm-g++ || exit 1

    # FIXME: This is a hack to get things working.
    for t in $GCC_TARGETS ; do
        ln -s -f ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/$t-apple-darwin$DARWIN_VERS-llvm-gcc-$MAJ_VERS  ${PWD}/$t-apple-darwin$DARWIN_VERS-llvm-gcc-$MAJ_VERS || exit 1
        ln -s -f ${BUILT_PREFIX}/llvm-gcc-$MAJ_VERS/bin/$t-apple-darwin$DARWIN_VERS-llvm-g++-$MAJ_VERS  ${PWD}/$t-apple-darwin$DARWIN_VERS-llvm-g++-$MAJ_VERS || exit 1
    done

    # Copy one of the libllvmgcc.dylib's up to libexec/gcc.
    cp $BUILT_PREFIX/libexec/gcc/$GCC_BUILD-apple-darwin$DARWIN_VERS/$VERS/libllvmgcc.dylib \
        $BUILT_PREFIX/libexec/gcc/

    # Replace the installed ones with symlinks to the common one.
    for t in $GCC_TARGETS ; do
        cd $BUILT_PREFIX/libexec/gcc/$t-apple-darwin$DARWIN_VERS/$VERS/
        rm libllvmgcc.dylib
        ln -s ../../libllvmgcc.dylib
    done

    # Remove unwind.h from the install directory for > 10.6
    if [ $DARWIN_VERS -gt 10 ]; then
        find $BUILT_PREFIX -name "unwind.h" -print | xargs rm || exit 1
    fi

    # Install libLTO.dylib
#    if [ "$INSTALL_LIBLTO" == yes ]; then # (it's not yes - from GNUmakefile invocation)
#      LTO=$LLVMCORE_PATH/lib/libLTO.dylib
#      if [ ! -r $LTO  ]; then
#        LTO=$LLVMCORE_PATH/../lib/libLTO.dylib
#        if [ ! -r $LTO ]; then
#          echo "Error: llvmCore installation is missing libLTO.dylib"
#          exit 1
#        fi
#      fi
#      mkdir -p $DEST_DIR/Developer/usr/lib
#      cp $LTO $DEST_DIR/Developer/usr/lib/libLTO.dylib
#      strip -S $DEST_DIR/Developer/usr/lib/libLTO.dylib
#
#      # Add a symlink in /usr/lib for B&I.
#      mkdir -p $DEST_DIR/usr/lib/
#      cd $DEST_DIR/usr/lib && \
#        ln -s ../../Developer/usr/lib/libLTO.dylib ./libLTO.dylib
#    fi

    # Remove lto.h from the install directory; clang will supply.
    # Also remove ppc_intrinsics.h.  Note that this breaks PPC support.
    find $BUILT_PREFIX \( -name lto.h -o -name ppc_intrinsics.h \) -delete -print || exit 1

    # LLVM LOCAL end

    find $BUILT_PREFIX -name \*.dSYM -print | xargs rm -r || exit 1
    chgrp -h -R staff $BUILT_PREFIX
    chgrp -R staff $BUILT_PREFIX

    # Done!
    exit 0




    # what i started with...
#
#    CPPFLAGS="-I/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/include \
#              -I/usr/include \
#              -I/usr/local/include" \
#        LDFLAGS="-arch x86_64 -arch i386 \
#                 -O2 \
#                 -L/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk/usr/lib \
#                 -L/usr/lib \
#                 -L/usr/local/lib" \
#        ARCHFLAGS="-arch x86_64 -arch i386" \
#        FFLAGS="-arch x86_64 -arch i386" \
#        ${SRC_DIR}/configure \
#            --disable-checking \
#            --enable-werror \
#            --prefix="${PREFIX}" \
#            --mandir=${PREFIX}/share/man \
#            --enable-languages=${COMPILE_LANGS} \
#            --program-prefix=llvm- \
#            --program-transform-name='/^[cg][^.-]*$/s/$/-4.2' \
#            --with-slibdir=/usr/lib \
#            --build=${TRIPLE} \
#            --host=${TRIPLE} \
#            --target=${TRIPLE} \
#            --enable-llvm=${XCODE_LLVM} \
#            --program-prefix="${TRIPLE}-" \
#            --with-gxx-include-dir=/usr/include/c++/4.2.1        #\
#            #--enable-targets=x86_64,powerpc \
#            #--enable-optimized  
#


