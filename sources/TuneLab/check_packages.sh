#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
OUT="$(pwd)/build/package-check"
mkdir -p "$OUT/bin"
cat > "$OUT/bin/uicache" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$TL_PACKAGE_TEST_LOG"
SH
chmod +x "$OUT/bin/uicache"
export PATH="$OUT/bin:$PATH"
export TL_PACKAGE_TEST_LOG="$OUT/uicache.log"
: > "$TL_PACKAGE_TEST_LOG"
for mode in rootless rootful; do
    if [ "$mode" = rootless ]; then
        DEB="../../debs/com.linghe.pianolab_0.2.0~alpha1_iphoneos-arm64.deb"
        PREFIX="var/jb/"
    else
        DEB="../../debs/com.linghe.pianolab.rootful_0.2.0~alpha1_iphoneos-arm.deb"
        PREFIX=""
    fi
    dpkg-deb --info "$DEB"
    dpkg-deb --extract "$DEB" "$OUT/$mode"
    dpkg-deb --control "$DEB" "$OUT/$mode-control"
    cmp build/TuneLab "$OUT/$mode/${PREFIX}Applications/TuneLab.app/TuneLab"
    cmp resources/Icon.png "$OUT/$mode/${PREFIX}Applications/TuneLab.app/Icon.png"
    sh -n "$OUT/$mode-control/postinst"
    sh -n "$OUT/$mode-control/prerm"
    sh "$OUT/$mode-control/postinst" configure
    sh "$OUT/$mode-control/prerm" remove
done
dpkg --compare-versions '0.1.0~beta1' lt '0.2.0~alpha1'
python3 - <<'PY'
from pathlib import Path
actual=Path('build/package-check/uicache.log').read_text().splitlines()
expected=[]
for prefix in ['/var/jb','']:
    expected += [f'-u {prefix}/Applications/PianoLab.app',f'-p {prefix}/Applications/TuneLab.app',f'-u {prefix}/Applications/TuneLab.app']
assert actual==expected,(actual,expected)
print('PASS: dpkg parsed and extracted both DEBs; executable/icon contents match; install/remove scripts and upgrade version ordering passed. Device installation not performed.')
PY
