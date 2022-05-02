#! /bin/bash

LLVM_VERSION=main

INSTALLDIR=/scratch/maximilian.boether/opt/llvm-${LLVM_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/llvm-${LLVM_VERSION}_tar

packageversion="$(whoami)-$(hostname -s)"

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

python3 build-llvm.py -p "clang;clang-tools-extra;libcxx;libcxxabi;libunwind;compiler-rt;lld" -s --branch "${LLVM_VERSION}" --install-folder="${INSTALLDIR}"

#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring gcc into shell
# environment
cat << EOF > ${INSTALLDIR}/activate
# source this script to bring llvm ${LLVM_VERSION} into your environment

# first, in case we are on ARM, we remove cray stuff from PATH
export PATH=$(echo \${PATH} | awk -v RS=: -v ORS=: '/cray/ {next} {print}' | sed 's/:*$//')

export PATH=${INSTALLDIR}/bin:\$PATH
export LD_LIBRARY_PATH=${INSTALLDIR}/lib:${INSTALLDIR}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${INSTALLDIR}/share/man:\$MANPATH
export INFOPATH=${INSTALLDIR}/share/info:\$INFOPATH

export CXX=clang++
export CC=clang
export AR=llvm-ar
export NM=llvm-nm
export RANLIB=llvm-ranlib
EOF

trap : 0

#end
