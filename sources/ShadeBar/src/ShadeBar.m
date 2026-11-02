#import "Common.h"
#import "Private.h"
#import <dlfcn.h>

@interface ShadeWindow : UIWindow
@property(nonatomic,strong) UIView *bar;
@property(nonatomic,strong) NSArray<UIView *> *handles;
@property(nonatomic,strong) UIButton *done;
@property(nonatomic) BOOL editing, passthrough;
@end
@implementation ShadeWindow
+ (BOOL)_isSystemWindow { return YES; }
- (BOOL)_isWindowServerHostingManaged { return NO; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)_canBecomeKeyWindow { return NO; }
- (BOOL)_ignoresHitTest { return !self.editing && self.passthrough; }
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if(self.hidden || (!self.editing && self.passthrough)) return nil;
    if(self.editing) {
        NSArray *targets=[self.handles arrayByAddingObject:self.done];
        for(UIView *view in targets) {
            CGPoint p=[view convertPoint:point fromView:self];
            if(!view.hidden && [view pointInside:p withEvent:event]) return view;
        }
    }
    CGPoint p=[self.bar convertPoint:point fromView:self];
    return [self.bar pointInside:p withEvent:event]?self.bar:nil;
}
@end

@interface ShadeController : UIViewController
@end
@implementation ShadeController
- (BOOL)shouldAutorotate { return NO; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskPortrait; }
@end

@interface ShadeManager : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic,strong) ShadeWindow *window;
@property(nonatomic,strong) ShadeController *controller;
@property(nonatomic,strong) NSDictionary *settings;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) FBSOrientationObserver *orientationObserver;
@property(nonatomic) UIInterfaceOrientation orientation;
@property(nonatomic) SBRect rect, gestureStart;
@property(nonatomic) NSInteger gestureOrientation;
@property(nonatomic) int changeToken;
- (void)reload;
- (void)tick;
@end

