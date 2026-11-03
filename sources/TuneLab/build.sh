#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TOOLS="${TUNELAB_TOOLROOT:-$(realpath ../../../shadebar/tools)}"
SDK="$TOOLS/sdks/iPhoneOS16.5.sdk"
LLVM="$TOOLS/llvm23/usr"
export LD_LIBRARY_PATH="$LLVM/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CLANG="$LLVM/lib/llvm-23/bin/clang"
mkdir -p build verification
FLAGS=(-target arm64-apple-ios16.0 -isysroot "$SDK" -Os -ffp-contract=off -fblocks -fno-modules -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations)
"$CLANG" "${FLAGS[@]}" -c native/OriginalDSP.s -o build/OriginalDSP.o
"$CLANG" "${FLAGS[@]}" -std=c++17 -c native/Platform.cpp -o build/NativePlatform.o
for source in native/InvokeOriginal.mm src/TLOriginalRuntime.mm src/TLOriginalAudio.mm src/TLSpectrum.mm src/App.mm; do
    "$CLANG" "${FLAGS[@]}" -std=c++17 -fobjc-arc -c "$source" -o "build/$(basename "${source%.*}").o"
done
"$CLANG" "${FLAGS[@]}" -fobjc-arc -c src/TLOriginalLayout.m -o build/TLOriginalLayout.o
"$TOOLS/native/bin/aarch64-apple-darwin-ld" -arch arm64 -syslibroot "$SDK" -platform_version ios 16.0 16.5 -lSystem -lc++ -lobjc -adhoc_codesign -o build/TuneLab build/App.o build/TLOriginalLayout.o build/TLSpectrum.o build/TLOriginalAudio.o build/TLOriginalRuntime.o build/InvokeOriginal.o build/OriginalDSP.o build/NativePlatform.o -framework UIKit -framework Foundation -framework CoreGraphics -framework AVFoundation -framework AudioToolbox -framework UniformTypeIdentifiers -framework WebKit -framework QuartzCore
"$TOOLS/linux/iphone/bin/ldid" -Sresources/App.entitlements -Cadhoc build/TuneLab
printf 'Built and signed standalone ARM64 iOS 16 TuneLab application.\n'
