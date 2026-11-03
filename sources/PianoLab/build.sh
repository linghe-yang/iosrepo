#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
TOOLS="${PIANOLAB_TOOLROOT:-$(realpath ../../../shadebar/tools)}"
SDK="$TOOLS/sdks/iPhoneOS16.5.sdk"
LLVM="$TOOLS/llvm23/usr"
export LD_LIBRARY_PATH="$LLVM/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CLANG="$LLVM/lib/llvm-23/bin/clang"
LINK="$TOOLS/native/bin/aarch64-apple-darwin-ld"
SIGN="$TOOLS/linux/iphone/bin/ldid"
mkdir -p build verification
FLAGS=(-target arm64-apple-ios16.0 -isysroot "$SDK" -std=c++17 -Os -ffp-contract=off -fblocks -fno-modules -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations)
"$CLANG" "${FLAGS[@]}" -c src/TLCore.cpp -o build/TLCore.o
"$CLANG" "${FLAGS[@]}" -c src/TLLegacy.cpp -o build/TLLegacy.o
"$CLANG" "${FLAGS[@]}" -fobjc-arc -c src/TLAudio.mm -o build/TLAudio.o
"$CLANG" "${FLAGS[@]}" -fobjc-arc -c src/App.mm -o build/App.o
"$LINK" -arch arm64 -syslibroot "$SDK" -platform_version ios 16.0 16.5 -lSystem -lc++ -lobjc -adhoc_codesign -o build/PianoLab build/App.o build/TLAudio.o build/TLCore.o build/TLLegacy.o -framework UIKit -framework Foundation -framework CoreGraphics -framework AVFoundation -framework AudioToolbox -framework UniformTypeIdentifiers
"$SIGN" -Sresources/App.entitlements -Cadhoc build/PianoLab
printf 'Built signed ARM64 iOS 16 PianoLab executable.\n'
