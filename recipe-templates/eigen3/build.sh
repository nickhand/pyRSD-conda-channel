#!/bin/sh

source /usr/common/contrib/bccp/conda-channel-bccp/nersc_profile.sh
mkdir build && cd build
cmake -DCMAKE_INSTALL_PREFIX=${PREFIX} -DCMAKE_BUILD_TYPE=Release ..
make install
