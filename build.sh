#!/bin/bash

# only one argument allowed
if [ $# -eq 0 ] || [ $# -gt 2 ] || [ $# -eq 2 ] && [ "$2" != "--clean" ]; then
    echo "usage: build.sh PYTHON [--clean]"
    exit 1
fi

if [[ -n $BASH_VERSION ]]; then
    _SCRIPT_LOCATION=${BASH_SOURCE[0]}
elif [[ -n $ZSH_VERSION ]]; then
    _SCRIPT_LOCATION=${funcstack[1]}
else
    echo "Only bash and zsh are supported"
    exit 1
fi

# the PYTHON version to build
PYTHON=$1
shift

_DIRNAME=`dirname ${_SCRIPT_LOCATION}`
_DIRNAME=`readlink -f $_DIRNAME`

# execute from the script's directory
pushd $_DIRNAME

INSTALL_FLAG=""
BUILD_FLAG="--skip-existing"

# get the bundle-anaconda command
source /usr/common/contrib/bccp/python-mpi-bcast/activate.sh

# activate our root anaconda install to start
source $LOCALSTACK/anaconda3/bin/activate root

# purge intermediate results
conda build purge

# keep conda and conda-build up to date
conda update --yes conda conda-build

# directory where recipes will be written
RECIPE_DIR=recipes

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
    conda build --python $PYTHON  mpi4py-cray* ||
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
            conda build --python $PYTHON --numpy 1.13  $BUILD_FLAG $f ||
            { echo "command 'conda build --python ${PYTHON} ${BUILD_FLAG} ${f}' failed"; exit 1; }
        fi
    done
    popd
}

install ()
{
    pushd recipe-templates

    # install packages into this python version's environment
    conda uninstall --yes mpich2
    conda install $INSTALL_FLAG --use-local --yes * ||
    { echo "conda install of packages failed"; exit 1; }
    conda update --yes --use-local -f * || { echo "forced conda update failed"; exit 1; }
    conda update --yes --use-local --all || { echo "conda update all failed"; exit 1; }
    popd

    # and tar the install
    bash $LOCALSTACK/tar-anaconda.sh $LOCALSTACK/anaconda3/envs/pyrsd-anaconda-$PYTHON-$NERSC_HOST.tar.gz $CONDA_PREFIX ||
    { echo "bundle-anaconda failed"; exit 1; }
}

# build fresh mpi4py first
build_mpi4py $PYTHON

# build packages for specific python version
build $PYTHON

# install
install

popd # return to start directory
