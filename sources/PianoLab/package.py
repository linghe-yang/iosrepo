"""Package a freshly compiled standalone ARM64 app for rootless/rootful iOS 16."""
import gzip,hashlib,io,json,math,plistlib,struct,tarfile
from pathlib import Path
from packaging_helpers import signature_check,archive
ROOT=Path(__file__).resolve().parent
VERSION='0.1.0~beta1'
APPID='com.linghe.pianolab'

def main():
    app=(ROOT/'build/PianoLab').read_bytes();binary=signature_check(app,0,2)
    assert any('AVFoundation' in p for p in binary['dependencies'])
    assert b'NSMicrophoneUsageDescription' not in app # privacy string belongs in Info.plist
    info={'CFBundleExecutable':'PianoLab','CFBundleIdentifier':APPID,'CFBundleName':'PianoLab','CFBundleDisplayName':'PianoLab','CFBundlePackageType':'APPL','CFBundleVersion':'1','CFBundleShortVersionString':'0.1.0','MinimumOSVersion':'16.0','LSRequiresIPhoneOS':True,'UIDeviceFamily':[1,2],'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'],'UILaunchScreen':{},'NSMicrophoneUsageDescription':'PianoLab 使用麦克风测量钢琴音高与非谐性，并显示调律偏差。','UIFileSharingEnabled':True,'LSSupportsOpeningDocumentsInPlace':True,'CFBundleIcons':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon-120','Icon-180']}},'CFBundleIcons~ipad':{'CFBundlePrimaryIcon':{'CFBundleIconFiles':['Icon-152','Icon-167']}}}
    reports=[]
    for scheme,arch,prefix,package in [('rootless','iphoneos-arm64','var/jb/',APPID),('rootful','iphoneos-arm','',APPID+'.rootful')]:
        base='./'+prefix+'Applications/PianoLab.app/'
        files={base+'PianoLab':(app,0o755),base+'Info.plist':(plistlib.dumps(info),0o644)}
        for icon in (ROOT/'resources').glob('Icon-*.png'):files[base+icon.name]=(icon.read_bytes(),0o644)
        for resource in (ROOT/'resources/Presets').iterdir():
            if resource.suffix in ('.tun','.tem'):files[base+'Presets/'+resource.name]=(resource.read_bytes(),0o644)
        control=f'''Package: {package}
Name: PianoLab ({'Rootless' if scheme=='rootless' else 'Rootful'} Beta)
Version: {VERSION}
Architecture: {arch}
Description: Standalone piano tuner with inharmonicity, stretch curves, spectrum and overpull.
Maintainer: Local Build
Author: Local Build
Section: Multimedia
Depends: firmware (>= 16.0), firmware (<< 17.0)
Conflicts: {APPID+'.rootful' if scheme=='rootless' else APPID}
Installed-Size: {math.ceil(sum(len(v[0]) for v in files.values())/1024)}
'''.encode()
        path='/'+prefix+'Applications/PianoLab.app'
        scripts={'./control':(control,0o644)}
        for name,action in [('postinst','-p'),('prerm','-u')]:
            content=f'''#!/bin/sh
set -e
if [ "$1" = "{'configure' if name=='postinst' else 'remove'}" ]; then
    if [ -x /{prefix}usr/bin/uicache ]; then
        /{prefix}usr/bin/uicache {action} {path}
    elif command -v uicache >/dev/null 2>&1; then
        uicache {action} {path}
    fi
fi
exit 0
'''.encode();scripts['./'+name]=(content,0o755)
        out=bytearray(b'!<arch>\n')
        for name,data in [('debian-binary',b'2.0\n'),('control.tar.gz',archive(scripts)),('data.tar.gz',archive(files))]:
            out.extend(f'{name:<16}{0:<12}{0:<6}{0:<6}{"100644":<8}{len(data):<10}`\n'.encode());out.extend(data)
            if len(data)%2:out.extend(b'\n')
        target=ROOT.parents[1]/'debs'/f'{package}_{VERSION}_{arch}.deb';target.write_bytes(out)
        reports.append({'file':target.name,'scheme':scheme,'sha256':hashlib.sha256(out).hexdigest(),'bytes':len(out),'payload_files':len(files)})
    report={'version':VERSION,'device_tested':False,'binary':binary,'packages':reports,'core_tests':json.loads((ROOT/'verification/core_results.json').read_text()),'source_hash_format':'UTF-8, LF newlines, no BOM','source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_text(encoding='utf-8-sig').encode('utf8')).hexdigest() for p in sorted((ROOT/'src').iterdir())}}
    (ROOT/'verification/package_results.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(reports,indent=2))
if __name__=='__main__':main()
