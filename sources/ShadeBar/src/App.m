#import "Common.h"
#import "Private.h"
#import <dlfcn.h>

@interface ShadeAppList : UITableViewController <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<NSDictionary *> *apps,*filtered;
@property(nonatomic,strong) UISearchController *search;
@end
@interface ShadeAppSettings : UITableViewController <UIColorPickerViewControllerDelegate>
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) NSTimer *statusTimer;
@end

@implementation ShadeAppList
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=SBT(@"Applications",@"应用名单");
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addBundle)];
    self.search=[[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater=self; self.search.obscuresBackgroundDuringPresentation=NO;
    self.navigationItem.searchController=self.search; self.definesPresentationContext=YES;
    [self loadApps];
}
- (void)loadApps {
    NSMutableDictionary *names=[@{@"com.apple.springboard":SBT(@"Home Screen",@"主屏幕")} mutableCopy];
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY);
    @try {
        Class cls=NSClassFromString(@"LSApplicationWorkspace");
        id workspace=[cls respondsToSelector:@selector(defaultWorkspace)]?[cls defaultWorkspace]:nil;
        if([workspace respondsToSelector:@selector(allInstalledApplications)]) {
            for(id app in [workspace allInstalledApplications]) {
                if(![app respondsToSelector:@selector(bundleIdentifier)]) continue;
                NSString *bundle=[app bundleIdentifier]; if(!bundle.length) continue;
                NSString *name=[app respondsToSelector:@selector(localizedName)]?[app localizedName]:nil;
                names[bundle]=name.length?name:bundle;
            }
        }
    } @catch(NSException *e) { NSLog(@"[ShadeBar App] App list: %@",e.name); }
    id selected=SBRead()[@"apps"];
    if([selected isKindOfClass:NSArray.class]) for(id bundle in selected)
        if([bundle isKindOfClass:NSString.class] && !names[bundle]) names[bundle]=bundle;
    NSMutableArray *items=[NSMutableArray new];
    for(NSString *bundle in names) [items addObject:@{@"id":bundle,@"name":names[bundle]}];
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
    self.apps=items; [self updateSearchResultsForSearchController:self.search];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSString *query=search.searchBar.text?:@"";
    self.filtered=query.length?[self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *a,NSDictionary *bindings){ return [a[@"name"] localizedCaseInsensitiveContainsString:query] || [a[@"id"] localizedCaseInsensitiveContainsString:query]; }]]:self.apps;
    [self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return self.filtered.count;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    NSDictionary *app=self.filtered[index.row]; cell.textLabel.text=app[@"name"]; cell.detailTextLabel.text=app[@"id"];
    id selected=SBRead()[@"apps"];
    cell.accessoryType=([selected isKindOfClass:NSArray.class] && [selected containsObject:app[@"id"]])?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
    return cell;
}
- (void)selectBundle:(NSString *)bundle {
    id current=SBRead()[@"apps"];
    NSMutableSet *selected=[NSMutableSet setWithArray:[current isKindOfClass:NSArray.class]?current:@[]];
    if([selected containsObject:bundle]) [selected removeObject:bundle]; else [selected addObject:bundle];
    SBWrite(@{@"apps":[selected.allObjects sortedArrayUsingSelector:@selector(compare:)]}); [self.tableView reloadData];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index { [self selectBundle:self.filtered[index.row][@"id"]]; [table deselectRowAtIndexPath:index animated:YES]; }
- (void)addBundle {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:SBT(@"Bundle identifier",@"应用包标识") message:@"com.example.app" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.autocorrectionType=UITextAutocorrectionTypeNo; field.autocapitalizationType=UITextAutocapitalizationTypeNone;}];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Cancel",@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Add",@"添加") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *bundle=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSCharacterSet *valid=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
        if(bundle.length && [bundle rangeOfCharacterFromSet:valid.invertedSet].location==NSNotFound) {
            id old=SBRead()[@"apps"]; NSMutableSet *set=[NSMutableSet setWithArray:[old isKindOfClass:NSArray.class]?old:@[]];
            [set addObject:bundle]; SBWrite(@{@"apps":set.allObjects}); [self loadApps];
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

@implementation ShadeAppSettings
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=SBT(@"ShadeBar",@"遮挡条");
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:SBT(@"Diagnostics",@"诊断") style:UIBarButtonItemStylePlain target:self action:@selector(exportDiagnostics)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; [self refresh];
    __weak typeof(self) weak=self;
    self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){[weak refresh];}];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.statusTimer invalidate]; self.statusTimer=nil; }
