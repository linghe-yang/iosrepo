#import <Foundation/Foundation.h>
// One serialized instance of the original library, as in the Android process.
@interface TLOriginalRuntime:NSObject
@property(nonatomic,copy) void (^update)(NSDictionary *state);
@property(nonatomic,copy) void (^measurementReady)(NSDictionary *state);
- (id)call:(NSString*)method arguments:(NSArray*)arguments;
- (void)configureNote:(int)note partial:(int)partial target:(float)target offset:(float)offset;
- (void)process44100PCM:(const int16_t*)samples count:(NSUInteger)count;
- (void)resetInputStream;
- (NSDictionary*)diagnostics;
- (void)setPhaseSpeed:(float)speed;
- (void)setPartials:(NSArray<NSNumber*>*)partials combined:(BOOL)combined;
- (void)beginMeasurement;
- (void)cancelMeasurement;
@end
