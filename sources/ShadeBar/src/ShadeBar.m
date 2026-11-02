#import "Common.h"
#import "Private.h"

@interface ShadeWindow : UIWindow
@property(nonatomic,strong) UIView *bar;
@end
@implementation ShadeWindow
// Keep UIKit's default window hosting; no unregistered unmanaged context.
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)_canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden || self.bar.hidden) return nil;
    CGPoint p=[self.bar convertPoint:point fromView:self];
    return [self.bar pointInside:p withEvent:event]?self.bar:nil;
}
@end

@interface ShadeController : UIViewController
@property(nonatomic,copy) void (^layoutChanged)(void);
@end
@implementation ShadeController
- (BOOL)shouldAutorotate { return YES; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (void)viewDidLayoutSubviews { [super viewDidLayoutSubviews]; if(self.layoutChanged) self.layoutChanged(); }
@end

@interface ShadeManager : NSObject
@property(nonatomic,strong) ShadeWindow *window;
@property(nonatomic,strong) ShadeController *controller;
@property(nonatomic,strong) UIView *canvas;
@property(nonatomic,strong) NSDictionary *settings,*profile,*lastDisplay;
@property(nonatomic,copy) NSString *activeBundle,*gestureBundle;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) UIInterfaceOrientation orientation;
@property(nonatomic) SBRect rect,gestureStart;
@property(nonatomic) NSInteger gestureOrientation;
@property(nonatomic) int changeToken;
@property(nonatomic) BOOL dragging;
@property(nonatomic,strong) NSString *orientationSource;
- (void)reload;
- (void)tick;
- (void)layout;
@end

