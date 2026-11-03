#import "TLOriginalLayout.h"

static NSString *RID(NSString *value){return value.lastPathComponent?:@"";}
static CGFloat Dim(NSString *value,CGFloat fallback){if(!value.length||[value hasPrefix:@"@"])return fallback;NSScanner *scanner=[NSScanner scannerWithString:value];double number=0;return [scanner scanDouble:&number]?number:fallback;}
static UIFont *SourceFont(CGFloat size,BOOL bold){UIFont *font=[UIFont fontWithName:@"Roboto-Regular" size:size];if(!font)return [UIFont systemFontOfSize:size weight:bold?UIFontWeightBold:UIFontWeightRegular];if(bold){UIFontDescriptor *descriptor=[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];if(descriptor)font=[UIFont fontWithDescriptor:descriptor size:size];}return font;}
static UIColor *Hex(NSString *text,UIColor *fallback){
    if([text isEqual:@"@android:color/transparent"])return UIColor.clearColor;
    if([text isEqual:@"@android:color/black"])return UIColor.blackColor;
    if([text isEqual:@"@android:color/white"])return UIColor.whiteColor;
    if(![text hasPrefix:@"#"])return fallback;unsigned long long value=0;[[NSScanner scannerWithString:[text substringFromIndex:1]] scanHexLongLong:&value];
    return [UIColor colorWithRed:((value>>16)&255)/255. green:((value>>8)&255)/255. blue:(value&255)/255. alpha:text.length==9?((value>>24)&255)/255.:1];
}
@interface TLResourceNode : NSObject
@property(nonatomic,strong) NSDictionary *spec;
@property(nonatomic,strong) UIView *view;
@property(nonatomic,strong) NSArray<TLResourceNode*> *children;
@end
@implementation TLResourceNode @end

