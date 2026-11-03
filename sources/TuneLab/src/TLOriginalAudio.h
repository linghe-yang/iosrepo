#import <Foundation/Foundation.h>
@class TLOriginalRuntime;
@interface TLOriginalAudio:NSObject
@property(nonatomic,copy) void (^error)(NSString *message);
@property(nonatomic,readonly) BOOL listening;
- (instancetype)initWithRuntime:(TLOriginalRuntime*)runtime;
- (void)listen;
- (void)stop;
- (void)playWithIncrements:(NSArray<NSNumber*>*)increments amplitudes:(NSArray<NSNumber*>*)amplitudes;
@end
