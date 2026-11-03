"""Generate simple keyboard icons using only the standard library."""
import math,struct,zlib
from pathlib import Path
ROOT=Path(__file__).resolve().parent/'resources'
for n in [76,120,152,167,180,1024]:
    rows=[]
    for y in range(n):
        row=bytearray()
        for x in range(n):
            a,b=x/n,y/n;c=(15,32,52)
            if .16<a<.84 and .24<b<.78:
                c=(230,242,246)
                if int((a-.16)/(.68/7)*100)%100<5:c=(50,70,85)
                if b<.56 and any(abs(a-(.16+i*.68/7))<.023 for i in [1,2,4,5,6]):c=(15,32,52)
            if .12<a<.88 and abs(b-(.16+.025*math.sin(a*30)))<.009:c=(41,211,181)
            row.extend(c)
        rows.append(b'\0'+row)
    def chunk(kind,data):return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data)&0xffffffff)
    png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',n,n,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(b''.join(rows),9))+chunk(b'IEND',b'')
    (ROOT/f'Icon-{n}.png').write_bytes(png)
