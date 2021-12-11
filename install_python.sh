PYTHON_VERSION=3.7.7
PYTHON_MAJOR=3
MAKE_FLAGS="-j16"

LIBFFIDIR=/scratch/maximilian.boether/opt/libffi
INSTALLDIR=/scratch/maximilian.boether/opt/python-${PYTHON_VERSION}
BUILDDIR=/scratch/maximilian.boether/tmp/python-${PYTHON_VERSION}_build
SOURCEDIR=/scratch/maximilian.boether/tmp/python-${PYTHON_VERSION}_source
TARDIR=/scratch/maximilian.boether/tmp/python-${PYTHON_VERSION}_tar

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

__wget https://github.com/libffi/libffi/releases/download/v3.4.2 libffi-3.4.2.tar.gz
__wget https://www.python.org/ftp/python/${PYTHON_VERSION} Python-${PYTHON_VERSION}.tgz

# Check tarfiles are found, if not found, dont proceed
if [ ! -f "$TARDIR/Python-${PYTHON_VERSION}.tgz" ]; then
    __die tarfile not found: $TARDIR/$f
fi


#======================================================================
# Unpack source tarfiles
#======================================================================
__untar  "$SOURCEDIR"  "$TARDIR/Python-${PYTHON_VERSION}.tgz"
__untar  "$SOURCEDIR"  "$TARDIR/libffi-3.4.2.tar.gz"

## Handle libeffi first

cd "${BUILDDIR}"
mkdir libffi
cd libffi
$SOURCEDIR/libffi-3.4.2/./configure --disable-docs --prefix=$LIBFFIDIR 
make $MAKE_FLAGS
make $MAKE_FLAGS install

#======================================================================
# Configure
#======================================================================


cd "${BUILDDIR}"

export LD_LIBRARY_PATH=$LIBFFIDIR:$LD_LIBRARY_PATH
export LD_RUN_PATH=$LIBFFIDIR:$LD_RUN_PATH

$SOURCEDIR/Python-${PYTHON_VERSION}/configure \
    --prefix=$INSTALLDIR \
    --enable-shared \
    --enable-ipv6 \
    --with-ensurepip=install \
    --with-system-ffi=$LIBFFIDIR \
    LDFLAGS="-Wl,-rpath=$INSTALLDIR/lib,--disable-new-dtags,-L$LIBFFIDIR" \
    CPPFLAGS="-I $LIBFFIDIR/libffi-3.4.2/include"

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
# source this script to bring python ${PYTHON_VERSION} into your environment
export PATH=${INSTALLDIR}/bin:\$PATH

alias python='python3'
EOF

trap : 0

#end


