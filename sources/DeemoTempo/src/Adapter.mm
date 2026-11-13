#import <UIKit/UIKit.h>
#include "Tempo.hpp"
#include "Deemo508.hpp"
#include <atomic>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <cstring>
#include <climits>

namespace {
using Object = void *;
using Method = const void *;
using Action = void (*)(Object,Method);
using Step = bool (*)(Object,Method);
using Clock = float (*)(Method);
using Integer = int (*)(Object,Method);
using Seek = void (*)(Object,int,Method);
using PlayDelay = void (*)(Object,float,Method);
using Key = void (*)(Object,int,int,float,Method);
using EffectHook = void (*)(void *,void *,void **);

uintptr_t base;
bool ready;
NSString *statusText;
std::atomic<float> selection{1.0f};
std::atomic<int> offsetMs{0};
std::atomic<bool> playing{false};
Tempo tempo;
Object manager, source;
uint32_t sourceHandle;
float normalPitch=1, frequency=0, delaySeconds=0;
double keyEpoch=0;
bool paused;
double pauseAt;
PitchSession pitchSession;
PitchBackend backend;
uint32_t (*retainObject)(Object,bool);
Object (*heldObject)(uint32_t);
void (*dropObject)(uint32_t);
Step originalFrame,originalKeyStep;
Action originalPlay,originalStop,originalLeave,originalPause;
Object (*originalEnd)(Object,Method);
Clock originalDelta,originalTime;
Integer originalSamples;
Seek originalSeek;
PlayDelay originalDelay;
Key originalKey;
static thread_local bool inFrame,inKeys;
static thread_local Object startingSource;

template<class T> T at(Deemo::Entry e) { return reinterpret_cast<T>(base+e.offset); }
template<class T> T field(Object object,size_t offset) {
    T value{};
    if (object) memcpy(&value,static_cast<char *>(object)+offset,sizeof value);
    return value;
}
void setPitch(float value) { at<PlayDelay>(Deemo::setPitch)(source,value,nullptr); }
void releaseAudio() {
    if (!sourceHandle) return;
    Object retained=heldObject(sourceHandle);
    if (retained && field<Object>(retained,Deemo::objectNative)) {
        source=retained;
        setPitch(normalPitch);
    }
    pitchSession.stop(backend);
    dropObject(sourceHandle);
    sourceHandle=0;
    frequency=0;
}
void endSong() {
    releaseAudio();
    source=nullptr; manager=nullptr; tempo={1};
    playing.store(false); paused=false;
}
void useNormalSpeed(NSString *reason) {
    releaseAudio(); tempo={1};
    statusText=[NSString stringWithFormat:@"本曲使用 1× · %@",reason];
    NSLog(@"[DeemoTempo] %@",statusText);
}
void prepareAudio(Object target) {
    if (tempo.rate==1) return;
    auto native=field<Object>(target,Deemo::objectNative);
    auto audio=at<Object(*)()>(Deemo::audioManager)();
    auto system=field<Object>(audio,Deemo::systemSlot);
    if (!native || !system) { useNormalSpeed(@"音源未就绪");return; }
    auto clip=at<Object(*)(Object,Method)>(Deemo::getClip)(target,nullptr);
    if (!clip) {useNormalSpeed(@"尚无歌曲");return;}
    frequency=at<Integer>(Deemo::clipHz)(clip,nullptr);
    int outputHz=0;
    auto format=at<int(*)(Object,int*,void*,void*,void*,void*,void*)>(Deemo::softwareFormat);
    if (!(frequency>0) || format(system,&outputHz,nullptr,nullptr,nullptr,nullptr,nullptr) || outputHz<8000) {
        useNormalSpeed(@"音频格式不可用");return;
    }
    at<void(*)(Object)>(Deemo::ensureSourceGroups)(native);
    auto bus=field<Object>(native,Deemo::sourceDryBus);
    normalPitch=field<float>(native,Deemo::sourcePitch);
    if (!std::isfinite(normalPitch) || std::fabs(normalPitch-1)>.001f) {
        useNormalSpeed(@"歌曲音源已有调音");return;
    }
    int rc=pitchSession.start(backend,system,bus,Deemo::pitchShifterType,tempo);
    if (rc) {useNormalSpeed([NSString stringWithFormat:@"音频效果 %d",rc]);return;}
    sourceHandle=retainObject(target,false);
    if (!sourceHandle) {
        pitchSession.stop(backend);useNormalSpeed(@"音源绑定失败");return;
    }
    // Real-time FFT latency estimate (window minus hop), plus the user's
    // measured correction for this output route. Unity keeps its own calibration.
    delaySeconds=pitchSession.latencySeconds(outputHz)+offsetMs.load()*.001f;
    setPitch(tempo.rate);
    statusText=[NSString stringWithFormat:@"本曲 %.3f× · BGM 保调",tempo.rate];
}
void onStop(Object object,Method method) {
    originalStop(object,method);
    // PlayMusic stops before seeking and replaying. Re-create the effect after
    // Stop so a resume never emits the previous section's FFT history.
    if (ready && object==startingSource && object==source && tempo.rate!=1) {
        releaseAudio();prepareAudio(object);
    }
}
void onPlay(Object owner,Method method) {
    if (!ready) {originalPlay(owner,method);return;}
    Object target=field<Object>(owner,Deemo::managerSource);
    if (!target) {endSong();originalPlay(owner,method);return;}
    if (owner!=manager || target!=source) {
        endSong(); manager=owner;source=target;
        tempo.rate=selection.load();playing.store(true);
        keyEpoch=originalTime(nullptr);
        statusText=[NSString stringWithFormat:@"本曲 %.3f×",tempo.rate];
    } else if (paused) {
        keyEpoch+=originalTime(nullptr)-pauseAt;
        paused=false;
    }
    Object previous=startingSource;startingSource=target;
    originalPlay(owner,method);
    startingSource=previous;
}
bool onFrame(Object enumerator,Method method) {
    bool prior=inFrame;inFrame=ready;
    bool more=originalFrame(enumerator,method);
    inFrame=prior;
    if (ready && !more && manager && manager==field<Object>(enumerator,Deemo::coroutineOwner)) endSong();
    return more;
}
void seek(Object obj,int frame,Method method) {
    if (sourceHandle && obj==startingSource) {
        Object clip=at<Object(*)(Object,Method)>(Deemo::getClip)(obj,nullptr);
        int length=clip?at<Integer>(Deemo::clipSamples)(clip,nullptr):0;
        if (length>0) frame=(int)fmax(0,fmin(length-1.0,frame+tempo.audibleSampleDelay(delaySeconds,frequency)));
    }
    originalSeek(obj,frame,method);
}
float chartDelta(Method method) {
    float delta=originalDelta(method);
    return inFrame ? tempo.chartDelta(delta) : delta;
}
void delayed(Object obj,float delay,Method method) {
    if (sourceHandle && obj==startingSource) delay=fmaxf(0,tempo.wallDuration(delay)-delaySeconds);
    originalDelay(obj,delay,method);
}
int samples(Object obj,Method method) {
    int count=originalSamples(obj,method);
    if (!inFrame || obj!=source || !sourceHandle) return count;
    double audible=count-tempo.audibleSampleDelay(delaySeconds,frequency);
    return static_cast<int>(fmax(0,fmin(INT_MAX,audible)));
}
bool onKeyStep(Object enumerator,Method method) {
    bool prior=inKeys;inKeys=ready && manager && tempo.rate!=1;
    bool more=originalKeyStep(enumerator,method);inKeys=prior;return more;
}
float keyTime(Method method) {
    float time=originalTime(method);
    if (!inKeys) return time;
    return static_cast<float>(((paused?pauseAt:time)-keyEpoch)*tempo.rate);
}
void keyPlay(Object bank,int pitch,int velocity,float duration,Method method) {
    originalKey(bank,pitch,velocity,inKeys?tempo.wallDuration(duration):duration,method);
}
void onPause(Object owner,Method method) {
    if (ready && owner==manager && !paused) {paused=true;pauseAt=originalTime(nullptr);}
    originalPause(owner,method);
}
void leave(Object owner,Method method) {
    if (ready && owner==manager) endSong();
    originalLeave(owner,method);
}
Object end(Object owner,Method method) {
    if (ready && owner==manager) endSong();
    return originalEnd(owner,method);
}
bool matches(const mach_header_64 *h) {
    if (h->magic!=MH_MAGIC_64 || h->cputype!=CPU_TYPE_ARM64) return false;
    const char *p=reinterpret_cast<const char *>(h+1);
    for (unsigned i=0;i<h->ncmds;i++) {
        auto cmd=reinterpret_cast<const load_command *>(p);
        if (cmd->cmd==LC_UUID) return !memcmp(reinterpret_cast<const uuid_command *>(p)->uuid,Deemo::uuid,16);
        p+=cmd->cmdsize;
    }
    return false;
}
template<class F> bool install(EffectHook hook,Deemo::Entry e,F replacement,F &original) {
    hook(at<void *>(e),reinterpret_cast<void *>(replacement),reinterpret_cast<void **>(&original));
    return original!=nullptr;
}
bool installAll(const mach_header_64 *header,const char *path) {
    if (!matches(header)) {statusText=@"Unity 构建不匹配";return false;}
    base=reinterpret_cast<uintptr_t>(header);
    for(auto e:Deemo::entries) if (*at<const uint32_t *>(e)!=e.word) {statusText=@"版本校验失败";return false;}
    void *runtime=dlopen(path,RTLD_LAZY|RTLD_NOLOAD);
    if (!runtime) {statusText=@"Unity 运行库不可用";return false;}
    retainObject=reinterpret_cast<decltype(retainObject)>(dlsym(runtime,"il2cpp_gchandle_new"));
    heldObject=reinterpret_cast<decltype(heldObject)>(dlsym(runtime,"il2cpp_gchandle_get_target"));
    dropObject=reinterpret_cast<decltype(dropObject)>(dlsym(runtime,"il2cpp_gchandle_free"));
    EffectHook hook=reinterpret_cast<EffectHook>(dlsym(RTLD_DEFAULT,"MSHookFunction"));
    if (!hook) {
        void *compat=dlopen("/var/jb/usr/lib/libsubstrate.dylib",RTLD_LAZY);
        if (compat) hook=reinterpret_cast<EffectHook>(dlsym(compat,"MSHookFunction"));
    }
    if (!hook || !retainObject || !heldObject || !dropObject) {statusText=@"运行接口不可用";return false;}
    backend={at<decltype(backend.create)>(Deemo::createDSPByType),at<decltype(backend.parameter)>(Deemo::setDSPParameter),
             at<decltype(backend.attach)>(Deemo::addDSP),at<decltype(backend.remove)>(Deemo::removeDSP),at<decltype(backend.release)>(Deemo::releaseDSP)};
    ready=install(hook,Deemo::getDelta,chartDelta,originalDelta)
       && install(hook,Deemo::getTime,keyTime,originalTime)
       && install(hook,Deemo::playDelayed,delayed,originalDelay)
       && install(hook,Deemo::setSamples,seek,originalSeek)
       && install(hook,Deemo::getSamples,samples,originalSamples)
       && install(hook,Deemo::bankPlay,keyPlay,originalKey)
       && install(hook,Deemo::noteStep,onKeyStep,originalKeyStep)
       && install(hook,Deemo::pause,onPause,originalPause)
       && install(hook,Deemo::leave,leave,originalLeave)
       && install(hook,Deemo::end,end,originalEnd)
       && install(hook,Deemo::mainStep,onFrame,originalFrame)
       && install(hook,Deemo::stopSource,onStop,originalStop)
       && install(hook,Deemo::playMusic,onPlay,originalPlay);
    statusText=ready?@"开曲前选择练习倍率":@"适配未就绪";
    return ready;
}
} // namespace