@implementation ShadeManager
- (instancetype)init {
    if((self=[super init])) {
        dlopen("/System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices",RTLD_LAZY);
        self.orientation=UIInterfaceOrientationPortrait;
        Class observer=NSClassFromString(@"FBSOrientationObserver");
        if(observer && [observer instancesRespondToSelector:@selector(setHandler:)]) {
            self.orientationObserver=[[observer alloc] init];
            __weak typeof(self) weak=self;
            [self.orientationObserver setHandler:^(FBSOrientationUpdate *update) {
                NSInteger orientation=update.orientation;
                dispatch_async(dispatch_get_main_queue(),^{ [weak changeOrientation:orientation]; });
            }];
            if([self.orientationObserver respondsToSelector:@selector(activeInterfaceOrientation)])
                [self changeOrientation:self.orientationObserver.activeInterfaceOrientation];
        }
        int token;
        __weak typeof(self) weak=self;
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
- (void)createWindow {
    if(self.window) return;
    CGRect fixed=UIScreen.mainScreen.fixedCoordinateSpace.bounds;
    self.window=[[ShadeWindow alloc] initWithFrame:fixed];
    self.window.windowLevel=100000;
    self.window.backgroundColor=UIColor.clearColor;
    self.controller=[ShadeController new];
    self.controller.view.backgroundColor=UIColor.clearColor;
    self.window.rootViewController=self.controller;
    self.window.bar=[UIView new];
    [self.controller.view addSubview:self.window.bar];
    UIPanGestureRecognizer *move=[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
    move.delegate=self; [self.window.bar addGestureRecognizer:move];
    NSMutableArray *handles=[NSMutableArray new];
    for(NSNumber *edge in @[@1,@2,@4,@8,@5,@6,@9,@10]) {
        UIView *handle=[UIView new]; handle.tag=edge.integerValue;
        handle.backgroundColor=UIColor.systemBlueColor;
        handle.layer.cornerRadius=10; handle.layer.borderWidth=2; handle.layer.borderColor=UIColor.whiteColor.CGColor;
        [handle addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resize:)]];
        [self.controller.view addSubview:handle]; [handles addObject:handle];
    }
    self.window.handles=handles;
    self.window.done=[UIButton buttonWithType:UIButtonTypeSystem];
    [self.window.done setTitle:SBT(@"Lock",@"锁定") forState:UIControlStateNormal];
    self.window.done.backgroundColor=UIColor.systemBlueColor;
    [self.window.done setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    self.window.done.layer.cornerRadius=10;
    [self.window.done addTarget:self action:@selector(finish) forControlEvents:UIControlEventTouchUpInside];
    [self.controller.view addSubview:self.window.done];
}
- (void)changeOrientation:(NSInteger)orientation {
    if(orientation<1 || orientation>4 || orientation==self.orientation) return;
    self.orientation=orientation;
    // A gesture belongs to its starting orientation; rotation cancels it.
    for(UIView *v in [self.window.handles arrayByAddingObject:self.window.bar])
        for(UIGestureRecognizer *g in v.gestureRecognizers) { g.enabled=NO; g.enabled=YES; }
    self.rect=SBFrame(self.settings,UIInterfaceOrientationIsLandscape(orientation),self.canvasSize);
    [self layout];
}
- (void)reload {
    self.settings=SBRead();
    [self.timer invalidate]; self.timer=nil;
    if(!SBBool(self.settings,@"enabled",NO)) { self.window.hidden=YES; return; }
    [self createWindow];
    self.window.editing=SBBool(self.settings,@"editing",YES);
    self.window.passthrough=SBBool(self.settings,@"passthrough",YES);
    self.window.bar.backgroundColor=[SBColor(self.settings) colorWithAlphaComponent:fmax(0,fmin(1,SBNumber(self.settings,@"opacity",1)))];
    self.window.bar.layer.borderWidth=self.window.editing?1:0;
    self.window.bar.layer.borderColor=UIColor.systemBlueColor.CGColor;
    self.rect=SBFrame(self.settings,UIInterfaceOrientationIsLandscape(self.orientation),self.canvasSize);
    [self layout]; [self tick];
    __weak typeof(self) weak=self;
    self.timer=[NSTimer timerWithTimeInterval:.2 repeats:YES block:^(NSTimer *t){ [weak tick]; }];
    self.timer.tolerance=.03;
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
}
- (void)tick {
    BOOL locked=YES; // Fail closed if the lock-state API is unavailable.
    Class lockClass=NSClassFromString(@"SBLockScreenManager");
    if([lockClass respondsToSelector:@selector(sharedInstance)]) {
        id manager=[lockClass sharedInstance];
        if([manager respondsToSelector:@selector(isUILocked)]) locked=[manager isUILocked];
    }
    BOOL known=NO; NSString *bundle=nil;
    if([UIApplication.sharedApplication respondsToSelector:@selector(_accessibilityFrontMostApplication)]) {
        id front=[UIApplication.sharedApplication _accessibilityFrontMostApplication];
        if(!front) { known=YES; bundle=@"com.apple.springboard"; }
        else if([front respondsToSelector:@selector(bundleIdentifier)]) { bundle=[front bundleIdentifier]; known=bundle.length>0; }
    }
    NSArray *selected=[self.settings[@"apps"] isKindOfClass:NSArray.class]?self.settings[@"apps"]:@[];
    BOOL show=SBVisible(SBBool(self.settings,@"enabled",NO),locked,SBBool(self.settings,@"restricted",NO),known,[selected containsObject:bundle?:@""]);
    if(self.window.hidden==show) self.window.hidden=!show;
}
- (void)layout {
    if(!self.window) return;
    CGSize size=self.canvasSize;
    UIView *root=self.controller.view;
    root.transform=CGAffineTransformIdentity;
    root.bounds=(CGRect){CGPointZero,size};
    root.center=CGPointMake(CGRectGetMidX(self.window.bounds),CGRectGetMidY(self.window.bounds));
    double angle=self.orientation==UIInterfaceOrientationLandscapeLeft?-M_PI_2:self.orientation==UIInterfaceOrientationLandscapeRight?M_PI_2:self.orientation==UIInterfaceOrientationPortraitUpsideDown?M_PI:0;
    root.transform=CGAffineTransformMakeRotation(angle);
    self.rect=SBClamp(self.rect,size.width,size.height);
    SBRect r=self.rect; CGRect frame=CGRectMake(r.x*size.width,r.y*size.height,r.w*size.width,r.h*size.height);
    self.window.bar.frame=frame;
    for(UIView *handle in self.window.handles) {
        NSUInteger e=handle.tag;
        double x=(e&SBLeft)?CGRectGetMinX(frame):(e&SBRight)?CGRectGetMaxX(frame):CGRectGetMidX(frame);
        double y=(e&SBTop)?CGRectGetMinY(frame):(e&SBBottom)?CGRectGetMaxY(frame):CGRectGetMidY(frame);
        handle.frame=CGRectMake(fmax(0,fmin(size.width-28,x-14)),fmax(0,fmin(size.height-28,y-14)),28,28);
        handle.hidden=!self.window.editing;
    }
    double y=CGRectGetMinY(frame)>=48?CGRectGetMinY(frame)-44:fmin(size.height-44,CGRectGetMaxY(frame)+8);
    self.window.done.frame=CGRectMake(fmax(0,fmin(size.width-76,CGRectGetMidX(frame)-38)),y,76,36);
    self.window.done.hidden=!self.window.editing;
}
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture { return self.window.editing; }
- (void)gesture:(UIPanGestureRecognizer *)gesture edges:(unsigned)edges {
    if(!self.window.editing) return;
    if(gesture.state==UIGestureRecognizerStateBegan) { self.gestureStart=self.rect; self.gestureOrientation=self.orientation; }
    if(self.gestureOrientation!=self.orientation) return;
    CGSize size=self.canvasSize; CGPoint p=[gesture translationInView:self.controller.view];
    if(gesture.state==UIGestureRecognizerStateBegan || gesture.state==UIGestureRecognizerStateChanged || gesture.state==UIGestureRecognizerStateEnded) {
        self.rect=edges?SBResize(self.gestureStart,edges,p.x/size.width,p.y/size.height,size.width,size.height):SBDrag(self.gestureStart,p.x/size.width,p.y/size.height,size.width,size.height);
        [self layout];
    }
    if(gesture.state==UIGestureRecognizerStateEnded) [self savePosition];
    if(gesture.state==UIGestureRecognizerStateCancelled) { self.rect=SBFrame(self.settings,UIInterfaceOrientationIsLandscape(self.orientation),size); [self layout]; }
}
- (void)move:(UIPanGestureRecognizer *)g { [self gesture:g edges:0]; }
- (void)resize:(UIPanGestureRecognizer *)g { [self gesture:g edges:(unsigned)g.view.tag]; }
- (void)savePosition {
    NSString *p=UIInterfaceOrientationIsLandscape(self.orientation)?@"landscape":@"portrait";
    SBRect r=self.rect;
    SBWrite(@{[p stringByAppendingString:@".x"]:@(r.x),[p stringByAppendingString:@".y"]:@(r.y),[p stringByAppendingString:@".w"]:@(r.w),[p stringByAppendingString:@".h"]:@(r.h)});
}
- (void)finish { [self savePosition]; SBWrite(@{@"editing":@NO}); }
@end

static ShadeManager *manager;
__attribute__((constructor)) static void ShadeStart(void) {
    @autoreleasepool {
        if(![NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]) return;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if(!manager) manager=[ShadeManager new];
        }];
    }
}
