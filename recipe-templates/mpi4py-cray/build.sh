source $PROGRAMS_DIR/source/pyRSD-conda-channel/nersc_profile.sh
export MPICC=cc
python setup.py install --single-version-externally-managed --record rec.txt
