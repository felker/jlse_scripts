#!/bin/bash

# TODO: consider skipping building the AMD libraries from source
# and reuse installs from /soft/compilers/rocm/rocm-4.5.2/*

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

# TODO: put these in a $DOWNLOADS directory and rm it at end?
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
# KGF: check that the above line pulls python 3.8.12 or so, not 3.8.0--- CONFIRMED


# create a setup file
cat > setup.sh << EOF
preferred_shell=\$(basename \$SHELL)

if [ -n "\$ZSH_EVAL_CONTEXT" ]; then
    DIR=\$( cd "\$( dirname "\$0" )" && pwd )
else  # bash, sh, etc.
    DIR=\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )
fi

eval "\$(\$DIR/bin/conda shell.\${preferred_shell} hook)"
EOF

# KGF: should I skip this part? etc/ dir does not exist in this installation, unlike
# on ThetaKNL and ThetaGPU (which has fish/, jupyter/, ...) might just be because I install
# more packages on those platforms
# -------------------------------------------------------------------
# create custom pythonstart in local area to deal with python readlines error
# cat > etc/pythonstart << EOF
# # startup script for python to enable saving of interpreter history and
# # enabling name completion

# # import needed modules
# import atexit
# import os
# #import readline
# import rlcompleter

# # where is history saved
# historyPath = os.path.expanduser("~/.pyhistory")

# # handler for saving history
# def save_history(historyPath=historyPath):
#     #import readline
#     #try:
#     #    readline.write_history_file(historyPath)
#     #except:
#     pass

# # read history, if it exists
# #if os.path.exists(historyPath):
# #    readline.set_history_length(10000)
# #    readline.read_history_file(historyPath)

# # register saving handler
# atexit.register(save_history)

# # enable completion
# #readline.parse_and_bind('tab: complete')

# # cleanup
# del os, atexit, rlcompleter, save_history, historyPath
# EOF
# -------------------------------------------------------------------

cat > .condarc << EOF
env_prompt: "(\$ENV_NAME/\$CONDA_DEFAULT_ENV) "
pkgs_dirs:
   - \$HOME/.conda/pkgs
EOF

# move to base install directory
cd $INSTALL_DIR
source ${MYPATH}/setup.sh
# KGF: alternatively,
#conda activate $MYPATH

echo CONDA BINARY: $(which conda)
echo CONDA VERSION: $(conda --version)
echo PYTHON VERSION: $(python --version)

cat > modulefile << EOF
#%Module2.0
## miniconda modulefile
##
proc ModulesHelp { } {
   puts stderr "This module will add Miniconda to your environment"
}

set _module_name  [module-info name]
set is_module_rm  [module-info mode remove]
set sys           [uname sysname]
set os            [uname release]
set HOME          $::env(HOME)

set CONDA_PREFIX                 $CONDA_PREFIX_PATH

setenv CONDA_PREFIX              \$CONDA_PREFIX
setenv PYTHONUSERBASE            \$HOME/.local/\${_module_name}
setenv ENV_NAME                  \$_module_name
setenv PYTHONSTARTUP             \$CONDA_PREFIX/etc/pythonstart

puts stdout "source \$CONDA_PREFIX/setup.sh"
module-whatis  "miniconda installation"
EOF

set -e

echo "Installing tensorflow-rocm and PyTorch ROCm"

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
