"""Exercise the 5.0.8 pool cleanup and Charming terminal frame used during a seek."""
import struct
import sys
import zipfile
from pathlib import Path

if len(sys.argv) > 2:
    sys.path.insert(0, str(Path(sys.argv[2]).resolve()))
from unicorn import Uc, UC_ARCH_ARM64, UC_MODE_ARM, UC_HOOK_CODE
from unicorn.arm64_const import (UC_ARM64_REG_PC, UC_ARM64_REG_SP, UC_ARM64_REG_LR,
                                 UC_ARM64_REG_X0, UC_ARM64_REG_W0, UC_ARM64_REG_W1,
                                 UC_ARM64_REG_S0)

with zipfile.ZipFile(sys.argv[1]) as ipa:
    image = ipa.read('Payload/Deemo.app/Frameworks/UnityFramework.framework/UnityFramework')
u = Uc(UC_ARCH_ARM64, UC_MODE_ARM)
for page in (0xa3000, 0x80000):
    u.mem_map(page, 4096)
    u.mem_write(page, image[page:page + 4096])
for page in (0x3741000, 0x385c000, 0x1836000, 0x1833000):
    u.mem_map(page, 4096)
heap = 0x5000000
u.mem_map(heap, 0x8000)
end = heap + 0x7000

def write(address, fmt, *values):
    u.mem_write(address, struct.pack('<' + fmt, *values))

def run(entry, owner):
    u.reg_write(UC_ARM64_REG_SP, end - 16)
    u.reg_write(UC_ARM64_REG_LR, end)
    u.reg_write(UC_ARM64_REG_X0, owner)
    u.emu_start(entry, end, count=1000)
    assert u.reg_read(UC_ARM64_REG_PC) == end
    return u.reg_read(UC_ARM64_REG_W0)

pool, items, array = heap, heap + 0x100, heap + 0x200
objects = [heap + 0x300 + i * 0x80 for i in range(3)]
klass, interface, table, set_active = [heap + i * 0x1000 for i in range(1, 5)]
iterator, sprite = heap + 0x5000, heap + 0x5100
write(0x3741d03, 'B', 1)
write(0x3741b54, 'B', 1)
write(0x385c760, 'Q', interface)
write(pool + 0x10, 'Q', items)
write(items + 0x10, 'Qi', array, len(objects))
write(array + 0x20, 'QQQ', *objects)
for obj in objects:
    write(obj, 'Q', klass)
write(klass + 0x126, 'H', 1)
write(klass + 0xb0, 'Q', table)
write(table, 'Qi', interface, 0)
write(klass + 0x130, 'QQ', set_active, 0)
for function in (set_active, 0x183662c, 0x1833b2c):
    write(function, 'I', 0xd65f03c0)  # ret
hidden = []
colors = []

def observe(emu, address, size, _):
    if address == set_active:
        assert emu.reg_read(UC_ARM64_REG_W1) == 0
        hidden.append(emu.reg_read(UC_ARM64_REG_X0))
    elif address == 0x183662c:
        emu.reg_write(UC_ARM64_REG_S0, 0)  # paused at loop boundary
    elif address == 0x1833b2c:
        assert emu.reg_read(UC_ARM64_REG_X0) == sprite
        colors.append(tuple(struct.unpack('<f', struct.pack('<I', emu.reg_read(UC_ARM64_REG_S0+i)))[0]
                            for i in range(4)))

u.hook_add(UC_HOOK_CODE, observe)
for _ in range(8):
    hidden.clear()
    run(0xa3a6c, pool)
    assert hidden == objects
    write(iterator + 0x10, 'i', 2)
    write(iterator + 0x28, 'ffQffff', .125, .125, sprite, 1., .75, .25, .9)
    assert run(0x801a0, iterator) == 0
    assert colors[-1] == (1., .75, .25, 0.)
assert len(colors) == 8
print('PASS: eight resets hid all pooled objects and ended the native Charming animation at zero alpha, including while paused.')
