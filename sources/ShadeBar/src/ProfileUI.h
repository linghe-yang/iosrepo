#import <UIKit/UIKit.h>
@interface ShadeProfileSettings : UITableViewController <UIColorPickerViewControllerDelegate>
@property(nonatomic,copy) NSString *bundle,*appName;
@property(nonatomic,strong) NSDictionary *profile;
@property(nonatomic,strong) NSMutableDictionary *pending;
@property(nonatomic,strong) NSTimer *saveTimer;
- (instancetype)initWithBundle:(NSString *)bundle name:(NSString *)name;
@end
