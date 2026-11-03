#import <Foundation/Foundation.h>
@class TLOriginalRuntime;
@interface TLOriginalAudio:NSObject
@property(nonatomic,copy) void (^error)(NSString *message);
@property(nonatomic,copy) void (^stateChanged)(NSDictionary *state);
@property(nonatomic,readonly) BOOL listening;
@property(nonatomic,readonly) NSDictionary *diagnostics;
- (instancetype)initWithRuntime:(TLOriginalRuntime*)runtime;
- (void)listen;
- (void)stop;
- (void)playWithIncrements:(NSArray<NSNumber*>*)increments amplitudes:(NSArray<NSNumber*>*)amplitudes;
@end
