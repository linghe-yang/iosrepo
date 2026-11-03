#import <UIKit/UIKit.h>
// Renderer consumes the frozen original Android resource tree. Activity state and
// original listeners are connected by the controller, never inferred from titles.
@interface TLOriginalLayout : UIView
@property(nonatomic,copy) void (^action)(NSString *viewID,NSString *method);
@property(nonatomic,readonly) NSDictionary<NSString*,UIView*> *viewsByID;
- (instancetype)initWithTree:(NSDictionary*)tree resources:(NSString*)path;
- (void)setText:(NSString*)text forID:(NSString*)viewID;
- (void)setInvisible:(BOOL)invisible forID:(NSString*)viewID; // Android INVISIBLE: retain layout space
@end

// Exact rectangle geometry from PhaseDisplayV.java. Phase values must come from
// the original demodulation algorithm; frequency-error animation is not a substitute.
@interface TLOriginalPhase : UIView
@property(nonatomic) uint16_t phase;
@property(nonatomic) BOOL blanked;
@property(nonatomic,strong) UIColor *beamColor;
@end
