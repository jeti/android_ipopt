# Exit if any error occurs
set -e

# Specify which version of IPOPT you want 
ipopt_version="3.12.9"

# Specify NDK release and API that you want to use. 
NDK_RELEASE="r13b"
API="24"

# We want to color the font to differentiate our comments from other stuff
normal="\e[0m"
colored="\e[104m"

declare -a SYSTEMS=("arm" 
                    "arm64" 
                    "mips" 
                    "mips64" 
                    "x86" 
                    "x86_64")
declare -a HEADERS=("arm-linux-androideabi"
                    "aarch64-linux-android"
                    "mipsel-linux-android"
                    "mips64el-linux-android"
                    "i686-linux-android"
                    "x86_64-linux-android")
declare -a ZIPS=("arm-linux-androideabi"
                 "aarch64-linux-android"
                 "mipsel-linux-android"
                 "mips64el-linux-android"
                 "x86"
                 "x86_64")
declare -a LIBNAMES=("armeabi"
                     "arm64-v8a"
                     "mips"
                     "mips64"
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
        echo -e "${colored}Unpacking the standalone toolchain ${SYSTEMS[$i]}${normal}" && echo
        mkdir -p ${TOOLCHAIN}
        7z x ${ARCHIVES}/${HEADERS[$i]}-4.9.7z -o${TOOLCHAIN} -aoa > 7z.log
        rm 7z.log
        echo -e "${colored}Unpacked the standalone toolchain ${SYSTEMS[$i]}${normal}" && echo
    fi
done

# Next, get IPOPT and its dependencies
if [ ! -d ipopt ] ; then

    # First, let's see if perhaps we have the complete toolchain, ready to build
    if [ ! -f ${ARCHIVES}/ipopt_before_building.7z ] ; then
    
        # We don't have it. So we have to download the individual IPOPT pieces...
        
        # See if we already have the ipopt zip already downloaded
        if [ ! -f ${ARCHIVES}/ipopt.zip ] ; then
            echo -e "${colored}Downloading IPOPT${normal}" && echo 
            curl -o ${ARCHIVES}/ipopt.zip https://www.coin-or.org/download/source/Ipopt/Ipopt-${ipopt_version}.zip
        fi
        
        # Now unzip the archive and rename the unzipped folder
        if which unzip > /dev/null; then
            echo ""
        else
            echo -e "${colored}To unpack IPOPT, we need 'unzip'. Please give us sudo rights to install it.${normal}" && echo 
            sudo apt install -y unzip
            echo ""
        fi
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

        # Finally, let's compress the ipopt repo so that if we want to rebuild, we don't have to go through all of that again. 
        echo -e "${colored}Compressing IPOPT in case we want to return to this point${normal}" && echo 
        7z a -t7z ${ARCHIVES}/ipopt_before_building.7z -m0=lzma2 -mx=9 -aoa ipopt > tmp.log
        rm tmp.log
      
    else      
        
        # We do have the complete ipopt toolchain archived. Let's just unpack that 
        echo -e "${colored}Unpacking IPOPT${normal}" && echo 
        7z x ${ARCHIVES}/ipopt_before_building.7z -aoa > tmp.log
        rm tmp.log

    fi

fi

# Now we will build BLAS, LAPACK, and IPOPT for each of the desired systems. 
for (( i=0; i<${N_SYSTEMS}; i++ )) ; do 
    
    mkdir -p $BASE/ipopt/build
    BUILD_DIR=$BASE/ipopt/build/${SYSTEMS[$i]}
    
    # Note that adding an ampersand at the end of the line should let the builds occur in parallel, but 
    # that doesnt seem to be working.
    ( . ./_build_impl.sh ) &
done

echo -e "${colored}All of the build processes have been started. Now we wait. This may take an hour. Literally.${normal}" && echo 
wait
echo -e "${colored}Everything has been built!!! Congratulations. Now we will compress the relevant files into an archive for you.${normal}" && echo 

# Finally, pack up all of the files we need a nice, convenient archive 
ARCHIVE=${ARCHIVES}/ipopt_android.7z
rm -rf ${ARCHIVE}

# We are going to copy all of the files to a separate folder, then just compress that folder 
LIBS=${BASE}/libs
mkdir -p ${LIBS}

# First, copy the includes from one of the builds 
cp -r ${BASE}/ipopt/build/arm/include ${LIBS}

# Now copy the libraries 
for (( i=0; i<${N_SYSTEMS}; i++ )) ; do 
    LIB=${LIBS}/${LIBNAMES[$i]}
    mkdir -p ${LIB}
    cp ${BASE}/ipopt/build/${SYSTEMS[$i]}/lib/*.a ${LIB}
done 

# Finally, compress everything
7z a -t7z ${ARCHIVE} -m0=lzma2 -mx=9 -aoa ${LIBS}/* > tmp.log
rm -rf ${LIBS}

