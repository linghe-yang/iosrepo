#import <UIKit/UIKit.h>
@interface UIImage (ShadeBarApplicationIcons)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundle format:(NSUInteger)format scale:(CGFloat)scale;
@end
@interface UIApplication (ShadeBarPrivate)
- (id)_accessibilityFrontMostApplication;
- (UIInterfaceOrientation)activeInterfaceOrientation;
- (BOOL)isLocked;
- (BOOL)isShowingHomescreen;
@end
@interface NSObject (ShadeBarPrivate)
- (NSString *)bundleIdentifier;
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
- (BOOL)isAnySwitcherVisible;
- (BOOL)isMainSwitcherVisible;
+ (instancetype)defaultWorkspace;
- (BOOL)isUILocked;
- (BOOL)isLockScreenVisible;
- (NSArray *)allInstalledApplications;
- (NSString *)localizedName;
- (NSString *)applicationType;
@end
