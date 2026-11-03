"""Shared DEB and Mach-O verification helpers, adapted from local ShadeBar tooling."""
import gzip,hashlib,io,struct,tarfile

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
