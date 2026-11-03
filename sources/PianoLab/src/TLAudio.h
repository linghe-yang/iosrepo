#import <Foundation/Foundation.h>
@interface TLAudio : NSObject
@property(nonatomic,copy) void (^update)(NSDictionary *result);
@property(nonatomic,copy) void (^measurement)(NSDictionary *result);
@property(nonatomic,copy) void (^status)(NSString *text);
- (void)start;
- (void)stop;
- (BOOL)isRunning;
- (void)setNote:(int)note target:(double)target automatic:(BOOL)automatic calibration:(double)cents;
- (void)measure;
- (void)cancelMeasurement;
- (void)tone:(BOOL)enabled frequency:(double)frequency;
- (void)setAdditionalTargets:(NSArray<NSNumber*>*)targets;
@end