@implementation ShadeManager
- (instancetype)init {
    if((self=[super init])) {
        self.orientation=UIInterfaceOrientationPortrait;
        __weak typeof(self) weak=self;
        int token;
        notify_register_dispatch(SBChanged,&token,dispatch_get_main_queue(),^(int t){ [weak reload]; });
        self.changeToken=token;
        [self reload];
    }
    return self;
}
- (CGSize)canvasSize {
    CGSize s=UIScreen.mainScreen.fixedCoordinateSpace.bounds.size;
    double w=fmin(s.width,s.height),h=fmax(s.width,s.height);
    return UIInterfaceOrientationIsLandscape(self.orientation)?CGSizeMake(h,w):CGSizeMake(w,h);
}
- (UIWindowScene *)hostScene {
    UIWindowScene *fallback=nil;
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if(![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene=(UIWindowScene *)scene;
        if(windowScene.screen!=UIScreen.mainScreen) continue;
        if(scene.activationState==UISceneActivationStateForegroundActive) return windowScene;
        if(!fallback) fallback=windowScene;
    }
    for(UIWindow *window in UIApplication.sharedApplication.windows) {
        if(window!=self.window && window.windowScene.screen==UIScreen.mainScreen) return window.windowScene;
    }
    return fallback;
}
- (void)createWindow {
    UIWindowScene *scene=[self hostScene];
    if(self.window) {
        if(!self.window.windowScene && scene) self.window.windowScene=scene;
        return;
    }
    self.window=scene?[[ShadeWindow alloc] initWithWindowScene:scene]:[[ShadeWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.frame=scene?scene.coordinateSpace.bounds:UIScreen.mainScreen.bounds;
    self.window.windowLevel=100000;
    self.window.backgroundColor=UIColor.clearColor;
    self.controller=[ShadeController new];
    self.controller.view.backgroundColor=UIColor.clearColor;
    self.window.rootViewController=self.controller;
    self.canvas=[UIView new];
    [self.controller.view addSubview:self.canvas];
    self.window.bar=[UIView new];
    self.window.bar.isAccessibilityElement=YES;
    self.window.bar.accessibilityLabel=SBT(@"Shade bar. Drag to move.",@"遮挡条，可拖动移动。");
    [self.canvas addSubview:self.window.bar];
    UIPanGestureRecognizer *move=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    move.maximumNumberOfTouches=1;
    [self.window.bar addGestureRecognizer:move];
    __weak typeof(self) weak=self;
    self.controller.layoutChanged=^{[weak layout];};
}
- (void)changeOrientation:(NSInteger)orientation {
    if(orientation<1 || orientation>4 || orientation==self.orientation) return;
    // Cancel before changing coordinate systems; never save a partial rotated drag.
    for(UIGestureRecognizer *g in self.window.bar.gestureRecognizers) {g.enabled=NO;g.enabled=YES;}
    self.dragging=NO;
    self.orientation=orientation;
    self.rect=SBFrame(self.profile,UIInterfaceOrientationIsLandscape(orientation));
    [self layout];
}
- (void)recordDisplay:(NSDictionary *)display {
    if([display isEqual:self.lastDisplay]) return;
    self.lastDisplay=display;
    NSMutableDictionary *report=[display mutableCopy];
    report[@"updatedAt"]=@([NSDate.date timeIntervalSince1970]);
    [report writeToFile:@"/var/mobile/Library/ShadeBar/display.plist" atomically:YES];
    // Preserve the last other-app observation when returning to settings.
    if([display[@"bundle"] length] && ![display[@"bundle"] isEqual:@"com.linghe.shadebar.app"])
        [report writeToFile:@"/var/mobile/Library/ShadeBar/last-target.plist" atomically:YES];
}
- (void)reload {
    @try {
        // A settings reset/disable wins over an unfinished drag, including a stale gesture.
        if(self.dragging) {
            for(UIGestureRecognizer *g in self.window.bar.gestureRecognizers) {g.enabled=NO;g.enabled=YES;}
            self.dragging=NO;
        }
        self.settings=SBRead();
        [self.timer invalidate]; self.timer=nil;
        if(!SBBool(self.settings,@"enabled",NO)) {
            self.window.hidden=YES;
            [self recordDisplay:@{@"reason":@"disabled",@"visible":@NO}];
            return;
        }
        [self createWindow];
        if(self.activeBundle.length) self.profile=SBProfile(self.settings,self.activeBundle);
        [self applyProfile];
        [self layout]; [self updateDisplay];
        __weak typeof(self) weak=self;
        self.timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *t){[weak tick];}];
        self.timer.tolerance=.03;
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    } @catch(NSException *exception) { [self stopWithException:exception]; }
}
- (void)stopWithException:(NSException *)exception {
    self.window.hidden=YES;[self.timer invalidate];self.timer=nil;
    NSString *message=[NSString stringWithFormat:@"%@\n%@\n%@",exception.name,exception.reason,exception.callStackSymbols];
    [message writeToFile:@"/var/mobile/Library/ShadeBar/renderer-error.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self recordDisplay:@{@"reason":@"error",@"visible":@NO,@"error":exception.reason?:exception.name}];
}
- (void)tick {
    @try { [self updateDisplay]; }
    @catch(NSException *exception) { [self stopWithException:exception]; }
}
- (void)applyProfile {
    self.window.bar.backgroundColor=[SBColor(self.profile) colorWithAlphaComponent:fmax(0,fmin(1,SBNumber(self.profile,@"opacity",1)))];
    if(!self.dragging) self.rect=SBFrame(self.profile,UIInterfaceOrientationIsLandscape(self.orientation));
}
- (void)selectProfile:(NSString *)bundle {
    if(!bundle.length || [bundle isEqual:self.activeBundle]) return;
    // An app switch must not persist an in-flight gesture into another app's profile.
    for(UIGestureRecognizer *g in self.window.bar.gestureRecognizers) {g.enabled=NO;g.enabled=YES;}
    self.dragging=NO;
    self.activeBundle=bundle;
    self.profile=SBProfile(self.settings,bundle);
    [self applyProfile];
}
- (void)updateDisplay {
    UIApplication *application=UIApplication.sharedApplication;
    NSInteger orientation=0;
    if([application respondsToSelector:@selector(activeInterfaceOrientation)]) {
        orientation=[application activeInterfaceOrientation];self.orientationSource=@"SpringBoard.activeInterfaceOrientation";
    }
    if(orientation<1 || orientation>4) {
        orientation=self.window.windowScene.interfaceOrientation;self.orientationSource=@"windowScene.interfaceOrientation";
    }
    BOOL lockKnown=NO,locked=YES;
    Class lockClass=NSClassFromString(@"SBLockScreenManager");
    if([lockClass respondsToSelector:@selector(sharedInstance)]) {
        id lock=[lockClass sharedInstance];
        if([lock respondsToSelector:@selector(isUILocked)]) {locked=[lock isUILocked];lockKnown=YES;}
        if([lock respondsToSelector:@selector(isLockScreenVisible)]) {locked=(lockKnown&&locked)||[lock isLockScreenVisible];lockKnown=YES;}
    }
    if(!lockKnown && [application respondsToSelector:@selector(isLocked)]) {locked=[application isLocked];lockKnown=YES;}
    BOOL known=NO;NSString *bundle=nil;
    if([application respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
        id front=[application _accessibilityFrontMostApplication];
        if([front respondsToSelector:@selector(bundleIdentifier)]) {
            id value=[front bundleIdentifier];
            if([value isKindOfClass:NSString.class]) {bundle=value;known=bundle.length>0;}
        } else if(!front && [application respondsToSelector:@selector(isShowingHomescreen)] && [application isShowingHomescreen]) {
            known=YES;bundle=@"com.apple.springboard";
        }
    }
    NSArray *selected=[self.settings[@"apps"] isKindOfClass:NSArray.class]?self.settings[@"apps"]:@[];
    BOOL enabled=SBBool(self.settings,@"enabled",NO),restricted=SBBool(self.settings,@"restricted",NO);
    BOOL matched=[selected containsObject:bundle?:@""];
    // Keep settings reachable even if the bar covers the entire screen.
    BOOL configuring=[bundle isEqual:@"com.linghe.shadebar.app"];
    if(known && !configuring) [self selectProfile:bundle];
    [self changeOrientation:orientation];
    BOOL show=SBVisible(enabled,locked,restricted,known,matched) && !configuring;
    SBRect pixels=SBPixelRect(self.rect,self.canvasSize.width,self.canvasSize.height);
    BOOL offscreen=!CGRectIntersectsRect(CGRectMake(pixels.x,pixels.y,pixels.w,pixels.h),(CGRect){CGPointZero,self.canvasSize});
    NSString *reason=!enabled?@"disabled":!lockKnown?@"lockUnknown":locked?@"locked":configuring?@"configuring":!known?@"frontUnknown":restricted&&!matched?@"notSelected":SBNumber(self.profile,@"opacity",1)<=0?@"transparent":offscreen?@"offscreen":@"visible";
    [self createWindow];
    self.window.windowLevel=100000;
    self.window.hidden=!show;
    [self layout];
    [self recordDisplay:@{@"reason":reason,@"visible":@(show),@"bundle":bundle?:@"",@"frontKnown":@(known),@"locked":@(locked),@"lockKnown":@(lockKnown),@"selected":@(matched),@"selectedCount":@(selected.count),@"restricted":@(restricted),@"orientation":@(self.orientation),@"orientationSource":self.orientationSource?:@"unknown",@"sceneAttached":@(self.window.windowScene!=nil),@"sceneState":@(self.window.windowScene?self.window.windowScene.activationState:-99),@"windowFrame":NSStringFromCGRect(self.window.frame),@"barFrame":NSStringFromCGRect(self.window.bar.frame)}];
}
- (CGPoint)rootPoint:(SBPoint)p {
    CGSize fixed=UIScreen.mainScreen.fixedCoordinateSpace.bounds.size;
    SBPoint q=SBPointInFixedScreen(p,(int)self.orientation,fmin(fixed.width,fixed.height),fmax(fixed.width,fixed.height));
    return [self.controller.view convertPoint:CGPointMake(q.x,q.y) fromCoordinateSpace:UIScreen.mainScreen.fixedCoordinateSpace];
}
- (void)layout {
    if(!self.window || !self.canvas) return;
    CGSize size=self.canvasSize;
    // Fixed-screen conversion accounts for scene rotation exactly once.
    CGPoint origin=[self rootPoint:(SBPoint){0,0}];
    CGPoint x=[self rootPoint:(SBPoint){1,0}],y=[self rootPoint:(SBPoint){0,1}];
    self.canvas.bounds=(CGRect){CGPointZero,size};
    self.canvas.center=[self rootPoint:(SBPoint){size.width/2,size.height/2}];
    self.canvas.transform=CGAffineTransformMake(x.x-origin.x,x.y-origin.y,y.x-origin.x,y.y-origin.y,0,0);
    self.rect=SBNormalizeRect(self.rect);
    SBRect r=SBPixelRect(self.rect,size.width,size.height);
    self.window.bar.frame=CGRectMake(r.x,r.y,r.w,r.h);
}
- (void)move:(UIPanGestureRecognizer *)gesture {
    if(gesture.state==UIGestureRecognizerStateBegan) {
        self.dragging=YES;self.gestureStart=self.rect;self.gestureOrientation=self.orientation;self.gestureBundle=self.activeBundle;
    }
    if(self.gestureOrientation!=self.orientation || ![self.gestureBundle isEqual:self.activeBundle]) return;
    CGSize size=self.canvasSize;CGPoint p=[gesture translationInView:self.canvas];
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        self.rect=SBDrag(self.gestureStart,p.x/size.width,p.y/size.height);[self layout];
    }
    if(gesture.state==UIGestureRecognizerStateEnded) {
        self.dragging=NO;
        NSString *prefix=UIInterfaceOrientationIsLandscape(self.orientation)?@"landscape":@"portrait";
        // Drag changes position only; App-owned width/height must not be overwritten.
        SBWriteProfile(self.gestureBundle,@{[prefix stringByAppendingString:@".cx"]:@(self.rect.x+self.rect.w/2),[prefix stringByAppendingString:@".cy"]:@(self.rect.y+self.rect.h/2)});
    }
    if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        self.dragging=NO;self.rect=SBFrame(self.profile,UIInterfaceOrientationIsLandscape(self.orientation));[self layout];
    }
}
@end

static ShadeManager *manager;
__attribute__((visibility("default"))) int ShadeRendererStart(void) {
    @autoreleasepool {
        if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"] || !NSThread.isMainThread) return 0;
        @try {if(!manager) manager=[ShadeManager new];else [manager reload];return 1;}
        @catch(NSException *exception) {
            NSString *message=[NSString stringWithFormat:@"%@\n%@\n%@",exception.name,exception.reason,exception.callStackSymbols];
            [message writeToFile:@"/var/mobile/Library/ShadeBar/renderer-error.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
            SBWrite(@{@"enabled":@NO});return 0;
        }
    }
}
