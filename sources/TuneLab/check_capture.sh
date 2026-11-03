#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build verification
g++ -std=c++17 -O2 -Wall -Wextra -Werror tests/CaptureTests.cpp -o build/CaptureTests
./build/CaptureTests > verification/capture_tests.json
cat verification/capture_tests.json