@implementation TLOriginalLayout {
    TLResourceNode *_root;
    NSMutableDictionary<NSString*,UIView*> *_views;
    NSString *_resourcePath;
}
- (instancetype)initWithTree:(NSDictionary*)tree resources:(NSString*)path {
    if((self=[super initWithFrame:CGRectZero])){_resourcePath=path;_views=[NSMutableDictionary new];_root=[self node:tree];[self addSubview:_root.view];}
    return self;
}
- (NSDictionary*)viewsByID{return [_views copy];}
- (UIImage*)image:(NSString*)reference pressed:(BOOL)pressed {
    if(!reference.length)return nil;NSString *name=RID(reference);
    NSString *selector=[_resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"res/drawable/%@.xml",name]];
    NSData *data=[NSData dataWithContentsOfFile:selector];
    if(data){NSString *xml=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];NSRegularExpression *regex=[NSRegularExpression regularExpressionWithPattern:@"android:drawable=\"@drawable/([^\"]+)\"" options:0 error:nil];NSArray *matches=[regex matchesInString:xml options:0 range:NSMakeRange(0,xml.length)];if(matches.count){NSTextCheckingResult *match=pressed?matches.firstObject:matches.lastObject;name=[xml substringWithRange:[match rangeAtIndex:1]];}}
    for(NSString *folder in @[@"drawable-xxxhdpi",@"drawable-xxhdpi",@"drawable-xhdpi",@"drawable-hdpi",@"drawable",@"drawable-mdpi"]){NSString *file=[_resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"res/%@/%@.png",folder,name]];UIImage *image=[UIImage imageWithContentsOfFile:file];if(image)return image;}return nil;
}
- (TLResourceNode*)node:(NSDictionary*)spec {
    TLResourceNode *node=[TLResourceNode new];node.spec=spec;NSDictionary *a=spec[@"attributes"];NSString *tag=spec[@"tag"],*viewID=RID(a[@"id"]);UIView *view;
    if([tag hasSuffix:@"PhaseDisplayV"]){view=[TLOriginalPhase new];}
    else if([tag isEqual:@"TextView"]){UILabel *label=[UILabel new];label.numberOfLines=[a[@"singleLine"] isEqual:@"true"]?1:0;label.text=a[@"text"]?:@"";label.font=SourceFont(Dim(a[@"textSize"],14),[a[@"textStyle"] isEqual:@"bold"]);label.textColor=Hex(a[@"textColor"],UIColor.whiteColor);NSString *gravity=a[@"gravity"]?:@"";label.textAlignment=[gravity containsString:@"center"]?NSTextAlignmentCenter:[gravity containsString:@"right"]?NSTextAlignmentRight:NSTextAlignmentLeft;view=label;}
    else if([tag isEqual:@"EditText"]){UITextField *field=[UITextField new];field.text=a[@"text"];field.placeholder=a[@"hint"];field.font=[UIFont systemFontOfSize:Dim(a[@"textSize"],18)];field.textColor=Hex(a[@"textColor"],UIColor.whiteColor);field.borderStyle=UITextBorderStyleNone;view=field;}
    else if([@[@"Button",@"ImageButton",@"CheckBox",@"RadioButton",@"Spinner"] containsObject:tag]){
        UIButton *button=[UIButton buttonWithType:UIButtonTypeCustom];[button setTitle:a[@"text"] forState:UIControlStateNormal];button.titleLabel.numberOfLines=0;button.titleLabel.font=[UIFont systemFontOfSize:Dim(a[@"textSize"],18)];[button setTitleColor:Hex(a[@"textColor"],UIColor.whiteColor) forState:UIControlStateNormal];[button setImage:[self image:a[@"src"] pressed:NO] forState:UIControlStateNormal];[button setImage:[self image:a[@"src"] pressed:YES] forState:UIControlStateHighlighted];button.imageView.contentMode=[a[@"scaleType"] isEqual:@"fitXY"]?UIViewContentModeScaleToFill:UIViewContentModeScaleAspectFit;
        button.accessibilityIdentifier=viewID;button.accessibilityLabel=a[@"onClick"]?:@"";[button addTarget:self action:@selector(click:) forControlEvents:UIControlEventTouchUpInside];view=button;
    }else if([tag isEqual:@"ImageView"]){UIImageView *image=[[UIImageView alloc] initWithImage:[self image:a[@"src"] pressed:NO]];image.contentMode=UIViewContentModeScaleAspectFit;view=image;}
    else if([tag isEqual:@"ScrollView"]){view=[UIScrollView new];}
    else {view=[UIView new];}
    view.backgroundColor=Hex(a[@"background"],UIColor.clearColor);view.hidden=[a[@"visibility"] isEqual:@"gone"]||[a[@"visibility"] isEqual:@"invisible"];view.accessibilityIdentifier=viewID;
    if(viewID.length)_views[viewID]=view;node.view=view;
    NSMutableArray *children=[NSMutableArray new];for(NSDictionary *child in spec[@"children"]){TLResourceNode *n=[self node:child];[children addObject:n];[view addSubview:n.view];}node.children=children;return node;
}
- (void)click:(UIButton*)button{if(self.action)self.action(button.accessibilityIdentifier?:@"",button.accessibilityLabel?:@"");}
- (void)setText:(NSString*)text forID:(NSString*)viewID {UIView *v=_views[viewID];if([v isKindOfClass:UILabel.class])((UILabel*)v).text=text;else if([v isKindOfClass:UITextField.class])((UITextField*)v).text=text;else if([v isKindOfClass:UIButton.class])[(UIButton*)v setTitle:text forState:UIControlStateNormal];[self setNeedsLayout];}
- (void)setInvisible:(BOOL)invisible forID:(NSString*)viewID{_views[viewID].hidden=invisible;}
- (CGSize)measure:(TLResourceNode*)node width:(CGFloat)width {
    NSDictionary *a=node.spec[@"attributes"];NSString *tag=node.spec[@"tag"];
    if([a[@"visibility"] isEqual:@"gone"])return CGSizeZero;
    CGFloat w=[a[@"layout_width"] isEqual:@"match_parent"]?width:Dim(a[@"layout_width"],-1);
    if(w<0)w=width;
    CGFloat h=Dim(a[@"layout_height"],-1);
    if(h<0){
        if([node.view isKindOfClass:UILabel.class])h=[node.view sizeThatFits:CGSizeMake(w,CGFLOAT_MAX)].height;
        else if([node.view isKindOfClass:UIButton.class]||[node.view isKindOfClass:UITextField.class])h=48;
        else if([tag isEqual:@"ImageView"])h=34;
        else if([tag isEqual:@"ScrollView"]){h=0;for(TLResourceNode *child in node.children)h=MAX(h,[self measure:child width:w].height);}
        else if([a[@"orientation"] isEqual:@"vertical"]||[tag isEqual:@"RadioGroup"]){h=0;for(TLResourceNode *child in node.children){NSDictionary *c=child.spec[@"attributes"];h+=[self measure:child width:w].height+Dim(c[@"layout_marginTop"],0)+Dim(c[@"layout_marginBottom"],0);}}
        else {h=0;for(TLResourceNode *child in node.children)h=MAX(h,[self measure:child width:w/MAX(1,node.children.count)].height);}
        h+=Dim(a[@"paddingTop"],0)+Dim(a[@"paddingBottom"],0);
    }
    return CGSizeMake(w,h);
}
- (void)layout:(TLResourceNode*)node frame:(CGRect)frame {
    node.view.frame=frame;NSDictionary *a=node.spec[@"attributes"];NSString *tag=node.spec[@"tag"];
    CGFloat w=frame.size.width,h=frame.size.height;
    if([tag isEqual:@"ScrollView"]){CGFloat y=0;for(TLResourceNode *child in node.children){CGSize s=[self measure:child width:w];[self layout:child frame:CGRectMake(0,y,w,s.height)];y+=s.height;}((UIScrollView*)node.view).contentSize=CGSizeMake(w,y);return;}
    if([tag isEqual:@"LinearLayout"]||[tag isEqual:@"RadioGroup"]||[tag isEqual:@"TableRow"]||[tag isEqual:@"TableLayout"]){
        BOOL vertical=[a[@"orientation"] isEqual:@"vertical"]||[tag isEqual:@"RadioGroup"]||[tag isEqual:@"TableLayout"];CGFloat weights=0,fixed=0;NSMutableArray *sizes=[NSMutableArray new];
        for(TLResourceNode *child in node.children){NSDictionary *c=child.spec[@"attributes"];CGFloat weight=Dim(c[@"layout_weight"],0);weights+=weight;CGSize size=[self measure:child width:vertical?w:w/MAX(1,node.children.count)];if(weight&&Dim(c[vertical?@"layout_height":@"layout_width"],-1)==0){if(vertical)size.height=0;else size.width=0;}[sizes addObject:[NSValue valueWithCGSize:size]];fixed+=vertical?size.height:size.width;fixed+=Dim(c[vertical?@"layout_marginTop":@"layout_marginLeft"],0)+Dim(c[vertical?@"layout_marginBottom":@"layout_marginRight"],0);}
        CGFloat position=Dim(a[vertical?@"paddingTop":@"paddingLeft"],0),space=MAX(0,(vertical?h:w)-fixed-position);NSUInteger index=0;
        for(TLResourceNode *child in node.children){NSDictionary *c=child.spec[@"attributes"];CGSize size=[sizes[index++] CGSizeValue];CGFloat extra=weights?space*Dim(c[@"layout_weight"],0)/weights:0;if(vertical)size.height+=extra;else size.width+=extra;position+=Dim(c[vertical?@"layout_marginTop":@"layout_marginLeft"],0);CGFloat cross=Dim(c[vertical?@"layout_marginLeft":@"layout_marginTop"],0);[self layout:child frame:vertical?CGRectMake(cross,position,MAX(0,w-cross),MAX(0,size.height)):CGRectMake(position,cross,MAX(0,size.width),MAX(0,h-cross))];position+=(vertical?size.height:size.width)+Dim(c[vertical?@"layout_marginBottom":@"layout_marginRight"],0);}
        return;
    }
    if([tag isEqual:@"RelativeLayout"]){NSMutableDictionary *frames=[NSMutableDictionary new];NSMutableSet *active=[NSMutableSet new];for(TLResourceNode *child in node.children)[self relative:child siblings:node.children width:w height:h frames:frames active:active];for(TLResourceNode *child in node.children)[self layout:child frame:[frames[child.view.accessibilityIdentifier.length?child.view.accessibilityIdentifier:[NSString stringWithFormat:@"%p",child]] CGRectValue]];return;}
    for(TLResourceNode *child in node.children)[self layout:child frame:CGRectMake(0,0,w,h)];
}
- (CGRect)relative:(TLResourceNode*)child siblings:(NSArray*)siblings width:(CGFloat)w height:(CGFloat)h frames:(NSMutableDictionary*)frames active:(NSMutableSet*)active {
    NSDictionary *a=child.spec[@"attributes"];NSString *key=child.view.accessibilityIdentifier.length?child.view.accessibilityIdentifier:[NSString stringWithFormat:@"%p",child];if(frames[key])return [frames[key] CGRectValue];if([active containsObject:key])return CGRectZero;[active addObject:key];
    CGSize size=[self measure:child width:w];CGFloat x=0,y=0;BOOL right=NO,bottom=NO;CGFloat maxX=w,maxY=h;
    if([a[@"layout_width"] isEqual:@"wrap_content"]&&[child.view isKindOfClass:UILabel.class])size.width=MIN(w,[child.view sizeThatFits:CGSizeMake(w,CGFLOAT_MAX)].width);
    if([a[@"layout_height"] isEqual:@"match_parent"])size.height=h;
    for(NSString *rule in @[@"layout_below",@"layout_above",@"layout_toRightOf",@"layout_toLeftOf",@"layout_alignBottom",@"layout_alignTop"]){NSString *reference=RID(a[rule]);if(!reference.length)continue;for(TLResourceNode *other in siblings)if([other.view.accessibilityIdentifier isEqual:reference]){CGRect r=[self relative:other siblings:siblings width:w height:h frames:frames active:active];if([rule isEqual:@"layout_below"])y=CGRectGetMaxY(r);if([rule isEqual:@"layout_above"]){maxY=r.origin.y;bottom=YES;}if([rule isEqual:@"layout_toRightOf"])x=CGRectGetMaxX(r);if([rule isEqual:@"layout_toLeftOf"]){maxX=r.origin.x;right=YES;}if([rule isEqual:@"layout_alignBottom"]){maxY=CGRectGetMaxY(r);bottom=YES;}if([rule isEqual:@"layout_alignTop"])y=r.origin.y;break;}}
    if([a[@"layout_alignParentBottom"] isEqual:@"true"]){maxY=h;bottom=YES;}if([a[@"layout_alignParentRight"] isEqual:@"true"]){maxX=w;right=YES;}
    if(right){if([a[@"layout_width"] isEqual:@"match_parent"])size.width=maxX-x;else x=maxX-size.width;}if(bottom){if([a[@"layout_height"] isEqual:@"match_parent"]||Dim(a[@"layout_height"],-1)==0||[a[@"layout_below"] length])size.height=maxY-y;else y=maxY-size.height;}
    if([a[@"layout_centerHorizontal"] isEqual:@"true"]||[a[@"layout_centerInParent"] isEqual:@"true"])x=(w-size.width)*.5;if([a[@"layout_centerVertical"] isEqual:@"true"]||[a[@"layout_centerInParent"] isEqual:@"true"])y=(h-size.height)*.5;
    CGRect r=CGRectMake(x,y,MAX(0,size.width),MAX(0,size.height));frames[key]=[NSValue valueWithCGRect:r];[active removeObject:key];return r;
}
- (void)layoutSubviews{[super layoutSubviews];[self layout:_root frame:self.bounds];}
@end

@implementation TLOriginalPhase
- (instancetype)initWithFrame:(CGRect)frame{if((self=[super initWithFrame:frame])){self.backgroundColor=[UIColor colorWithWhite:.8 alpha:1];_beamColor=UIColor.blackColor;_blanked=YES;}return self;}
- (void)drawRect:(CGRect)rect {
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetShouldAntialias(c,false);CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
    // Source PhaseDisplayV.onDraw: 4%-wide blue markers, spaced every 8%.
    CGContextSetFillColorWithColor(c,UIColor.blueColor.CGColor);for(CGFloat x=0;x<w;x+=w*.08){CGContextFillRect(c,CGRectMake(x,0,w*.04,h*.12));CGContextFillRect(c,CGRectMake(x,h-h*.12,w*.04,h*.12));}
    if(self.blanked)return;CGContextSetFillColorWithColor(c,self.beamColor.CGColor);
    CGFloat x=self.phase*(w/131072.),beam=w*.125,half=w*.5;
    CGContextFillRect(c,CGRectMake(x,0,beam,h));CGContextFillRect(c,CGRectMake(x+half,0,beam,h));CGFloat wrap=x-half+beam;if(wrap>0)CGContextFillRect(c,CGRectMake(0,0,wrap,h));
}
@end
