#import "TLOriginalRuntime.h"
#include "../native/OriginalDSP.hpp"
#include <array>
#include <vector>
#include <cmath>
extern id TLInvokeOriginal(NSString*,NSArray*);
static char kOriginalQueueKey;
@implementation TLOriginalRuntime {
    dispatch_queue_t _queue;
    std::array<int16_t,2048> _input;
    std::vector<int16_t> _pending;
    uint16_t _phase[5];float _speed;
    int _note,_partial,_multiCount,_measureState;
    BOOL _combined,_configured;
    float _target,_offset;
}
- (instancetype)init {
    if((self=[super init])){
        _queue=dispatch_queue_create("com.realtimespecialties.tunelab.original",DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_queue,&kOriginalQueueKey,(__bridge void*)self,nullptr);_speed=1;_target=440;_partial=1;_note=48;
        dispatch_sync(_queue,^{TLNativeInitialize();TLInvokeOriginal(@"setAudioBlockAddress",@[[NSValue valueWithPointer:self->_input.data()],@22050]);});
    }return self;
}
- (id)call:(NSString*)method arguments:(NSArray*)args {
    if(dispatch_get_specific(&kOriginalQueueKey)==(__bridge void*)self)return TLInvokeOriginal(method,args);
    __block id result;dispatch_sync(_queue,^{result=TLInvokeOriginal(method,args);});return result;
}
- (void)configureNote:(int)note partial:(int)partial target:(float)target offset:(float)offset {
    if(note<0||note>87||partial<1||partial>16||target<=25.4||target>=10200)return;
    dispatch_sync(_queue,^{BOOL changed=!self->_configured||note!=self->_note||partial!=self->_partial||target!=self->_target;
        if(changed){TLInvokeOriginal(@"SetNote",@[@(note),@(target/partial),@(partial)]);TLInvokeOriginal(@"CalcDemodParms",@[@(target)]);}
        if(changed||offset!=self->_offset)TLInvokeOriginal(@"CalcPhaseIncrement",@[@(target),@(offset)]);
        self->_note=note;self->_partial=partial;self->_target=target;self->_offset=offset;self->_configured=YES;
    });
}
- (void)setPhaseSpeed:(float)speed {if(!std::isfinite(speed)||speed<=0)return;dispatch_async(_queue,^{self->_speed=speed;});}
- (void)setPartials:(NSArray<NSNumber*>*)partials combined:(BOOL)combined {
    if(partials.count>4)return;for(NSNumber *p in partials)if(p.intValue<1||p.intValue>16)return;
    dispatch_sync(_queue,^{self->_multiCount=(int)partials.count;self->_combined=combined;NSMutableArray *a=[partials mutableCopy];while(a.count<4)[a addObject:@0];TLInvokeOriginal(@"setupPartials",a);});
}
- (void)beginMeasurement {dispatch_async(_queue,^{self->_measureState=1;TLInvokeOriginal(@"SetMeasureState",@[@1]);});}
- (void)cancelMeasurement {dispatch_async(_queue,^{self->_measureState=0;TLInvokeOriginal(@"SetMeasureState",@[@0]);});}
- (void)process44100PCM:(const int16_t*)samples count:(NSUInteger)count {
    NSData *data=[NSData dataWithBytes:samples length:count*sizeof(int16_t)];
    dispatch_async(_queue,^{@autoreleasepool{
        const int16_t *values=(const int16_t*)data.bytes;self->_pending.insert(self->_pending.end(),values,values+count);
        NSUInteger consumed=0;while(self->_pending.size()-consumed>=2048){std::copy(self->_pending.begin()+consumed,self->_pending.begin()+consumed+2048,self->_input.begin());consumed+=2048;[self processBlock];}
        self->_pending.erase(self->_pending.begin(),self->_pending.begin()+consumed);
    }});
}
- (void)processBlock {
    int flags=[TLInvokeOriginal(@"processAudioBuffer",@[@4096]) intValue];if(flags&32768)return;
    int velocity=flags>>16,phaseState=(flags>>4)&3,quality=(flags>>8)&127;
    NSMutableArray *phases=[NSMutableArray new],*qualities=[NSMutableArray new];
    if(_multiCount==0){_phase[0]=uint16_t(_phase[0]+int(velocity*_speed));[phases addObject:@(_phase[0])];[qualities addObject:@(quality)];}
    else if(_combined){int packed=[TLInvokeOriginal(@"mparAvgVelQual",@[]) intValue];_phase[0]=uint16_t(_phase[0]+int((packed>>16)*_speed));[phases addObject:@(_phase[0])];[qualities addObject:@(packed&65535)];}
    else for(int i=0;i<_multiCount;i++){int packed=[TLInvokeOriginal(@"mparVelQual",@[@(i)]) intValue];_phase[i+1]=uint16_t(_phase[i+1]+int((packed>>16)*_speed));[phases addObject:@(_phase[i+1])];[qualities addObject:@(packed&65535)];}
    if(flags&64)TLInvokeOriginal(@"processForAutoNote",@[]);
    int pending=[TLInvokeOriginal(@"GetPitch",@[@63]) intValue];
    NSMutableDictionary *state=[@{@"phase":phases,@"phaseQuality":qualities,@"phaseDisplayState":@(phaseState),@"velocity":@(velocity),@"level":@(quality),@"pending":@(pending),@"note":@(_note),@"partial":@(_partial)} mutableCopy];
    if(pending&64)state[@"autoNote"]=TLInvokeOriginal(@"GetPitch",@[@71]);
    if(pending&512)state[@"autoPartial"]=TLInvokeOriginal(@"GetPitch",@[@72]);
    if(pending&32){state[@"lockError"]=TLInvokeOriginal(@"GetPitch",@[@65]);state[@"lockState"]=TLInvokeOriginal(@"GetPitch",@[@66]);state[@"triggerCount"]=TLInvokeOriginal(@"GetPitch",@[@64]);}
    if(pending&256)state[@"premeasurement"]=TLInvokeOriginal(@"IHform",@[@1014]);
    if((flags&12)!=0){int measure=(flags>>2)&3;if(measure>1&&measure!=_measureState){_measureState=measure;if(measure==3){TLInvokeOriginal(@"SetMeasureState",@[@0]);float h=[TLInvokeOriginal(@"AnalyzeForIH",@[]) floatValue];NSMutableArray *partials=[NSMutableArray new];for(int p=1;p<=12;p++)[partials addObject:@{@"partial":@(p),@"offset":TLInvokeOriginal(@"GetOneIHResultOffset",@[@(p)]),@"amplitude":TLInvokeOriginal(@"GetOneIHResultAmp",@[@(p)])}];NSDictionary *measurement=@{@"note":@(_note),@"ih":@(h),@"partials":partials};dispatch_async(dispatch_get_main_queue(),^{if(self.measurementReady)self.measurementReady(measurement);});}}}
    dispatch_async(dispatch_get_main_queue(),^{if(self.update)self.update(state);});
}
@end
