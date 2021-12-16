#!/bin/bash

# https://www.videogames.ai/Install-ROCM-Machine-Learning-AMD-GPU

# SUSE RPMs for zypper (2021-10-19)
# https://repo.radeon.com/rocm/zyp/zypper/


cd $HOME
mkdir miopen-install
mkdir hipfft-install
mkdir miopen-deps
mkdir rccl-install

git clone https://github.com/ROCmSoftwarePlatform/MIOpen.git
git clone https://github.com/ROCmSoftwarePlatform/hipFFT.git
git clone https://github.com/ROCmSoftwarePlatform/rccl.git

module use /soft/modulefiles; module load cmake

cd $HOME/rccl
mkdir build; cd build
CXX=/usr/bin/hipcc cmake -DCMAKE_INSTALL_PREFIX=$HOME/rccl-install ..
make -j 8
make install
export LD_LIBRARY_PATH=$HOME/rccl-install/lib:$LD_LIBRARY_PATH


cd $HOME/hipFFT
mkdir build; cd build
cmake -DCMAKE_INSTALL_PREFIX=$HOME/hipfft-install -DCMAKE_CXX_COMPILER=hipcc -DCMAKE_BUILD_TYPE=Release -DBUILD_CLIENTS=OFF -L ..
make -j 8
make install
export LD_LIBRARY_PATH=$HOME/hipfft-install/lib:$LD_LIBRARY_PATH

cd $HOME/MIOpen
cmake -P install_deps.cmake --prefix $HOME/miopen-deps

# KGF: needed?
#export LD_LIBRARY_PATH=$HOME/miopen-deps:$LD_LIBRARY_PATH


mkdir build; cd build
CXX=/opt/rocm/llvm/bin/clang++ cmake -DMIOPEN_BACKEND=HIP -DCMAKE_INSTALL_PREFIX=$HOME/miopen-install -DCMAKE_PREFIX_PATH=$HOME/miopen-deps ..
make -j 8
make install
export LD_LIBRARY_PATH=$HOME/miopen-install/lib:$LD_LIBRARY_PATH

cd $HOME
export MYPATH=/home/$USER/amdenv
conda create -p $MYPATH python=3.8 pip
# KGF: check that the above line pulls python 3.8.12 or so, not 3.8.0
conda activate $MYPATH
pip install tensorflow-rocm


# testing; possible bug in TF 2.6.0 / Keras with "multiple optimizers"
git clone https://github.com/tensorflow/benchmarks.git tf_benchmarks || true
python $HOME/tf_benchmarks/scripts/tf_cnn_benchmarks/tf_cnn_benchmarks.py --model=resnet50


# https://pytorch.org/get-started/locally/
pip install torch torchvision==0.11.1 -f https://download.pytorch.org/whl/rocm4.2/torch_stable.html


#export LD_LIBRARY_PATH=$HOME/rccl-install/lib:$HOME/hipfft-install/lib:$HOME/miopen-deps:$HOME/miopen-install/lib:$LD_LIBRARY_PATH
