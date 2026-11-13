"""Run the original 5.0.8 position iterator. Only the three renderer interfaces
are test doubles. Verify visibility and real local-position output on reversals."""
import struct, sys, zipfile
from pathlib import Path
if len(sys.argv)>2: sys.path.insert(0,str(Path(sys.argv[2]).resolve()))
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import *
with zipfile.ZipFile(sys.argv[1]) as ipa:
    image=ipa.read('Payload/Deemo.app/Frameworks/UnityFramework.framework/UnityFramework')
u=Uc(UC_ARCH_ARM64,UC_MODE_ARM)
def pack(addr,fmt,*values): u.mem_write(addr,struct.pack('<'+fmt,*values))
for page in {addr & ~4095 for addr in (0xcca14,0x181468c,0x1829928,0x1814c0c,0x2b70378)}:
    u.mem_map(page,4096); u.mem_write(page,image[page:page+4096])
for page in (0x3741000,0x385c000,0x385d000,0x3863000,0x3865000):
    u.mem_map(page,4096)
heap=0x5000000
u.mem_map(heap,0x18000)
it,note,params,klass,statics=[heap+4096*i for i in range(5)]
pack(0x3741f08,'B',1)
for ptr in (0x3865490,0x3863938): pack(ptr,'Q',klass)
pack(klass+0xb8,'Q',statics);pack(statics,'ff',.25,.10)
pack(it+0x20,'Q',note);pack(note+0x18,'Q',params)
pack(note+0x68,'f',30.);pack(note+0x70,'f',1.3);pack(params+0x14,'f',10.)
callbacks={}
for i,(interface,offset,slot,action) in enumerate(((0x385cca8,0x58,1,'enabled'),(0x385d060,0x48,3,'position'),(0x385cf90,0x50,1,'color'))):
    obj=heap+(5+i)*4096
    cls=obj+0x100;table=obj+0x500;iface=obj+0x600;callback=obj+0x700
    pack(note+offset,'Q',obj);pack(obj,'Q',cls);pack(interface,'Q',iface)
    pack(cls+0x126,'H',1);pack(cls+0xb0,'Q',table);pack(table,'Qi',iface,0)
    pack(cls+0x130+16*slot,'QQ',callback,0);pack(callback,'I',0xd65f03c0)
    callbacks[callback]=action
writes={}
def intercept(emu,address,size,data):
    action=callbacks.get(address)
    if action=='enabled':writes[action]=u.reg_read(UC_ARM64_REG_W1)
    elif action:
        widths=3 if action=='position' else 4
        writes[action]=tuple(struct.unpack('<f',struct.pack('<I',u.reg_read(UC_ARM64_REG_S0+j)))[0] for j in range(widths))
u.hook_add(UC_HOOK_CODE,intercept)
def step():
    end=heap+0x14000
    u.reg_write(UC_ARM64_REG_X0,it);u.reg_write(UC_ARM64_REG_SP,end-16);u.reg_write(UC_ARM64_REG_X30,end)
    u.emu_start(0xcca14,end,count=700)
    assert u.reg_read(UC_ARM64_REG_PC)==end and u.reg_read(UC_ARM64_REG_W0)==1
step()
assert writes=={'enabled':1}
for t in (29.,29.25,29.75,29.5,28.5,30.):
    pack(params+0x10,'f',t);pack(it+0x2c,'f',1)
    writes.clear();step()
    x,y,z=writes['position'];alpha=writes['color'][3]
    assert abs(z-(30-t)*10)<1e-5 and abs(x-1.3)<1e-5 and y==0 and alpha>.1,(t,writes)
print('PASS: native DEEMO iterator enabled the sprite, then emitted six visible positions in both directions (Z 10, 7.5, 2.5, 5, 15, 0).')
