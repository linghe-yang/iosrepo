#import <UIKit/UIKit.h>
@interface UIApplication (ShadeBarPrivate)
- (id)_accessibilityFrontMostApplication;
- (UIInterfaceOrientation)activeInterfaceOrientation;
- (BOOL)isLocked;
- (BOOL)isShowingHomescreen;
@end
@interface NSObject (ShadeBarPrivate)
- (NSString *)bundleIdentifier;
+ (instancetype)sharedInstance;
+ (instancetype)defaultWorkspace;
- (BOOL)isUILocked;
- (BOOL)isLockScreenVisible;
- (NSArray *)allInstalledApplications;
- (NSString *)localizedName;
- (NSString *)applicationType;
@end
