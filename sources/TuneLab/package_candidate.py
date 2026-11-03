"""Build an honest installable alpha; this does not satisfy the complete-port release gate.

Use --activate to replace the obsolete prototype in the LOCAL repository index.
No Git commit, push, Pages publication, or device installation is performed.
"""
import argparse,hashlib,io,json,math,plistlib,struct,subprocess,sys,tarfile
from pathlib import Path
from packaging_helpers import signature_check,archive
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[1]

def members(data):
    assert data[:8]==b'!<arch>\n'
    offset=8
    while offset<len(data):
        header=data[offset:offset+60];assert header[58:60]==b'`\n'
        name=header[:16].strip().rstrip(b'/').decode();size=int(header[48:58])
        yield name,data[offset+60:offset+60+size]
        offset+=60+size+size%2
    assert offset==len(data)

def binary_check(data):
    report=signature_check(data,0,2)
    for name in ['UIKit','AVFoundation','WebKit']:
        assert any(name in path for path in report['dependencies']),name
    assert '__tlrom' in report['sections'] and '__tlram' in report['sections']
    offset=32;entry=None;minimum=None;entitlements=None
    for _ in range(struct.unpack_from('<I',data,16)[0]):
        cmd,size=struct.unpack_from('<II',data,offset)
        if cmd==0x80000028:entry=struct.unpack_from('<Q',data,offset+8)[0]
        if cmd==0x32:minimum=struct.unpack_from('<3I',data,offset+8)
        if cmd==0x1d:
            base,length=struct.unpack_from('<II',data,offset+8)
            for i in range(struct.unpack_from('>I',data,base+8)[0]):
                slot,relative=struct.unpack_from('>II',data,base+12+i*8)
                if slot==5:
                    start=base+relative;magic,n=struct.unpack_from('>II',data,start)
                    assert magic==0xfade7171
                    entitlements=plistlib.loads(data[start+8:start+n])
        offset+=size
    assert entry and entry<len(data)
    assert minimum and minimum[0]==2 and minimum[1]==0x100000
    assert entitlements==plistlib.loads((ROOT/'resources/App.entitlements').read_bytes())
    report.update(entry_offset=entry,minimum_ios='16.0',entitlements=entitlements)
    return report

