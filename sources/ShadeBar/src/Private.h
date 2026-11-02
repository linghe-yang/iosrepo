#import <UIKit/UIKit.h>
@interface UIApplication (ShadeBarPrivate)
- (id)_accessibilityFrontMostApplication;
@end
@interface NSObject (ShadeBarPrivate)
- (NSString *)bundleIdentifier;
+ (instancetype)sharedInstance;
+ (instancetype)defaultWorkspace;
- (BOOL)isUILocked;
- (NSArray *)allInstalledApplications;
- (NSString *)localizedName;
- (NSString *)applicationType;
@end
@interface FBSOrientationUpdate : NSObject
@property(nonatomic,readonly) NSInteger orientation;
@end
@interface FBSOrientationObserver : NSObject
@property(nonatomic,readonly) NSInteger activeInterfaceOrientation;
- (void)setHandler:(void (^)(FBSOrientationUpdate *))handler;
- (void)invalidate;
@end
