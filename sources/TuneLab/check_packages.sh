#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
VERSION="$(python3 -c 'import json; print(json.load(open("version.json"))["version"])')"
PREVIOUS="$(python3 -c 'import json; print(json.load(open("version.json")).get("previous_installable_version","0.1.0~beta1"))')"
OUT="$(pwd)/build/package-check-$VERSION"
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
        DEB="../../debs/com.linghe.pianolab_${VERSION}_iphoneos-arm64.deb"
        PREFIX="var/jb/"
    else
        DEB="../../debs/com.linghe.pianolab.rootful_${VERSION}_iphoneos-arm.deb"
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
dpkg --compare-versions "$PREVIOUS" lt "$VERSION"
python3 - <<'PY'
import json,os
from pathlib import Path
actual=Path(os.environ['TL_PACKAGE_TEST_LOG']).read_text().splitlines()
expected=[]
for prefix in ['/var/jb','']:
    expected += [f'-u {prefix}/Applications/PianoLab.app',f'-p {prefix}/Applications/TuneLab.app',f'-u {prefix}/Applications/TuneLab.app']
assert actual==expected,(actual,expected)
candidate=json.loads(Path('verification/installable_candidate.json').read_text())
report={'passed':True,'version':candidate['version'],'actual_dpkg_deb_info_and_extract':True,'extracted_executable_and_icon_identical':True,'shell_syntax_passed':True,'maintainer_scripts_executed_with_mock_uicache':True,'uicache_calls':actual,'upgrade_version_order_passed':True,'device_installation_performed':False,'packages':candidate['packages']}
Path('verification/package_install_checks.json').write_text(json.dumps(report,indent=2))
print('PASS: dpkg parsed and extracted both DEBs; executable/icon contents match; install/remove scripts and upgrade version ordering passed. Device installation not performed.')
PY
