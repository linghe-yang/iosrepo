import sys,hashlib,plistlib,os
from pathlib import Path
root=Path(__file__).resolve().parent
repo=root.parents[1]
sys.dont_write_bytecode=True
sys.path.insert(0,str(repo/'sources/PianoLab'))
from packaging_helpers import signature_check,archive
package='com.linghe.deemotempo'
version='0.2.0~beta1'
binary=(root/'build/DeemoTempo.dylib').read_bytes()
check=signature_check(binary,expected_subtype=0,expected_kind=6)
assert check['code_pages_verified']>0
base='./var/jb/Library/MobileSubstrate/DynamicLibraries/DeemoTempo'
payload={base+'.dylib':(binary,0o755),base+'.plist':(plistlib.dumps({'Filter':{'Bundles':['com.rayark.pluto']}}),0o644)}
control=f"""Package: {package}
Name: DEEMO Practice Tempo
Version: {version}
Architecture: iphoneos-arm64
Description: Pre-song practice tempo and pitch correction for DEEMO 5.0.8 (1001405).
Section: Tweaks
Author: Local Build
Maintainer: Local Build
Depends: mobilesubstrate, firmware (>= 16.0)
""".encode()
out=bytearray(b'!<arch>\n')
for name,data in [('debian-binary',b'2.0\n'),('control.tar.gz',archive({'./control':(control,0o644)})),('data.tar.gz',archive(payload))]:
    out.extend(f'{name:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode());out.extend(data)
    if len(data)%2:out.extend(b'\n')
path=repo/'debs'/f'{package}_{version}_iphoneos-arm64.deb'
temp=path.with_suffix('.deb.tmp')
temp.write_bytes(out);os.replace(temp,path)
print(f'{path.name}: {len(out)} bytes, SHA256 {hashlib.sha256(out).hexdigest()}')
