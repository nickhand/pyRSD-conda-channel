#!/bin/bash

# fortran is used, so need this line

if [[ $OSTYPE == darwin* ]]; then
    export LDFLAGS="$LDFLAGS -Wl,-rpath,${CONDA_PREFIX}/lib"
fi

# this uses CFLAGS for CCFLAG
cp $RECIPE_DIR/class.cfg depends/class.cfg

$PYTHON setup.py --quiet install --single-version-externally-managed --record rec.txt
