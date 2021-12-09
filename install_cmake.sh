CMAKE_VERSION=3.21
MAKE_FLAGS="-j16"

INSTALLDIR=/scratch/maximilian.boether/opt/cmake-${CMAKE_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/cmake-${CMAKE_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/cmake-${CMAKE_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/cmake-${CMAKE_VERSION}_tar

mkdir cmake
cd cmake
version=3.21
build=1
mkdir /scratch/maximilian.boether/temp
cd /scratch/maximilian.boether/temp
wget https://cmake.org/files/v$version/cmake-$version.$build.tar.gz
tar -xzvf cmake-$version.$build.tar.gz
cd cmake-$version.$build/
./configure --prefix=$INSTALL_DIR
make -j$(nproc)
make install

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

__wget https://cmake.org/files/v$version cmake-$version.$build.tar.gz

# Check tarfiles are found, if not found, dont proceed
if [ ! -f "$TARDIR/cmake-$version.$build.tar.gz" ]; then
    __die tarfile not found: $TARDIR/$f
fi


#======================================================================
# Unpack source tarfiles
#======================================================================
__untar  "$SOURCEDIR"  "$TARDIR/cmake-$version.$build.tar.gz"


#======================================================================
# Configure
#======================================================================
cd "${BUILDDIR}"

$source_dir/gcc-${GCC_VERSION}/configure --prefix=${INSTALLDIR}      


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
# source this script to bring cmake ${CMAKE_VERSION} into your environment
export PATH=${INSTALLDIR}/bin:\$PATH
EOF

trap : 0

#end


