#!/bin/bash

if [[ -n $BASH_VERSION ]]; then
    _SCRIPT_LOCATION=${BASH_SOURCE[0]}
elif [[ -n $ZSH_VERSION ]]; then
    _SCRIPT_LOCATION=${funcstack[1]}
else
    echo "Only bash and zsh are supported"
    exit 1
fi

# the PYTHON version to build
PYTHON=3.6

_DIRNAME=`dirname ${_SCRIPT_LOCATION}`
_DIRNAME=`readlink -f $_DIRNAME`

# execute from the script's directory
pushd $_DIRNAME

INSTALL_FLAG=""
BUILD_FLAG="--skip-existing"

ENVNAME=$PYTHON

# activate our root anaconda install to start
source activate dev

# directory where recipes will be written
RECIPE_DIR=recipes-$ENVNAME

# make the recipes
python extrude_recipes requirements.yml --recipe-dir $RECIPE_DIR || { echo "extrude_recipes failed"; exit 1; }

# determine the build order (ordered by dependencies)
BUILD_ORDER=$(python sort_recipes $RECIPE_DIR/*)
if [ -z "$BUILD_ORDER" ]; then
    echo "sort_recipes failed"
    exit 1
fi

build_mpi4py ()
{
    local PYTHON=$1
    pushd $RECIPE_DIR
    conda build --python $PYTHON mpi4py-cray* ||
    { echo "conda build of mpi4py-cray failed"; exit 1; }
    popd
}

build ()
{
    local PYTHON=$1

    pushd $RECIPE_DIR
    for f in $BUILD_ORDER; do
        echo Building for $f
        if [ $f != mpi4py-cray* ]; then
            conda build --python $PYTHON $BUILD_FLAG $f ||
            { echo "command 'conda build --python ${PYTHON} ${BUILD_FLAG} ${f}' failed"; exit 1; }
        fi
    done
    popd
}

install ()
{
    local PYTHON=$1
    pushd recipe-templates

    # install packages into this python version's environment
    conda uninstall --yes mpich2
    conda install $INSTALL_FLAG --use-local --yes * ||
    { echo "conda install of packages failed"; exit 1; }
    conda update --yes --use-local -f * || { echo "forced conda update failed"; exit 1; }
    conda update --yes --use-local --all || { echo "conda update all failed"; exit 1; }
    popd

    # and tar the install
    bundle-anaconda $TAR_DIR/$NERSC_HOST/pyrsd-anaconda-$PYTHON.tar.gz $CONDA_PREFIX ||
    { echo "bundle-anaconda failed"; exit 1; }
}

# build fresh mpi4py first
build_mpi4py $PYTHON

# build packages for specific python version
build $PYTHON

# install
install $ENVNAME

popd # return to start directory
