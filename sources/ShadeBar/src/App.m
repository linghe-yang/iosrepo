#import "Common.h"
#import "Private.h"
#import <dlfcn.h>

#import "ProfileUI.h"

@interface ShadeAppList : UITableViewController <UISearchResultsUpdating>
@property(nonatomic,strong) NSArray<NSDictionary *> *apps,*filtered;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic) BOOL configureProfiles;
@end
@interface ShadeAppSettings : UITableViewController
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) NSTimer *statusTimer;
@end

@implementation ShadeAppList
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=self.configureProfiles?SBT(@"Configure applications",@"配置应用"):SBT(@"Choose applications",@"选择显示应用");
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
                NSString *bundle=[app bundleIdentifier]; if(!bundle.length || [bundle isEqual:@"com.linghe.shadebar.app"]) continue;
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
    cell.accessoryType=self.configureProfiles?UITableViewCellAccessoryDisclosureIndicator:([selected isKindOfClass:NSArray.class] && [selected containsObject:app[@"id"]])?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
    return cell;
}
- (void)selectBundle:(NSString *)bundle {
    id current=SBRead()[@"apps"];
    NSMutableSet *selected=[NSMutableSet setWithArray:[current isKindOfClass:NSArray.class]?current:@[]];
    if([selected containsObject:bundle]) [selected removeObject:bundle]; else [selected addObject:bundle];
    SBWrite(@{@"apps":[selected.allObjects sortedArrayUsingSelector:@selector(compare:)]}); [self.tableView reloadData];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    NSDictionary *app=self.filtered[index.row];
    if(self.configureProfiles) [self.navigationController pushViewController:[[ShadeProfileSettings alloc] initWithBundle:app[@"id"] name:app[@"name"]] animated:YES];
    else [self selectBundle:app[@"id"]];
    [table deselectRowAtIndexPath:index animated:YES];
}
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
    [super viewDidLoad];self.title=SBT(@"ShadeBar",@"遮挡条");
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:SBT(@"Diagnostics",@"诊断") style:UIBarButtonItemStylePlain target:self action:@selector(exportDiagnostics)];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];[self refresh];
    __weak typeof(self) weak=self;
    self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:2 repeats:YES block:^(NSTimer *timer){[weak refresh];}];
}
- (void)viewWillDisappear:(BOOL)animated {[super viewWillDisappear:animated];[self.statusTimer invalidate];self.statusTimer=nil;}
- (void)refresh {self.settings=SBRead();[self.tableView reloadData];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {return 3;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return ((NSInteger[]){4,3,1})[section];}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return @[SBT(@"Display",@"显示"),SBT(@"Per-app settings",@"逐应用设置"),SBT(@"Diagnostics",@"诊断")][section];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Enable after each SpringBoard restart. Drag the rectangle to move it, including off screen. It hides on the lock screen and in this settings app.",@"每次重新加载 SpringBoard 后手动启用。用手指拖动矩形条，可拖出屏幕。锁屏和本设置 App 内隐藏。");
    if(section==1) return SBT(@"Choose which apps may show the bar, then configure each app's size, color, opacity and centered reset. Settings persist across app launches. An empty enabled allowlist shows nothing.",@"先选择允许显示的应用，再逐个配置尺寸、颜色、不透明度和居中重置。设置会保存，下次打开应用自动恢复。开启名单后，空名单不显示。");
    return SBT(@"Diagnostics include display decisions and the most recent foreground app identifier, but not your full application list.",@"诊断包含显示判断和最近前台应用的包标识，不包含完整应用名单。");
}
- (NSString *)displayText {
    NSDictionary *display=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/display.plist"];
    if([display[@"reason"] isEqual:@"configuring"]) display=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/last-target.plist"]?:display;
    NSDictionary *names=@{@"disabled":SBT(@"Disabled",@"总开关已关闭"),@"locked":SBT(@"Hidden while locked",@"锁屏隐藏"),@"lockUnknown":SBT(@"Cannot read lock state",@"无法读取锁屏状态"),@"frontUnknown":SBT(@"Cannot identify foreground app",@"无法识别前台应用"),@"notSelected":SBT(@"Foreground app not selected",@"前台应用未勾选"),@"configuring":SBT(@"Hidden in settings; open a target app",@"设置中隐藏，请打开目标应用"),@"offscreen":SBT(@"Off screen; reset this app position",@"已在屏幕外，请重置此应用的位置"),@"transparent":SBT(@"Opacity is zero",@"不透明度为零"),@"visible":SBT(@"Window requested visible",@"窗口已请求显示"),@"error":SBT(@"Display error; export diagnostics",@"显示异常，请导出诊断")};
    NSString *text=names[display[@"reason"]?:@""]?:SBT(@"No display report yet",@"尚未收到显示报告");
    NSString *bundle=[display[@"bundle"] isKindOfClass:NSString.class]?display[@"bundle"]:nil;
    return bundle.length?[NSString stringWithFormat:@"%@\n%@",text,bundle]:text;
}
- (NSString *)statusText {
    NSDictionary *status=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/status.plist"];
    NSString *state=status[@"state"];
    NSDictionary *names=@{@"ready":SBT(@"Ready to enable",@"等待启用"),@"loading":SBT(@"Starting overlay…",@"正在启动遮挡层…"),@"running":SBT(@"Overlay loaded",@"遮挡层已加载"),@"failed":SBT(@"Start failed — export diagnostics",@"启动失败，请导出诊断"),@"guarded":SBT(@"Previous start failed",@"上次启动异常")};
    return names[state?:@""]?:SBT(@"Restart SpringBoard after installing",@"安装后请重新加载 SpringBoard");
}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    NSInteger section=index.section,row=index.row;
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    NSString *key=nil;
    if(section==0) {
        if(row==0) {cell.textLabel.text=SBT(@"Enable overlay",@"启用遮挡层");key=@"enabled";}
        if(row==1) {cell.textLabel.text=[self statusText];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
        if(row==2) {cell.textLabel.text=[self displayText];cell.selectionStyle=UITableViewCellSelectionStyleNone;}
        if(row==3) {cell.textLabel.text=SBT(@"Retry starting overlay",@"重新启动遮挡层");cell.textLabel.textColor=UIColor.systemBlueColor;}
    } else if(section==1) {
        if(row==0) {cell.textLabel.text=SBT(@"Only selected apps",@"仅在指定应用显示");key=@"restricted";}
        if(row==1) {cell.textLabel.text=SBT(@"Choose applications",@"选择显示应用");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
        if(row==2) {cell.textLabel.text=SBT(@"Configure each application's bar",@"设置各应用的遮挡条");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    } else {cell.textLabel.text=SBT(@"Export diagnostics",@"导出诊断信息");cell.textLabel.textColor=UIColor.systemBlueColor;}
    if(key) {UISwitch *control=[UISwitch new];control.accessibilityIdentifier=key;control.on=SBBool(self.settings,key,NO);[control addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;}
    cell.textLabel.numberOfLines=0;return cell;
}
- (void)toggle:(UISwitch *)control {
    NSString *key=control.accessibilityIdentifier;
    if(!SBWrite(@{key:@(control.on)})) {[self showSaveError];[self refresh];return;}
    if([key isEqual:@"enabled"] && control.on) notify_post("com.linghe.shadebar.start");
    [self refresh];
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];
    if(index.section==0 && index.row==3) {
        if(SBWrite(@{@"enabled":@YES})) notify_post("com.linghe.shadebar.start");else [self showSaveError];
        [self refresh];return;
    }
    if(index.section==1 && index.row>=1) {
        ShadeAppList *list=[[ShadeAppList alloc] initWithStyle:UITableViewStyleInsetGrouped];
        list.configureProfiles=index.row==2;
        [self.navigationController pushViewController:list animated:YES];return;
    }
    if(index.section==2) [self exportDiagnostics];
}
- (void)showSaveError {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:SBT(@"Could not save",@"无法保存设置") message:SBT(@"The shared settings file could not be written. Export diagnostics and reinstall the package.",@"无法写入共享设置文件。请导出诊断信息并重新安装软件包。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"OK",@"好") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)exportDiagnostics {
    NSMutableDictionary *report=[NSMutableDictionary new];
    report[@"version"]=@"0.3.0~beta1";
    report[@"system"]=UIDevice.currentDevice.systemVersion;
    report[@"status"]=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/status.plist"]?:@{};
    report[@"display"]=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/display.plist"]?:@{};
    report[@"lastTarget"]=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/last-target.plist"]?:@{};
    report[@"sharedSettingsExists"]=@([[NSFileManager defaultManager] fileExistsAtPath:@SB_SETTINGS]);
    report[@"enabled"]=@(SBBool(SBRead(),@"enabled",NO));
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