def verify(path,version,package,arch,prefix,binary):
    sys.path.insert(0,str(REPO/'tools'))
    from update_repo import control,fields
    data=path.read_bytes();parts=dict(members(data));assert parts['debian-binary']==b'2.0\n'
    meta=fields(control(data));assert (meta['Package'],meta['Version'],meta['Architecture'])==(package,version,arch)
    with tarfile.open(fileobj=io.BytesIO(parts['data.tar.gz']),mode='r:gz') as tar:
        entries={m.name.removeprefix('./'):m for m in tar}
        base=prefix+'Applications/TuneLab.app/'
        assert tar.extractfile(entries[base+'TuneLab']).read()==binary
        assert entries[base+'TuneLab'].mode==0o755
        info=plistlib.loads(tar.extractfile(entries[base+'Info.plist']).read())
        assert info['CFBundleExecutable']=='TuneLab' and info['CFBundleDisplayName']=='Piano Tuner'
        assert info['NSMicrophoneUsageDescription'] and info['MinimumOSVersion']=='16.0'
        assert tar.extractfile(entries[base+'Icon.png']).read()==(ROOT/'resources/Icon.png').read_bytes()
        for name,item in entries.items():
            assert not name.startswith('/') and '..' not in Path(name).parts
            assert item.isdir() or item.isfile()
        payload_files=sum(m.isfile() for m in entries.values())
    with tarfile.open(fileobj=io.BytesIO(parts['control.tar.gz']),mode='r:gz') as tar:
        for name in ['postinst','prerm']:
            m=tar.getmember('./'+name);script=tar.extractfile(m).read()
            assert m.mode==0o755 and script.startswith(b'#!/bin/sh\n') and b'\r' not in script
    return {'path':path.relative_to(REPO).as_posix(),'package':package,'architecture':arch,
            'version':version,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
            'payload_files':payload_files,'payload_and_scripts_verified':True}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--activate',action='store_true');args=parser.parse_args()
    version=json.loads((ROOT/'version.json').read_text(encoding='utf8'))['version']
    assert '~alpha' in version,'Only clearly labelled development candidates are built here.'
    binary=(ROOT/'build/TuneLab').read_bytes();check=binary_check(binary)
    info=plistlib.loads((ROOT/'resources/Info.plist').read_bytes());assert info['CFBundleShortVersionString']=='0.2.0' and info['CFBundleVersion']=='2'
    reports=[]
    for arch,prefix,package,label in [('iphoneos-arm64','var/jb/','com.linghe.pianolab','Rootless'),('iphoneos-arm','','com.linghe.pianolab.rootful','Rootful')]:
        base='./'+prefix+'Applications/TuneLab.app/'
        files={base+'TuneLab':(binary,0o755)}
        for path in sorted((ROOT/'resources').rglob('*')):
            if path.is_file() and path.name!='App.entitlements':files[base+path.relative_to(ROOT/'resources').as_posix()]=(path.read_bytes(),0o644)
        opposite='com.linghe.pianolab.rootful' if prefix else 'com.linghe.pianolab'
        text=f'''Package: {package}
Name: Piano Tuner (TuneLab, {label} Alpha)
Version: {version}
Architecture: {arch}
Description: Installable TuneLab 3.2 iOS port alpha with original ARM64 DSP. Complete UI and feature parity remains in progress; device testing pending.
Maintainer: Local Build
Author: Local Build
Section: Multimedia
Depends: firmware (>= 16.0), firmware (<< 17.0), uikittools
Conflicts: {opposite}
Icon: https://linghe-yang.github.io/iosrepo/sources/TuneLab/resources/Icon.png
Installed-Size: {math.ceil(sum(len(v[0]) for v in files.values())/1024)}
'''
        app='/'+prefix+'Applications/TuneLab.app';old='/'+prefix+'Applications/PianoLab.app'
        scripts={'./control':(text.encode(),0o644)}
        scripts['./postinst']=(f'''#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
    UICACHE="/{prefix}usr/bin/uicache"
    if [ ! -x "$UICACHE" ]; then UICACHE="$(command -v uicache || true)"; fi
    if [ -n "$UICACHE" ]; then
        "$UICACHE" -u {old} >/dev/null 2>&1 || true
        "$UICACHE" -p {app}
    fi
fi
exit 0
'''.encode(),0o755)
        scripts['./prerm']=(f'''#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "deconfigure" ]; then
    UICACHE="/{prefix}usr/bin/uicache"
    if [ ! -x "$UICACHE" ]; then UICACHE="$(command -v uicache || true)"; fi
    if [ -n "$UICACHE" ]; then "$UICACHE" -u {app} || true; fi
fi
exit 0
'''.encode(),0o755)
        out=bytearray(b'!<arch>\n')
        for name,data in [('debian-binary',b'2.0\n'),('control.tar.gz',archive(scripts)),('data.tar.gz',archive(files))]:
            out.extend(f'{name:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode());out.extend(data)
            if len(data)%2:out.extend(b'\n')
        path=REPO/'debs'/f'{package}_{version}_{arch}.deb';path.write_bytes(out)
        reports.append(verify(path,version,package,arch,prefix,binary))
    report={'version':version,'installable_candidate_built':True,'complete_original_port':False,'device_tested':False,
            'published_to_remote':False,'binary':check,'packages':reports,
            'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for directory in ['src','native'] for p in sorted((ROOT/directory).iterdir()) if p.is_file()}}
    (ROOT/'verification/installable_candidate.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    if args.activate:
        retired=REPO/'retired/PianoLab-0.1.0';retired.mkdir(parents=True,exist_ok=True)
        for name in ['com.linghe.pianolab_0.1.0~beta1_iphoneos-arm64.deb','com.linghe.pianolab.rootful_0.1.0~beta1_iphoneos-arm.deb']:
            old=REPO/'debs'/name;destination=retired/name
            assert old.resolve().is_relative_to((REPO/'debs').resolve()) and destination.resolve().is_relative_to(retired.resolve())
            if old.exists():
                if destination.exists():assert destination.read_bytes()==old.read_bytes();old.unlink()
                else:old.replace(destination)
        subprocess.run([sys.executable,str(REPO/'tools/update_repo.py')],check=True)
        subprocess.run([sys.executable,str(REPO/'tools/update_repo.py'),'--check'],check=True)
    print(json.dumps({'version':version,'complete_original_port':False,'packages':reports},indent=2))
if __name__=='__main__':main()
