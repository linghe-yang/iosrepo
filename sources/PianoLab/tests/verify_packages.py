"""Inspect actual DEB payload, registration scripts, privacy metadata and signed Mach-O."""
import hashlib,io,json,plistlib,struct,sys,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from packaging_helpers import signature_check
report=json.loads((ROOT/'verification/package_results.json').read_text())
checks=[]
for package in report['packages']:
    path=ROOT.parents[1]/'debs'/package['file'];data=path.read_bytes();assert data[:8]==b'!<arch>\n'
    assert hashlib.sha256(data).hexdigest()==package['sha256'];members={};offset=8
    while offset<len(data):
        header=data[offset:offset+60];assert header[58:60]==b'`\n';size=int(header[48:58]);members[header[:16].strip().decode().rstrip('/')]=data[offset+60:offset+60+size];offset+=60+size+size%2
    archives={}
    for kind in ['control','data']:
        with tarfile.open(fileobj=io.BytesIO(members[kind+'.tar.gz']),mode='r:gz') as tar:
            archives[kind]={m.name.removeprefix('./'):(tar.extractfile(m).read(),m.mode) for m in tar if m.isfile()}
    rootless=package['scheme']=='rootless';prefix='var/jb/' if rootless else '';base=prefix+'Applications/PianoLab.app/'
    assert all(name.startswith(base) for name in archives['data'])
    info=plistlib.loads(archives['data'][base+'Info.plist'][0]);assert info['NSMicrophoneUsageDescription'] and info['MinimumOSVersion']=='16.0' and info['UIDeviceFamily']==[1,2]
    executable,mode=archives['data'][base+info['CFBundleExecutable']];assert mode==0o755;binary=signature_check(executable,0,2)
    assert binary['sha256']==report['binary']['sha256']
    position=32;signature=None;minimum=None
    for _ in range(struct.unpack_from('<I',executable,16)[0]):
        cmd,size=struct.unpack_from('<II',executable,position)
        if cmd==0x32:minimum=struct.unpack_from('<II',executable,position+8)
        if cmd==0x1d:signature=struct.unpack_from('<II',executable,position+8)
        position+=size
    assert minimum==(2,16<<16)
    offset,size=signature;_,_,count=struct.unpack_from('>III',executable,offset);entitlements=None
    for i in range(count):
        slot,relative=struct.unpack_from('>II',executable,offset+12+i*8)
        if slot==5:
            magic,length=struct.unpack_from('>II',executable,offset+relative);assert magic==0xfade7171
            entitlements=plistlib.loads(executable[offset+relative+8:offset+relative+length])
    assert entitlements['platform-application'] and entitlements['com.apple.private.security.no-container']
    control=archives['control']['control'][0].decode();assert ('Architecture: '+('iphoneos-arm64' if rootless else 'iphoneos-arm')) in control
    for name in ['postinst','prerm']:
        script,mode=archives['control'][name];assert mode==0o755 and b'\r' not in script and ('/'+base.rstrip('/')).encode() in script
    assert sum(n.endswith('.tun') for n in archives['data'])==7
    assert sum(n.endswith('.tem') for n in archives['data'])==21
    checks.append({'file':path.name,'passed':True,'code_pages_verified':binary['code_pages_verified'],'preset_files':28,'entitlements_verified':True,'minimum_ios':'16.0'})
result={'passed':True,'packages':checks,'device_installed':False}
(ROOT/'verification/install_checks.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
