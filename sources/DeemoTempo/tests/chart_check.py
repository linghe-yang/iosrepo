"""Validate source-time mapping against real 5.0.8 charts (UnityPy required).
No song data is written. Output is a host simulation, not measured device latency.
"""
import json, sys, zipfile
from pathlib import Path
if len(sys.argv)>2: sys.path.insert(0,str(Path(sys.argv[2]).resolve()))
import UnityPy
cases=('12thchance','mirrornight','yubikiri_genman')
rates=(.10,.1073,.125,.17,.251,.499,.5,.75,.9387,1,1.427,2)
notes=events=charts=0
with zipfile.ZipFile(sys.argv[1]) as ipa:
    for song in cases:
        file=next(n for n in ipa.namelist() if n.endswith('/songdata_'+song+'.ab'))
        env=UnityPy.load(ipa.read(file))
        clip=next(o.read() for o in env.objects if o.type.name=='AudioClip')
        for obj in env.objects:
            if obj.type.name!='TextAsset':continue
            rows=json.loads(obj.read().m_Script)['notes']
            charts+=1
            for row in rows:
                notes+=1
                time=row['_time']
                for rate in rates:
                    hit=time/rate
                    assert abs(round(hit*rate*clip.m_Frequency)/clip.m_Frequency-time)<=.51/clip.m_Frequency
                    for sound in row.get('sounds',[]):
                        wait=sound.get('w',0)
                        duration=sound.get('d',0)
                        assert abs((hit+wait/rate)*rate-(time+wait))<1e-6
                        assert abs(duration/rate*rate-duration)<1e-6
                events+=len(row.get('sounds',[]))
print(f'PASS: {charts} original charts, {notes} notes, {events} keysound events; {len(rates)} practice rates')
