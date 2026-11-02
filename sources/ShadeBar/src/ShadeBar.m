#import "Common.h"
#import "Private.h"
#import "OverlayUI.h"

@interface ShadeWindow : UIWindow
@property(nonatomic,strong) UIView *bar;
@property(nonatomic,strong) ShadeFloatingIcon *icon;
@property(nonatomic,strong) UIControl *mask;
@property(nonatomic,strong) ShadeQuickPanel *panel;
@property(nonatomic) SBOverlayState overlayState;
@end
@implementation ShadeWindow
- (BOOL)canBecomeKeyWindow {return NO;}
- (BOOL)_canBecomeKeyWindow {return NO;}
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden) return nil;
    CGPoint bar=[self.bar convertPoint:point fromView:self],icon=[self.icon convertPoint:point fromView:self],panel=[self.panel convertPoint:point fromView:self];
    int route=SBOverlayHit(self.overlayState,[self.bar pointInside:bar withEvent:event],[self.icon pointInside:icon withEvent:event],[self.panel pointInside:panel withEvent:event]);
    if(route==SBHitPanel) return [self.panel hitTest:panel withEvent:event]?:self.panel;
    if(route==SBHitMask) return self.mask;
    if(route==SBHitIcon) return [self.icon hitTest:icon withEvent:event]?:self.icon;
    return route==SBHitBar?self.bar:nil;
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

@interface ShadeManager : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic,strong) ShadeWindow *window;
@property(nonatomic,strong) ShadeController *controller;
@property(nonatomic,strong) UIView *canvas,*panelCanvas;
@property(nonatomic,strong) NSDictionary *settings,*profile,*lastDisplay;
@property(nonatomic,copy) NSString *activeBundle,*gestureBundle;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic) UIInterfaceOrientation orientation;
@property(nonatomic) NSInteger panelOrientation;
@property(nonatomic) BOOL observingDeviceOrientation;
@property(nonatomic) SBRect rect,gestureStart;
@property(nonatomic) NSInteger gestureOrientation;
@property(nonatomic) int changeToken;
@property(nonatomic) BOOL dragging,iconDragging,pinching,panelOpen,eligible;
@property(nonatomic) CGPoint iconStart;
@property(nonatomic) NSInteger iconOrientation;
@property(nonatomic) double pinchOpacityStart;
@property(nonatomic,copy) NSString *iconBundle,*panelBundle,*pendingBundle;
@property(nonatomic,strong) NSMutableDictionary *pendingChanges;
@property(nonatomic,strong) NSTimer *saveTimer;
@property(nonatomic,strong) NSString *orientationSource;
- (void)reload;
- (void)tick;
- (void)layout;
@end

