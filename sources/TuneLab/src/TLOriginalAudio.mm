#import "TLOriginalAudio.h"
#import "TLOriginalRuntime.h"
#import <AVFoundation/AVFoundation.h>
#import <QuartzCore/QuartzCore.h>
#import <UIKit/UIKit.h>
#include "TLCapturePolicy.hpp"
#include <array>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <memory>
#include <vector>

@implementation TLOriginalAudio {
    TLOriginalRuntime *_runtime;AVAudioEngine *_engine;AVAudioInputNode *_inputNode;
    AVAudioFormat *_captureFormat;NSArray *_observers;dispatch_queue_t _conversionQueue;
    dispatch_source_t _monitor;std::atomic<unsigned> _generation;
    std::atomic<uint64_t> _inputCallbacks,_inputFrames,_convertedFrames;
    std::atomic<double> _lastInput,_lastOutput;std::atomic<float> _peak;
    tl::CapturePolicy _policy;BOOL _listening,_tapInstalled,_restartScheduled;
    double _startedAt;NSString *_status,*_lastError,*_lastRecovery;
}
- (instancetype)initWithRuntime:(TLOriginalRuntime*)runtime {
    if((self=[super init])){
        _runtime=runtime;_generation=0;_status=@"Stopped";
        _conversionQueue=dispatch_queue_create("com.realtimespecialties.tunelab.capture-conversion",DISPATCH_QUEUE_SERIAL);
        __weak TLOriginalAudio *weak=self;NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
        id interruption=[center addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weak interrupted:n];}];
        id route=[center addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weak routeChanged:n];}];
        // Engine teardown runs on the main queue, outside its internal callback.
        id config=[center addObserverForName:AVAudioEngineConfigurationChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){TLOriginalAudio *s=weak;if(s&&n.object==s->_engine)[s scheduleRecovery:@"Audio engine configuration changed"]; }];
        id reset=[center addObserverForName:AVAudioSessionMediaServicesWereResetNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weak scheduleRecovery:@"Audio services restarted"]; }];
        id background=[center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weak stop];}];
        _observers=@[interruption,route,config,reset,background];
        _monitor=dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER,0,0,dispatch_get_main_queue());
        dispatch_source_set_timer(_monitor,dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/2),NSEC_PER_SEC/2,NSEC_PER_SEC/10);
        dispatch_source_set_event_handler(_monitor,^{[weak checkCapture];});dispatch_resume(_monitor);
    }return self;
}
- (BOOL)listening{return _listening&&_engine.isRunning;}
- (NSDictionary*)diagnostics {
    AVAudioSession *session=AVAudioSession.sharedInstance;NSMutableArray *inputs=[NSMutableArray new];
    for(AVAudioSessionPortDescription *port in session.currentRoute.inputs)[inputs addObject:@{@"name":port.portName?:@"",@"type":port.portType?:@""}];
    return @{@"status":_status?:@"Stopped",@"requested":@(_policy.requested),@"interrupted":@(_policy.interrupted),@"engineRunning":@(_engine.isRunning),@"inputSampleRate":@(_captureFormat.sampleRate),@"inputChannels":@(_captureFormat.channelCount),@"algorithmInputRate":@44100,@"inputCallbacks":@(_inputCallbacks.load()),@"inputFrames":@(_inputFrames.load()),@"convertedFrames":@(_convertedFrames.load()),@"peak":@(_peak.load()),@"recoveryAttempts":@(_policy.recoveries),@"lastRecovery":_lastRecovery?:@"",@"lastError":_lastError?:@"",@"inputRoute":inputs};
}
- (void)publish {if(self.stateChanged)self.stateChanged(self.diagnostics);}
- (void)teardown {
    ++_generation;_listening=NO;_restartScheduled=NO;
    AVAudioEngine *old=_engine;_engine=nil;
    [old stop];if(_tapInstalled&&_inputNode)[_inputNode removeTapOnBus:0];
    _tapInstalled=NO;_inputNode=nil;[_runtime resetInputStream];
}
- (void)failed:(NSString*)message {
    _lastError=message?:@"Audio input failed";_status=@"Audio error";_policy.stop();[self teardown];[self publish];
    if(self.error)self.error(_lastError);
}
- (void)startupFailed:(NSString*)message {
    _lastError=message?:@"Microphone startup failed";_policy.starting=false;
    [self teardown];[self scheduleRecovery:_lastError];
}
- (void)listen {
    if(_policy.requested&&(_policy.starting||self.listening))return;
    _policy.request();[self teardown];_policy.starting=true;_status=@"Microphone permission";_lastError=nil;[self publish];
    unsigned request=_generation.load();__weak TLOriginalAudio *weak=self;
    [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL allowed){dispatch_async(dispatch_get_main_queue(),^{TLOriginalAudio *s=weak;if(!s||s->_generation!=request||!s->_policy.requested)return;if(!allowed){[s failed:@"Microphone access is disabled. Allow Piano Tuner in Settings > Privacy & Security > Microphone, then tap the microphone status to retry."];return;}[s beginListening:request];});}];
}
- (void)beginListening:(unsigned)request {
    if(request!=_generation||!_policy.requested)return;
    _policy.starting=true;_status=@"Starting microphone";[self publish];
    NSError *error=nil;AVAudioSession *session=AVAudioSession.sharedInstance;
    // Capture the input node at its actual hardware format. Do not depend on
    // a muted playback/mixer graph to pull microphone data or resample it.
    if(![session setCategory:AVAudioSessionCategoryRecord mode:AVAudioSessionModeMeasurement options:0 error:&error]){[self failed:error.localizedDescription];return;}
    [session setPreferredSampleRate:44100 error:nil];[session setPreferredIOBufferDuration:.02 error:nil];
    if(![session setActive:YES error:&error]){[self startupFailed:error.localizedDescription];return;}
    _engine=[AVAudioEngine new];_inputNode=_engine.inputNode;
    AVAudioFormat *hardware=[_inputNode outputFormatForBus:0];_captureFormat=hardware;
    if(hardware.sampleRate<=0||hardware.channelCount==0){[self startupFailed:@"No active microphone is available on the current audio route."];return;}
    AVAudioFormat *mono=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];
    AVAudioConverter *converter=[[AVAudioConverter alloc] initFromFormat:hardware toFormat:mono];
    if(!converter){[self failed:@"The current microphone format cannot be converted to 44100 Hz mono."];return;}
    converter.sampleRateConverterQuality=AVAudioQualityMax;converter.downmix=hardware.channelCount>1;
    _inputCallbacks=0;_inputFrames=0;_convertedFrames=0;_peak=0;
    _startedAt=CACurrentMediaTime();_lastInput=_startedAt;_lastOutput=_startedAt;
    __weak TLOriginalAudio *weak=self;
    @try {
        [_inputNode installTapOnBus:0 bufferSize:2048 format:hardware block:^(AVAudioPCMBuffer *buffer,AVAudioTime *when){
            TLOriginalAudio *s=weak;if(!s||request!=s->_generation||!buffer.frameLength)return;
            s->_inputCallbacks.fetch_add(1);s->_inputFrames.fetch_add(buffer.frameLength);s->_lastInput=CACurrentMediaTime();
            // Engine tap memory is reused. Own the bytes before returning.
            AVAudioPCMBuffer *copy=[[AVAudioPCMBuffer alloc] initWithPCMFormat:buffer.format frameCapacity:buffer.frameLength];
            if(!copy)return;copy.frameLength=buffer.frameLength;
            const AudioBufferList *src=buffer.audioBufferList;AudioBufferList *dst=copy.mutableAudioBufferList;
            if(src->mNumberBuffers!=dst->mNumberBuffers)return;
            for(unsigned b=0;b<src->mNumberBuffers;b++){if(!src->mBuffers[b].mData||src->mBuffers[b].mDataByteSize>dst->mBuffers[b].mDataByteSize)return;std::memcpy(dst->mBuffers[b].mData,src->mBuffers[b].mData,src->mBuffers[b].mDataByteSize);dst->mBuffers[b].mDataByteSize=src->mBuffers[b].mDataByteSize;}
            dispatch_async(s->_conversionQueue,^{@autoreleasepool{TLOriginalAudio *live=weak;if(live&&request==live->_generation)[live convert:copy using:converter generation:request];}});
        }];
        _tapInstalled=YES;[_engine prepare];
        if(![_engine startAndReturnError:&error]){[self startupFailed:error.localizedDescription];return;}
    }@catch(NSException *exception){[self startupFailed:exception.reason?:@"The microphone could not start."];return;}
    _policy.starting=false;_listening=YES;_status=@"Listening";[self publish];
}
- (void)convert:(AVAudioPCMBuffer*)input using:(AVAudioConverter*)converter generation:(unsigned)request {
    __block AVAudioFrameCount cursor=0;double ratio=44100./input.format.sampleRate;
    AVAudioFrameCount capacity=AVAudioFrameCount(ceil(input.frameLength*ratio))+64;
    AVAudioPCMBuffer *output=[[AVAudioPCMBuffer alloc] initWithPCMFormat:converter.outputFormat frameCapacity:capacity];
    if(!output)return;
    for(int iteration=0;iteration<16&&request==_generation;iteration++){
        NSError *error=nil;output.frameLength=0;
        AVAudioConverterOutputStatus result=[converter convertToBuffer:output error:&error withInputFromBlock:^AVAudioBuffer*(AVAudioPacketCount requested,AVAudioConverterInputStatus *status){
            if(cursor>=input.frameLength||!requested){*status=AVAudioConverterInputStatus_NoDataNow;return nil;}
            AVAudioFrameCount count=MIN(requested,input.frameLength-cursor);
            AVAudioPCMBuffer *part=[[AVAudioPCMBuffer alloc] initWithPCMFormat:input.format frameCapacity:count];part.frameLength=count;
            const AudioBufferList *src=input.audioBufferList;AudioBufferList *dst=part.mutableAudioBufferList;UInt32 bytes=input.format.streamDescription->mBytesPerFrame;
            for(unsigned b=0;b<src->mNumberBuffers;b++){std::memcpy(dst->mBuffers[b].mData,(const char*)src->mBuffers[b].mData+size_t(cursor)*bytes,size_t(count)*bytes);dst->mBuffers[b].mDataByteSize=count*bytes;}
            cursor+=count;*status=AVAudioConverterInputStatus_HaveData;return part;
        }];
        if(request!=_generation)return;
        if(result==AVAudioConverterOutputStatus_Error){NSString *message=error.localizedDescription?:@"Microphone sample-rate conversion failed.";__weak TLOriginalAudio *weak=self;dispatch_async(dispatch_get_main_queue(),^{TLOriginalAudio *s=weak;if(s&&request==s->_generation)[s startupFailed:message];});return;}
        if(output.frameLength&&output.floatChannelData){
            std::vector<int16_t> pcm(output.frameLength);float peak=0;
            for(unsigned i=0;i<output.frameLength;i++){float v=output.floatChannelData[0][i];pcm[i]=tl::pcm16(v);if(std::isfinite(v))peak=std::max(peak,fabsf(v));}
            _peak=peak;_convertedFrames.fetch_add(pcm.size());_lastOutput=CACurrentMediaTime();
            [_runtime process44100PCM:pcm.data() count:pcm.size()];
        }
        if(result==AVAudioConverterOutputStatus_InputRanDry||result==AVAudioConverterOutputStatus_EndOfStream)break;
        if(!output.frameLength&&cursor>=input.frameLength)break;
    }
}
- (void)routeChanged:(NSNotification*)notification {
    if(!_policy.requested||_policy.starting||_policy.interrupted)return;
    NSUInteger reason=[notification.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if(reason==AVAudioSessionRouteChangeReasonNewDeviceAvailable||reason==AVAudioSessionRouteChangeReasonOldDeviceUnavailable||!_engine.isRunning)[self scheduleRecovery:@"Microphone route changed"];
}
- (void)interrupted:(NSNotification*)notification {
    NSUInteger type=[notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if(type==AVAudioSessionInterruptionTypeBegan){if(!_policy.requested)return;_policy.interrupted=true;_policy.starting=false;[self teardown];_status=@"Microphone interrupted";[self publish];}
    else if(_policy.interrupted){_policy.interrupted=false;if(_policy.requested)[self scheduleRecovery:@"Audio interruption ended"];}
}
- (void)scheduleRecovery:(NSString*)reason {
    if(!_policy.requested||_policy.interrupted||_policy.starting||_restartScheduled)return;
    _restartScheduled=YES;_lastRecovery=reason;_status=@"Reconnecting microphone";[self publish];
    unsigned request=_generation.load();__weak TLOriginalAudio *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC/4),dispatch_get_main_queue(),^{
        TLOriginalAudio *s=weak;if(!s||request!=s->_generation||!s->_policy.requested||s->_policy.interrupted)return;
        s->_restartScheduled=NO;
        if(!s->_policy.recover()){[s failed:@"The microphone is not delivering usable audio. Tap the microphone status to retry; AudioDiagnostics.json records the input route and processing counters."];return;}
        [s teardown];[s beginListening:s->_generation.load()];
    });
}
- (void)checkCapture {
    if(!_policy.requested)return;
    auto health=_policy.inspect(CACurrentMediaTime(),_startedAt,_lastInput.load(),_lastOutput.load(),_engine.isRunning);
    switch(health){
        case tl::CapturePolicy::Health::Healthy:_policy.recoveries=0;break;
        case tl::CapturePolicy::Health::EngineStopped:[self scheduleRecovery:@"Audio engine stopped"];break;
        case tl::CapturePolicy::Health::NoInput:[self scheduleRecovery:@"No microphone callbacks"];break;
        case tl::CapturePolicy::Health::NoConvertedOutput:[self scheduleRecovery:@"No converted audio frames"];break;
        default:break;
    }
    [self publish];
}
- (void)playWithIncrements:(NSArray<NSNumber*>*)increments amplitudes:(NSArray<NSNumber*>*)amplitudes {
    if(increments.count!=16||amplitudes.count!=16){[self failed:@"Invalid original tone parameters."];return;}
    [self stop];NSError *error=nil;
    if(![AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:&error]||![AVAudioSession.sharedInstance setActive:YES error:&error]){[self failed:error.localizedDescription];return;}
    struct Tone {std::array<uint32_t,16> increment{},phase{};std::array<float,16> amplitude{};std::array<float,256> sine{};};
    auto tone=std::make_shared<Tone>();for(int p=0;p<16;p++){tone->increment[p]=[increments[p] unsignedIntValue];tone->amplitude[p]=[amplitudes[p] floatValue];}for(int i=0;i<256;i++)tone->sine[i]=float(std::sin(i*.024543692606170234));
    _engine=[AVAudioEngine new];AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:22050 channels:1];
    AVAudioSourceNode *source=[[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent,const AudioTimeStamp *timestamp,AVAudioFrameCount count,AudioBufferList *output){for(unsigned i=0;i<count;i++){int16_t sample=0;for(int p=0;p<16;p++)if(tone->amplitude[p]>0){sample=int16_t(sample+int16_t(tone->sine[tone->phase[p]>>24]*tone->amplitude[p]));tone->phase[p]+=tone->increment[p];}for(unsigned b=0;b<output->mNumberBuffers;b++)((float*)output->mBuffers[b].mData)[i]=sample/32768.f;}*silent=NO;return noErr;}];
    [_engine attachNode:source];[_engine connect:source to:_engine.mainMixerNode format:format];[_engine prepare];if(![_engine startAndReturnError:&error]){[self failed:error.localizedDescription];return;}_status=@"Reference tone";[self publish];
}
- (void)stop {_policy.stop();[self teardown];_status=@"Stopped";[AVAudioSession.sharedInstance setActive:NO error:nil];[self publish];}
- (void)dealloc {if(_monitor)dispatch_source_cancel(_monitor);for(id token in _observers)[NSNotificationCenter.defaultCenter removeObserver:token];}
@end
