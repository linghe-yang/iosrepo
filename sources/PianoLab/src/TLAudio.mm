#import "TLAudio.h"
#import <AVFoundation/AVFoundation.h>
#include "TLCore.hpp"
#include <atomic>
#include <memory>
@implementation TLAudio {
    AVAudioEngine *_engine;
    dispatch_queue_t _queue;
    std::unique_ptr<tl::Resampler> _resampler;
    std::vector<int16_t> _ring,_capture;
    std::vector<double> _additionalTargets;
    std::atomic<int> _pending,_generation,_permissionSerial;
    std::atomic<bool> _tone;
    std::atomic<double> _toneHz;
    int _note,_measureNote,_since;
    double _target,_calibration,_phase;
    bool _automatic,_armed,_collecting;
    NSArray *_observers;
}
- (instancetype)init {
    if((self=[super init])){
        _queue=dispatch_queue_create("com.linghe.pianolab.dsp",DISPATCH_QUEUE_SERIAL);_target=440;_note=48;_toneHz=440;_pending=0;_generation=0;_permissionSerial=0;_tone=false;
        __weak TLAudio *weak=self;
        id a=[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){if([n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan){[weak stop];[weak report:@"音频被系统中断；结束后点开始恢复"];}}];
        id b=[[NSNotificationCenter defaultCenter] addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){TLAudio *s=weak;NSUInteger reason=[n.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];if(s&&s->_engine.isRunning&&(reason==AVAudioSessionRouteChangeReasonOldDeviceUnavailable||reason==AVAudioSessionRouteChangeReasonNewDeviceAvailable)){[s stop];[s report:@"音频设备已改变，请重新开始"];}}];
        _observers=@[a,b];
    }return self;
}
- (void)report:(NSString*)text {dispatch_async(dispatch_get_main_queue(),^{if(self.status)self.status(text);});}
- (void)setNote:(int)note target:(double)target automatic:(BOOL)automatic calibration:(double)cents {
    dispatch_async(_queue,^{self->_note=note;self->_target=target;self->_automatic=automatic;self->_calibration=cents;self->_armed=false;self->_collecting=false;self->_capture.clear();});
}
- (void)setAdditionalTargets:(NSArray<NSNumber*>*)targets {dispatch_async(_queue,^{self->_additionalTargets.clear();for(NSNumber *v in targets)if(v.doubleValue>20&&v.doubleValue<9000)self->_additionalTargets.push_back(v.doubleValue);});}
- (void)start {
    __weak TLAudio *weak=self;
    int request=++_permissionSerial;
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted){dispatch_async(dispatch_get_main_queue(),^{TLAudio *s=weak;if(!s||request!=s->_permissionSerial)return;if(!granted){[s report:@"麦克风权限未开启，请到系统设置允许录音"];return;}[s beginAudio];});}];
}
- (void)beginAudio {
    bool desiredTone=_tone;[self stop];_tone=desiredTone;NSError *error=nil;AVAudioSession *session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error]||![session setPreferredSampleRate:44100 error:&error]||![session setActive:YES error:&error]){[self report:error.localizedDescription];return;}
    _engine=[AVAudioEngine new];AVAudioInputNode *input=_engine.inputNode;AVAudioFormat *format=[input outputFormatForBus:0];
    if(format.sampleRate<22050||format.channelCount<1){[self stop];[self report:@"当前音频输入不支持，请更换输入设备"];return;}
    double rate=format.sampleRate;int generation=++_generation;
    dispatch_sync(_queue,^{self->_resampler.reset(new tl::Resampler(rate));self->_ring.clear();self->_capture.clear();self->_armed=false;self->_collecting=false;self->_since=0;});
    __weak TLAudio *weak=self;
    [input installTapOnBus:0 bufferSize:2048 format:format block:^(AVAudioPCMBuffer *buffer,AVAudioTime *time){
        TLAudio *s=weak;if(!s||generation!=s->_generation||!buffer.floatChannelData)return;
        if(s->_pending.fetch_add(1)>=3){s->_pending.fetch_sub(1);dispatch_async(s->_queue,^{s->_armed=false;s->_collecting=false;});[s report:@"分析负载过高，测量已取消；请重新测量"];return;}
        auto samples=std::make_shared<std::vector<float>>(buffer.frameLength);for(AVAudioFrameCount i=0;i<buffer.frameLength;i++){float sum=0;for(unsigned ch=0;ch<buffer.format.channelCount;ch++)sum+=buffer.floatChannelData[ch][i];(*samples)[i]=sum/buffer.format.channelCount;}
        dispatch_async(s->_queue,^{if(generation==s->_generation)[s process:*samples];s->_pending.fetch_sub(1);});
    }];
    AVAudioFormat *output=[_engine.outputNode inputFormatForBus:0];double outRate=output.sampleRate;
    if(outRate>0){AVAudioFormat *mono=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:outRate channels:1];
        AVAudioSourceNode *source=[[AVAudioSourceNode alloc] initWithFormat:mono renderBlock:^OSStatus(BOOL *silent,const AudioTimeStamp *ts,AVAudioFrameCount count,AudioBufferList *list){TLAudio *s=weak;bool enabled=s&&s->_tone;double hz=s?s->_toneHz.load():440;for(unsigned b=0;b<list->mNumberBuffers;b++){float *p=(float*)list->mBuffers[b].mData;for(unsigned i=0;i<count;i++){double phase=s?s->_phase:0;p[i]=enabled?.08f*std::sin(phase):0;if(s&&b==0){s->_phase+=2*3.141592653589793*hz/outRate;if(s->_phase>2*3.141592653589793)s->_phase-=2*3.141592653589793;}}}*silent=!enabled;return noErr;}];
        [_engine attachNode:source];[_engine connect:source to:_engine.mainMixerNode format:mono];
    }
    [_engine prepare];if(![_engine startAndReturnError:&error]){[self stop];[self report:error.localizedDescription];return;}
    [self report:[NSString stringWithFormat:@"正在监听 · 输入 %.0f Hz",rate]];
}
- (void)process:(const std::vector<float>&)samples {
    auto pcm=_resampler->feed(samples.data(),samples.size());double sum=0;for(auto v:pcm)sum+=double(v)*v;double rms=pcm.empty()?0:std::sqrt(sum/pcm.size());
    if(_armed&&rms>160){_armed=false;_collecting=true;_capture.clear();[self report:@"正在采集非谐性，请等待…"];}
    if(_collecting){size_t needed=_measureNote<45?65536:_measureNote<66?32768:16384;for(auto v:pcm){if(_capture.size()<needed)_capture.push_back(v);}
        if(_capture.size()==needed){_collecting=false;auto measured=tl::analyze(_capture,_measureNote);NSMutableArray *rows=[NSMutableArray new];for(auto p:measured.partials)[rows addObject:@{@"p":@(rows.count+1),@"valid":@(p.valid),@"code":@(p.code),@"cents":@(p.offset),@"amplitude":@(std::isfinite(p.amplitude)?p.amplitude:0),@"snr":@(std::isfinite(p.snr)?p.snr:0)}];NSDictionary *result=@{@"note":@(_measureNote),@"ih":@(measured.ih),@"partials":rows};dispatch_async(dispatch_get_main_queue(),^{if(self.measurement)self.measurement(result);});}
    }
    _ring.insert(_ring.end(),pcm.begin(),pcm.end());if(_ring.size()>16384)_ring.erase(_ring.begin(),_ring.end()-16384);_since+=pcm.size();
    if(_ring.size()<16384||_since<2048)return;_since=0;auto p=tl::pitch(_ring,_target,_note,_automatic);double correction=std::exp2(_calibration/1200);float cents=p.valid?1200*std::log2((p.hz*correction)/_target):0;
    NSMutableArray *partials=[NSMutableArray new];std::vector<float> estimates;if(p.valid)estimates.push_back(cents);
    for(double target:_additionalTargets){auto more=tl::pitch(_ring,target,_note,false);float delta=more.valid?1200*std::log2(more.hz*correction/target):0;[partials addObject:@{@"target":@(target),@"valid":@(more.valid),@"cents":@(delta)}];if(more.valid)estimates.push_back(delta);}
    if(!_additionalTargets.empty()&&!estimates.empty()){std::sort(estimates.begin(),estimates.end());cents=estimates[estimates.size()/2];p.valid=true;p.hz=_target*std::exp2(cents/1200)/correction;}
    NSMutableArray *bins=[NSMutableArray new];for(auto v:p.spectrum)[bins addObject:@(v)];int generation=_generation;NSDictionary *result=@{@"valid":@(p.valid),@"hz":@(p.hz*correction),@"cents":@(cents),@"note":@(p.note),@"level":@(rms/32768),@"spectrum":bins,@"partials":partials};dispatch_async(dispatch_get_main_queue(),^{if(generation==self->_generation&&self.update)self.update(result);});
}
- (void)measure {dispatch_async(_queue,^{self->_tone=false;self->_measureNote=self->_note;self->_armed=true;self->_collecting=false;self->_capture.clear();[self report:@"等待击键：请弹当前音，保持单弦发声"];});}
- (void)cancelMeasurement {dispatch_async(_queue,^{self->_armed=false;self->_collecting=false;self->_capture.clear();});}
- (void)tone:(BOOL)enabled frequency:(double)frequency {_toneHz=std::max(20.,std::min(10000.,frequency));_tone=enabled;}
- (void)stop {++_permissionSerial;++_generation;_tone=false;[_engine.inputNode removeTapOnBus:0];[_engine stop];_engine=nil;dispatch_async(_queue,^{self->_armed=false;self->_collecting=false;});[AVAudioSession.sharedInstance setActive:NO error:nil];}
- (BOOL)isRunning{return _engine.isRunning;}
- (void)dealloc {for(id token in _observers)[NSNotificationCenter.defaultCenter removeObserver:token];}
@end
