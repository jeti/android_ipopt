set -e

# Specify which version of IPOPT you want 
ipopt_version="3.12.9"

# Specify NDK release and API that you want to use. 
NDK_RELEASE="r13b"
API="24"

# We want to color the font to differentiate our comments from other stuff
normal="\e[0m"
colored="\e[104m"

declare -a SYSTEMS=("arm64" 
                    "arm" 
                    "mips64" 
                    "mips" 
                    "x86" 
                    "x86_64")
declare -a HEADERS=("aarch64-linux-android"
                    "arm-linux-androideabi"
                    "mips64el-linux-android"
                    "mipsel-linux-android"
                    "x86"
                    "x86_64")
N_SYSTEMS=${#SYSTEMS[@]}

# Save the base directory
BASE=$PWD
ARCHIVES=${BASE}/archives
mkdir -p ${ARCHIVES}
TOOLCHAINS=${BASE}/standalone_toolchains
mkdir -p ${TOOLCHAINS}

# First, we need to grab all of the standalone toolchains
for (( i=0; i<${N_SYSTEMS}; i++ )) ; do 

    # If we don't have the toolchain... 
    TOOLCHAIN=${TOOLCHAINS}/${SYSTEMS[$i]}
    if [ ! -d ${TOOLCHAIN} ] ; then    

        # If we don't have the compressed toochain, download it  
        if [ ! -f ${ARCHIVES}/${HEADERS[$i]}-4.9.7z ] ; then

            echo -e "${colored}Downloading the standalone toolchain ${SYSTEMS[$i]}${normal}" && echo
            wget https://github.com/jeti/android_fortran/releases/download/toolchains/${SYSTEMS[$i]}-4.9.7z -P ${ARCHIVES}
            echo -e "${colored}Downloaded the standalone toolchain ${SYSTEMS[$i]}${normal}" && echo
        fi
        
        # Now unpack the toolchain
        echo -e "${colored}Unpacking the standalone toolchain ${HEADERS[$i]}${normal}" && echo
        mkdir -p ${TOOLCHAIN}
        7z x ${ARCHIVES}/${HEADERS[$i]}-4.9.7z -o${TOOLCHAIN} -aoa > 7z.log
        rm 7z.log
        echo -e "${colored}Unpacked the standalone toolchain ${HEADERS[$i]}${normal}" && echo
    fi
done

# Next, get IPOPT and its dependencies
if [ ! -d ipopt ] ; then

    # Make sure that we have "unzip" installed
    if which unzip > /dev/null; then
        echo ""
    else
        echo -e "${colored}To unpack IPOPT, we need 'unzip'. Please give us sudo rights to install it.${normal}" && echo 
        sudo apt install -y unzip
        echo ""
    fi

    # Next, see if we already have the ipopt zip by chance... 
    if [ ! -d ${ARCHIVES}/ipopt.zip ] ; then
        echo -e "${colored}Downloading IPOPT${normal}" && echo 
        curl -o ${ARCHIVES}/ipopt.zip https://www.coin-or.org/download/source/Ipopt/Ipopt-${ipopt_version}.zip
    fi
    
    # Now unzip the archive and rename the unzipped folder
    echo -e "${colored}Unpacking IPOPT${normal}" && echo 
    unzip ${ARCHIVES}/ipopt.zip
    mv Ipopt-${ipopt_version} ipopt
    
    # Get all of the dependencies (we build later)
    echo -e "${colored}Getting dependencies${normal}" && echo 
    cd $BASE/ipopt/ThirdParty/Blas
    ./get.Blas
    cd $BASE/ipopt/ThirdParty/Lapack
    ./get.Lapack
    cd $BASE/ipopt/ThirdParty/ASL
    ./get.ASL
    cd $BASE/ipopt/ThirdParty/Mumps
    ./get.Mumps
    cd $BASE/ipopt/ThirdParty/Metis
    ./get.Metis
    cd $BASE
     
fi

# Get the newest versions of config.guess and config.sub
if [ ! -f ${BASE}/config.guess ] ; then
    echo -e "${colored}Downloading the newest version of config.guess${normal}" && echo 
    wget -O config.guess 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
fi
if [ ! -f ${BASE}/config.sub ] ; then
    echo -e "${colored}Downloading the newest version of config.sub${normal}" && echo 
    wget -O config.sub 'http://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=HEAD'
fi

# Replace config.guess and config.sub in all of the IPOPT files 
echo -e "${colored}Replacing config.guess${normal}" && echo 
find ${BASE}/ipopt -type f -name "config.guess" | while read file; do
    cp ${BASE}/config.guess ${file}
done

echo -e "${colored}Replacing config.sub${normal}" && echo 
find ${BASE}/ipopt -type f -name "config.sub" | while read file; do
    cp ${BASE}/config.sub ${file}
done

# There seems to be a problem in the configure scripts where they are accidentally grabbing an 
# extra ' when finding the math library. Specifically, it is found as -lm' instead of -lm
echo -e "${colored}Replacing FLIBS in configure files${normal}" && echo 
find ${BASE}/ipopt -type f -name "configure" | while read file; do
    sed -i 's|FLIBS="$ac_cv_f77_libs"|FLIBS=${ac_cv_f77_libs/"-lm'"'"'"/"-lm"}|g' ${file}
done

# Now we will build BLAS, LAPACK, and IPOPT for each of the desired systems. 
for (( i=0; i<${N_SYSTEMS}; i++ )) ; do 
    
    mkdir -p $BASE/ipopt/build
    
    # See if we already built for this system
    if [ ! -d $BASE/ipopt/build/${SYSTEMS[$i]} ] ; then
    
        # Define the folder where we will dump all of the built files 
        BUILD_DIR=$BASE/ipopt/build/${SYSTEMS[$i]}
        
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
    
        # Build BLAS
        echo -e "${colored}Building BLAS for ${SYSTEMS[$i]}${normal}" && echo 
        cd $BASE/ipopt/ThirdParty/Blas
        mkdir -p build/${SYSTEMS[$i]}
        cd build/${SYSTEMS[$i]}
        ../../configure --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --disable-shared --with-pic
        make install
        cd $BASE
        
        # Build Lapack
        echo -e "${colored}Building Lapack for ${SYSTEMS[$i]}${normal}" && echo 
        cd $BASE/ipopt/ThirdParty/Lapack
        mkdir -p build/${SYSTEMS[$i]}
        cd build/${SYSTEMS[$i]}
        ../../configure --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --disable-shared --with-pic \
            --with-blas="$BUILD_DIR/libcoinblas.a -lgfortran"
        make install
        cd $BASE
    
        # Build IPOPT
        echo -e "${colored}Building IPOPT for ${SYSTEMS[$i]}${normal}" && echo 
        cd $BASE/ipopt
        ./configure --prefix=$BUILD_DIR --host="${HEADERS[$i]}" --disable-shared --with-pic \
            coin_skip_warn_cxxflags=yes \
            --with-blas="$BUILD_DIR/libcoinblas.a -lgfortran" \
            --with-lapack=$BUILD_DIR/libcoinlapack.a
        make
        make -j4 install
        cd $BASE
        
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
    fi
done
