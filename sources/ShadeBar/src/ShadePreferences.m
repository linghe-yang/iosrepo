#import "Common.h"
#import "Preferences.h"
#import "Private.h"
#import <dlfcn.h>

static PSSpecifier *Group(NSString *name,NSString *footer) {
    PSSpecifier *s=[PSSpecifier preferenceSpecifierNamed:name target:nil set:NULL get:NULL detail:nil cell:0 edit:nil];
    if(footer) [s setProperty:footer forKey:@"footerText"]; return s;
}
@interface ShadeAppsController : PSListController
- (void)reloadApplicationList;
@end
@interface ShadePreferencesController : PSListController <UIColorPickerViewControllerDelegate>
@end

@implementation ShadePreferencesController
- (PSSpecifier *)row:(NSString *)name key:(NSString *)key cell:(NSInteger)cell fallback:(id)fallback {
    PSSpecifier *s=[PSSpecifier preferenceSpecifierNamed:name target:self set:@selector(write:specifier:) get:@selector(read:) detail:nil cell:cell edit:nil];
    [s setProperty:key forKey:@"key"]; [s setProperty:fallback forKey:@"default"];
    if(cell==8) { [s setProperty:@YES forKey:@"noAutoCorrect"]; [s setProperty:@YES forKey:@"isDecimalPad"]; }
    return s;
}
- (NSArray *)specifiers {
    if(_specifiers) return _specifiers;
    self.title=SBT(@"ShadeBar",@"遮挡条");
    NSMutableArray *r=[NSMutableArray new];
    [r addObject:Group(SBT(@"Display",@"显示"),SBT(@"Edit: drag the bar or blue handles, then tap Lock. To edit again, enable Edit mode here. The bar stays hidden on the lock screen.",@"编辑时拖动遮挡条或蓝色手柄，完成后点击“锁定”。再次编辑请打开下面的编辑模式。锁屏时自动隐藏。"))];
    [r addObject:[self row:SBT(@"Enable ShadeBar",@"启用遮挡条") key:@"enabled" cell:6 fallback:@NO]];
    [r addObject:[self row:SBT(@"Edit mode",@"编辑模式") key:@"editing" cell:6 fallback:@YES]];
    [r addObject:[self row:SBT(@"Pass touches through when locked",@"锁定后允许触摸穿透") key:@"passthrough" cell:6 fallback:@YES]];
    [r addObject:Group(SBT(@"Applications",@"应用范围"),SBT(@"When enabled, show only for the selected foreground app. An empty selection shows nothing. On split screen, the focused app decides visibility. Changes may take about 0.2 seconds.",@"打开后，仅在选中的应用处于前台时显示；未选应用时不显示。分屏时以当前焦点应用为准。切换可能有约 0.2 秒延迟。"))];
    [r addObject:[self row:SBT(@"Only selected applications",@"仅在指定应用显示") key:@"restricted" cell:6 fallback:@NO]];
    [r addObject:[PSSpecifier preferenceSpecifierNamed:SBT(@"Choose applications",@"选择应用") target:self set:NULL get:NULL detail:ShadeAppsController.class cell:1 edit:nil]];
    [r addObject:Group(SBT(@"Appearance",@"外观"),SBT(@"Opacity: 0 is invisible, 1 is opaque. Blue edit handles remain visible at zero opacity.",@"不透明度：0 为完全透明，1 为完全遮挡。透明时编辑手柄仍可见。"))];
    PSSpecifier *color=[PSSpecifier preferenceSpecifierNamed:SBT(@"Choose color",@"选择颜色") target:self set:NULL get:NULL detail:nil cell:13 edit:nil];
    [color setButtonAction:@selector(pickColor)]; [r addObject:color];
    PSSpecifier *hex=[self row:SBT(@"Color HEX",@"颜色 HEX") key:@"color" cell:8 fallback:@"000000"];
    [hex setProperty:@NO forKey:@"isDecimalPad"]; [r addObject:hex];
    PSSpecifier *opacity=[self row:SBT(@"Opacity",@"不透明度") key:@"opacity" cell:5 fallback:@1];
    [opacity setProperty:@0 forKey:@"min"]; [opacity setProperty:@1 forKey:@"max"]; [opacity setProperty:@YES forKey:@"showValue"]; [r addObject:opacity];
    for(NSString *p in @[@"portrait",@"landscape"]) {
        BOOL land=[p isEqual:@"landscape"];
        [r addObject:Group(land?SBT(@"Landscape geometry (%)",@"横屏位置与尺寸（%）"):SBT(@"Portrait geometry (%)",@"竖屏位置与尺寸（%）"),SBT(@"Values are percentages of the current screen. Width and height are independent. Coordinates are clamped to keep the bar on screen.",@"数值是屏幕对应方向的百分比。宽度、高度分别调整，超出屏幕的位置会自动修正。"))];
        NSArray *keys=@[@"x",@"y",@"w",@"h"], *names=@[SBT(@"Left",@"左侧位置"),SBT(@"Top",@"顶部位置"),SBT(@"Width",@"宽度"),SBT(@"Height",@"高度")], *defaults=@[@10,@35,@80,@12];
        for(NSUInteger i=0;i<4;i++) {
            PSSpecifier *s=[self row:names[i] key:[NSString stringWithFormat:@"%@.%@",p,keys[i]] cell:8 fallback:defaults[i]];
            [s setProperty:@YES forKey:@"percent"]; [r addObject:s];
        }
    }
    [r addObject:Group(nil,SBT(@"ShadeBar 0.1.0 — device testing build. System Settings remains available even when the bar is hidden.",@"遮挡条 0.1.0：真机测试版。即使遮挡条隐藏，也能在系统设置中重新调整。"))];
    PSSpecifier *reset=[PSSpecifier preferenceSpecifierNamed:SBT(@"Reset both positions and enter edit mode",@"重置横竖屏位置并进入编辑模式") target:self set:NULL get:NULL detail:nil cell:13 edit:nil];
    [reset setButtonAction:@selector(resetPosition)]; [r addObject:reset];
    _specifiers=r; return r;
}
- (id)read:(PSSpecifier *)s {
    id v=SBRead()[[s propertyForKey:@"key"]];
    if([[s propertyForKey:@"percent"] boolValue] && [v respondsToSelector:@selector(doubleValue)]) return @([v doubleValue]*100);
    return v?:[s propertyForKey:@"default"];
}
- (void)write:(id)value specifier:(PSSpecifier *)s {
    NSString *key=[s propertyForKey:@"key"];
    if([key isEqual:@"color"]) {
        NSString *hex=[[value description] stringByReplacingOccurrencesOfString:@"#" withString:@""];
        unsigned n; NSScanner *scan=[NSScanner scannerWithString:hex];
        if(hex.length!=6 || ![scan scanHexInt:&n] || !scan.isAtEnd) { [self reloadSpecifiers]; return; }
        value=hex.uppercaseString;
    } else if([[s propertyForKey:@"percent"] boolValue]) {
        NSScanner *scan=[NSScanner scannerWithString:[value description]]; double n;
        if(![scan scanDouble:&n] || !scan.isAtEnd || !isfinite(n)) { [self reloadSpecifiers]; return; }
        value=@(fmax(0,fmin(100,n))/100);
    } else if([key isEqual:@"opacity"]) value=@(fmax(0,fmin(1,[value doubleValue])));
    SBWrite(@{key:value});
}
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self reloadSpecifiers]; }
- (void)resetPosition {
    SBWrite(@{@"portrait.x":@.1,@"portrait.y":@.35,@"portrait.w":@.8,@"portrait.h":@.12,@"landscape.x":@.1,@"landscape.y":@.35,@"landscape.w":@.8,@"landscape.h":@.12,@"editing":@YES});
    [self reloadSpecifiers];
}
- (void)pickColor {
    UIColorPickerViewController *picker=[UIColorPickerViewController new]; picker.delegate=self;
    picker.supportsAlpha=NO; picker.selectedColor=SBColor(SBRead());
    [self presentViewController:picker animated:YES completion:nil];
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker {
    CGFloat r=0,g=0,b=0,a=1; [picker.selectedColor getRed:&r green:&g blue:&b alpha:&a];
    SBWrite(@{@"color":[NSString stringWithFormat:@"%02X%02X%02X",(unsigned)lround(r*255),(unsigned)lround(g*255),(unsigned)lround(b*255)]});
}
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker { [self reloadSpecifiers]; }
@end

@implementation ShadeAppsController
- (NSArray *)specifiers {
    if(_specifiers) return _specifiers;
    self.title=SBT(@"Applications",@"应用名单");
    NSMutableArray *r=[NSMutableArray new];
    [r addObject:Group(nil,SBT(@"Select the apps that may show the bar. Add a bundle identifier manually if an app is missing. Selection is used only when Only selected applications is on.",@"选择允许显示遮挡条的应用。缺少的应用可以手动添加包标识。只有打开“仅在指定应用显示”时，此名单才生效。"))];
    PSSpecifier *add=[PSSpecifier preferenceSpecifierNamed:SBT(@"Add bundle identifier…",@"手动添加应用标识…") target:self set:NULL get:NULL detail:nil cell:13 edit:nil];
    [add setButtonAction:@selector(addApplication)]; [r addObject:add];
    NSMutableDictionary *apps=[@{@"com.apple.springboard":SBT(@"Home Screen",@"主屏幕")} mutableCopy];
    dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY);
    Class workspaceClass=NSClassFromString(@"LSApplicationWorkspace");
    @try {
        if([workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
            id workspace=[workspaceClass defaultWorkspace];
            if([workspace respondsToSelector:@selector(allInstalledApplications)]) {
                for(id app in [workspace allInstalledApplications]) {
                    if(![app respondsToSelector:@selector(bundleIdentifier)]) continue;
                    NSString *bundle=[app bundleIdentifier];
                    if(!bundle.length) continue;
                    NSString *name=[app respondsToSelector:@selector(localizedName)]?[app localizedName]:nil;
                    apps[bundle]=name.length?name:bundle;
                }
            }
        }
    } @catch(NSException *exception) { NSLog(@"[ShadeBar] Application enumeration unavailable: %@",exception.name); }
    NSArray *selected=[SBRead()[@"apps"] isKindOfClass:NSArray.class]?SBRead()[@"apps"]:@[];
    for(id bundle in selected) if([bundle isKindOfClass:NSString.class] && !apps[bundle]) apps[bundle]=bundle;
    NSArray *ordered=[apps.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a,NSString *b){ return [apps[a] localizedCaseInsensitiveCompare:apps[b]]; }];
    for(NSString *bundle in ordered) {
        PSSpecifier *s=[PSSpecifier preferenceSpecifierNamed:apps[bundle] target:self set:@selector(select:specifier:) get:@selector(selected:) detail:nil cell:6 edit:nil];
        [s setProperty:bundle forKey:@"bundle"]; [r addObject:s];
    }
    _specifiers=r; return r;
}
- (id)selected:(PSSpecifier *)s {
    id apps=SBRead()[@"apps"]; return @([apps isKindOfClass:NSArray.class] && [apps containsObject:[s propertyForKey:@"bundle"]]);
}
- (void)select:(id)value specifier:(PSSpecifier *)s {
    id previous=SBRead()[@"apps"];
    NSMutableSet *apps=[NSMutableSet setWithArray:[previous isKindOfClass:NSArray.class]?previous:@[]];
    NSString *bundle=[s propertyForKey:@"bundle"];
    if([value boolValue]) [apps addObject:bundle]; else [apps removeObject:bundle];
    SBWrite(@{@"apps":[apps.allObjects sortedArrayUsingSelector:@selector(compare:)]});
}
- (void)addApplication {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:SBT(@"Bundle identifier",@"应用包标识") message:@"com.example.app" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){ field.autocorrectionType=UITextAutocorrectionTypeNo; field.autocapitalizationType=UITextAutocapitalizationTypeNone; }];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Cancel",@"取消") style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weak=self;
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Add",@"添加") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *bundle=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSCharacterSet *valid=[NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-"];
        if(!bundle.length || [bundle rangeOfCharacterFromSet:valid.invertedSet].location!=NSNotFound) return;
        PSSpecifier *s=[PSSpecifier new]; [s setProperty:bundle forKey:@"bundle"]; [weak select:@YES specifier:s];
        [weak reloadApplicationList];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)reloadApplicationList { _specifiers=nil; [self reloadSpecifiers]; }
@end