@implementation ShadeManager
- (instancetype)init {
    if((self=[super init])) {
        self.orientation=UIInterfaceOrientationPortrait;self.pendingChanges=[NSMutableDictionary new];
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
    move.maximumNumberOfTouches=1;move.delegate=self;
    [self.window.bar addGestureRecognizer:move];
    UIPinchGestureRecognizer *pinch=[[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinch:)];pinch.delegate=self;[self.window.bar addGestureRecognizer:pinch];
    self.window.icon=[[ShadeFloatingIcon alloc] initWithFrame:CGRectMake(0,0,24,24)];[self.canvas addSubview:self.window.icon];
    UIPanGestureRecognizer *iconMove=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveIcon:)];iconMove.maximumNumberOfTouches=1;[self.window.icon addGestureRecognizer:iconMove];
    UITapGestureRecognizer *tap=[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openPanel)];[tap requireGestureRecognizerToFail:iconMove];[self.window.icon addGestureRecognizer:tap];
    // The panel follows physical orientation independently of an orientation-locked app.
    self.panelCanvas=[UIView new];[self.controller.view addSubview:self.panelCanvas];
    self.window.mask=[UIControl new];self.window.mask.backgroundColor=[UIColor colorWithWhite:0 alpha:.44];self.window.mask.hidden=YES;
    self.window.mask.accessibilityLabel=SBT(@"Close quick settings",@"关闭快捷设置");self.window.mask.accessibilityTraits=UIAccessibilityTraitButton;
    [self.window.mask addTarget:self action:@selector(closePanel) forControlEvents:UIControlEventTouchUpInside];[self.panelCanvas addSubview:self.window.mask];
    self.window.panel=[ShadeQuickPanel new];self.window.panel.hidden=YES;[self.panelCanvas addSubview:self.window.panel];
    __weak typeof(self) weak=self;
    self.controller.layoutChanged=^{[weak layout];};
    self.window.panel.change=^(NSDictionary *changes,BOOL finished){
        if(weak.panelOpen && [weak.panelBundle isEqual:weak.activeBundle]) [weak stageChanges:changes finished:finished];
    };
    self.window.panel.dismiss=^{[weak closePanel];};
}
- (void)changeOrientation:(NSInteger)orientation {
    if(orientation<1 || orientation>4 || orientation==self.orientation) return;
    [self flushPending];[self cancelInteractions];
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
        self.settings=SBRead();
        [self.timer invalidate]; self.timer=nil;
        if(!SBBool(self.settings,@"enabled",NO)) {
            [self stopDeviceOrientation];
            self.eligible=NO;[self closePanel];[self cancelInteractions];self.window.hidden=YES;
            [self recordDisplay:@{@"reason":@"disabled",@"visible":@NO}];return;
        }
        [self createWindow];
        if(!self.observingDeviceOrientation) { [UIDevice.currentDevice beginGeneratingDeviceOrientationNotifications];self.observingDeviceOrientation=YES; }
        if(self.activeBundle.length) {
            NSMutableDictionary *updated=[SBProfile(self.settings,self.activeBundle) mutableCopy];
            if([self.pendingBundle isEqual:self.activeBundle]) [updated addEntriesFromDictionary:self.pendingChanges];
            if(![updated isEqual:self.profile]) [self cancelInteractions];
            self.profile=updated;
        }
        [self applyProfile];
        [self layout]; [self updateDisplay];
        __weak typeof(self) weak=self;
        self.timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *t){[weak tick];}];
        self.timer.tolerance=.03;
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
    } @catch(NSException *exception) { [self stopWithException:exception]; }
}
- (void)stopDeviceOrientation {
    if(self.observingDeviceOrientation) { [UIDevice.currentDevice endGeneratingDeviceOrientationNotifications];self.observingDeviceOrientation=NO; }
}
- (void)stopWithException:(NSException *)exception {
    [self stopDeviceOrientation];
    self.eligible=NO;self.window.hidden=YES;[self.timer invalidate];self.timer=nil;[self.saveTimer invalidate];self.saveTimer=nil;
    NSString *message=[NSString stringWithFormat:@"%@\n%@\n%@",exception.name,exception.reason,exception.callStackSymbols];
    [message writeToFile:@"/var/mobile/Library/ShadeBar/renderer-error.txt" atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [self recordDisplay:@{@"reason":@"error",@"visible":@NO,@"error":exception.reason?:exception.name}];
}
- (void)tick {
    @try { [self updateDisplay]; }
    @catch(NSException *exception) { [self stopWithException:exception]; }
}
- (void)applyProfile {
    self.window.bar.backgroundColor=[SBColor(self.profile) colorWithAlphaComponent:SBOpacity(SBNumber(self.profile,@"opacity",1))];
    if(!self.dragging && !self.pinching) self.rect=SBFrame(self.profile,UIInterfaceOrientationIsLandscape(self.orientation));
    self.window.bar.userInteractionEnabled=SBBool(self.profile,@"interactive",YES);
    if(self.panelOpen) [self.window.panel updateProfile:self.profile];
    [self refreshLayers];
}
- (void)selectProfile:(NSString *)bundle {
    if(!bundle.length || [bundle isEqual:self.activeBundle]) return;
    [self flushPending];[self closePanel];[self cancelInteractions];
    self.activeBundle=bundle;
    self.profile=SBProfile(self.settings,bundle);
    [self applyProfile];
}
- (BOOL)appSwitcherVisible:(BOOL *)known {
    *known=NO;
    // iOS 16 uses the coordinator; older releases expose the view controller.
    // Probe instances and selectors before calling; never assume an OS-specific ABI.
    for(NSString *name in @[@"SBMainSwitcherControllerCoordinator",@"SBMainSwitcherViewController"]) {
        Class cls=NSClassFromString(name);
        id controller=nil;
        if([cls respondsToSelector:@selector(sharedInstanceIfExists)]) controller=[cls sharedInstanceIfExists];
        else if([cls respondsToSelector:@selector(sharedInstance)]) controller=[cls sharedInstance];
        if([controller respondsToSelector:@selector(isAnySwitcherVisible)]) {
            *known=YES;return [controller isAnySwitcherVisible];
        }
        if([controller respondsToSelector:@selector(isMainSwitcherVisible)]) {
            *known=YES;return [controller isMainSwitcherVisible];
        }
    }
    return NO;
}
- (void)updateDisplay {
    BOOL switcherKnown=NO,switcherVisible=[self appSwitcherVisible:&switcherKnown];
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
    BOOL enabled=SBBool(self.settings,@"enabled",NO),restricted=YES;
    BOOL matched=SBApplicationEnabled(self.settings,bundle);
    // Keep settings reachable even if the bar covers the entire screen.
    BOOL configuring=[bundle isEqual:@"com.linghe.shadebar.app"];
    if(!switcherVisible) {
        if(known && !configuring) [self selectProfile:bundle];
        [self changeOrientation:orientation];
    }
    BOOL show=SBVisible(enabled,locked,restricted,known,matched,switcherVisible) && !configuring;
    self.eligible=show;
    if(!show) {[self closePanel];[self cancelInteractions];}
    if(self.panelOpen && !SBBool(self.profile,@"iconEnabled",YES)) [self closePanel];
    SBRect pixels=SBPixelRect(self.rect,self.canvasSize.width,self.canvasSize.height);
    BOOL offscreen=!CGRectIntersectsRect(CGRectMake(pixels.x,pixels.y,pixels.w,pixels.h),(CGRect){CGPointZero,self.canvasSize});
    NSString *reason=!enabled?@"disabled":!lockKnown?@"lockUnknown":locked?@"locked":switcherVisible?@"switcher":configuring?@"configuring":!known?@"frontUnknown":restricted&&!matched?@"notSelected":!SBBool(self.profile,@"barVisible",YES)?@"barHidden":SBNumber(self.profile,@"opacity",1)<=0?@"transparent":offscreen?@"offscreen":@"visible";
    [self createWindow];
    self.window.windowLevel=100000;
    [self refreshLayers];
    [self layout];
    [self recordDisplay:@{@"reason":reason,@"visible":@(self.window.overlayState.bar),@"iconVisible":@(self.window.overlayState.icon),@"panelOpen":@(self.panelOpen),@"interactive":@(SBBool(self.profile,@"interactive",YES)),@"bundle":bundle?:@"",@"frontKnown":@(known),@"switcherVisible":@(switcherVisible),@"switcherKnown":@(switcherKnown),@"locked":@(locked),@"lockKnown":@(lockKnown),@"selected":@(matched),@"selectedCount":@(selected.count),@"restricted":@(restricted),@"orientation":@(self.orientation),@"panelOrientation":@(self.panelOrientation),@"deviceOrientation":@(UIDevice.currentDevice.orientation),@"orientationSource":self.orientationSource?:@"unknown",@"sceneAttached":@(self.window.windowScene!=nil),@"sceneState":@(self.window.windowScene?self.window.windowScene.activationState:-99),@"windowFrame":NSStringFromCGRect(self.window.frame),@"barFrame":NSStringFromCGRect(self.window.bar.frame)}];
}
- (CGPoint)rootPoint:(SBPoint)p {
    return [self rootPoint:p orientation:self.orientation];
}
- (CGPoint)rootPoint:(SBPoint)p orientation:(NSInteger)orientation {
    CGSize fixed=UIScreen.mainScreen.fixedCoordinateSpace.bounds.size;
    SBPoint q=SBPointInFixedScreen(p,(int)orientation,fmin(fixed.width,fixed.height),fmax(fixed.width,fixed.height));
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
    self.window.bar.bounds=CGRectMake(0,0,r.w,r.h);
    self.window.bar.center=CGPointMake(r.x+r.w/2,r.y+r.h/2);
    if(!self.iconDragging) {
        NSString *prefix=UIInterfaceOrientationIsLandscape(self.orientation)?@"landscape":@"portrait";
        double cx=SBNumber(self.profile,[prefix stringByAppendingString:@".icon.cx"],.88),cy=SBNumber(self.profile,[prefix stringByAppendingString:@".icon.cy"],.2);
        self.window.icon.center=CGPointMake(SBIconCoordinate(cx,size.width),SBIconCoordinate(cy,size.height));
    }
    self.panelOrientation=SBPanelOrientation((int)UIDevice.currentDevice.orientation,(int)self.panelOrientation,(int)self.orientation);
    CGSize fixed=UIScreen.mainScreen.fixedCoordinateSpace.bounds.size;
    CGFloat shortSide=fmin(fixed.width,fixed.height),longSide=fmax(fixed.width,fixed.height);
    CGSize panelSize=self.panelOrientation>=3?CGSizeMake(longSide,shortSide):CGSizeMake(shortSide,longSide);
    CGPoint po=[self rootPoint:(SBPoint){0,0} orientation:self.panelOrientation];
    CGPoint px=[self rootPoint:(SBPoint){1,0} orientation:self.panelOrientation],py=[self rootPoint:(SBPoint){0,1} orientation:self.panelOrientation];
    self.panelCanvas.bounds=(CGRect){CGPointZero,panelSize};
    self.panelCanvas.center=[self rootPoint:(SBPoint){panelSize.width/2,panelSize.height/2} orientation:self.panelOrientation];
    self.panelCanvas.transform=CGAffineTransformMake(px.x-po.x,px.y-po.y,py.x-po.x,py.y-po.y,0,0);
    self.window.mask.frame=(CGRect){CGPointZero,panelSize};
    CGFloat width=fmin(380,panelSize.width-40),height=fmin(632,panelSize.height-72);
    self.window.panel.frame=CGRectMake((panelSize.width-width)/2,(panelSize.height-height)/2,width,height);
}
- (void)refreshLayers {
    SBOverlayState state=SBOverlayVisibility(self.eligible,SBBool(self.profile,@"barVisible",YES),SBBool(self.profile,@"iconEnabled",YES),self.panelOpen,SBBool(self.profile,@"interactive",YES));
    self.window.overlayState=state;
    self.window.bar.hidden=!state.bar;self.window.icon.hidden=!state.icon;
    self.window.mask.hidden=!state.panel;self.window.panel.hidden=!state.panel;self.window.hidden=!state.window;
}
- (void)cancelInteractions {
    if(self.pinching && [self.gestureBundle isEqual:self.activeBundle]) {
        NSMutableDictionary *restored=[self.profile mutableCopy];restored[@"opacity"]=@(self.pinchOpacityStart);self.profile=restored;
    }
    self.dragging=NO;self.iconDragging=NO;self.pinching=NO;
    if(!self.window) return;
    for(UIView *view in @[self.window.bar,self.window.icon]) for(UIGestureRecognizer *g in view.gestureRecognizers) {
        if(![g isKindOfClass:UITapGestureRecognizer.class] && (g.state==UIGestureRecognizerStateBegan || g.state==UIGestureRecognizerStateChanged)) {g.enabled=NO;g.enabled=YES;}
    }
    [self.window.bar.layer removeAllAnimations];self.window.bar.transform=CGAffineTransformIdentity;self.window.bar.alpha=1;
    self.rect=SBFrame(self.profile,UIInterfaceOrientationIsLandscape(self.orientation));
    [self applyProfile];
}
- (BOOL)flushPending {
    [self.saveTimer invalidate];self.saveTimer=nil;
    if(!self.pendingChanges.count) return YES;
    NSDictionary *changes=[self.pendingChanges copy];NSString *bundle=self.pendingBundle;
    [self.pendingChanges removeAllObjects];self.pendingBundle=nil;
    BOOL saved=SBWriteProfile(bundle,changes);self.settings=SBRead();
    if(saved) return YES;
    if([bundle isEqual:self.activeBundle]) {
        self.profile=SBProfile(self.settings,bundle);[self applyProfile];[self layout];
    }
    [self.window.panel showSaveFailure];return NO;
}
- (void)stageChanges:(NSDictionary *)changes finished:(BOOL)finished {
    if(!self.activeBundle.length) return;
    if(self.pendingBundle && ![self.pendingBundle isEqual:self.activeBundle]) [self flushPending];
    self.pendingBundle=self.activeBundle;[self.pendingChanges addEntriesFromDictionary:changes];
    NSMutableDictionary *profile=[self.profile mutableCopy];[profile addEntriesFromDictionary:changes];self.profile=profile;
    [self applyProfile];[self layout];
    [self.saveTimer invalidate];self.saveTimer=nil;
    if(finished) [self flushPending];
    else {
        __weak typeof(self) weak=self;
        self.saveTimer=[NSTimer timerWithTimeInterval:.15 repeats:NO block:^(NSTimer *timer){[weak flushPending];}];
        [NSRunLoop.mainRunLoop addTimer:self.saveTimer forMode:NSRunLoopCommonModes];
    }
}
- (void)openPanel {
    if(!self.eligible || !SBBool(self.profile,@"iconEnabled",YES)) return;
    [self cancelInteractions];self.panelOpen=YES;self.panelBundle=self.activeBundle;
    [self.window.panel updateProfile:self.profile];[self layout];[self refreshLayers];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,self.window.panel);
}
- (void)closePanel {
    if(!self.panelOpen) return;
    [self flushPending];self.panelOpen=NO;self.panelBundle=nil;[self refreshLayers];
    UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,self.eligible?self.window.icon:nil);
}
- (void)moveIcon:(UIPanGestureRecognizer *)gesture {
    if(!self.eligible || self.panelOpen) return;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        self.iconDragging=YES;self.iconStart=self.window.icon.center;self.iconOrientation=self.orientation;self.iconBundle=self.activeBundle;
    }
    if(self.iconOrientation!=self.orientation || ![self.iconBundle isEqual:self.activeBundle]) return;
    CGSize size=self.canvasSize;CGPoint translation=[gesture translationInView:self.canvas];
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        self.window.icon.center=CGPointMake(SBIconCoordinate((self.iconStart.x+translation.x)/size.width,size.width),SBIconCoordinate((self.iconStart.y+translation.y)/size.height,size.height));
    }
    if(gesture.state==UIGestureRecognizerStateEnded) {
        self.iconDragging=NO;NSString *prefix=UIInterfaceOrientationIsLandscape(self.orientation)?@"landscape":@"portrait";
        [self stageChanges:@{[prefix stringByAppendingString:@".icon.cx"]:@(self.window.icon.center.x/size.width),[prefix stringByAppendingString:@".icon.cy"]:@(self.window.icon.center.y/size.height)} finished:YES];
    }
    if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {self.iconDragging=NO;[self layout];}
}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return gesture.view==self.window.bar && other.view==self.window.bar;
}
- (void)pinch:(UIPinchGestureRecognizer *)gesture {
    if(!self.eligible || self.panelOpen || !SBBool(self.profile,@"interactive",YES)) return;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        [self flushPending];
        self.pinching=YES;self.dragging=NO;self.gestureBundle=self.activeBundle;self.gestureOrientation=self.orientation;
        self.pinchOpacityStart=SBOpacity(SBNumber(self.profile,@"opacity",1));
    }
    if(!self.pinching || ![self.gestureBundle isEqual:self.activeBundle] || self.gestureOrientation!=self.orientation) return;
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        double opacity=SBPinchOpacity(self.pinchOpacityStart,gesture.scale);
        NSMutableDictionary *updated=[self.profile mutableCopy];updated[@"opacity"]=@(opacity);self.profile=updated;
        [self applyProfile];
        if(gesture.state==UIGestureRecognizerStateEnded) {
            self.pinching=NO;[self stageChanges:@{@"opacity":@(opacity)} finished:YES];
        }
    } else if(gesture.state==UIGestureRecognizerStateCancelled || gesture.state==UIGestureRecognizerStateFailed) {
        [self cancelInteractions];[self layout];
    }
}
- (void)move:(UIPanGestureRecognizer *)gesture {
    if(self.pinching || self.panelOpen || !self.eligible || !SBBool(self.profile,@"interactive",YES)) return;
    if(gesture.state==UIGestureRecognizerStateBegan) {
        self.dragging=YES;self.gestureStart=self.rect;self.gestureOrientation=self.orientation;self.gestureBundle=self.activeBundle;
    }
    if(!self.dragging) return;
    if(self.gestureOrientation!=self.orientation || ![self.gestureBundle isEqual:self.activeBundle]) return;
    CGSize size=self.canvasSize;CGPoint p=[gesture translationInView:self.canvas];
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        self.rect=SBDrag(self.gestureStart,p.x/size.width,p.y/size.height);[self layout];
    }
    if(gesture.state==UIGestureRecognizerStateEnded) {
        self.dragging=NO;
        NSString *prefix=UIInterfaceOrientationIsLandscape(self.orientation)?@"landscape":@"portrait";
        // Drag changes position only; App-owned width/height must not be overwritten.
        [self stageChanges:@{[prefix stringByAppendingString:@".cx"]:@(self.rect.x+self.rect.w/2),[prefix stringByAppendingString:@".cy"]:@(self.rect.y+self.rect.h/2)} finished:YES];
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
