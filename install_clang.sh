#! /bin/bash

LLVM_VERSION=main
PAR_COMPILE_JOBS=8
PAR_LINK_JOBS=2
GCC_PATH=/scratch/maximilian.boether/opt/gcc-ml-11.2.0

INSTALLDIR=/scratch/maximilian.boether/opt/llvm-${LLVM_VERSION}
INSTALLDIR_ST1=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}-st1
BUILDDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_tar

packageversion="$(whoami)-$(hostname -s)"

GCC_LIB64_PATH="${GCC_PATH}/lib64"
GCC_LIB_PATH="${GCC_PATH}/lib"

# Set script to abort on any command that results an error status
trap '__abort' 0
set -e

__abort()
{
        cat <<EOF
***************
*** ABORTED ***
***************
An error occurred. Exiting...
EOF
        exit 1
}

__die()
{
    echo $*
    exit 1
}

#======================================================================
# Directory creation
#======================================================================
# ensure workspace directories don't already exist
for d in  "$BUILDDIR" "$SOURCEDIR" ; do
    if [ -d  "$d" ]; then
        __die "directory already exists - please remove and try again: $d"
    fi
done

for d in "$INSTALLDIR" "$BUILDDIR" "$SOURCEDIR" "$TARDIR" ;
do
    test  -d "$d" || mkdir --verbose -p $d
done

#======================================================================
# Download source code
#======================================================================

cd ${SOURCEDIR}

git clone https://github.com/ClangBuiltLinux/tc-build
cd tc-build


#======================================================================
# Let the script do all the work
#======================================================================
module purge || true

mkdir -p "${INSTALLDIR}/lib" || true
cp $(find ${GCC_PATH} | grep crtbeginS.o) "${INSTALLDIR}/lib" || true
cp $(find ${GCC_PATH} | grep crtendS.o) "${INSTALLDIR}/lib" || true

# First, build stage 1 using gcc
python3 build-llvm.py -p "clang;clang-tools-extra;libcxx;libcxxabi;libunwind;compiler-rt;lld" -s --branch "${LLVM_VERSION}" --install-folder="${INSTALLDIR_ST1}" --build-stage1-only --install-stage1-only -D LLVM_PARALLEL_COMPILE_JOBS="${PAR_COMPILE_JOBS}" LLVM_PARALLEL_LINK_JOBS="${PAR_LINK_JOBS}" CMAKE_CXX_LINK_FLAGS="-Wl,-rpath,${GCC_LIB_PATH} -L${GCC_LIB_PATH} -Wl,-rpath,${GCC_LIB64_PATH} -L${GCC_LIB64_PATH}" LINK_FLAGS="-Wl,-rpath,${GCC_LIB_PATH} -L${GCC_LIB_PATH} -Wl,-rpath,${GCC_LIB64_PATH} -L${GCC_LIB64_PATH}" COMPILER_RT_BUILD_CRT=ON

# Clear build files
rm -r ${SOURCEDIR}/tc-build/build

# Use stage 1 clang
export PATH=${INSTALLDIR_ST1}/bin:${PATH}
export LD_LIBRARY_PATH=${INSTALLDIR_ST1}/lib:${INSTALLDIR_ST1}/lib64:${LD_LIBRARY_PATH}
export CXX=clang++
export CC=clang
export LD="/usr/bin/ld"

cp $(find ${GCC_PATH} | grep crtbeginS.o) "${INSTALLDIR_ST1}/lib" || true
cp $(find ${GCC_PATH} | grep crtendS.o) "${INSTALLDIR_ST1}/lib" || true

# Build stage 1 and 2 again using stage 1 clang
python3 build-llvm.py -p "clang;clang-tools-extra;libcxx;libcxxabi;libunwind;compiler-rt;lld" -s --branch "${LLVM_VERSION}" --install-folder="${INSTALLDIR}" -D LLVM_PARALLEL_COMPILE_JOBS="${PAR_COMPILE_JOBS}" LLVM_PARALLEL_LINK_JOBS="${PAR_LINK_JOBS}" CMAKE_CXX_FLAGS="--gcc-toolchain=${GCC_PATH}" CMAKE_C_FLAGS="--gcc-toolchain=${GCC_PATH}" COMPILER_RT_BUILD_CRT=ON


#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring gcc into shell
# environment
cat << EOF > ${INSTALLDIR}/activate
# source this script to bring llvm ${LLVM_VERSION} into your environment

# first, in case we are on ARM, we remove cray stuff from PATH
export PATH=$(echo \${PATH} | awk -v RS=: -v ORS=: '/cray/ {next} {print}' | sed 's/:*$//')

module purge # clang really does not like all the other modules

export PATH=${INSTALLDIR}/bin:\$PATH
export LD_LIBRARY_PATH=${INSTALLDIR}/lib:${INSTALLDIR}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${INSTALLDIR}/share/man:\$MANPATH
export INFOPATH=${INSTALLDIR}/share/info:\$INFOPATH

export CXX=clang++
export CC=clang
export AR=llvm-ar
export NM=llvm-nm
export RANLIB=llvm-ranlib
export CXXFLAGS="-fuse-ld=lld -stdlib=libc++ --rtlib=compiler-rt ${CXXFLAGS}"
export CFLAGS="-fuse-ld=lld --rtlib=compiler-rt ${CFLAGS}"
EOF

trap : 0

#end
