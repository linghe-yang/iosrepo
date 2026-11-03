"""Linux host C++ core vs frozen original Android numerical results."""
import ctypes as C,json,math,struct,subprocess,wave
import random
from pathlib import Path
BASE=Path(__file__).resolve().parents[1]
VECTORS=BASE/'tests/vectors'
build=BASE/'build';build.mkdir(exist_ok=True)
subprocess.run(['g++','-std=c++17','-O2','-ffp-contract=off','-fPIC','-shared',str(BASE/'src/TLCore.cpp'),str(BASE/'src/TLLegacy.cpp'),str(BASE/'tests/bridge.cpp'),'-o',str(build/'core.so')],check=True)
lib=C.CDLL(str(build/'core.so'));F=C.c_float;I=C.c_int;S=C.c_int16
lib.pl_resample.argtypes=[C.POINTER(F),I,C.c_double,I,C.POINTER(S)]
lib.pl_pitch.argtypes=[C.POINTER(S),I,C.c_double,C.POINTER(F)]
def floats(xs):return (F*len(xs))(*xs)
def ints(xs):return (I*len(xs))(*xs)
def read(name):return json.loads((VECTORS/name).read_text())
audio=[];max_ih=0.;max_fields=[0.]*5
for case in read('measurement_vectors.json')['pcm']:
    name=case['input']['name']
    with wave.open(str(VECTORS/'audio'/f'{name}.wav'),'rb') as w:pcm=struct.unpack('<'+'h'*w.getnframes(),w.readframes(w.getnframes()))
    out=(F*85)();assert lib.pl_analyze((S*len(pcm))(*pcm),len(pcm),case['input']['note'],out)==0
    err=abs(out[0]-case['native_ih']);max_ih=max(max_ih,err);assert err<.0002
    for j,p in enumerate(case['partials']):
        assert out[1+j*7+5]==p['valid'] and out[1+j*7+6]==p['failure_code']
        for k,key in enumerate(['fft_bin','offset','relative_amplitude','snr_ratio','width_cents']):
            a,b=out[1+j*7+k],float(p[key]);d=abs(a-b) if math.isfinite(a) and math.isfinite(b) else (0 if math.isnan(a) and math.isnan(b) or a==b else math.inf)
            max_fields[k]=max(max_fields[k],d);assert d<[.002,.001,.001,.05,.001][k],(name,j,key,a,b)
    audio.append({'name':name,'ih_difference':err})
model_cases=0;max_stretch=0.
for model in read('model_vectors.json'):
    values=[0.]*88;counts=[0]*88
    for n,h in model['input']['measurements'].items():values[int(n)]=h;counts[int(n)]=1
    for case in model['cases']:
        out=(F*264)();assert lib.pl_model(floats(values),ints(counts),*case['interval_indices'],case['middle_start'],int(case['modern']),out)==0
        assert max(abs(out[n]-model['native_ih_88'][n]) for n in range(88))<.0001
        error=max(abs(out[176+n]-case['native_stretch_p6_below_A4_p1_above'][n]) for n in range(88));max_stretch=max(max_stretch,error);assert error<.01;model_cases+=1
max_op=0.
for case in read('overpull_vectors.json'):
    p=case['parameters'];parms=[p['bass_break'],p['wound_break'],*p['struts'],p['factor_step'],p['ignore_struts']];out=(F*88)()
    assert lib.pl_overpull(floats(case['offsets']),ints(case['present']),ints(parms),out)==0
    error=max(abs(a-b) for a,b in zip(out,case['original_smali_output_cents']));max_op=max(max_op,error);assert error<1e-5
# Live tuning estimator must recover signed cents across bass partials and treble.
pitch_cases=[]
for target in [165.,440.,1000.,4186.]:
    for cents in [-30.,0.,30.]:
        hz=target*2**(cents/1200);pcm=[round(6000*math.sin(2*math.pi*hz*i/22050)) for i in range(16384)];out=(F*3)()
        assert lib.pl_pitch((S*len(pcm))(*pcm),len(pcm),C.c_double(target),out)==0
        assert out[0] and abs(out[2]-cents)<.02,(target,cents,list(out));pitch_cases.append({'target':target,'cents':cents,'error_cents':abs(out[2]-cents)})
resampling=[]
for rate in [44100.,48000.,96000.]:
    n=int(rate);samples=floats([.2*math.sin(2*math.pi*440*i/rate) for i in range(n)]);a=(S*22052)();b=(S*22052)()
    na=lib.pl_resample(samples,n,rate,1024,a);nb=lib.pl_resample(samples,n,rate,317,b);assert na==nb and list(a[:na])==list(b[:nb]) and abs(na-22050)<=1
    out=(F*3)();tail=(S*16384)(*a[na-16384:na]);lib.pl_pitch(tail,16384,440.,out);assert out[0] and abs(out[2])<.02
    resampling.append({'input_rate':rate,'output_samples':na,'cents_error':out[2],'chunk_invariant':True})
legacy_cases=[]
for case in read('legacy_vectors.json'):
    values=[0.]*88;counts=[0]*88
    for n,h in case['measurements'].items():values[int(n)]=h;counts[int(n)]=1
    out=(F*92)();assert lib.pl_legacy(floats(values),ints(counts),int(case['modern_beta']),case['actual_split'],out)==0
    error=max(abs(a-b) for a,b in zip(out[4:],case['auto_model_cents']));assert error<.01,(case['profile'],error,list(out[:4]),case['auto_parameters'])
    legacy_cases.append({'profile':case['profile'],'modern':case['modern_beta'],'split':case['actual_split'],'max_curve_error_cents':error})
rng=random.Random(1601);out=(F*3)();noise=(S*16384)(*[rng.randint(-1000,1000) for _ in range(16384)]);assert lib.pl_pitch(noise,16384,440.,out)==0 and out[0]==0
result={'passed':True,'audio_cases':audio,'max_ih_difference':max_ih,'partial_max_differences':max_fields,'model_cases':model_cases,'max_stretch_difference_cents':max_stretch,'overpull_notes':1056,'max_overpull_difference':max_op,'pitch_cases':pitch_cases,'resampling':resampling,'legacy_cases':legacy_cases,'scope':'Host C++ numerical tests, not iOS hardware validation.'}
(BASE/'verification/core_results.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
