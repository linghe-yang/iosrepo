#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
SDK="$PWD/tools/sdks/iPhoneOS16.5.sdk"
BIN="$PWD/tools/linux/iphone/bin"
CLANG="$BIN/clang"
COMMON=(-target arm64e-apple-ios16.0 -isysroot "$SDK" -Os -fobjc-arc -fblocks -fno-modules -Wall -Wextra -Wno-unused-parameter -Wno-unused-variable -Wno-unused-function -Wno-deprecated-declarations -Wno-nullability-completeness -F"$SDK/System/Library/PrivateFrameworks")
"$CLANG" "${COMMON[@]}" -c src/ShadeBar.m -o build/ShadeBar.o
"$CLANG" "${COMMON[@]}" -c src/ShadePreferences.m -o build/ShadePreferences.o
"$CLANG" -target arm64e-apple-ios16.0 -isysroot "$SDK" -Os -c src/Geometry.c -o build/Geometry.o
"$CLANG" "${COMMON[@]}" -dynamiclib -Wl,-install_name,@rpath/ShadeBar.dylib -Wl,-no_uuid -o build/ShadeBar.dylib build/ShadeBar.o build/Geometry.o -framework UIKit -framework Foundation -framework CoreFoundation -framework QuartzCore -framework CoreGraphics
"$CLANG" "${COMMON[@]}" -dynamiclib -Wl,-install_name,@rpath/ShadePreferences.bundle/ShadePreferences -Wl,-no_uuid -o build/ShadePreferences build/ShadePreferences.o build/Geometry.o -framework UIKit -framework Foundation -framework CoreFoundation -framework Preferences
g++ -std=c++20 -w tools/allemande/main.cpp -o build/allemande
build/allemande build/ShadeBar.dylib > build/abi-tweak.log
build/allemande build/ShadePreferences > build/abi-preferences.log
"$BIN/ldid" -S -Cadhoc build/ShadeBar.dylib
"$BIN/ldid" -S -Cadhoc build/ShadePreferences
cc -std=c11 -Wall -Wextra -Werror -fsanitize=address,undefined tests/test_geometry.c src/Geometry.c -lm -o build/test_geometry
build/test_geometry
printf 'Compiled, converted and signed both arm64e components. Core tests passed.\n'
