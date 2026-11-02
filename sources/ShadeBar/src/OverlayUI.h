#import <UIKit/UIKit.h>

@interface ShadeFloatingIcon : UIView
@end

@interface ShadeQuickPanel : UIScrollView
@property(nonatomic,copy) void (^change)(NSDictionary *changes,BOOL finished);
@property(nonatomic,copy) void (^dismiss)(void);
- (void)updateProfile:(NSDictionary *)profile;
- (void)showSaveFailure;
@end