@interface DTRatePanel : UIViewController
@property(nonatomic,strong) UILabel *readout;
@property(nonatomic,strong) UISlider *slider;
@end
@implementation DTRatePanel
- (void)applyRate:(UISlider *)slider {
    if (playing.load()) return;
    selection.store(slider.value);
    [NSUserDefaults.standardUserDefaults setDouble:(double)slider.value*100 forKey:@"DTPracticeRate"];
    self.readout.text=[NSString stringWithFormat:@"练习倍率   %.3f×",slider.value];
    slider.accessibilityValue=[NSString stringWithFormat:@"%.3f×",slider.value];
}
- (void)reset {
    [self.slider setValue:1 animated:YES];
    [self applyRate:self.slider];
}
- (void)close { [self dismissViewControllerAnimated:YES completion:nil]; }
- (void)editDelay {
    UIAlertController *edit=[UIAlertController alertControllerWithTitle:@"声音延迟微调（毫秒）" message:@"正值将判定线向后移。对当前设备保存，默认 0。" preferredStyle:UIAlertControllerStyleAlert];
    [edit addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=[NSString stringWithFormat:@"%d",offsetMs.load()];f.keyboardType=UIKeyboardTypeNumbersAndPunctuation;}];
    [edit addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [edit addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSScanner *scan=[NSScanner scannerWithString:edit.textFields.firstObject.text?:@""];
        NSInteger ms=0;if ([scan scanInteger:&ms] && scan.isAtEnd && ms>=-200 && ms<=200) {
            offsetMs.store((int)ms);[NSUserDefaults.standardUserDefaults setInteger:ms forKey:@"DTPracticeOffset"];
        }
    }]];
    [self presentViewController:edit animated:YES completion:nil];
}
- (UIButton *)button:(NSString *)title action:(SEL)action {
    UIButton *button=[UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor=UIColor.systemBackgroundColor;
    UIStackView *stack=[UIStackView new];
    stack.axis=UILayoutConstraintAxisVertical;
    stack.spacing=8;
    stack.translatesAutoresizingMaskIntoConstraints=NO;
    [self.view addSubview:stack];
    UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:14]
    ]];
    self.readout=[UILabel new];
    self.readout.font=[UIFont monospacedDigitSystemFontOfSize:19 weight:UIFontWeightSemibold];
    self.readout.text=[NSString stringWithFormat:@"练习倍率   %.3f×",selection.load()];
    [stack addArrangedSubview:self.readout];
    UILabel *status=[UILabel new];
    status.font=[UIFont systemFontOfSize:13];
    status.textColor=UIColor.secondaryLabelColor;
    status.text=statusText;
    [stack addArrangedSubview:status];
    if (ready) {
        self.slider=[UISlider new];
        self.slider.minimumValue=.1f;
        self.slider.maximumValue=2.f;
        self.slider.value=selection.load();
        self.slider.continuous=YES;
        self.slider.accessibilityLabel=@"练习倍率";
        self.slider.accessibilityValue=[NSString stringWithFormat:@"%.3f×",self.slider.value];
        [self.slider addTarget:self action:@selector(applyRate:) forControlEvents:UIControlEventValueChanged];
        [stack addArrangedSubview:self.slider];
        UIStackView *limits=[UIStackView new];
        limits.distribution=UIStackViewDistributionEqualSpacing;
        for (NSString *value in @[@"0.10×",@"2.00×"]) {
            UILabel *label=[UILabel new]; label.text=value; label.font=[UIFont systemFontOfSize:13];
            [limits addArrangedSubview:label];
        }
        [stack addArrangedSubview:limits];
    }
    UIStackView *buttons=[UIStackView new];
    buttons.distribution=UIStackViewDistributionEqualSpacing;
    if (ready) {
        [buttons addArrangedSubview:[self button:@"恢复 1×" action:@selector(reset)]];
        [buttons addArrangedSubview:[self button:@"延迟微调" action:@selector(editDelay)]];
    }
    [buttons addArrangedSubview:[self button:@"完成" action:@selector(close)]];
    [stack addArrangedSubview:buttons];
}
@end

