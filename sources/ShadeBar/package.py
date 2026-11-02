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
VERSION='0.3.0~beta1'

def signature_check(data,expected_subtype=2,expected_kind=6):
    magic,cpu,subtype,kind,ncmds=struct.unpack_from('<5I',data)
    assert magic==0xfeedfacf and cpu==0x100000c and (subtype&0xffffff)==expected_subtype
    assert kind==expected_kind
    position=32; signature=None; paths=[]; sections=[]; uuid=None
    for _ in range(ncmds):
        cmd,size=struct.unpack_from('<II',data,position)
        assert size>=8
        if cmd==0x1d: signature=struct.unpack_from('<II',data,position+8)
        if cmd==0x1b: uuid=data[position+8:position+24].hex()
        if cmd==0x19:
            count=struct.unpack_from('<I',data,position+64)[0]
            for index in range(count):
                section=position+72+index*80
                sections.append(data[section:section+16].split(b'\0')[0].decode())
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
    assert uuid
    return {'architecture':'arm64e native' if expected_subtype==2 else 'arm64','cpu_subtype':hex(subtype),'uuid':uuid,'sections':sections,'code_pages_verified':verified,'dependencies':paths,'sha256':hashlib.sha256(data).hexdigest()}

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
    dylib=(ROOT/'build/ShadeBootstrap.dylib').read_bytes()
    renderer=(ROOT/'build/ShadeRenderer.dylib').read_bytes()
    app=(ROOT/'build/ShadeBarApp').read_bytes()
    checks={'bootstrap':signature_check(dylib),'renderer':signature_check(renderer),'app':signature_check(app,0,2)}
    assert not any(s.startswith('__objc') or s=='__cfstring' for s in checks['bootstrap']['sections'])
    assert not any('UIKit' in p or 'libobjc' in p for p in checks['bootstrap']['dependencies'])
    assert not any(s in checks['renderer']['sections'] for s in ('__mod_init_func','__init_offsets'))
    assert b'setHandler:\0' not in renderer, 'Old crashing orientation callback is still linked'
    assert checks['bootstrap']['cpu_subtype']=='0x80000002'
    assert checks['renderer']['cpu_subtype']=='0x80000002'
    plist=lambda d:plistlib.dumps(d,sort_keys=True)
    base='./var/jb/Library/'
    appbase='./var/jb/Applications/ShadeBar.app/'
    info={'CFBundleExecutable':'ShadeBarApp','CFBundleIdentifier':'com.linghe.shadebar.app','CFBundleName':'ShadeBar','CFBundleDisplayName':'ShadeBar','CFBundlePackageType':'APPL','CFBundleVersion':'3','CFBundleShortVersionString':'0.3.0','MinimumOSVersion':'16.0','LSRequiresIPhoneOS':True,'UIDeviceFamily':[1,2],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationPortraitUpsideDown','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UILaunchScreen':{},'CFBundleDevelopmentRegion':'en','CFBundleIcons':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon-120','Icon-180']}},'CFBundleIcons~ipad':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon-76','Icon-152','Icon-167']}}}
    files={
      base+'MobileSubstrate/DynamicLibraries/ShadeBootstrap.dylib':(dylib,0o755),
      base+'MobileSubstrate/DynamicLibraries/ShadeBootstrap.plist':(plist({'Filter':{'Bundles':['com.apple.springboard']}}),0o644),
      appbase+'ShadeBarApp':(app,0o755),
      appbase+'Info.plist':(plist(info),0o644),
      appbase+'Frameworks/ShadeRenderer.dylib':(renderer,0o755)
    }
    for icon in sorted((ROOT/'resources').glob('Icon-*.png')): files[appbase+icon.name]=(icon.read_bytes(),0o644)
    assert len([name for name in files if name.endswith('.png')])==6
    control=f'''Package: com.linghe.shadebar
Name: ShadeBar (Beta)
Version: {VERSION}
Architecture: iphoneos-arm64
Description: Per-app rectangular overlay: 1-120% size sliders, free dragging, centered reset. Manual start after respring.
Maintainer: Local Build
Author: Local Build
Section: Tweaks
Depends: mobilesubstrate, firmware (>= 16.0), firmware (<< 17.0)
Installed-Size: {math.ceil(sum(len(x[0]) for x in files.values())/1024)}
'''.encode()
    out=bytearray(b'!<arch>\n')
    scripts={'./control':(control,0o644)}
    for name in ('postinst','prerm'): scripts['./'+name]=((ROOT/'resources'/name).read_bytes().replace(b'\r\n',b'\n'),0o755)
    for name,content in [('debian-binary',b'2.0\n'),('control.tar.gz',archive(scripts)),('data.tar.gz',archive(files))]:
        out.extend(f'{name:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(content):<10}`\n'.encode()); out.extend(content)
        if len(content)%2: out.extend(b'\n')
    path=ROOT/'packages'/f'com.linghe.shadebar_{VERSION}_iphoneos-arm64.deb'
    path.parent.mkdir(exist_ok=True); path.write_bytes(out)
    manifest={'package':path.name,'version':VERSION,'sha256':hashlib.sha256(out).hexdigest(),'bytes':len(out),'device_tested':False,'binaries':checks,'payloads':sorted(files),'source_hash_format':'UTF-8, LF newlines, no BOM','sources':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_text(encoding='utf-8-sig').encode('utf-8')).hexdigest() for p in sorted((ROOT/'src').glob('*'))},'limits':['beta1 device crash confirmed in ShadeManager init -> FBSOrientationObserver setHandler: -> objc_msgSend. Callback registration removed.','Native Clang 23 + Apple ld64 956.6 arm64e build; no ABI converter. New build still needs physical-device validation.','Desktop app and manual renderer loading are separate. Overlay does not automatically start after respring.','Focused foreground application only; polling interval 0.2 seconds; lock screen and settings app hidden.','0.2.0 device feedback: desktop app opened but overlay was absent even without app filtering; exact device-side cause remains unconfirmed.','0.3.0 adds scene association, default window hosting, shared settings and display diagnostics; physical-device verification is still required.','Each app has an independent profile: 1-120 percent width/height, color/opacity, and separate portrait/landscape centers.','Dragging changes position only and may move the bar fully off screen; the app reset centers both orientations without changing size or appearance.']}
    (ROOT/'build/package_manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    print('PASS: signed arm64e binaries, dependencies, rootless payload; built',path.name,len(out),'bytes')

if __name__=='__main__': main()
