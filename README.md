This archive contains a script `build.sh` to generate shared and static libraries for IPOPT on Android. In the process of building IPOPT, we also generate shared and static versions of 

- BLAS
- Lapack
- Metis
- Mumps

So if you need those libraries for an Android project, you have come to the right place.

To build these libraries, you can either run the build script, or download the prebuilt files in the releases section. The build script can take very long to run (maybe an hour depending on your connection speed and computer), so I would recommend just heading to the `releases` tab. However, if you run the build script, then it will use the Android standalone toolchains (with Fortran) that are available in the [release section](https://github.com/jeti/android_fortran/releases) of [this repo](https://github.com/jeti/android_fortran).

In the [release section](https://github.com/jeti/android_ipopt/releases) of this repo, you will find two archives, one containing the includes and static libraries

- libcoinblas.a
- libcoinlapack.a
- libcoinmetis.a
- libcoinmumps.a
- libipopt.a

and one containing the includes and the shared libraries

- libcoinblas.so
- libcoinlapack.so
- libcoinmetis.so
- libcoinmumps.so
- libipopt.so

Both of these archives contain the libraries for all of the possible Android architectures, that is,

- arm
- arm64
- mips
- mips64
- x86
- x86_64

The archives are packaged so that you can simply unpack them into the `libs` folder of your Android project. 