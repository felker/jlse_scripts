#!/bin/bash

# https://www.videogames.ai/Install-ROCM-Machine-Learning-AMD-GPU

# SUSE RPMs for zypper (2021-10-19)
# https://repo.radeon.com/rocm/zyp/zypper/

# Run this script in /soft/conda/amd/
# Modulefile in /soft/modulefiles/conda/amd/
INSTALL_DIR="${PWD}/2022-01-11/"

set -e

mkdir -p $INSTALL_DIR
cd $INSTALL_DIR
mkdir miopen-install
mkdir hipfft-install
mkdir miopen-deps
mkdir rccl-install

git clone https://github.com/ROCmSoftwarePlatform/MIOpen.git
git clone https://github.com/ROCmSoftwarePlatform/hipFFT.git
git clone https://github.com/ROCmSoftwarePlatform/rccl.git


. /etc/profile.d/modules.sh  # get module shell command
module use /soft/modulefiles; module load cmake

cd ${INSTALL_DIR}/rccl
mkdir build; cd build
CXX=/usr/bin/hipcc cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/rccl-install ..
make -j 8
make install
export LD_LIBRARY_PATH=${INSTALL_DIR}/rccl-install/lib:$LD_LIBRARY_PATH


cd ${INSTALL_DIR}/hipFFT
mkdir build; cd build
cmake -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/hipfft-install -DCMAKE_CXX_COMPILER=hipcc -DCMAKE_BUILD_TYPE=Release -DBUILD_CLIENTS=OFF -L ..
make -j 8
make install
export LD_LIBRARY_PATH=${INSTALL_DIR}/hipfft-install/lib:$LD_LIBRARY_PATH

cd ${INSTALL_DIR}/MIOpen
cmake -P install_deps.cmake --prefix ${INSTALL_DIR}/miopen-deps

# KGF: needed?
#export LD_LIBRARY_PATH=${INSTALL_DIR}/miopen-deps:$LD_LIBRARY_PATH


mkdir build; cd build
CXX=/opt/rocm/llvm/bin/clang++ cmake -DMIOPEN_BACKEND=HIP -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR}/miopen-install -DCMAKE_PREFIX_PATH=${INSTALL_DIR}/miopen-deps ..
make -j 8
make install
export LD_LIBRARY_PATH=${INSTALL_DIR}/miopen-install/lib:$LD_LIBRARY_PATH

cd ${INSTALL_DIR}
export MYPATH=${INSTALL_DIR}/mconda3
conda create -y -p $MYPATH python=3.8 pip
# KGF: check that the above line pulls python 3.8.12 or so, not 3.8.0
conda activate $MYPATH
pip install tensorflow-rocm

# https://pytorch.org/get-started/locally/
pip install torch torchvision==0.11.1 -f https://download.pytorch.org/whl/rocm4.2/torch_stable.html

echo "Cleaning up"

conda list

chmod -R a-w ${INSTALL_DIR}

set +e

#----------------------------------------------------

# testing; possible bug in TF 2.6.0 / Keras with "multiple optimizers"
#git clone https://github.com/tensorflow/benchmarks.git tf_benchmarks || true
#python $HOME/tf_benchmarks/scripts/tf_cnn_benchmarks/tf_cnn_benchmarks.py --model=resnet50


# user (or modulefile) should modify their library path as follows:
#export LD_LIBRARY_PATH=${INSTALL_DIR}/rccl-install/lib:${INSTALL_DIR}/hipfft-install/lib:${INSTALL_DIR}/miopen-deps:${INSTALL_DIR}/miopen-install/lib:$LD_LIBRARY_PATH
