#import <UIKit/UIKit.h>
// Only declarations used by this bundle; implementations belong to iOS Preferences.
@interface PSSpecifier : NSObject
@property(nonatomic,copy) NSString *identifier;
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
- (void)setProperty:(id)value forKey:(NSString *)key;
- (id)propertyForKey:(NSString *)key;
- (void)setButtonAction:(SEL)action;
@end
@interface PSViewController : UIViewController
@end
@interface PSListController : PSViewController {
    NSMutableArray *_specifiers;
}
- (NSArray *)specifiers;
- (void)reloadSpecifiers;
@end
