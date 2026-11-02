#import "Common.h"
#import "OverlayUI.h"

@implementation ShadeFloatingIcon
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    return hypot(point.x-CGRectGetMidX(self.bounds),point.y-CGRectGetMidY(self.bounds))<=self.bounds.size.width/2;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.clearColor;self.opaque=NO;
        self.isAccessibilityElement=YES;self.accessibilityTraits=UIAccessibilityTraitButton;
        self.accessibilityLabel=SBT(@"ShadeBar quick settings. Drag to move.",@"遮挡条快捷设置，可拖动移动。");
    }return self;
}
- (void)drawRect:(CGRect)rect {
    // Code-native icon: translucent circular base, a shade rectangle and two sliders.
    UIBezierPath *circle=[UIBezierPath bezierPathWithOvalInRect:CGRectInset(self.bounds,1,1)];
    [[UIColor colorWithRed:.08 green:.15 blue:.25 alpha:.76] setFill];[circle fill];
    [[UIColor colorWithWhite:1 alpha:.6] setStroke];circle.lineWidth=1;[circle stroke];
    CGFloat scale=self.bounds.size.width/48;
    CGContextRef context=UIGraphicsGetCurrentContext();CGContextSaveGState(context);CGContextScaleCTM(context,scale,scale);
    [[UIColor colorWithWhite:1 alpha:.95] setFill];UIRectFill(CGRectMake(12,13,24,9));
    UIBezierPath *lines=[UIBezierPath bezierPath];[lines moveToPoint:CGPointMake(12,28)];[lines addLineToPoint:CGPointMake(36,28)];
    [lines moveToPoint:CGPointMake(12,35)];[lines addLineToPoint:CGPointMake(36,35)];
    [[UIColor colorWithWhite:1 alpha:.78] setStroke];lines.lineWidth=1.5;[lines stroke];
    [[UIColor colorWithRed:.35 green:.88 blue:1 alpha:1] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(17,25,6,6)] fill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(28,32,6,6)] fill];
    CGContextRestoreGState(context);
}
@end

