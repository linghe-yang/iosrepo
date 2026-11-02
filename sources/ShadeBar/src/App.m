#import "Common.h"
#import "Private.h"
#import <dlfcn.h>

#import "ProfileUI.h"

@interface ShadeAppList : UITableViewController <UISearchResultsUpdating, UISearchBarDelegate>
@property(nonatomic,strong) NSArray<NSDictionary *> *apps,*filtered;
@property(nonatomic,strong) UISearchController *search;
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) NSCache<NSString *,UIImage *> *icons;
@end
@interface ShadeAppSettings : UITableViewController
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) NSTimer *statusTimer;
@end

@implementation ShadeAppList
- (void)viewDidLoad {
    [super viewDidLoad]; self.title=SBT(@"Applications",@"应用列表");self.icons=[NSCache new];self.icons.countLimit=160;self.settings=SBRead();
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addBundle)];
    self.search=[[UISearchController alloc] initWithSearchResultsController:nil];
    self.search.searchResultsUpdater=self; self.search.obscuresBackgroundDuringPresentation=NO;
    self.navigationItem.searchController=self.search; self.definesPresentationContext=YES;
    self.navigationItem.hidesSearchBarWhenScrolling=NO;
    self.search.searchBar.placeholder=SBT(@"Search name or bundle ID",@"搜索名称或包标识");
    self.search.searchBar.autocapitalizationType=UITextAutocapitalizationTypeNone;
    self.search.searchBar.autocorrectionType=UITextAutocorrectionTypeNo;
    self.search.searchBar.scopeButtonTitles=@[SBT(@"All",@"全部"),SBT(@"Enabled",@"已启用")];
    self.search.searchBar.showsScopeBar=YES;self.search.searchBar.delegate=self;
    self.tableView.keyboardDismissMode=UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight=68;
    [self loadApps];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];self.settings=SBRead();
    [self updateSearchResultsForSearchController:self.search];
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
    id selected=self.settings[@"apps"];
    if([selected isKindOfClass:NSArray.class]) for(id bundle in selected)
        if([bundle isKindOfClass:NSString.class] && !names[bundle]) names[bundle]=bundle;
    // Keep manually added apps discoverable even when their switch is off.
    for(NSString *key in self.settings) {
        if([key hasPrefix:@"profile."] && [key hasSuffix:@".enabled"] && key.length>16) {
            NSString *bundle=[key substringWithRange:NSMakeRange(8,key.length-16)];
            if(!names[bundle]) names[bundle]=bundle;
        }
    }
    [names removeObjectForKey:@"com.linghe.shadebar.app"];
    NSMutableArray *items=[NSMutableArray new];
    for(NSString *bundle in names) [items addObject:@{@"id":bundle,@"name":names[bundle]}];
    [items sortUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];}];
    self.apps=items; [self updateSearchResultsForSearchController:self.search];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)search {
    NSString *query=[(search.searchBar.text?:@"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL enabledOnly=search.searchBar.selectedScopeButtonIndex==1;
    self.filtered=[self.apps filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDictionary *app,NSDictionary *bindings){
        BOOL matches=!query.length || [app[@"name"] localizedCaseInsensitiveContainsString:query] || [app[@"id"] localizedCaseInsensitiveContainsString:query];
        return matches && (!enabledOnly || SBApplicationEnabled(self.settings,app[@"id"]));
    }]];
    UILabel *empty=[UILabel new];empty.text=SBT(@"No matching applications",@"没有匹配的应用");empty.textAlignment=NSTextAlignmentCenter;empty.textColor=UIColor.secondaryLabelColor;
    self.tableView.backgroundView=self.filtered.count?nil:empty;
    [self.tableView reloadData];
}
- (void)searchBar:(UISearchBar *)searchBar selectedScopeButtonIndexDidChange:(NSInteger)selectedScope {
    [self updateSearchResultsForSearchController:self.search];
}
- (UIImage *)iconForBundle:(NSString *)bundle {
    UIImage *cached=[self.icons objectForKey:bundle];if(cached) return cached;
    UIImage *icon=nil;
    if([bundle isEqual:@"com.apple.springboard"]) icon=[UIImage systemImageNamed:@"house.fill"];
    else @try {
        if([UIImage respondsToSelector:@selector(_applicationIconImageForBundleIdentifier:format:scale:)])
            icon=[UIImage _applicationIconImageForBundleIdentifier:bundle format:1 scale:UIScreen.mainScreen.scale];
    } @catch(NSException *exception) { /* Missing/system-only icons fall back below. */ }
    if(!icon) icon=[UIImage systemImageNamed:@"app"];
    if(icon.renderingMode==UIImageRenderingModeAlwaysTemplate || [bundle isEqual:@"com.apple.springboard"])
        icon=[icon imageWithTintColor:UIColor.systemBlueColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *source=icon;
    UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(40,40)];
    UIImage *sized=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){[source drawInRect:CGRectMake(0,0,40,40)];}];
    [self.icons setObject:sized forKey:bundle];return sized;
}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return self.filtered.count;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    UITableViewCell *cell=[table dequeueReusableCellWithIdentifier:@"application"];
    if(!cell) cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"application"];
    NSDictionary *app=self.filtered[index.row];BOOL enabled=SBApplicationEnabled(self.settings,app[@"id"]);
    cell.textLabel.text=app[@"name"];
    cell.detailTextLabel.text=[NSString stringWithFormat:@"%@ · %@",enabled?SBT(@"Enabled",@"已启用"):SBT(@"Disabled",@"未启用"),app[@"id"]];
    cell.detailTextLabel.textColor=enabled?UIColor.systemGreenColor:UIColor.secondaryLabelColor;
    cell.imageView.image=[self iconForBundle:app[@"id"]];cell.imageView.layer.cornerRadius=8;cell.imageView.clipsToBounds=YES;
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    NSDictionary *app=self.filtered[index.row];
    [self.navigationController pushViewController:[[ShadeProfileSettings alloc] initWithBundle:app[@"id"] name:app[@"name"]] animated:YES];
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
            if([bundle isEqual:@"com.linghe.shadebar.app"]) return;
            NSDictionary *settings=SBRead();
            if(!settings[SBProfileKey(bundle,@"enabled")] && !SBWriteProfile(bundle,@{@"enabled":@(SBApplicationEnabled(settings,bundle))})) return;
            self.settings=SBRead();[self loadApps];
            [self.navigationController pushViewController:[[ShadeProfileSettings alloc] initWithBundle:bundle name:bundle] animated:YES];
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
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return ((NSInteger[]){4,1,1})[section];}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {
    return @[SBT(@"Display",@"显示"),SBT(@"Per-app settings",@"逐应用设置"),SBT(@"Diagnostics",@"诊断")][section];
}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Enable after each SpringBoard restart. Drag the rectangle to move it, including off screen. It hides on the lock screen and in this settings app.",@"每次重新加载 SpringBoard 后手动启用。用手指拖动矩形条，可拖出屏幕。锁屏和本设置 App 内隐藏。");
    if(section==1) return SBT(@"Open Applications to search by name or bundle ID. Each app has its own enable switch, size, color and position settings. Turning an app off keeps its settings.",@"进入应用列表，可搜索名称或包标识。每个应用的设置页有独立启用开关、尺寸、颜色和位置设置。关闭开关仍保留配置。");
    return SBT(@"Diagnostics include display decisions and the most recent foreground app identifier, but not your full application list.",@"诊断包含显示判断和最近前台应用的包标识，不包含完整应用名单。");
}
- (NSString *)displayText {
    NSDictionary *display=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/display.plist"];
    if([display[@"reason"] isEqual:@"configuring"]) display=[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/ShadeBar/last-target.plist"]?:display;
    NSDictionary *names=@{@"disabled":SBT(@"Disabled",@"总开关已关闭"),@"switcher":SBT(@"Hidden in app switcher",@"多任务预览中隐藏"),@"locked":SBT(@"Hidden while locked",@"锁屏隐藏"),@"lockUnknown":SBT(@"Cannot read lock state",@"无法读取锁屏状态"),@"frontUnknown":SBT(@"Cannot identify foreground app",@"无法识别前台应用"),@"notSelected":SBT(@"Overlay disabled for this app",@"该应用未启用遮挡条"),@"configuring":SBT(@"Hidden in settings; open a target app",@"设置中隐藏，请打开目标应用"),@"offscreen":SBT(@"Off screen; reset this app position",@"已在屏幕外，请重置此应用的位置"),@"barHidden":SBT(@"Shade bar hidden; restore from floating icon or app",@"遮挡条已隐藏，可从悬浮图标或 App 恢复"),@"transparent":SBT(@"Opacity is zero",@"不透明度为零"),@"visible":SBT(@"Window requested visible",@"窗口已请求显示"),@"error":SBT(@"Display error; export diagnostics",@"显示异常，请导出诊断")};
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
        cell.textLabel.text=SBT(@"Applications",@"应用列表");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
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
    if(index.section==1) {
        ShadeAppList *list=[[ShadeAppList alloc] initWithStyle:UITableViewStyleInsetGrouped];
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
    report[@"version"]=@"0.6.0~beta1";
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
