#import "Common.h"
#import "ProfileUI.h"

@implementation ShadeProfileSettings
- (instancetype)initWithBundle:(NSString *)bundle name:(NSString *)name {
    if((self=[super initWithStyle:UITableViewStyleInsetGrouped])) {
        self.bundle=bundle;self.appName=name;self.pending=[NSMutableDictionary new];
    }
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=self.appName;
    self.profile=SBProfile(SBRead(),self.bundle);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillResign:) name:UIApplicationWillResignActiveNotification object:nil];
}
- (void)appWillResign:(NSNotification *)notification {[self flushPending];}
- (void)viewWillDisappear:(BOOL)animated {[self flushPending];[super viewWillDisappear:animated];}
- (void)dealloc {[[NSNotificationCenter defaultCenter] removeObserver:self];[self.saveTimer invalidate];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {return 3;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return ((NSInteger[]){2,3,1})[section];}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return @[SBT(@"Rectangle size (%)",@"矩形尺寸（%）"),SBT(@"Color and opacity",@"颜色与不透明度"),SBT(@"Position",@"位置")][section];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Width and height: 1–120% of the current screen. 100% × 20% spans the screen horizontally. Rotation recalculates the size using the new screen dimensions; excess area is allowed off screen.",@"宽高均为当前屏幕的 1–120%。100% × 20% 表示横跨屏幕的条。旋转后按新屏幕尺寸重新计算，允许部分超出屏幕。");
    if(section==1) return SBT(@"Saved automatically for this app only. Width, height, color and opacity are shared between its portrait and landscape views. Zero opacity is invisible.",@"自动保存，仅影响此应用。此应用的横竖屏共用宽高比例、颜色和不透明度。不透明度为 0 时不可见。");
    return [NSString stringWithFormat:@"%@\n%@",SBT(@"Drag the bar freely, including completely off screen. Portrait and landscape remember their positions separately. Reset centers both without changing size or appearance.",@"遮挡条可自由拖动，包括完全拖出屏幕。横竖屏分别记住位置。重置使两种方向都居中，保留尺寸与外观。"),self.bundle];
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)index {return index.section==0 || (index.section==1 && index.row==2)?86:UITableViewAutomaticDimension;}
- (UITableViewCell *)sliderCell:(UITableView *)table field:(NSString *)field title:(NSString *)title {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle=UITableViewCellSelectionStyleNone;
    CGFloat width=cell.contentView.bounds.size.width-32;
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(16,7,width,25)];label.tag=101;
    label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];label.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    [cell.contentView addSubview:label];
    UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(16,38,width,32)];
    slider.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    slider.minimumValue=[field isEqual:@"opacity"]?0:1;
    slider.maximumValue=[field isEqual:@"opacity"]?100:120;
    slider.value=100*SBNumber(self.profile,field,[field isEqual:@"width"]?.8:[field isEqual:@"height"]?.2:1);
    slider.accessibilityIdentifier=field;slider.accessibilityLabel=title;
    slider.continuous=YES;
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [slider addTarget:self action:@selector(sliderFinished:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [cell.contentView addSubview:slider];
    [self updateSliderLabel:slider];return cell;
}
- (void)updateSliderLabel:(UISlider *)slider {
    UILabel *label=(UILabel *)[slider.superview viewWithTag:101];
    label.text=[NSString stringWithFormat:@"%@: %.1f%%",slider.accessibilityLabel,slider.value];
    slider.accessibilityValue=[NSString stringWithFormat:@"%.1f%%",slider.value];
}
- (void)sliderChanged:(UISlider *)slider {
    slider.value=roundf(slider.value*10)/10;
    [self updateSliderLabel:slider];
    NSString *field=slider.accessibilityIdentifier;
    self.pending[field]=@(slider.value/100.0);
    NSMutableDictionary *updated=[self.profile mutableCopy];updated[field]=self.pending[field];self.profile=updated;
    [self.saveTimer invalidate];
    __weak typeof(self) weak=self;
    self.saveTimer=[NSTimer scheduledTimerWithTimeInterval:.12 repeats:NO block:^(NSTimer *timer){[weak flushPending];}];
}
- (void)sliderFinished:(UISlider *)slider {[self flushPending];}
- (void)flushPending {
    [self.saveTimer invalidate];self.saveTimer=nil;
    if(!self.pending.count) return;
    if(SBWriteProfile(self.bundle,self.pending)) [self.pending removeAllObjects];
    else [self showError:SBT(@"Could not save this application's settings.",@"无法保存此应用的设置。")];
}
- (void)saveChanges:(NSDictionary *)changes {
    [self.pending addEntriesFromDictionary:changes];[self flushPending];
    NSMutableDictionary *updated=[SBProfile(SBRead(),self.bundle) mutableCopy];
    [updated addEntriesFromDictionary:self.pending];self.profile=updated;
    [self.tableView reloadData];
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    if(index.section==0) return [self sliderCell:table field:index.row==0?@"width":@"height" title:index.row==0?SBT(@"Width",@"宽度"):SBT(@"Height",@"高度")];
    if(index.section==1 && index.row==2) return [self sliderCell:table field:@"opacity" title:SBT(@"Opacity",@"不透明度")];
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];cell.textLabel.numberOfLines=0;
    if(index.section==1 && index.row==0) {
        cell.textLabel.text=SBT(@"Choose color",@"选择颜色");
        UIView *swatch=[[UIView alloc] initWithFrame:CGRectMake(0,0,32,24)];swatch.backgroundColor=SBColor(self.profile);cell.accessoryView=swatch;
    } else if(index.section==1) {cell.textLabel.text=SBT(@"Color HEX",@"颜色 HEX");cell.detailTextLabel.text=self.profile[@"color"];}
    else {cell.textLabel.text=SBT(@"Reset position to screen center",@"重置位置到屏幕正中央");cell.textLabel.textColor=UIColor.systemBlueColor;}
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];
    if(index.section==2) {
        [self saveChanges:@{@"portrait.cx":@.5,@"portrait.cy":@.5,@"landscape.cx":@.5,@"landscape.cy":@.5}];return;
    }
    if(index.section==1 && index.row==0) {
        UIColorPickerViewController *picker=[UIColorPickerViewController new];picker.delegate=self;picker.supportsAlpha=NO;picker.selectedColor=SBColor(self.profile);
        [self presentViewController:picker animated:YES completion:nil];return;
    }
    if(index.section!=1 || index.row!=1) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:SBT(@"Color HEX",@"颜色 HEX") message:SBT(@"Six hexadecimal digits, such as FF0000.",@"六位十六进制颜色，例如 FF0000。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.text=self.profile[@"color"];field.autocorrectionType=UITextAutocorrectionTypeNo;field.keyboardType=UIKeyboardTypeASCIICapable;}];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Cancel",@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Save",@"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *text=[[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByReplacingOccurrencesOfString:@"#" withString:@""];
        unsigned value;NSScanner *scan=[NSScanner scannerWithString:text];
        if(text.length==6 && [scan scanHexInt:&value] && scan.isAtEnd) [self saveChanges:@{@"color":text.uppercaseString}];
        else [self showError:SBT(@"Enter a six-digit HEX color.",@"请输入六位 HEX 颜色。")];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker {
    CGFloat r=0,g=0,b=0,a=1;[picker.selectedColor getRed:&r green:&g blue:&b alpha:&a];
    [self saveChanges:@{@"color":[NSString stringWithFormat:@"%02X%02X%02X",(unsigned)lround(r*255),(unsigned)lround(g*255),(unsigned)lround(b*255)]}];
}
- (void)showError:(NSString *)message {
    if(self.presentedViewController) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:SBT(@"Settings",@"设置") message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"OK",@"好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
