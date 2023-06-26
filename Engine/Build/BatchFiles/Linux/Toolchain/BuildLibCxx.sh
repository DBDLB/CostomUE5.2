#!/bin/bash

# Use after you build the toolchain ie. once RunMe.sh has completed.
# Make sure you setup LINUX_MULTIARCH_ROOT to the base of the new toolchain
#
# Grab libcxx and libcxxabi source and place them in build/ dir where llvm is synced
# make sure they are renamed to libcxx and libcxxabi folder wise so it looks like:
#
# build
# ...
# ├── libcxx
# ├── libcxxabi
# ├── llvm
# ...
#
# from there run this script by:
# ./BuildLibCxx.sh <Path/To/Engine>/Engine/Build/BatchFiles/Linux/Toolchain/build

set -eu

SCRIPT_DIR=$(cd "$(dirname "$BASH_SOURCE")" ; pwd)

LLVM_DIR=${1:---help}

echo $LLVM_DIR

if [[ ! -f "${LLVM_DIR}/llvm/CMakeLists.txt" ]]; then
  echo "Usage: ${BASH_SOURCE} llvm-git-repo"
  echo "  llvm-git-repo is https://github.com/llvm/llvm-project.git"
  exit 2
fi

# Get num of cores
export CORES=$(getconf _NPROCESSORS_ONLN)
echo "Using ${CORES} cores for building"

echo "LLVM_DIR: ${LLVM_DIR}"

BuildLibCxx()
{
    export ARCH=$1
    local BUILD_DIR=${SCRIPT_DIR}/Build.${ARCH}
    export INSTALL_DIR=${SCRIPT_DIR}/INSTALL.${ARCH}

    echo "Building ${ARCH}"
    rm -rf ${BUILD_DIR}
    mkdir -p ${BUILD_DIR}

    pushd ${BUILD_DIR}

    set -x
    cmake \
      -DCMAKE_TOOLCHAIN_FILE="/tmp/__cmake_toolchain.cmake" \
      -DCMAKE_MAKE_PROGRAM=$(which make) \
      -DPYTHON_EXECUTABLE=$(which python) \
      -DPython3_EXECUTABLE=$(which python3) \
      -DLLVM_INCLUDE_BENCHMARKS=OFF \
      -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
      -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
      -DLLVM_TEMPORARILY_ALLOW_OLD_TOOLCHAIN=TRUE \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
      -DLLVM_ENABLE_PROJECTS="libcxx;libcxxabi" \
      -DLIBCXX_ENABLE_SHARED=OFF \
      -DLIBCXXABI_ENABLE_SHARED=OFF \
      -DLIBCXX_ENABLE_STATIC=ON \
      -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON \
      -DLIBCXXABI_INSTALL_SHARED_LIBRARY=OFF \
      -DLIBCXX_CXX_ABI_LIBRARY=c++abi \
      -DLIBCXX_ENABLE_FILESYSTEM=ON \
      ${LLVM_DIR}/llvm
    set +x

    make -j ${CORES} cxxabi cxx
    make install-cxx-headers

    mkdir -p ${INSTALL_DIR}/lib/Linux/${ARCH}
    cp -v lib/libc++.a ${INSTALL_DIR}/lib/Linux/${ARCH}
    cp -v lib/libc++abi.a ${INSTALL_DIR}/lib/Linux/${ARCH}

    popd
}

( cat <<_EOF_
  ## autogenerated by ${BASH_SOURCE} script
  SET(LINUX_MULTIARCH_ROOT \$ENV{LINUX_MULTIARCH_ROOT})
  SET(ARCHITECTURE_TRIPLE \$ENV{ARCH})

  message (STATUS "LINUX_MULTIARCH_ROOT is '\${LINUX_MULTIARCH_ROOT}'")
  message (STATUS "ARCHITECTURE_TRIPLE is '\${ARCHITECTURE_TRIPLE}'")

  SET(CMAKE_CROSSCOMPILING TRUE)
  SET(CMAKE_SYSTEM_NAME Linux)
  SET(CMAKE_SYSTEM_VERSION 1)

  # sysroot
  SET(CMAKE_SYSROOT \${LINUX_MULTIARCH_ROOT}/\${ARCHITECTURE_TRIPLE})

  SET(CMAKE_LIBRARY_ARCHITECTURE \${ARCHITECTURE_TRIPLE})

  # specify the cross compiler
  SET(CMAKE_C_COMPILER            \${CMAKE_SYSROOT}/bin/clang)
  SET(CMAKE_C_COMPILER_TARGET     \${ARCHITECTURE_TRIPLE})
  SET(CMAKE_C_FLAGS "-target      \${ARCHITECTURE_TRIPLE}")

  SET(CMAKE_CXX_COMPILER          \${CMAKE_SYSROOT}/bin/clang++)
  SET(CMAKE_CXX_COMPILER_TARGET   \${ARCHITECTURE_TRIPLE})
  SET(CMAKE_CXX_FLAGS "-target    \${ARCHITECTURE_TRIPLE}")

  SET(CMAKE_ASM_COMPILER          \${CMAKE_SYSROOT}/bin/clang)

  SET(CMAKE_FIND_ROOT_PATH        \${LINUX_MULTIARCH_ROOT})

  # hoping to force it to use ar
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

_EOF_
) > /tmp/__cmake_toolchain.cmake

BuildLibCxx x86_64-unknown-linux-gnu
BuildLibCxx aarch64-unknown-linux-gnueabi