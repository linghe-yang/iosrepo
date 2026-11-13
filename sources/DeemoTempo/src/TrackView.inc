@interface DTSongTrack : UIView
@property(nonatomic,strong) UILabel *timeLabel;
@property(nonatomic) unsigned session;
@end

@implementation DTSongTrack
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.opaque=NO;
        self.backgroundColor=[UIColor colorWithWhite:.06 alpha:.72];
        self.layer.cornerRadius=14;
        self.multipleTouchEnabled=NO;
        self.timeLabel=[UILabel new];
        self.timeLabel.textColor=UIColor.whiteColor;
        self.timeLabel.font=[UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
        self.timeLabel.textAlignment=NSTextAlignmentCenter;
        [self addSubview:self.timeLabel];
        self.isAccessibilityElement=YES;
        self.accessibilityLabel=@"歌曲进度";
    }
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w=CGRectGetWidth(self.bounds);
    self.timeLabel.frame=CGRectMake(w-83,0,78,CGRectGetHeight(self.bounds));
    [self setNeedsDisplay];
}
- (CGFloat)travel { return MAX(1,CGRectGetWidth(self.bounds)-100); }
- (void)drawRect:(CGRect)rect {
    if (!(durationSec>0)) return;
    CGFloat y=CGRectGetMidY(self.bounds),travel=[self travel];
    CGFloat x=10+travel*std::clamp((dragging?positionSec:progressSec)/durationSec,0.f,1.f);
    [UIColor.systemGrayColor setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(10,y-2,travel,4) cornerRadius:2] fill];
    [UIColor.systemTealColor setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(10,y-2,x-10,4) cornerRadius:2] fill];
    if (region.first>=0) {
        const CGFloat left=10+travel*region.first/durationSec;
        const BOOL pair=region.complete();
        UIColor *color=pair?UIColor.systemGreenColor:UIColor.systemRedColor;
        const CGFloat right=pair?10+travel*region.second/durationSec:left;
        if (pair) {
            [[color colorWithAlphaComponent:.22] setFill];
            UIRectFill(CGRectMake(left,2,right-left,self.bounds.size.height-4));
        }
        NSDictionary *attrs=@{NSForegroundColorAttributeName:color,NSFontAttributeName:[UIFont boldSystemFontOfSize:10]};
        [color setFill]; UIRectFill(CGRectMake(left-1,4,2,24));
        [@"1" drawAtPoint:CGPointMake(left-8,0) withAttributes:attrs];
        if (pair) {
            UIRectFill(CGRectMake(right-1,4,2,24));
            [@"2" drawAtPoint:CGPointMake(right+2,0) withAttributes:attrs];
        }
    }
    if (dragging) {
        CGFloat goal=10+travel*aimSec/durationSec;
        [[UIColor colorWithWhite:1 alpha:.5] setFill];
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(goal-3,y-3,6,6)] fill];
    }
    [UIColor.whiteColor setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x-6,y-6,12,12)] fill];
}
- (void)refresh {
    int pos=MAX(0,(int)(dragging?positionSec:progressSec)),end=MAX(0,(int)durationSec);
    self.timeLabel.text=[NSString stringWithFormat:@"%d:%02d / %d:%02d",pos/60,pos%60,end/60,end%60];
    self.accessibilityValue=self.timeLabel.text;
    [self setNeedsDisplay];
}
- (void)aim:(UITouch *)touch {
    CGFloat travel=[self travel];
    CGFloat x=[touch locationInView:self].x-10;
    // A thumb centered on the physical end of the rail should select it reliably.
    if (x<=3) aimSec=0;
    else if (x>=travel-3) aimSec=durationSec;
    else aimSec=durationSec*x/travel;
    aimSec=region.constrain(aimSec);
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch=touches.anyObject;
    if (!chartReady || !historyOK || paused || !playing.load() ||
        [touch locationInView:self].x>[self travel]+20) return;
    self.session=transportID;
    [self aim:touch];beginRequested=true;finishRequested=false;cancelRequested=false;
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((dragging||beginRequested) && self.session==transportID) [self aim:touches.anyObject];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((dragging||beginRequested) && self.session==transportID) finishRequested=true;
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((dragging||beginRequested) && self.session==transportID) cancelRequested=true;
}
@end
