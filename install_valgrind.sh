#! /bin/bash

VALGRIND_VERSION=master
MAKE_FLAGS="-j16"

INSTALLDIR=/scratch/maximilian.boether/opt/valgrind-${VALGRIND_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/valgrind-${VALGRIND_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/valgrind-${VALGRIND_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/valgrind-${VALGRIND_VERSION}_tar

packageversion="$(whoami)-$(hostname -s)"

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

cd ${SOURCEDIR}
git clone git://sourceware.org/git/valgrind.git

#======================================================================
# Setup the environment
#======================================================================

cd valgrind
chmod +x autogen.sh
./autogen.sh

#======================================================================
# Configure
#======================================================================
cd "${BUILDDIR}"

$SOURCEDIR/valgrind/configure             \
    --prefix=${INSTALLDIR}                           

#======================================================================
# Compiling and installing
#======================================================================

cd "$BUILDDIR"
make $MAKE_FLAGS
make $MAKE_FLAGS install

#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring gcc into shell
# environment
cat << EOF > ${INSTALLDIR}/activate
# source this script to bring valgrind into your environment

export PATH=${INSTALLDIR}/bin:\$PATH
export LD_LIBRARY_PATH=${INSTALLDIR}/lib:${INSTALLDIR}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${INSTALLDIR}/share/man:\$MANPATH
export INFOPATH=${INSTALLDIR}/share/info:\$INFOPATH
EOF

trap : 0

#end
