#! /bin/bash

ARMCLANG_VERSION=22.0.2

INSTALLDIR=/scratch/maximilian.boether/opt/armclang-${ARMCLANG_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/armclang-${ARMCLANG_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/armclang-${ARMCLANG_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/armclang-${ARMCLANG_VERSION}_tar

# Set script to abort on any command that results an error status
trap '__abort' 0
set -e

__wget()
{
    urlroot=$1; shift
    tarfile=$1; shift

    if [ ! -e "$TARDIR/$tarfile" ]; then
        wget --verbose ${urlroot}/$tarfile --directory-prefix="$TARDIR"
    else
        echo "already downloaded: $tarfile  '$TARDIR/$tarfile'"
    fi
}

__untar()
{
    dir="$1";
    file="$2"
    case $file in
        *xz)
            tar xJ -C "$dir" -f "$file"
            ;;
        *bz2)
            tar xj -C "$dir" -f "$file"
            ;;
        *gz)
            tar xz -C "$dir" -f "$file"
            ;;
        *)
            __die "don't know how to unzip $file"
            ;;
    esac
}


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

wget --verbose -O ${TARDIR}/armclang-${ARMCLANG_VERSION}.tar.gz https://developer.arm.com/-/media/Files/downloads/hpc/arm-allinea-studio/22-0-1/arm-compiler-for-linux_22.0.1_RHEL-8_aarch64.tar?revision=f0b78a0a-48a5-4f91-871b-24ed3e4db860 

# Check tarfiles are found, if not found, dont proceed
if [ ! -f "$TARDIR/armclang-${ARMCLANG_VERSION}.tar.gz" ]; then
    __die tarfile not found: $TARDIR/$f
fi

#======================================================================
# Unpack source tarfiles and install
#======================================================================
tar -xvf "$TARDIR/armclang-${ARMCLANG_VERSION}.tar.gz" -C "$SOURCEDIR"  

cd ${SOURCEDIR}/arm-compiler-for-linux_22.0.1_RHEL-8
./arm-compiler-for-linux_22.0.1_RHEL-8.sh -a -i ${INSTALLDIR}


#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring gcc into shell
# environment
cat << EOF > ${INSTALLDIR}/activate
# source this script to bring armclang ${ARMCLANG_VERSION} into your environment

module use ${INSTALLDIR}/modulefiles
module load acfl/22.0.1

export CXX=armclang++
export CC=armclang
export CXXFLAGS=-armpl ${CXXFLAGS}
export CFLAGS=-armpl ${CFLAGS}
export LDFLAGS=-armpl ${LDFLAGS}
EOF

trap : 0

#end
