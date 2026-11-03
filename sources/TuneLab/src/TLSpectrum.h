#import <UIKit/UIKit.h>
@class TLOriginalRuntime;
@interface TLSpectrum : UIView
@property(nonatomic,strong) TLOriginalRuntime *runtime;
@property(nonatomic) float target, fundamental;
@property(nonatomic) int zoom, thickness;
@property(nonatomic) BOOL dark;
@property(nonatomic,copy) NSString *intervals;
@property(nonatomic,readonly) float pitchError;
@end
