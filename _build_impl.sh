#!/bin/bash

# Define the folder where we will dump all of the built files 
mkdir -p ${BUILD_DIR}

# Specify the variables for compiling
TOOLCHAIN_BIN=${TOOLCHAINS}/${SYSTEMS[$i]}/bin
export F77=${TOOLCHAIN_BIN}/${HEADERS[$i]}-gfortran
export CC=${TOOLCHAIN_BIN}/${HEADERS[$i]}-gcc
export CPP=${TOOLCHAIN_BIN}/${HEADERS[$i]}-cpp
export CXX=${TOOLCHAIN_BIN}/${HEADERS[$i]}-g++

export CFLAGS="--sysroot=${TOOLCHAINS}/${SYSTEMS[$i]}/sysroot"
export CXXFLAGS="--sysroot=${TOOLCHAINS}/${SYSTEMS[$i]}/sysroot"
export CPPFLAGS="--sysroot=${TOOLCHAINS}/${SYSTEMS[$i]}/sysroot"
export FFLAGS="--sysroot=${TOOLCHAINS}/${SYSTEMS[$i]}/sysroot"

# Actually, we will let the IPOPT configure script build these for us. 
# But if you just wanted to build BLAS and Lapack, it would look like this
if [ ]; then
    # Build BLAS
    if [ ! -f ${BUILD_DIR}/lib/libcoinblas.a ] ; then
        echo -e "${colored}Building BLAS for ${SYSTEMS[$i]}${normal}" && echo 
        cd $BASE/ipopt/ThirdParty/Blas
        mkdir -p build/${SYSTEMS[$i]}
        cd build/${SYSTEMS[$i]}
        ../../configure --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --enable-static --with-pic > _configure.blas.log
        make -j4 install > _make.blas.log
        cd $BASE
    fi 

    # Build Lapack
    if [ ! -f ${BUILD_DIR}/lib/libcoinlapack.a ] ; then
        echo -e "${colored}Building Lapack for ${SYSTEMS[$i]}${normal}" && echo 
        cd $BASE/ipopt/ThirdParty/Lapack
        mkdir -p build/${SYSTEMS[$i]}
        cd build/${SYSTEMS[$i]}
        ../../configure --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --enable-static --with-pic \
            --with-blas=BUILD > _configure.lapack.log
        make -j4 install > _make.lapack.log
        cd $BASE
    fi
fi

# Build IPOPT and its dependencies
if [ ! -f ${BUILD_DIR}/lib/libipopt.a ] ; then

    mkdir -p ${BUILD_DIR}/tmp
    cd ${BUILD_DIR}/tmp
    echo -e "${colored}Building IPOPT for ${SYSTEMS[$i]}${normal}" && echo 
    echo ${BUILD_DIR}/tmp
    ../../../configure COIN_SKIP_PROJECTS='ASL' --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --with-pic --enable-static \
        coin_skip_warn_cxxflags=yes \
        --with-blas=BUILD \
        --with-lapack=BUILD > _configure.ipopt.log
    make -j4 install > _make.ipopt.log
    cd $BASE
fi 

# Reset the sysroot and other variables
unset FC
unset F77
unset CC
unset CPP
unset CXX
unset LD
unset AR
unset AS
unset RANLIB
unset STRIP
