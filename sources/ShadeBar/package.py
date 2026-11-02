"""Create a rootless package exclusively from our freshly built components."""
import gzip
import hashlib
import io
import json
import math
from pathlib import Path
import plistlib
import struct
import tarfile

ROOT=Path(__file__).resolve().parent
VERSION='0.1.0~beta1'

def signature_check(data):
    magic,cpu,subtype,kind,ncmds=struct.unpack_from('<5I',data)
    assert magic==0xfeedfacf and cpu==0x100000c and (subtype&0xffffff)==2
    assert kind==6  # MH_DYLIB
    position=32; signature=None; paths=[]
    for _ in range(ncmds):
        cmd,size=struct.unpack_from('<II',data,position)
        assert size>=8
        if cmd==0x1d: signature=struct.unpack_from('<II',data,position+8)
        if cmd==0xc:
            offset=struct.unpack_from('<I',data,position+8)[0]
            paths.append(data[position+offset:data.index(b'\0',position+offset,position+size)].decode())
        position+=size
    assert signature
    offset,size=signature
    magic,length,count=struct.unpack_from('>III',data,offset)
    assert magic==0xfade0cc0 and length<=size and offset+size<=len(data)
    verified=0
    for i in range(count):
        slot,relative=struct.unpack_from('>II',data,offset+12+i*8)
        base=offset+relative
        if struct.unpack_from('>I',data,base)[0]!=0xfade0c02: continue
        _,_,_,flags,hashes,_,special,pages,limit,hashsize,hashtype,_,exponent=struct.unpack_from('>9I4B',data,base)
        algorithm={1:'sha1',2:'sha256'}[hashtype]
        assert flags&2 and limit==offset
        for page in range(pages):
            start=page<<exponent
            digest=hashlib.new(algorithm,data[start:min(start+(1<<exponent),limit)]).digest()
            assert digest==data[base+hashes+page*hashsize:base+hashes+(page+1)*hashsize]
        verified+=pages
    assert verified
    assert all(p.startswith(('/usr/lib/','/System/Library/')) for p in paths)
    return {'architecture':'arm64e (allemande converted)','code_pages_verified':verified,'dependencies':paths,'sha256':hashlib.sha256(data).hexdigest()}

def archive(files):
    raw=io.BytesIO()
    with tarfile.open(fileobj=raw,mode='w',format=tarfile.USTAR_FORMAT) as tar:
        directories={'.'}
        for name in files:
            parts=name.split('/')
            for index in range(1,len(parts)): directories.add('/'.join(parts[:index]))
        for name in sorted(directories,key=lambda n:(n.count('/'),n)):
            item=tarfile.TarInfo(name); item.type=tarfile.DIRTYPE; item.mode=0o755; tar.addfile(item)
        for name,(content,mode) in sorted(files.items()):
            item=tarfile.TarInfo(name); item.mode=mode; item.size=len(content); tar.addfile(item,io.BytesIO(content))
    return gzip.compress(raw.getvalue(),mtime=0)

def main():
    dylib=(ROOT/'build/ShadeBar.dylib').read_bytes()
    prefs=(ROOT/'build/ShadePreferences').read_bytes()
    checks={'tweak':signature_check(dylib),'preferences':signature_check(prefs)}
    plist=lambda d:plistlib.dumps(d,sort_keys=True)
    base='./var/jb/Library/'
    files={
      base+'MobileSubstrate/DynamicLibraries/ShadeBar.dylib':(dylib,0o755),
      base+'MobileSubstrate/DynamicLibraries/ShadeBar.plist':(plist({'Filter':{'Bundles':['com.apple.springboard']}}),0o644),
      base+'PreferenceBundles/ShadePreferences.bundle/ShadePreferences':(prefs,0o755),
      base+'PreferenceBundles/ShadePreferences.bundle/Info.plist':(plist({'CFBundleExecutable':'ShadePreferences','CFBundleIdentifier':'com.linghe.shadebar.preferences','CFBundleName':'ShadeBar','CFBundlePackageType':'BNDL','CFBundleVersion':'1','CFBundleShortVersionString':'0.1.0','NSPrincipalClass':'ShadePreferencesController','MinimumOSVersion':'16.0'}),0o644),
      base+'PreferenceLoader/Preferences/ShadeBar.plist':(plist({'entry':{'bundle':'ShadePreferences','cell':'PSLinkCell','detail':'ShadePreferencesController','isController':True,'label':'ShadeBar'}}),0o644)
    }
    control=f'''Package: com.linghe.shadebar
Name: ShadeBar (Beta)
Version: {VERSION}
Architecture: iphoneos-arm64
Description: Adjustable screen cover with a foreground app allowlist. iOS 16 arm64e test build.
Maintainer: Local Build
Author: Local Build
Section: Tweaks
Depends: mobilesubstrate, preferenceloader, firmware (>= 16.0), firmware (<< 17.0)
Installed-Size: {math.ceil(sum(len(x[0]) for x in files.values())/1024)}
'''.encode()
    out=bytearray(b'!<arch>\n')
    for name,content in [('debian-binary',b'2.0\n'),('control.tar.gz',archive({'./control':(control,0o644)})),('data.tar.gz',archive(files))]:
        out.extend(f'{name:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(content):<10}`\n'.encode()); out.extend(content)
        if len(content)%2: out.extend(b'\n')
    path=ROOT/'packages'/f'com.linghe.shadebar_{VERSION}_iphoneos-arm64.deb'
    path.parent.mkdir(exist_ok=True); path.write_bytes(out)
    manifest={'package':path.name,'version':VERSION,'sha256':hashlib.sha256(out).hexdigest(),'bytes':len(out),'device_tested':False,'binaries':checks,'payloads':sorted(files),'sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((ROOT/'src').glob('*'))},'limits':['No physical-device execution or UIKit rendering verification.','Uses Theos-documented allemande ABI conversion; live arm64e compatibility remains unverified.','Focused foreground application only, not every visible split-screen app.','Foreground polling interval 0.2 seconds; lock screen intentionally hidden.']}
    (ROOT/'build/package_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('PASS: signed arm64e binaries, dependencies, rootless payload; built',path.name,len(out),'bytes')

if __name__=='__main__': main()