@interface ShadeQuickPanel ()
@property(nonatomic,strong) UILabel *titleLabel,*colorLabel,*footer;
@property(nonatomic,strong) UIButton *closeButton;
@property(nonatomic,strong) UIView *swatch;
@property(nonatomic,strong) NSMutableDictionary<NSString *,UISlider *> *sliders;
@property(nonatomic,strong) NSMutableDictionary<NSString *,UILabel *> *labels;
@property(nonatomic,strong) NSMutableDictionary<NSString *,UISwitch *> *switches;
@end
@implementation ShadeQuickPanel
- (UILabel *)label:(NSString *)text {
    UILabel *label=[UILabel new];label.text=text;label.textColor=UIColor.labelColor;
    label.font=[UIFont systemFontOfSize:15];[self addSubview:label];return label;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.backgroundColor=UIColor.secondarySystemBackgroundColor;self.layer.cornerRadius=20;self.clipsToBounds=YES;
        self.accessibilityViewIsModal=YES;self.alwaysBounceVertical=NO;
        self.sliders=[NSMutableDictionary new];self.labels=[NSMutableDictionary new];self.switches=[NSMutableDictionary new];
        self.titleLabel=[self label:SBT(@"ShadeBar",@"遮挡条快捷设置")];self.titleLabel.font=[UIFont boldSystemFontOfSize:19];
        self.closeButton=[UIButton buttonWithType:UIButtonTypeSystem];[self.closeButton setTitle:SBT(@"Done",@"完成") forState:UIControlStateNormal];
        [self.closeButton addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];[self addSubview:self.closeButton];
        NSArray *keys=@[@"barVisible",@"interactive"];
        NSArray *titles=@[SBT(@"Show shade bar",@"显示遮挡条"),SBT(@"Allow bar interaction",@"允许遮挡条交互")];
        for(NSUInteger i=0;i<keys.count;i++) {
            NSString *key=keys[i];self.labels[key]=[self label:titles[i]];
            UISwitch *control=[UISwitch new];control.accessibilityIdentifier=key;control.accessibilityLabel=titles[i];
            [control addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];
            self.switches[key]=control;[self addSubview:control];
        }
        NSArray *fields=@[@"width",@"height",@"opacity",@"red",@"green",@"blue"];
        NSArray *names=@[SBT(@"Width",@"宽度"),SBT(@"Height",@"高度"),SBT(@"Opacity",@"不透明度"),SBT(@"Red",@"红"),SBT(@"Green",@"绿"),SBT(@"Blue",@"蓝")];
        for(NSUInteger i=0;i<fields.count;i++) {
            NSString *key=fields[i];self.labels[key]=[self label:names[i]];
            UISlider *slider=[UISlider new];slider.accessibilityIdentifier=key;slider.accessibilityLabel=names[i];
            slider.minimumValue=i<2?1:0;slider.maximumValue=i<2?120:i==2?100:255;
            [slider addTarget:self action:@selector(slide:) forControlEvents:UIControlEventValueChanged];
            [slider addTarget:self action:@selector(finishSlider:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
            self.sliders[key]=slider;[self addSubview:slider];
        }
        self.colorLabel=[self label:SBT(@"Color",@"颜色")];self.swatch=[UIView new];self.swatch.layer.cornerRadius=6;[self addSubview:self.swatch];
        self.footer=[self label:SBT(@"Tap the dark area to close. Changes are saved for this app.",@"点击暗色区域关闭，修改会保存到当前应用。")];
        self.footer.numberOfLines=0;self.footer.font=[UIFont systemFontOfSize:12];self.footer.textColor=UIColor.secondaryLabelColor;
    }return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat width=self.bounds.size.width;
    self.titleLabel.frame=CGRectMake(18,16,width-100,27);self.closeButton.frame=CGRectMake(width-76,10,64,40);
    NSArray *keys=@[@"barVisible",@"interactive"];
    for(NSUInteger i=0;i<keys.count;i++) {NSString *key=keys[i];CGFloat y=58+i*48;
        self.labels[key].frame=CGRectMake(18,y,width-96,32);self.switches[key].frame=CGRectMake(width-71,y,51,31);
    }
    NSArray *fields=@[@"width",@"height",@"opacity",@"red",@"green",@"blue"];
    for(NSUInteger i=0;i<fields.count;i++) {NSString *key=fields[i];CGFloat y=158+i*62+(i>=3?38:0);
        self.labels[key].frame=CGRectMake(18,y,width-36,22);self.sliders[key].frame=CGRectMake(18,y+23,width-36,32);
    }
    self.colorLabel.frame=CGRectMake(18,344,width-100,26);self.swatch.frame=CGRectMake(width-70,344,52,26);
    self.footer.frame=CGRectMake(18,574,width-36,42);self.contentSize=CGSizeMake(width,632);
}
- (void)updateLabels {
    for(NSString *key in self.sliders) {
        UISlider *slider=self.sliders[key];BOOL rgb=[@[@"red",@"green",@"blue"] containsObject:key];
        NSString *value=rgb?[NSString stringWithFormat:@"%.0f",slider.value]:[NSString stringWithFormat:@"%.1f%%",slider.value];
        self.labels[key].text=[NSString stringWithFormat:@"%@: %@",slider.accessibilityLabel,value];slider.accessibilityValue=value;
    }
    NSString *hex=[self currentHex];self.colorLabel.text=[NSString stringWithFormat:@"%@  #%@",SBT(@"Color",@"颜色"),hex];self.swatch.backgroundColor=SBColor(@{@"color":hex});
}
- (NSString *)currentHex {
    return [NSString stringWithFormat:@"%02X%02X%02X",(unsigned)lroundf(self.sliders[@"red"].value),(unsigned)lroundf(self.sliders[@"green"].value),(unsigned)lroundf(self.sliders[@"blue"].value)];
}
- (void)updateProfile:(NSDictionary *)profile {
    self.footer.text=SBT(@"Tap the dark area to close. Changes are saved for this app.",@"点击暗色区域关闭，修改会保存到当前应用。");self.footer.textColor=UIColor.secondaryLabelColor;
    for(NSString *key in self.switches) self.switches[key].on=SBBool(profile,key,YES);
    for(NSString *key in @[@"width",@"height",@"opacity"]) {
        UISlider *slider=self.sliders[key];if(!slider.tracking) slider.value=100*SBNumber(profile,key,[key isEqual:@"width"]?.8:[key isEqual:@"height"]?.2:1);
    }
    CGFloat r=0,g=0,b=0,a=1;[SBColor(profile) getRed:&r green:&g blue:&b alpha:&a];
    NSDictionary *rgb=@{@"red":@(r*255),@"green":@(g*255),@"blue":@(b*255)};
    for(NSString *key in rgb) if(!self.sliders[key].tracking) self.sliders[key].value=[rgb[key] floatValue];
    [self updateLabels];
}
- (void)toggle:(UISwitch *)control {if(self.change) self.change(@{control.accessibilityIdentifier:@(control.on)},YES);}
- (void)slide:(UISlider *)slider {
    NSString *key=slider.accessibilityIdentifier;BOOL rgb=[@[@"red",@"green",@"blue"] containsObject:key];
    slider.value=rgb?roundf(slider.value):roundf(slider.value*10)/10;
    [self updateLabels];
    if(self.change) self.change(rgb?@{@"color":[self currentHex]}:@{key:@(slider.value/100.0)},NO);
}
- (void)finishSlider:(UISlider *)slider {if(self.change) self.change(@{},YES);}
- (void)close {if(self.dismiss) self.dismiss();}
- (BOOL)accessibilityPerformEscape {[self close];return YES;}
- (void)showSaveFailure {self.footer.text=SBT(@"Could not save. Please retry or export diagnostics in ShadeBar.",@"保存失败，请重试或在 ShadeBar 中导出诊断。");self.footer.textColor=UIColor.systemRedColor;}
@end
