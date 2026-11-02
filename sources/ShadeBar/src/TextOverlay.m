#import "Common.h"
#import "TextOverlay.h"
@interface ShadeTextOverlay ()
@property(nonatomic,strong) NSDictionary *configuration;
@property(nonatomic,strong) NSMutableArray<UILabel *> *labels;
@property(nonatomic,strong) NSMutableArray<NSValue *> *metrics;
@end
@implementation ShadeTextOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.userInteractionEnabled=NO;self.clipsToBounds=YES;self.backgroundColor=UIColor.clearColor;
        self.labels=[NSMutableArray new];self.metrics=[NSMutableArray new];
    }return self;
}
- (void)updateProfile:(NSDictionary *)profile {
    NSDictionary *configuration=@{@"enabled":@(SBBool(profile,@"textEnabled",NO)),@"lines":profile[@"textLines"]?:@[],@"spacing":@(SBTextSpacing(SBNumber(profile,@"textSpacing",4))),@"horizontal":@(SBTextAlignment(SBNumber(profile,@"textHorizontal",1))),@"vertical":@(SBTextAlignment(SBNumber(profile,@"textVertical",1)))};
    if([configuration isEqual:self.configuration]) return;
    self.configuration=configuration;self.hidden=![configuration[@"enabled"] boolValue];
    for(UILabel *label in self.labels) [label removeFromSuperview];
    [self.labels removeAllObjects];[self.metrics removeAllObjects];
    if(self.hidden) return;
    for(NSDictionary *line in SBTextLines(configuration[@"lines"])) {
        UILabel *label=[UILabel new];label.userInteractionEnabled=NO;label.text=line[@"text"];
        label.font=SBTextFont(line);label.textColor=SBColor(line);
        label.numberOfLines=1;label.lineBreakMode=NSLineBreakByClipping;
        label.adjustsFontSizeToFitWidth=NO;label.adjustsFontForContentSizeCategory=NO;
        label.textAlignment=NSTextAlignmentNatural;label.backgroundColor=UIColor.clearColor;
        // Measure once at natural width, independently of both screen and bar dimensions.
        CGSize size=[label sizeThatFits:CGSizeMake(CGFLOAT_MAX,CGFLOAT_MAX)];
        size.width=ceil(size.width);size.height=ceil(fmax(size.height,label.font.lineHeight));
        [self.metrics addObject:[NSValue valueWithCGSize:size]];[self.labels addObject:label];[self addSubview:label];
    }
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];NSUInteger count=self.labels.count;
    if(!count) return;
    SBTextMetric metrics[SBTextMaxLines];SBRect frames[SBTextMaxLines];
    for(NSUInteger i=0;i<count;i++) {CGSize size=self.metrics[i].CGSizeValue;metrics[i]=(SBTextMetric){size.width,size.height};}
    SBTextArrange(self.bounds.size.width,self.bounds.size.height,metrics,count,[self.configuration[@"spacing"] doubleValue],[self.configuration[@"horizontal"] intValue],[self.configuration[@"vertical"] intValue],frames);
    for(NSUInteger i=0;i<count;i++) {SBRect r=frames[i];self.labels[i].frame=CGRectMake(r.x,r.y,r.w,r.h);}
}
@end
