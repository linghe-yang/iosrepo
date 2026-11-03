#import "TLOriginalAudio.h"
#import "TLOriginalRuntime.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#include <array>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <memory>
#include <vector>
@implementation TLOriginalAudio {
    TLOriginalRuntime *_runtime;AVAudioEngine *_engine;
    NSArray *_observers;std::atomic<unsigned> _generation;
    BOOL _listening;
}
- (instancetype)initWithRuntime:(TLOriginalRuntime*)runtime {
    if((self=[super init])){_runtime=runtime;_generation=0;__weak TLOriginalAudio *weak=self;
        id interruption=[NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionInterruptionNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){if([n.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue]==AVAudioSessionInterruptionTypeBegan)[weak stop];}];
        id route=[NSNotificationCenter.defaultCenter addObserverForName:AVAudioSessionRouteChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){NSUInteger reason=[n.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];if(reason==AVAudioSessionRouteChangeReasonOldDeviceUnavailable||reason==AVAudioSessionRouteChangeReasonNewDeviceAvailable)[weak stop];}];
        id background=[NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *n){[weak stop];}];
        _observers=@[interruption,route,background];
    }return self;
}
- (BOOL)listening{return _listening;}
- (void)failed:(NSString*)message {[self stop];if(self.error)self.error(message);}
- (void)listen {
    [self stop];unsigned request=++_generation;__weak TLOriginalAudio *weak=self;
    [AVAudioSession.sharedInstance requestRecordPermission:^(BOOL allowed){dispatch_async(dispatch_get_main_queue(),^{TLOriginalAudio *s=weak;if(!s||s->_generation!=request)return;if(!allowed){[s failed:@"This app needs to RECORD AUDIO to listen to the piano."];return;}[s beginListening:request];});}];
}
- (void)beginListening:(unsigned)request {
    NSError *error=nil;AVAudioSession *session=AVAudioSession.sharedInstance;
    if(![session setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeMeasurement options:AVAudioSessionCategoryOptionDefaultToSpeaker error:&error]||![session setActive:YES error:&error]){[self failed:error.localizedDescription];return;}
    _engine=[AVAudioEngine new];AVAudioInputNode *input=_engine.inputNode;AVAudioFormat *hardware=[input outputFormatForBus:0];
    if(hardware.sampleRate==0||hardware.channelCount==0){[self failed:@"Unable to access the microphone at 44100 samples per second."];return;}
    // A mixer performs system SRC at the hardware boundary. The original library
    // still receives 44100-Hz int16 PCM and performs its own original 2:1 stage.
    AVAudioFormat *original=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100 channels:1];
    AVAudioMixerNode *capture=[AVAudioMixerNode new],*silence=[AVAudioMixerNode new];
    [_engine attachNode:capture];[_engine attachNode:silence];[_engine connect:input to:capture format:hardware];[_engine connect:capture to:silence format:original];[_engine connect:silence to:_engine.mainMixerNode format:original];silence.outputVolume=0;
    __weak TLOriginalAudio *weak=self;
    [capture installTapOnBus:0 bufferSize:2048 format:original block:^(AVAudioPCMBuffer *buffer,AVAudioTime *when){TLOriginalAudio *s=weak;if(!s||request!=s->_generation||!buffer.floatChannelData)return;std::vector<int16_t> pcm(buffer.frameLength);for(unsigned i=0;i<buffer.frameLength;i++){double v=buffer.floatChannelData[0][i];pcm[i]=std::isfinite(v)?int16_t(std::max(-32768.,std::min(32767.,std::round(v*32768)))):0;}[s->_runtime process44100PCM:pcm.data() count:pcm.size()];}];
    [_engine prepare];if(![_engine startAndReturnError:&error]){[self failed:error.localizedDescription];return;}_listening=YES;
}
- (void)playWithIncrements:(NSArray<NSNumber*>*)increments amplitudes:(NSArray<NSNumber*>*)amplitudes {
    if(increments.count!=16||amplitudes.count!=16){[self failed:@"Invalid original tone parameters."];return;}
    [self stop];NSError *error=nil;
    if(![AVAudioSession.sharedInstance setCategory:AVAudioSessionCategoryPlayback error:&error]||![AVAudioSession.sharedInstance setActive:YES error:&error]){[self failed:error.localizedDescription];return;}
    // Original d3.run: 16 unsigned phase accumulators, 256-entry float sine table,
    // truncation to int16, wraparound addition, 22050-Hz output.
    struct Tone {std::array<uint32_t,16> increment{},phase{};std::array<float,16> amplitude{};std::array<float,256> sine{};};
    auto tone=std::make_shared<Tone>();for(int p=0;p<16;p++){tone->increment[p]=[increments[p] unsignedIntValue];tone->amplitude[p]=[amplitudes[p] floatValue];}for(int i=0;i<256;i++)tone->sine[i]=float(std::sin(i*.024543692606170234));
    _engine=[AVAudioEngine new];AVAudioFormat *format=[[AVAudioFormat alloc] initStandardFormatWithSampleRate:22050 channels:1];
    AVAudioSourceNode *source=[[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL *silent,const AudioTimeStamp *timestamp,AVAudioFrameCount count,AudioBufferList *output){for(unsigned i=0;i<count;i++){int16_t sample=0;for(int p=0;p<16;p++)if(tone->amplitude[p]>0){sample=int16_t(sample+int16_t(tone->sine[tone->phase[p]>>24]*tone->amplitude[p]));tone->phase[p]+=tone->increment[p];}for(unsigned b=0;b<output->mNumberBuffers;b++)((float*)output->mBuffers[b].mData)[i]=sample/32768.f;}*silent=NO;return noErr;}];
    [_engine attachNode:source];[_engine connect:source to:_engine.mainMixerNode format:format];[_engine prepare];if(![_engine startAndReturnError:&error])[self failed:error.localizedDescription];
}
- (void)stop {++_generation;_listening=NO;[_engine stop];_engine=nil;[_runtime cancelMeasurement];[AVAudioSession.sharedInstance setActive:NO error:nil];}
- (void)dealloc {for(id token in _observers)[NSNotificationCenter.defaultCenter removeObserver:token];}
@end
