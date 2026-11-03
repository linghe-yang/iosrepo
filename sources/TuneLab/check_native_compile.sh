#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TOOLS="${TUNELAB_TOOLROOT:-$(realpath ../../../shadebar/tools)}"
LLVM="$TOOLS/llvm23/usr"
export LD_LIBRARY_PATH="$LLVM/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CLANG="$LLVM/lib/llvm-23/bin/clang"
mkdir -p build
"$CLANG" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -c native/OriginalDSP.s -o build/OriginalDSP.o
"$CLANG" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -std=c++17 -ffp-contract=off -c native/Platform.cpp -o build/NativePlatform.o
"$CLANG" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -std=c++17 -fobjc-arc -fblocks -fno-modules -c native/InvokeOriginal.mm -o build/InvokeOriginal.o
"$CLANG" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -std=c++17 -fobjc-arc -fblocks -fno-modules -c src/TLOriginalRuntime.mm -o build/TLOriginalRuntime.o
"$CLANG" -target arm64-apple-ios16.0 -isysroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -std=c++17 -fobjc-arc -fblocks -fno-modules -Wno-deprecated-declarations -c src/TLOriginalAudio.mm -o build/TLOriginalAudio.o
"$TOOLS/native/bin/aarch64-apple-darwin-ld" -arch arm64 -dylib -syslibroot "$TOOLS/sdks/iPhoneOS16.5.sdk" -platform_version ios 16.0 16.5 -lSystem -lc++ -adhoc_codesign -install_name @rpath/OriginalDSP.dylib -o build/OriginalDSP.dylib build/OriginalDSP.o build/NativePlatform.o
"$TOOLS/linux/iphone/bin/ldid" -S -Cadhoc build/OriginalDSP.dylib
printf 'Complete original DSP image statically linked and signed as ARM64 iOS 16 Mach-O.\n'
