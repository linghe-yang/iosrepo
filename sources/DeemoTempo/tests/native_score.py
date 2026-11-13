"""Run the UUID-matched game's original score accumulator on a real chart in Unicorn.
Supply the IPA, a Python dependency directory containing unicorn, and one with UnityPy.
"""
import json, struct, sys, zipfile
from pathlib import Path
sys.path[:0]=[str(Path(x).resolve()) for x in sys.argv[2:]]
import UnityPy
from unicorn import Uc,UC_ARCH_ARM64,UC_MODE_ARM
from unicorn.arm64_const import UC_ARM64_REG_X0,UC_ARM64_REG_X30,UC_ARM64_REG_S0,UC_ARM64_REG_SP
with zipfile.ZipFile(sys.argv[1]) as z:
    binary=z.read('Payload/Deemo.app/Frameworks/UnityFramework.framework/UnityFramework')
    asset=next(n for n in z.namelist() if n.endswith('/songdata_12thchance.ab'))
    env=UnityPy.load(z.read(asset))
    chart=next(o.read() for o in env.objects if o.type.name=='TextAsset' and '.hard.' in o.read().m_Name)
notes=json.loads(chart.m_Script)['notes']
times=[n['_time']+n.get('shift',0) for n in notes if -2<=n.get('pos',0)<=2]
emu=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
for page in (0xb0000,0xb1000,0x2b70000,0x1a96000):
    emu.mem_map(page,4096);emu.mem_write(page,binary[page:page+4096])
result=0x4000000;end=0x4100000
emu.mem_map(result,4096)
for page in (0x3741000,0x3863000): emu.mem_map(page,4096)
emu.mem_write(0x3741d7f,b'\x01')
emu.mem_write(0x3863928,struct.pack('<Q',result+0x200))
emu.reg_write(UC_ARM64_REG_SP,result+0xff0)
def run(fn):
    emu.reg_write(UC_ARM64_REG_X0,result);emu.reg_write(UC_ARM64_REG_X30,end)
    emu.emu_start(fn,end,count=128)
    return emu.reg_read(UC_ARM64_REG_X0)
def reset():
    emu.mem_write(result+0x1c,struct.pack('<i',len(times)));run(0xb11d4)
def judge(v):
    emu.reg_write(UC_ARM64_REG_S0,struct.unpack('<I',struct.pack('<f',v))[0]);run(0xb12d4)
def snapshot(): return bytes(emu.mem_read(result+0x10,0x40))
# Use real hit timestamps on both sides of a note and simultaneous chords.
events=sorted([(t+(i%3-1)*.03,i,(1.,.8,0.,1.)[i%4]) for i,t in enumerate(times)])
origin,target=80.,50.
reset()
for t,i,v in events:
    if t<=target:judge(v)
expected=snapshot()
for t,i,v in events:
    if target<t<=origin:judge(v)
assert snapshot()!=expected
reset()
kept=[(t,i,v) for t,i,v in events if t<=target]
for t,i,v in kept:judge(v)
assert snapshot()==expected
done={i for t,i,v in kept}
missed=[i for i,t in enumerate(times) if i not in done and t<origin]
old_misses=struct.unpack_from('<i',expected,0x3c-0x10)[0]
for i in missed:judge(0.)
count=struct.unpack('<i',emu.mem_read(result+0x20,4))[0]
miss=struct.unpack('<i',emu.mem_read(result+0x3c,4))[0]
combo=struct.unpack('<i',emu.mem_read(result+0x18,4))[0]
assert count==len(done)+len(missed) and miss==old_misses+len(missed) and combo==0
print(f'PASS: native DEEMO result bytes restored at 50s; 50->80s generated {len(missed)} misses once; combo {combo}.')

# The same native queries used by the results screen on an untouched perfect run
# and after replacing that run with one miss for each playable note.
reset()
for _ in times: judge(1.)
assert (run(0xb0f78),run(0xb10a8),run(0xb10bc))==(1_000_000,1,1)
reset()
for _ in times: judge(0.)
assert (run(0xb0f78),run(0xb10a8),run(0xb10bc))==(0,0,0)
assert struct.unpack_from('<5i',snapshot())==(0,0,0,len(times),len(times))
assert run(0xb12cc)==len(times)
print(f'PASS: {len(times)} perfect hits score 1000000 with AC/FC; practice settlement scores 0, AC/FC false, {len(times)} misses.')