@interface DTMenu : NSObject
@property(nonatomic,strong) UIButton *button;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) BOOL attempted;
@end
@implementation DTMenu
- (void)check:(NSTimer *)timer {
    UIApplication *app=UIApplication.sharedApplication;
    if (app.applicationState!=UIApplicationStateActive) return;
    if (!self.attempted) {
        for (uint32_t i=0;i<_dyld_image_count();i++) {
            const char *path=_dyld_get_image_name(i);
            if (!path || !strstr(path,"/UnityFramework.framework/UnityFramework")) continue;
            self.attempted=YES;
            installAll(reinterpret_cast<const mach_header_64 *>(_dyld_get_image_header(i)),path);
            break;
        }
    }
    UIWindow *window=nil;
    for (UIWindow *w in app.windows) if (w.isKeyWindow && w.rootViewController) {window=w;break;}
    if (!window || !self.attempted) return;
    if (self.button.superview!=window) {
        [self.button removeFromSuperview];[window addSubview:self.button];
    }
    self.button.frame=CGRectMake(window.safeAreaInsets.left+10,window.safeAreaInsets.top+8,84,32);
    [self.button setTitle:ready?[NSString stringWithFormat:@"♫ %.3f×",selection.load()]:@"♫ 状态" forState:UIControlStateNormal];
    self.button.hidden=playing.load();
    if (!self.button.hidden) [window bringSubviewToFront:self.button];
}
- (void)open {
    UIViewController *vc=self.button.window.rootViewController;
    while(vc.presentedViewController) vc=vc.presentedViewController;
    if (!vc || playing.load()) return;
    DTRatePanel *panel=[DTRatePanel new];
    panel.modalPresentationStyle=UIModalPresentationPopover;
    panel.preferredContentSize=CGSizeMake(320,ready?204:120);
    panel.popoverPresentationController.sourceView=self.button;
    panel.popoverPresentationController.sourceRect=self.button.bounds;
    [vc presentViewController:panel animated:YES completion:nil];
}
- (void)start {
    // Older versions also stored percentages, restricted to eight integer values.
    double saved=[NSUserDefaults.standardUserDefaults doubleForKey:@"DTPracticeRate"]/100.0;
    if (saved>=.1 && saved<=2) selection.store((float)saved);
    int ms=(int)[NSUserDefaults.standardUserDefaults integerForKey:@"DTPracticeOffset"];
    if (ms>=-200 && ms<=200) offsetMs.store(ms);
    self.button=[UIButton buttonWithType:UIButtonTypeSystem];
    self.button.backgroundColor=[UIColor colorWithWhite:.08 alpha:.78];self.button.layer.cornerRadius=12;
    [self.button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    [self.button addTarget:self action:@selector(open) forControlEvents:UIControlEventTouchUpInside];
    self.timer=[NSTimer timerWithTimeInterval:.5 target:self selector:@selector(check:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];[self check:nil];
}
@end

__attribute__((constructor)) static void DTStart(void) {
    @autoreleasepool {
        NSBundle *app=NSBundle.mainBundle;
        if (![app.bundleIdentifier isEqual:@"com.rayark.pluto"] ||
            ![[app objectForInfoDictionaryKey:@"CFBundleShortVersionString"] isEqual:@"5.0.8"] ||
            ![[app objectForInfoDictionaryKey:@"CFBundleVersion"] isEqual:@"1001405"]) return;
        dispatch_async(dispatch_get_main_queue(),^{static DTMenu *menu;menu=[DTMenu new];[menu start];});
    }
}