- (void)refresh { self.settings=SBRead(); [self.tableView reloadData]; }
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {return 6;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return ((NSInteger[]){4,2,3,4,4,2})[section];}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return @[SBT(@"Display",@"显示"),SBT(@"Applications",@"应用范围"),SBT(@"Appearance",@"外观"),SBT(@"Portrait (%)",@"竖屏位置与尺寸（%）"),SBT(@"Landscape (%)",@"横屏位置与尺寸（%）"),SBT(@"Recovery",@"恢复与状态")][section];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Enable manually after each SpringBoard restart. Drag the blue handles in edit mode, then tap Lock. Lock screen is hidden.",@"每次重新加载 SpringBoard 后需要手动启用。编辑时拖动蓝色手柄，完成后点“锁定”。锁屏时自动隐藏。");
    if(section==1) return SBT(@"Only the selected foreground app can show the bar. An empty list shows nothing. On split screen, the focused app decides.",@"开启名单后，仅在选中的前台应用中显示；空名单不显示。分屏时按焦点应用判断。");
    if(section==2) return SBT(@"Opacity 0 is transparent, 1 is opaque. Edit handles remain visible at zero opacity.",@"不透明度 0 为透明，1 为完全遮挡。透明时编辑手柄仍可见。");
    if(section==3 || section==4) return SBT(@"Position and size are percentages of screen dimensions. The bar is constrained to stay on screen.",@"位置与尺寸按屏幕百分比输入，超出屏幕的部分会自动修正。");
    return SBT(@"The desktop app and the overlay start separately. Export diagnostics if starting the overlay fails.",@"桌面 App 和遮挡层分别启动。遮挡层启动失败时，可导出诊断信息。");
}
- (NSString *)statusText {
    NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/status.plist"];
    NSString *state=status[@"state"];
    NSDictionary *names=@{@"ready":SBT(@"Ready to enable",@"等待启用"),@"loading":SBT(@"Starting overlay…",@"正在启动遮挡层…"),@"running":SBT(@"Overlay loaded",@"遮挡层已加载"),@"failed":SBT(@"Start failed — export diagnostics",@"启动失败，请导出诊断"),@"guarded":SBT(@"Previous start failed",@"上次启动异常")};
    return names[state]?:SBT(@"Restart SpringBoard after installing",@"安装后请重新加载 SpringBoard");
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    NSInteger section=index.section,row=index.row;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    NSString *key=nil; BOOL fallback=NO;
    if(section==0) {
        if(row==0) {cell.textLabel.text=SBT(@"Enable overlay",@"启用遮挡层");key=@"enabled";}
        if(row==1) {cell.textLabel.text=SBT(@"Edit mode",@"编辑模式");key=@"editing";fallback=YES;}
        if(row==2) {cell.textLabel.text=SBT(@"Pass touches through when locked",@"锁定后触摸穿透");key=@"passthrough";fallback=YES;}
        if(row==3) {cell.textLabel.text=[self statusText];cell.textLabel.numberOfLines=0;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
    } else if(section==1) {
        if(row==0) {cell.textLabel.text=SBT(@"Only selected apps",@"仅在指定应用显示");key=@"restricted";}
        else {cell.textLabel.text=SBT(@"Choose applications",@"选择应用");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    } else if(section==2) {
        cell.textLabel.text=@[SBT(@"Choose color",@"选择颜色"),SBT(@"Color HEX",@"颜色 HEX"),SBT(@"Opacity",@"不透明度")][row];
        if(row==0) {UIView *swatch=[[UIView alloc] initWithFrame:CGRectMake(0,0,32,24)];swatch.backgroundColor=SBColor(self.settings);swatch.layer.cornerRadius=5;cell.accessoryView=swatch;}
        if(row==1) cell.detailTextLabel.text=self.settings[@"color"]?:@"000000";
        if(row==2) cell.detailTextLabel.text=[NSString stringWithFormat:@"%.2f",SBNumber(self.settings,@"opacity",1)];
    } else if(section==3 || section==4) {
        cell.textLabel.text=@[SBT(@"Left",@"左侧位置"),SBT(@"Top",@"顶部位置"),SBT(@"Width",@"宽度"),SBT(@"Height",@"高度")][row];
        NSString *p=section==3?@"portrait":@"landscape";
        NSString *k=[NSString stringWithFormat:@"%@.%@",p,@[@"x",@"y",@"w",@"h"][row]];
        cell.detailTextLabel.text=[NSString stringWithFormat:@"%.1f",100*SBNumber(self.settings,k,((double[]){.1,.35,.8,.12})[row])];
    } else {
        cell.textLabel.text=row==0?SBT(@"Reset positions and edit",@"重置位置并进入编辑模式"):SBT(@"Export diagnostics",@"导出诊断信息");
        cell.textLabel.textColor=UIColor.systemBlueColor;
    }
    if(key) {UISwitch *control=[UISwitch new];control.accessibilityIdentifier=key;control.on=SBBool(self.settings,key,fallback);[control addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
    cell.textLabel.numberOfLines=0;return cell;
}
- (void)toggle:(UISwitch *)control {
    NSString *key=control.accessibilityIdentifier;
    SBWrite(@{key:@(control.on)});
    if([key isEqual:@"enabled"] && control.on) notify_post("com.linghe.shadebar.start");
    [self refresh];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES]; NSInteger section=index.section,row=index.row;
    if(section==1 && row==1) {[self.navigationController pushViewController:[[ShadeAppList alloc] initWithStyle:UITableViewStyleInsetGrouped] animated:YES];return;}
    if(section==2 && row==0) {UIColorPickerViewController *picker=[UIColorPickerViewController new];picker.delegate=self;picker.supportsAlpha=NO;picker.selectedColor=SBColor(self.settings);[self presentViewController:picker animated:YES completion:nil];return;}
    if(section==5 && row==0) {SBWrite(@{@"portrait.x":@.1,@"portrait.y":@.35,@"portrait.w":@.8,@"portrait.h":@.12,@"landscape.x":@.1,@"landscape.y":@.35,@"landscape.w":@.8,@"landscape.h":@.12,@"editing":@YES});[self refresh];return;}
    if(section==5 && row==1) {[self exportDiagnostics];return;}
    NSString *key=nil;NSString *value=nil;NSString *title=[table cellForRowAtIndexPath:index].textLabel.text;
    if(section==2 && row==1) {key=@"color";value=self.settings[key]?:@"000000";}
    if(section==2 && row==2) {key=@"opacity";value=[NSString stringWithFormat:@"%.2f",SBNumber(self.settings,key,1)];}
    if(section==3 || section==4) {key=[NSString stringWithFormat:@"%@.%@",section==3?@"portrait":@"landscape",@[@"x",@"y",@"w",@"h"][row]];value=[table cellForRowAtIndexPath:index].detailTextLabel.text;}
    if(!key) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.text=value;field.autocorrectionType=UITextAutocorrectionTypeNo;field.keyboardType=[key isEqual:@"color"]?UIKeyboardTypeASCIICapable:UIKeyboardTypeDecimalPad;}];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Cancel",@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Save",@"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){
        NSString *text=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];id result=nil;
        if([key isEqual:@"color"]) {text=[text stringByReplacingOccurrencesOfString:@"#" withString:@""];unsigned n;NSScanner *scan=[NSScanner scannerWithString:text];if(text.length==6 && [scan scanHexInt:&n] && scan.isAtEnd) result=text.uppercaseString;}
        else {double n;NSScanner *scan=[NSScanner scannerWithString:text];if([scan scanDouble:&n] && scan.isAtEnd && isfinite(n)) result=@([key isEqual:@"opacity"]?fmax(0,fmin(1,n)):fmax(0,fmin(100,n))/100);}
        if(result) {SBWrite(@{key:result});[self refresh];}
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker {
    CGFloat r=0,g=0,b=0,a=1;[picker.selectedColor getRed:&r green:&g blue:&b alpha:&a];
    SBWrite(@{@"color":[NSString stringWithFormat:@"%02X%02X%02X",(unsigned)lround(r*255),(unsigned)lround(g*255),(unsigned)lround(b*255)]});
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {[self refresh];}
- (void)exportDiagnostics {
    NSMutableDictionary *report=[NSMutableDictionary new];
    report[@"version"]=@"0.2.0~beta1";
    report[@"system"]=UIDevice.currentDevice.systemVersion;
    report[@"status"]=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/status.plist"]?:@{};
    report[@"previousLoadIncomplete"]=@([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/ShadeBar/loading.guard"]);
    NSString *rendererError=[NSString stringWithContentsOfFile:@"/var/mobile/Library/ShadeBar/renderer-error.txt" encoding:NSUTF8StringEncoding error:nil];
    if(rendererError.length) report[@"rendererError"]=rendererError;
    // Do not include the user's application allowlist or unrelated device logs.
    NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"ShadeBar-diagnostics.json"]];
    if(![data writeToURL:url atomically:YES]) return;
    UIActivityViewController *share=[[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    share.popoverPresentationController.barButtonItem=self.navigationItem.rightBarButtonItem;
    [self presentViewController:share animated:YES completion:nil];
}
@end

@interface ShadeAppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation ShadeAppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController=[[UINavigationController alloc] initWithRootViewController:[[ShadeAppSettings alloc] initWithStyle:UITableViewStyleInsetGrouped]];
    [self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv) {@autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(ShadeAppDelegate.class));}}
