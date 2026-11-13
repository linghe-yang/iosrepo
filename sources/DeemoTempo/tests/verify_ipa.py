"""Check the exact application build and adapter instructions against a user-provided IPA."""
import re,struct,sys,uuid,zipfile,plistlib
from pathlib import Path
root=Path(__file__).resolve().parents[1]
with zipfile.ZipFile(sys.argv[1]) as z:
    p=plistlib.loads(z.read('Payload/Deemo.app/Info.plist'))
    assert (p['CFBundleIdentifier'],p['CFBundleShortVersionString'],p['CFBundleVersion'])==('com.rayark.pluto','5.0.8','1001405')
    b=z.read('Payload/Deemo.app/Frameworks/UnityFramework.framework/UnityFramework')
h=(root/'src/Deemo508.hpp').read_text(encoding='utf-8-sig')
commands=32
for _ in range(struct.unpack_from('<I',b,16)[0]):
    cmd,length=struct.unpack_from('<II',b,commands)
    if cmd==0x1b: image_uuid=b[commands+8:commands+24]
    commands+=length
assert image_uuid==bytes.fromhex('37b8f14dccfd33588c31cbe88ff67b2a')
entries=re.findall(r'(\w+)\{(0x[0-9a-f]+),(0x[0-9a-f]+)\}',h)
assert len(entries)>20
for name,offset,word in entries:
    assert struct.unpack_from('<I',b,int(offset,16))[0]==int(word,16),name
# Confirm all the gameplay paths whose timing the adapter depends upon.
edges={0xa6968:0xa58cc,0xa672c:0xa58cc,0xa5918:0x180f06c,0xa5b4c:0x180ef00,
       0xa5c1c:0x180eddc,0xa6a70:0x183662c,0xa6b38:0x183662c,0xa6b0c:0x180ed9c,
       0x14e31c:0x18365c4,0x14e344:0x18365c4,0x14e3b4:0x14d534,
       0xb84ac:0xb12d4,0xcb6a0:0xcb6c4,0xcc904:0xcb6c4,0xd18c0:0xd14e4,
       0xa5d20:0xb11d4,0xa4f28:0xf2358,0xd0ce4:0xd0e40,0xb8538:0xb0f78,
       0x202fccC:0x28557d8,0x2023898:0x2035388,0x20231a0:0x27f8ccc}
for address,target in edges.items():
    word=struct.unpack_from('<I',b,address)[0]
    assert word>>26==0x25 and address+(((word&0x3ffffff)^0x2000000)-0x2000000)*4==target
assert struct.unpack_from('<I',b,0x2ef5c10)[0]==11
print(f'PASS: {p["CFBundleShortVersionString"]} ({p["CFBundleVersion"]}), {uuid.UUID(bytes=image_uuid)}, {len(entries)} ABI entries and {len(edges)} branch targets')
