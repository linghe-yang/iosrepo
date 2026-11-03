#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TOOLS="${TUNELAB_TOOLROOT:-$(realpath ../../../shadebar/tools)}"
LLVM="$TOOLS/llvm23/usr"
export LD_LIBRARY_PATH="$LLVM/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
mkdir -p build
"$LLVM/lib/llvm-23/bin/clang" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -fobjc-arc -fblocks -fno-modules -Wall -Wextra -Werror -c src/TLOriginalLayout.m -o build/TLOriginalLayout.o
printf 'Original layout renderer compiles for iOS 16 ARM64. Pixel and behavior parity remain unverified.\n'
