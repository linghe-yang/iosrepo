#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
SDK="$PWD/tools/sdks/iPhoneOS16.5.sdk"
LLVM="$PWD/tools/llvm23/usr"
export LD_LIBRARY_PATH="$LLVM/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
CLANG="$LLVM/lib/llvm-23/bin/clang"
LINK="$PWD/tools/native/bin/aarch64-apple-darwin-ld"
SIGN="$PWD/tools/linux/iphone/bin/ldid"
COMMON=(-isysroot "$SDK" -Os -g -gdwarf-4 -fblocks -fno-modules -fvisibility=hidden -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-nullability-completeness)
"$CLANG" -target arm64e-apple-ios16.0 "${COMMON[@]}" -c src/Bootstrap.c -o build/Bootstrap.o
"$CLANG" -target arm64e-apple-ios16.0 "${COMMON[@]}" -fobjc-arc -c src/ShadeBar.m -o build/ShadeRenderer.o
"$CLANG" -target arm64e-apple-ios16.0 "${COMMON[@]}" -c src/Geometry.c -o build/Geometry.o
"$CLANG" -target arm64-apple-ios16.0 "${COMMON[@]}" -fobjc-arc -c src/App.m -o build/App.o
"$CLANG" -target arm64-apple-ios16.0 "${COMMON[@]}" -fobjc-arc -c src/ProfileUI.m -o build/ProfileUI.o
LINKFLAGS=(-syslibroot "$SDK" -platform_version ios 16.0 16.5 -lSystem -adhoc_codesign)
"$LINK" -arch arm64e -dylib "${LINKFLAGS[@]}" -install_name @rpath/ShadeBootstrap.dylib -o build/ShadeBootstrap.dylib build/Bootstrap.o -framework CoreFoundation
"$LINK" -arch arm64e -dylib "${LINKFLAGS[@]}" -install_name @rpath/ShadeRenderer.dylib -o build/ShadeRenderer.dylib build/ShadeRenderer.o build/Geometry.o -lobjc -framework UIKit -framework Foundation -framework CoreFoundation -framework QuartzCore -framework CoreGraphics
"$LINK" -arch arm64 "${LINKFLAGS[@]}" -o build/ShadeBarApp build/App.o build/ProfileUI.o -lobjc -framework UIKit -framework Foundation -framework CoreFoundation -framework QuartzCore
"$SIGN" -S -Cadhoc build/ShadeBootstrap.dylib
"$SIGN" -S -Cadhoc build/ShadeRenderer.dylib
"$SIGN" -Sresources/App.entitlements -Cadhoc build/ShadeBarApp
cc -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/test_geometry.c src/Geometry.c -lm -o build/test_geometry
build/test_geometry
printf 'Built native arm64e bootstrap/renderer and ARM64 desktop app; no ABI converter.\n'
