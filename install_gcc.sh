#! /bin/bash

GCC_VERSION=11.2.0
MAKE_FLAGS="-j16"

INSTALLDIR=/scratch/maximilian.boether/opt/gcc-${GCC_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/gcc-${GCC_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/gcc-${GCC_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/gcc-${GCC_VERSION}_tar

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

__wget https://ftp.mpi-inf.mpg.de/mirrors/gnu/mirror/gcc.gnu.org/pub/gcc/releases/gcc-${GCC_VERSION}/gcc-${GCC_VERSION}.tar.gz

# Check tarfiles are found, if not found, dont proceed
if [ ! -f "$TARDIR/gcc-${GCC_VERSION}.tar.gz" ]; then
    __die tarfile not found: $TARDIR/$f
fi

#======================================================================
# Unpack source tarfiles
#======================================================================
__untar  "$SOURCEDIR"  "$TARDIR/gcc-${GCC_VERSION}.tar.gz"

#======================================================================
# Download the prerequisites
#======================================================================
${SOURCEDIR}/gcc-${GCC_VERSION}/contrib/download_prerequisites


#======================================================================
# Configure
#======================================================================
cd "${BUILDDIR}"

$source_dir/gcc-${GCC_VERSION}/configure             \
    --prefix=${INSTALLDIR}                           \
    --enable-shared                                  \
    --enable-threads=posix                           \
    --enable-checking=release                        \
    --enable-__cxa_atexit                            \
    --enable-clocale=gnu                             \
    --enable-linker-build-id                         \
    --enable-languages=c,c++,lto,jit                 \
    --disable-multilib                               \
    --disable-libunwind-exceptions                   \
    --disable-vtable-verify                          \
    --enable-libstdcxx-debug                         \
    --enable-plugin                                  \
    --disable-libgcj                                 \
    --with-pkgversion="$packageversion"

# Notes
#
#   --enable-shared --enable-threads=posix --enable-__cxa_atexit: 
#       These parameters are required to build the C++ libraries to published standards.
#   
#   --enable-clocale=gnu: 
#       This parameter is a failsafe for incomplete locale data.
#   
#   --disable-multilib: 
#       This parameter ensures that files are created for the specific
#       architecture of your computer.
#        This will disable building 32-bit support on 64-bit systems where the
#        32 bit version of libc is not installed and you do not want to go
#        through the trouble of building it. Diagnosis: "Compiler build fails
#        with fatal error: gnu/stubs-32.h: No such file or directory"
#   
#   --with-system-zlib: 
#       Uses the system zlib instead of the bundled one. zlib is used for
#       compressing and uncompressing GCC's intermediate language in LTO (Link
#       Time Optimization) object files.
#   
#   --enable-languages=all
#   --enable-languages=c,c++,fortran,go,objc,obj-c++: 
#       This command identifies which languages to build. You may modify this
#       command to remove undesired language


#======================================================================
# Compiling and installing
#======================================================================

cd "$BUILDDIR"
make $MAKE_FLAGS bootstrap
make $MAKE_FLAGS install

#======================================================================
# Post build
#======================================================================

# Create a shell script that users can source to bring gcc into shell
# environment
cat << EOF > ${INSTALLDIR}/activate
# source this script to bring gcc ${GCC_VERSION} into your environment
export PATH=${INSTALLDIR}/bin:\$PATH
export LD_LIBRARY_PATH=${INSTALLDIR}/lib:${INSTALLDIR}/lib64:\$LD_LIBRARY_PATH
export MANPATH=${INSTALLDIR}/share/man:\$MANPATH
export INFOPATH=${INSTALLDIR}/share/info:\$INFOPATH
EOF

trap : 0

#end
