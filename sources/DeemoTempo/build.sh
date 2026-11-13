#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
tools="${DEEMO_TOOLROOT:?Set DEEMO_TOOLROOT to the ShadeBar iOS cross-toolchain directory}"
sdk="$tools/sdks/iPhoneOS16.5.sdk"
llvm="$tools/llvm23/usr"
export LD_LIBRARY_PATH="$llvm/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p build
c++ -std=c++17 -include initializer_list -Wall -Werror tests/tempo.cpp -o build/test-tempo
build/test-tempo
"$llvm/lib/llvm-23/bin/clang" -target arm64-apple-ios16.0 -isysroot "$sdk" -std=c++17 -include initializer_list -Os -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations -c src/Adapter.mm -o build/Adapter.o
"$tools/native/bin/aarch64-apple-darwin-ld" -arch arm64 -dylib -syslibroot "$sdk" -platform_version ios 16.0 16.5 -install_name @rpath/DeemoTempo.dylib -o build/DeemoTempo.dylib build/Adapter.o -lc++ -lSystem -lobjc -framework UIKit -framework Foundation -framework QuartzCore -adhoc_codesign
"$tools/linux/iphone/bin/ldid" -S -Cadhoc build/DeemoTempo.dylib
