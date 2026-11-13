"""Desktop FMOD backend comparison. Requires fmod_toolkit and pyfmodex. Output: rate, measured Hz, audible seconds."""
import sys,wave,struct,tempfile,array,math,ctypes,os
from pathlib import Path
if len(sys.argv)>1: sys.path.insert(0,str(Path(sys.argv[1]).resolve()))
from fmod_toolkit.importer import import_pyfmodex
fm=import_pyfmodex()
from pyfmodex.enums import OUTPUTTYPE,DSP_TYPE
from pyfmodex.flags import INIT_FLAGS
with tempfile.TemporaryDirectory(dir=Path.cwd()) as folder:
    folder=Path(folder).resolve()
    source=folder/'tone.wav'
    tone=array.array('h',(round(12000*math.sin(i*2*math.pi*440/48000)) for i in range(2*48000)))
    with wave.open(str(source),'wb') as w:
        w.setparams((1,2,48000,0,'NONE',''));w.writeframes(tone.tobytes())
    for rate in (.1,.1073,.125,.17,.25,.251,.499,.5,.73,1.,1.37,2.):
        sysfm=fm.System()
        dst=folder/f'out{rate}.wav'
        sysfm.output=OUTPUTTYPE.WAVWRITER_NRT
        sysfm.init(8,INIT_FLAGS.NORMAL,ctypes.c_char_p(os.fsencode(dst)))
        sound=sysfm.create_sound(str(source))
        group=sysfm.create_channel_group('BGM')
        sysfm.master_channel_group.add_group(group)
        count=max(1,math.ceil(math.log2(1/rate)))
        nodes=[]
        factors=[min(2.,1/rate/(2**i)) for i in range(count)]
        for factor in reversed(factors):
            fx=sysfm.create_dsp_by_type(DSP_TYPE.PITCHSHIFT)
            fx.set_parameter_float(1,4096 if rate<.5 else 512)
            fx.set_parameter_float(0,factor)
            group.add_dsp(0,fx)
            nodes.append(fx)
        ch=sysfm.play_sound(sound,group,paused=True)
        ch.pitch=rate;ch.paused=False
        for i in range(math.ceil((2/rate+1)*100)):sysfm.update()
        for fx in reversed(nodes):
            group.remove_dsp(fx)
            fx.release()
        sound.release();group.release()
        sysfm.close();sysfm.release()
        with wave.open(str(dst),'rb') as w:
            hz=w.getframerate();channels=w.getnchannels();width=w.getsampwidth()
            data=w.readframes(w.getnframes())
        assert width in (2,3,4),width
        signal=[int.from_bytes(data[i:i+width], 'little',signed=True)/(1<<(8*width-1)) for i in range(0,len(data),width*channels)]
        crossings=[i for i in range(int((1.0 if rate<.5 else .35)*hz),int((2.0 if rate<.5 else .85)*hz)) if signal[i]>0 and signal[i-1]<=0]
        pitch=(len(crossings)-1)*hz/(crossings[-1]-crossings[0])
        audible=[i for i,x in enumerate(signal) if abs(x)>.02]
        duration=(audible[-1]-audible[0])/hz
        print(rate,round(pitch,2),round(duration,3))
        assert abs(440-pitch)<4 and abs(duration-2/rate)<(.32 if rate<.5 else .12)
