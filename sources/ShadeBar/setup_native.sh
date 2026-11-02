#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$PWD"
NATIVE="$ROOT/tools/native"
CMAKE="$ROOT/tools/cmake/cmake/data/bin/cmake"
chmod +x "$CMAKE"
"$CMAKE" -S tools/libdispatch -B tools/libdispatch-build -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$NATIVE" -DBUILD_TESTING=OFF -DENABLE_SWIFT=OFF
"$CMAKE" --build tools/libdispatch-build -j 6
"$CMAKE" --install tools/libdispatch-build
cd tools/cctools-current/cctools
CC=clang CXX=clang++ bash configure --prefix="$NATIVE" --target=aarch64-apple-darwin --with-libtapi="$ROOT/tools/linux/iphone" --with-libdispatch="$NATIVE" --with-libblocksruntime="$NATIVE" --disable-lto-support
make -j 6
make install
