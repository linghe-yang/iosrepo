#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "TLOriginalRuntime.h"
#import "TLOriginalAudio.h"
#import "TLOriginalLayout.h"
#import "TLSpectrum.h"
#include <algorithm>
#include <cmath>
#include <array>

static NSString *Assets(){return [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Original/apk/assets"];}
static NSString *Note(int n){if(n<0||n>=88)return @"";return [@[@"A",@"A#",@"B",@"C",@"C#",@"D",@"D#",@"E",@"F",@"F#",@"G",@"G#"][n%12] stringByAppendingFormat:@"%d",(n+9)/12];}
static int ParseNote(NSString *text){for(int n=0;n<88;n++)if([Note(n) isEqual:text])return n;return -1;}
static UIFont *Font(CGFloat size){return [UIFont fontWithName:@"Roboto-Regular" size:size]?:[UIFont systemFontOfSize:size];}
static UIColor *RGB(int value){return [UIColor colorWithRed:((value>>16)&255)/255. green:((value>>8)&255)/255. blue:(value&255)/255. alpha:1];}
static UIImage *Image(NSString *name){
    for(NSString *folder in @[@"drawable-xxxhdpi",@"drawable-xxhdpi",@"drawable-xhdpi",@"drawable-hdpi",@"drawable",@"mipmap-xxxhdpi"]){NSString *path=[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:[NSString stringWithFormat:@"Original/apk/res/%@/%@.png",folder,name]];UIImage *image=[UIImage imageWithContentsOfFile:path];if(image)return image;}
    return [UIImage imageWithContentsOfFile:[Assets() stringByAppendingPathComponent:[name stringByAppendingPathExtension:@"png"]]];
}
static UILabel *Label(NSString *text,CGFloat size){UILabel *v=[UILabel new];v.text=text;v.font=Font(size);v.textColor=UIColor.blackColor;v.numberOfLines=1;return v;}
static UIButton *IconButton(NSString *name,id target,SEL action){UIButton *b=[UIButton buttonWithType:UIButtonTypeCustom];[b setImage:Image(name) forState:UIControlStateNormal];[b setImage:Image([name stringByAppendingString:@"pushed"]) forState:UIControlStateHighlighted];b.imageView.contentMode=UIViewContentModeScaleAspectFit;[b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];return b;}
static NSArray *Tokens(NSString *line){NSMutableArray *parts=[NSMutableArray new];for(NSString *p in [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet])if(p.length)[parts addObject:p];return parts;}
static NSArray *Zeros(int n){NSMutableArray *a=[NSMutableArray new];while(n--)[a addObject:@0];return a;}
static int Interval(int upper,int lower){const int a[]={2,4,6,8,10,12,4,8,12,3,6,3,6,8,9,6},b[]={1,2,3,4,5,6,1,2,3,1,2,2,4,1,3,1};for(int i=0;i<16;i++)if(a[i]==upper&&b[i]==lower)return i;return 0;}
static NSArray *Intervals(){return @[@"2:1 octaves",@"4:2 octaves",@"6:3 octaves",@"8:4 octaves",@"10:5 octaves",@"12:6 octaves",@"4:1 dbl octaves",@"8:2 dbl octaves",@"12:3 dbl octaves",@"3:1 12ths",@"6:2 12ths",@"3:2 fifths",@"6:4 fifths",@"8:1 trpl octaves",@"9:3 12ths",@"6:1 oct+12ths"];}

// The Android activity header and list dimensions are retained. iOS owns only
// the system status area and the document picker / microphone permission sheet.
@interface TLPage:UIViewController <UITableViewDataSource,UITableViewDelegate>
@property(nonatomic,strong) NSArray<NSString*> *items,*icons;
@property(nonatomic,strong) UITableView *table;
@property(nonatomic,strong) UIView *content;
@property(nonatomic,copy) void (^choose)(NSInteger);
@property(nonatomic,copy) void (^closed)(void);
@property(nonatomic) CGFloat rowHeight;
- (void)close;
@end
@implementation TLPage {
    UIView *_header;UIButton *_back;UILabel *_titleLabel;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.view.backgroundColor=UIColor.blackColor;self.modalPresentationStyle=UIModalPresentationFullScreen;
    _header=[UIView new];_header.backgroundColor=RGB(0x222222);[self.view addSubview:_header];
    _back=[UIButton buttonWithType:UIButtonTypeCustom];[_back setTitle:@"‹" forState:UIControlStateNormal];_back.titleLabel.font=Font(38);[_back addTarget:self action:@selector(close) forControlEvents:UIControlEventTouchUpInside];[_header addSubview:_back];
    _titleLabel=Label(self.title,20);_titleLabel.textColor=UIColor.whiteColor;[_header addSubview:_titleLabel];
    if(_content)[self.view addSubview:_content];else{_table=[[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];_table.backgroundColor=UIColor.blackColor;_table.separatorColor=RGB(0x444444);_table.dataSource=self;_table.delegate=self;_table.sectionHeaderTopPadding=0;[self.view addSubview:_table];}
}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
- (void)viewDidLayoutSubviews{[super viewDidLayoutSubviews];CGFloat top=self.view.safeAreaInsets.top,w=self.view.bounds.size.width,bottom=self.view.safeAreaInsets.bottom;_header.frame=CGRectMake(0,top,w,48);_back.frame=CGRectMake(0,0,44,48);_titleLabel.frame=CGRectMake(48,0,w-52,48);CGRect frame=CGRectMake(0,top+48,w,MAX(0,self.view.bounds.size.height-top-48-bottom));_content.frame=frame;_table.frame=frame;}
- (NSInteger)tableView:(UITableView*)table numberOfRowsInSection:(NSInteger)section{return self.items.count;}
- (CGFloat)tableView:(UITableView*)table heightForRowAtIndexPath:(NSIndexPath*)path{return [self.items[path.row] length]?(_rowHeight?:50):10;}
- (UITableViewCell*)tableView:(UITableView*)table cellForRowAtIndexPath:(NSIndexPath*)path {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];NSString *text=self.items[path.row];cell.backgroundColor=text.length?UIColor.blackColor:RGB(0x333333);cell.textLabel.text=text;cell.textLabel.textColor=RGB(0xcccccc);cell.textLabel.font=Font(20);cell.textLabel.numberOfLines=0;
    if(NSUInteger(path.row)<self.icons.count){UIImage *icon=Image(self.icons[path.row]);if(icon){UIGraphicsBeginImageContextWithOptions(CGSizeMake(34,34),NO,0);[icon drawInRect:CGRectMake(0,0,34,34)];cell.imageView.image=UIGraphicsGetImageFromCurrentImageContext();UIGraphicsEndImageContext();}}
    return cell;
}
- (void)tableView:(UITableView*)table didSelectRowAtIndexPath:(NSIndexPath*)path{[table deselectRowAtIndexPath:path animated:NO];if([self.items[path.row] length]&&self.choose)self.choose(path.row);}
- (void)close{[self dismissViewControllerAnimated:YES completion:^{if(self.closed)self.closed();}];}
@end

@interface TLCurve:UIView
@property(nonatomic,strong) NSArray<NSNumber*> *values;
@property(nonatomic,copy) NSString *caption;
@end
@implementation TLCurve
- (void)drawRect:(CGRect)rect {
    [UIColor.whiteColor setFill];UIRectFill(self.bounds);CGFloat w=self.bounds.size.width,h=self.bounds.size.height-30;
    CGFloat lo=-20,hi=40;for(NSNumber *v in _values){lo=MIN(lo,floor(v.doubleValue/10)*10);hi=MAX(hi,ceil(v.doubleValue/10)*10);}if(hi<=lo)hi=lo+10;
    CGContextRef c=UIGraphicsGetCurrentContext();CGContextSetLineWidth(c,1);NSDictionary *a=@{NSFontAttributeName:Font(12),NSForegroundColorAttributeName:UIColor.blackColor};
    for(float value=lo;value<=hi;value+=10){CGFloat y=(hi-value)/(hi-lo)*h;[RGB(0x008000) setStroke];CGContextMoveToPoint(c,0,y);CGContextAddLineToPoint(c,w,y);CGContextStrokePath(c);[[NSString stringWithFormat:@"%+.0f",value] drawAtPoint:CGPointMake(w-35,y) withAttributes:a];}
    [UIColor.blackColor setStroke];CGContextSetLineWidth(c,2);for(NSUInteger i=0;i<_values.count;i++){CGFloat x=i*w/87,y=(hi-[_values[i] doubleValue])/(hi-lo)*h;if(i)CGContextAddLineToPoint(c,x,y);else CGContextMoveToPoint(c,x,y);}CGContextStrokePath(c);
    for(int n=3;n<88;n+=12)[Note(n) drawAtPoint:CGPointMake(n*w/87,h) withAttributes:a];[_caption drawAtPoint:CGPointMake(3,2) withAttributes:a];
}
@end

@interface TLMain:UIViewController <UIDocumentPickerDelegate>
@end
@implementation TLMain {
    TLOriginalRuntime *_runtime;TLOriginalAudio *_audio;
    UIView *_header,*_body,*_blush;UILabel *_titleLabel,*_fileLabel,*_offsetLabel,*_temperLabel,*_partialLabel,*_frequencyLabel,*_autoLabel,*_current,*_left,*_right;
    UIImageView *_appIcon;UIButton *_help,*_fileButton;NSMutableArray<UIButton*> *_buttons;
    TLOriginalPhase *_phase;TLSpectrum *_spectrum;
    NSMutableDictionary *_document,*_preferences;NSString *_folder;
    int _note,_partial,_opMode,_lockFrames,_lastLockState,_lastTrigger;
    float _target,_fundamental,_temporaryOffset,_lockGain;BOOL _locked,_tone,_measuring,_foreground;
    CFTimeInterval _lastSpectrum,_lastDiagnosticSave;NSDictionary *_lastMeasurement,*_audioDiagnostics;
    NSString *_microphoneStatus;
}
- (UIViewController*)presenter{UIViewController *p=self;while(p.presentedViewController&&!p.presentedViewController.isBeingDismissed&&![p.presentedViewController isKindOfClass:UIAlertController.class])p=p.presentedViewController;return p;}
- (void)message:(NSString*)title text:(NSString*)text{UIAlertController *alert=[UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];[[self presenter] presentViewController:alert animated:YES completion:nil];}
- (TLPage*)list:(NSString*)title items:(NSArray*)items choose:(void(^)(NSInteger))choose {
    TLPage *page=[TLPage new];page.title=title;page.items=items;page.choose=choose;page.modalPresentationStyle=UIModalPresentationFullScreen;[[self presenter] presentViewController:page animated:YES completion:nil];return page;
}
- (void)ask:(NSString*)title value:(NSString*)value multiline:(BOOL)multiline apply:(void(^)(NSString*))apply {
    UIAlertController *a=[UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.text=value;f.autocorrectionType=UITextAutocorrectionTypeNo;f.autocapitalizationType=UITextAutocapitalizationTypeNone;f.keyboardType=multiline?UIKeyboardTypeDefault:UIKeyboardTypeNumbersAndPunctuation;}];[a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];[a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSString *text=a.textFields.firstObject.text?:@"";[a dismissViewControllerAnimated:YES completion:^{apply(text);}];}]];[[self presenter] presentViewController:a animated:YES completion:nil];
}
- (void)number:(NSString*)title value:(float)value min:(float)lo max:(float)hi apply:(void(^)(float))apply {
    __weak TLMain *weak=self;[self ask:title value:[NSString stringWithFormat:@"%.4g",value] multiline:NO apply:^(NSString *text){NSScanner *s=[NSScanner scannerWithString:text];float result;if(![s scanFloat:&result]||!s.isAtEnd||!std::isfinite(result)||result<lo||result>hi){[weak message:@"Invalid value" text:[NSString stringWithFormat:@"Enter a number from %.4g to %.4g.",lo,hi]];return;}apply(result);}];
}
- (NSMutableDictionary*)newDocument {
    NSMutableArray *partials=[NSMutableArray new];for(int i=0;i<88;i++)[partials addObject:@(i<20?6:i<32?4:i<48?2:1)];
    return [@{@"name":@"Untitled",@"template":@[@1.3146566,@14.5814,@1.6481711,@22.5174],@"ih":[NSMutableDictionary new],@"ihOffsets":[NSMutableDictionary new],@"partials":partials,@"custom":[Zeros(88) mutableCopy],@"temperament":[Zeros(12) mutableCopy],@"temperName":@"",@"basicOffset":@0,@"three":@[@8,@4,@4,@2,@4,@1,@36],@"useThree":@YES,@"intervals":@[@1,@2],@"fver":@0,@"opParms":@[@25,@25],@"struts":@[@0,@0],@"premeasure":[NSMutableDictionary new],@"notations":@""} mutableCopy];
}
- (BOOL)validDocument:(id)d {
    if(![d isKindOfClass:NSDictionary.class])return NO;
    for(NSString *key in @[@"name",@"temperName",@"notations"])if(![d[key] isKindOfClass:NSString.class])return NO;
    NSDictionary *counts=@{@"template":@4,@"partials":@88,@"custom":@88,@"temperament":@12,@"three":@7,@"intervals":@2,@"opParms":@2,@"struts":@2};
    for(NSString *key in counts){id a=d[key];if(![a isKindOfClass:NSArray.class]||[a count]!=[counts[key] unsignedIntegerValue])return NO;for(id v in a)if(![v isKindOfClass:NSNumber.class]||!std::isfinite([v floatValue])||fabs([v floatValue])>10000)return NO;}
    for(id v in d[@"partials"])if([v intValue]<1||[v intValue]>16)return NO;
    for(NSString *key in @[@"basicOffset",@"fver",@"useThree"])if(![d[key] isKindOfClass:NSNumber.class])return NO;
    for(NSString *key in @[@"ih",@"premeasure",@"ihOffsets"]){id map=d[key];if(![map isKindOfClass:NSDictionary.class])return NO;for(id n in map){if(![n isKindOfClass:NSString.class]||![n isEqual:@([n intValue]).stringValue]||[n intValue]<0||[n intValue]>87)return NO;id v=map[n];if([key isEqual:@"ihOffsets"]){if(![v isKindOfClass:NSArray.class]||[v count]!=12)return NO;for(id x in v)if(![x isKindOfClass:NSNumber.class]||!std::isfinite([x floatValue]))return NO;}else if(![v isKindOfClass:NSNumber.class]||!std::isfinite([v floatValue])||fabs([v floatValue])>500)return NO;}}
    NSArray *three=d[@"three"];for(int i=0;i<6;i++)if([three[i] intValue]<1||[three[i] intValue]>12)return NO;if([three[6] intValue]<22||[three[6] intValue]>44)return NO;
    if([d[@"opParms"][0] intValue]<1||[d[@"opParms"][0] intValue]>86)return NO;
    return YES;
}
- (NSMutableDictionary*)parseTuning:(NSString*)text name:(NSString*)name {
    NSMutableDictionary *d=[self newDocument];d[@"name"]=name;d[@"useThree"]=@NO;BOOL recognized=NO;NSMutableString *notations=[NSMutableString new];
    for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){
        NSArray *t=Tokens(line);if(!t.count)continue;NSString *key=t[0];int n=ParseNote(key);
        if([line hasPrefix:@"_"]){[notations appendFormat:@"%@\n",[line substringFromIndex:1]];continue;}
        if(n>=0&&t.count>=4){recognized=YES;int p=[t[1] intValue];if(p<1||p>16)return nil;d[@"partials"][n]=@(p);d[@"custom"][n]=@([t[3] floatValue]);}
        else if([key isEqual:@"Template"]&&t.count>=5)d[@"template"]=@[@([t[1] floatValue]),@([t[2] floatValue]),@([t[3] floatValue]),@([t[4] floatValue])];
        else if([key isEqual:@"IntervalSel"]&&t.count>=3)d[@"intervals"]=@[@(MAX(0,MIN(13,[t[1] intValue]))),@(MAX(0,MIN(8,[t[2] intValue])))];
        else if([key isEqual:@"ThreePart"]&&t.count>=8){NSMutableArray *three=[NSMutableArray new];for(int i=1;i<8;i++)[three addObject:@([t[i] intValue])];d[@"three"]=three;d[@"useThree"]=@YES;}
        else if([key isEqual:@"Fver"]&&t.count>1)d[@"fver"]=@([t[1] intValue]&3);
        else if([key isEqual:@"BasicOffset"]&&t.count>1)d[@"basicOffset"]=@([t[1] floatValue]);
        else if([key isEqual:@"OPParms"]&&t.count>2)d[@"opParms"]=@[@([t[1] intValue]),@([t[2] intValue])];
        else if([key isEqual:@"Struts"]&&t.count>2)d[@"struts"]=@[@([t[1] intValue]),@([t[2] intValue])];
        else if([key isEqual:@"TempName"])d[@"temperName"]=[[line substringFromIndex:8] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        else if([key isEqual:@"Offset"]&&t.count>2){int note=ParseNote([t[1] stringByAppendingString:@"0"]);if(note>=0)d[@"temperament"][note%12]=@([t[2] floatValue]);}
        else if([key isEqual:@"IHCon"]&&t.count>=3){int note=ParseNote(t[1]);float ih=[t[2] floatValue];if(note<0||ih<=0||ih>20)return nil;d[@"ih"][@(note).stringValue]=@(ih);NSMutableArray *off=[NSMutableArray new];for(NSUInteger i=4;i<t.count&&off.count<12;i++)[off addObject:[t[i] isEqual:@"*"]?@(-99999):@([t[i] floatValue])];if(off.count==12)d[@"ihOffsets"][@(note).stringValue]=off;}
    }
    d[@"notations"]=notations;return recognized&&[self validDocument:d]?d:nil;
}
- (void)viewDidLoad {
    [super viewDidLoad];_foreground=YES;self.view.backgroundColor=UIColor.blackColor;
    _folder=[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/TuneLab"];NSError *error=nil;[[NSFileManager defaultManager] createDirectoryAtPath:_folder withIntermediateDirectories:YES attributes:nil error:&error];
    _preferences=[@{@"auto":@0,@"autoType":@1,@"triggerOnly":@NO,@"autoPartialBelow":@15,@"autoPartialMax":@7,@"persistent":@NO,@"zoom":@1,@"phaseSpeed":@1,@"thickness":@1,@"dark":@NO,@"updateRate":@1,@"calibration":@0,@"sequence":@[@3,@15,@27,@39,@51,@63],@"multi":@[],@"combined":@NO} mutableCopy];
    NSDictionary *savedPrefs=[NSDictionary dictionaryWithContentsOfFile:[_folder stringByAppendingPathComponent:@"Preferences.plist"]];
    // Restore into the mutable dictionary while enumerating an independent key
    // snapshot. Fast enumeration of _preferences itself throws on replacement,
    // including when the saved value equals the default value (second launch).
    for(NSString *key in _preferences.allKeys)if([savedPrefs[key] isKindOfClass:[_preferences[key] class]])_preferences[key]=savedPrefs[key];
    NSData *data=[NSData dataWithContentsOfFile:[_folder stringByAppendingPathComponent:@"Current.json"]];if(data){id d=[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];if([self validDocument:d])_document=d;}
    if(!_document){NSString *average=[NSString stringWithContentsOfFile:[Assets() stringByAppendingPathComponent:@"Average.tun"] encoding:NSUTF8StringEncoding error:nil];_document=[self parseTuning:average?:@"" name:@"Average"]?:[self newDocument];}
    _note=48;_partial=[_document[@"partials"][_note] intValue];_runtime=[TLOriginalRuntime new];_audio=[[TLOriginalAudio alloc] initWithRuntime:_runtime];
    _header=[UIView new];_header.backgroundColor=RGB(0xbbc4b0);[self.view addSubview:_header];_appIcon=[[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Icon.png"]]];[_header addSubview:_appIcon];_titleLabel=Label(@"Piano Tuner",18);_titleLabel.textColor=UIColor.whiteColor;[_header addSubview:_titleLabel];_help=IconButton(@"help",self,@selector(help));_fileButton=IconButton(@"open120",self,@selector(files));[_header addSubview:_help];[_header addSubview:_fileButton];
    _body=[UIView new];[self.view addSubview:_body];_fileLabel=Label(@"",18);_offsetLabel=Label(@"",18);_offsetLabel.textAlignment=NSTextAlignmentRight;_temperLabel=Label(@"",15);_partialLabel=Label(@"",18);_frequencyLabel=Label(@"",18);_autoLabel=Label(@"",18);_autoLabel.textAlignment=NSTextAlignmentRight;_current=Label(@"A4",38);_current.textAlignment=NSTextAlignmentCenter;_current.backgroundColor=RGB(0xb0e0ff);_left=Label(@"",14);_right=Label(@"",14);_left.numberOfLines=_right.numberOfLines=0;_right.textAlignment=NSTextAlignmentRight;_blush=[UIView new];_blush.backgroundColor=RGB(0x555555);
    _phase=[TLOriginalPhase new];_spectrum=[TLSpectrum new];_spectrum.runtime=_runtime;
    for(UIView *v in @[_fileLabel,_offsetLabel,_temperLabel,_partialLabel,_frequencyLabel,_autoLabel,_current,_left,_right,_blush,_phase,_spectrum])[_body addSubview:v];
    _buttons=[NSMutableArray new];NSArray *icons=@[@"tuningcurve120",@"ruler120",@"lock120",@"speaker120",@"gears120"];SEL selectors[]={@selector(curve),@selector(measure),@selector(lock),@selector(tone),@selector(settings)};for(int i=0;i<5;i++){UIButton *b=IconButton(icons[i],self,selectors[i]);[_body addSubview:b];[_buttons addObject:b];}
    for(NSArray *pair in @[@[_current,NSStringFromSelector(@selector(pickNote))],@[_partialLabel,NSStringFromSelector(@selector(partials))],@[_frequencyLabel,NSStringFromSelector(@selector(offset))],@[_fileLabel,NSStringFromSelector(@selector(files))],@[_autoLabel,NSStringFromSelector(@selector(autoNote))],@[_spectrum,NSStringFromSelector(@selector(zoom))]]){UIView *v=pair[0];v.userInteractionEnabled=YES;[v addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:NSSelectorFromString(pair[1])]];}
    [_phase addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)]];
    _right.userInteractionEnabled=YES;[_right addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(microphone)]];
    __weak TLMain *weak=self;_runtime.update=^(NSDictionary *state){[weak receive:state];};_runtime.measurementReady=^(NSDictionary *state){[weak measured:state];};_audio.stateChanged=^(NSDictionary *state){[weak audioState:state];};_audio.error=^(NSString *message){TLMain *s=weak;if(s){s->_tone=NO;UIApplication.sharedApplication.idleTimerDisabled=NO;[s message:@"Audio" text:message];}};
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(background) name:UIApplicationDidEnterBackgroundNotification object:nil];[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foreground) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self applyModel];[self refresh];[self save];if(error)[self message:@"Storage" text:error.localizedDescription];
}
- (UIStatusBarStyle)preferredStatusBarStyle{return UIStatusBarStyleLightContent;}
- (void)viewDidAppear:(BOOL)animated{[super viewDidAppear:animated];if(!_audio.listening&&!_tone&&_foreground)[_audio listen];}
- (void)background{_foreground=NO;_tone=NO;_locked=NO;_measuring=NO;[_runtime call:@"GetPitch" arguments:@[@62]];[_audio stop];[self save];UIApplication.sharedApplication.idleTimerDisabled=NO;}
- (void)foreground{_foreground=YES;if(self.isViewLoaded&&self.view.window&&!_tone){[_audio listen];[self refresh];}}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width,top=self.view.safeAreaInsets.top,h=self.view.bounds.size.height-top-self.view.safeAreaInsets.bottom;BOOL portrait=h>w;
    CGFloat factor=MIN(1.7,MAX(1,w/360));CGFloat header=48;_header.frame=CGRectMake(0,top,w,header);_appIcon.frame=CGRectMake(12,8,32,32);_titleLabel.frame=CGRectMake(48,0,w-150,48);_help.frame=CGRectMake(w-100,8,32,32);_fileButton.frame=CGRectMake(w-44,8,32,32);
    _body.frame=CGRectMake(0,top+header,w,MAX(0,h-header));CGFloat height=_body.bounds.size.height;_body.backgroundColor=[_preferences[@"dark"] boolValue]?RGB(0x99aaa2):RGB(0xbbc4b0);_header.backgroundColor=_body.backgroundColor;
    CGFloat buttons=portrait?MIN(w/5,150):MAX(60,w*.104),bottom=portrait?height-buttons:height;
    CGFloat contentWidth=portrait?w:w-buttons*2,fs=18*factor,line=24.4*factor;
    CGFloat phaseHeight=MIN(height*.125,MAX(height*.35,contentWidth*.185));if(!portrait)phaseHeight=MIN(height*.18,contentWidth*.185);
    CGFloat upper=portrait?MAX(line*4,MIN(height*.24,110*factor)):line*2;
    CGFloat noteW=85*factor,noteH=60*factor,noteY=upper+phaseHeight+10*factor;
    if(noteY+noteH>bottom-50){upper=MAX(line*2,bottom-phaseHeight-noteH-60);noteY=upper+phaseHeight+10*factor;}
    _fileLabel.frame=CGRectMake(0,0,contentWidth*.7,line);_offsetLabel.frame=CGRectMake(contentWidth*.55,0,contentWidth*.45,line);_temperLabel.frame=CGRectMake(0,line,contentWidth,line);
    _partialLabel.frame=CGRectMake(0,upper-line*2,contentWidth*.55,line);_frequencyLabel.frame=CGRectMake(4,upper-line,contentWidth*.55,line);_autoLabel.frame=CGRectMake(contentWidth*.45,upper-line,contentWidth*.55,line);
    _phase.frame=CGRectMake(0,upper,contentWidth,phaseHeight);_blush.frame=CGRectMake((contentWidth-noteW)/2,upper+phaseHeight,noteW,10*factor);_current.frame=CGRectMake((contentWidth-noteW)/2,noteY,noteW,noteH);_left.frame=CGRectMake(2,noteY,(contentWidth-noteW)/2-3,noteH);_right.frame=CGRectMake((contentWidth+noteW)/2+3,noteY,(contentWidth-noteW)/2-3,noteH);_spectrum.frame=CGRectMake(0,noteY+noteH,contentWidth,MAX(0,bottom-noteY-noteH));
    for(UILabel *l in @[_fileLabel,_offsetLabel,_partialLabel,_frequencyLabel,_autoLabel])l.font=Font(fs);_current.font=Font(38*factor);_temperLabel.font=Font(15*factor);
    for(int i=0;i<5;i++){CGRect f;if(portrait)f=CGRectMake(i*w/5,height-buttons,w/5,buttons);else if(i==0)f=CGRectMake(w-buttons*2,0,buttons*2,buttons);else f=CGRectMake(w-buttons*2+((i-1)%2)*buttons,buttons+((i-1)/2)*buttons,buttons,MIN(buttons,(height-buttons)/2));_buttons[i].frame=CGRectInset(f,2,2);}
}
- (void)applyModel {
    [_runtime call:@"ClearIHOffsets" arguments:@[]];for(int n=0;n<88;n++)[_runtime call:@"ClearIHConstant" arguments:@[@(n)]];
    for(NSString *key in _document[@"ih"]){int n=key.intValue;[_runtime call:@"AddIHConstant" arguments:@[@(n),_document[@"ih"][key]]];NSArray *offsets=_document[@"ihOffsets"][key];for(NSUInteger p=1;p<=offsets.count;p++)if([offsets[p-1] floatValue]!=-99999)[_runtime call:@"AddThisIHOffset" arguments:@[@(n),@(p),offsets[p-1]]];}
    [_runtime call:@"CPcomm" arguments:@[@109,@(([_document[@"fver"] intValue]&2)?1:0)]];
    NSArray *t=_document[@"template"];[_runtime call:@"DoAdjust" arguments:@[@0,t[0],t[1],t[2],t[3]]];
    const int ba[]={4,6,8,10,12,4,8,12,8,3,6,3,6,6},bb[]={2,3,4,5,6,1,2,3,1,2,4,1,2,1},bd[]={12,12,12,12,12,24,24,24,36,7,7,19,19,31};const int ta[]={2,4,4,8,8,3,6,3,6},tb[]={1,2,1,2,1,2,4,1,1},td[]={12,12,24,24,36,7,7,19,31};int b=MAX(0,MIN(13,[_document[@"intervals"][0] intValue])),r=MAX(0,MIN(8,[_document[@"intervals"][1] intValue]));
    [_runtime call:@"SetAdjustmentParms" arguments:@[@0,@0,@(bd[b]),@(b>=9?-1.955f:0),@(bb[b]),@(ba[b])]];[_runtime call:@"SetAdjustmentParms" arguments:@[@0,@1,@(td[r]),@(r>=5?-1.955f:0),@(tb[r]),@(ta[r])]];
    NSArray *three=_document[@"three"];[_runtime call:@"Set3partParms" arguments:@[_document[@"useThree"],@(Interval([three[0] intValue],[three[1] intValue])),@(Interval([three[2] intValue],[three[3] intValue])),@(Interval([three[4] intValue],[three[5] intValue])),three[6],@(([_document[@"fver"] intValue]&1)?0:1)]];
    [self configureAuto];[_runtime setPhaseSpeed:[_preferences[@"phaseSpeed"] floatValue]];[_runtime setPartials:_preferences[@"multi"] combined:[_preferences[@"combined"] boolValue]];
}
- (void)configureAuto {
    NSArray *pairs=@[@[@100,_preferences[@"auto"]],@[@101,_preferences[@"autoType"]],@[@103,_preferences[@"autoPartialBelow"]],@[@104,_preferences[@"autoPartialMax"]],@[@128,_preferences[@"triggerOnly"]],@[@126,_preferences[@"updateRate"]]];for(NSArray *p in pairs)[_runtime call:@"CPcomm" arguments:p];[_runtime call:@"SetAutoNoteParms" arguments:@[]];
}
- (float)temperament:(int)n {return [_document[@"temperament"][n%12] floatValue]-[_document[@"temperament"][0] floatValue];}
- (float)targetFor:(int)n partial:(int)p {
    float stretch=[[_runtime call:@"TStretchForPartial" arguments:@[@(n),@(p)]] floatValue],custom=[_document[@"custom"][n] floatValue]+[self temperament:n];
    float exponent=((stretch+custom)/100.f+n)*.057762265f;
    return (float(std::exp(double(exponent)))*27.5f)*p;
}
- (float)opValue:(int)i {
    static const float v[]={.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.12,.126,.134,.14,.148,.154,.162,.168,.176,.182,.19,.196,.204,.21,.218,.224,.232,.238,.244,.252,.258,.266,.272,.28,.286,.294,.3,.308,.314,.322,.328,.336,.342,.35,.356,.364,.37,.37,.362,.356,.35,.342,.334,.328,.32,.314,.306,.3,.292,.284,.278,.272,.264,.256,.25,.242,.236,.228,.222,.214,.208,.2,.2};
    NSDictionary *pre=_document[@"premeasure"];int bridge=MAX(1,MIN(86,[_document[@"opParms"][0] intValue]));
    auto value=[&](int n)->float{NSNumber *result=pre[@(n).stringValue];if(result)return result.floatValue;int low=n-1,high=n+1;while(low>=0&&!pre[@(low).stringValue])low--;while(high<88&&!pre[@(high).stringValue])high++;if(bridge<high&&n<=bridge)high=88;if(low<=bridge&&bridge<n)low=-1;if(low>=0&&high<88){float mix=float(high-n)/(high-low);return mix*[pre[@(low).stringValue] floatValue]+(1-mix)*[pre[@(high).stringValue] floatValue];}return low>=0?[pre[@(low).stringValue] floatValue]:high<88?[pre[@(high).stringValue] floatValue]:0;};
    auto factor=[&](int n)->float{int index=n<=bridge?n*25/bridge:(n-bridge)*62/(87-bridge)+25;return v[std::min(87,index)];};
    auto strut=[&](int a,int b)->float{int first=[_document[@"struts"][0] intValue],second=[_document[@"struts"][1] intValue];float result=1;if(a<=first&&first<b)result=.3;if(a<=second&&second<b)result=.4;return result;};
    float weight=1,sum=0,total=0;for(int k=0;k<20;k++){int high=i+k,low=i-k;if(high<88){float e=value(high);if(i<=bridge&&bridge<high)e*=.11f;sum+=strut(i,high)*e*weight*factor(high);}if(low>=0){float e=value(low),a=factor(low);if(low<=bridge&&bridge<i)e*=.81f;sum+=strut(low,i)*e*weight*a*a;}total+=weight;weight*=.894f;}float safety=i<=[_document[@"opParms"][1] intValue]?20:30;return std::min(safety,-sum/total);
}
- (void)refresh {
    _partial=MAX(1,MIN(16,_partial));_fundamental=[self targetFor:_note partial:1];_target=[self targetFor:_note partial:_partial];if(!std::isfinite(_target)||_target<=25.4||_target>=10200){_partial=1;_target=_fundamental;}
    float offset=[_document[@"basicOffset"] floatValue]+_temporaryOffset+[_preferences[@"calibration"] floatValue]+(_opMode==2?[self opValue:_note]:0);
    [_runtime configureNote:_note partial:_partial target:_target offset:offset];
    float frequency=_target*float(std::exp(double(offset*5.776227E-4f)));_fileLabel.text=_document[@"name"];_offsetLabel.text=fabs(offset)>.001?[NSString stringWithFormat:@"%+.2f ¢",offset]:@"";_temperLabel.text=_document[@"temperName"];
    _partialLabel.text=_partial==1?@"fundamental":[NSString stringWithFormat:@"%d%@ partial",_partial,_partial==2?@"nd":_partial==3?@"rd":@"th"];_frequencyLabel.text=[NSString stringWithFormat:@"%7.2f Hz.",frequency];_current.text=Note(_note);
    _autoLabel.text=[_preferences[@"auto"] intValue]?@[@"Manual Note",@"Auto Up",@"Auto Down",@"Auto Both",@"Auto All"][MAX(0,MIN(4,[_preferences[@"autoType"] intValue]))]:@"Manual Note";
    _left.text=_measuring?@"Measuring IH…":_locked?@"Locking…":_opMode==1?@"Pre-measure":_opMode==2?@"Over-pull":@"";_right.text=_tone?@"Sound":(_microphoneStatus?:@"Microphone starting");
    _spectrum.target=frequency;_spectrum.fundamental=_fundamental;_spectrum.zoom=MAX(0,MIN(5,[_preferences[@"zoom"] intValue]));_spectrum.thickness=MAX(0,MIN(2,[_preferences[@"thickness"] intValue]));_spectrum.dark=[_preferences[@"dark"] boolValue];NSArray *t=_document[@"three"];_spectrum.intervals=[_document[@"useThree"] boolValue]?[NSString stringWithFormat:@"Bass:%@:%@\nMid:%@:%@\nTreb:%@:%@",t[0],t[1],t[2],t[3],t[4],t[5]]:@"";[_spectrum setNeedsDisplay];[self.view setNeedsLayout];
    [_buttons[2] setImage:Image(_locked?@"lock120p":@"lock120")?:Image(@"lock120") forState:UIControlStateNormal];
    if(_tone)[self playTone];
}
- (void)save {
    NSData *json=[NSJSONSerialization dataWithJSONObject:_document options:NSJSONWritingPrettyPrinted error:nil];NSError *error=nil;if(![json writeToFile:[_folder stringByAppendingPathComponent:@"Current.json"] options:NSDataWritingAtomic error:&error]){_right.text=@"Save failed";NSLog(@"TuneLab save: %@",error);}
    [_preferences writeToFile:[_folder stringByAppendingPathComponent:@"Preferences.plist"] atomically:YES];
}
- (void)audioState:(NSDictionary*)state {
    NSMutableDictionary *record=[state mutableCopy];record[@"runtime"]=[_runtime diagnostics];record[@"iosVersion"]=UIDevice.currentDevice.systemVersion;record[@"appVersion"]=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"";record[@"build"]=[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]?:@"";_audioDiagnostics=record;
    NSString *status=state[@"status"];
    if([status isEqual:@"Listening"]){
        float peak=[state[@"peak"] floatValue];
        _microphoneStatus=[state[@"convertedFrames"] unsignedLongLongValue]?[NSString stringWithFormat:@"Mic level\n%.0f dB",20*log10f(MAX(peak,.000001f))]:@"Mic connected\nWaiting for audio";
    }else _microphoneStatus=status;
    if(!_tone)_right.text=_microphoneStatus;UIApplication.sharedApplication.idleTimerDisabled=_foreground&&(_audio.listening||_tone);
    // Input health must remain visible even if no DSP update is being emitted.
    [_spectrum setNeedsDisplay];
    CFTimeInterval now=CACurrentMediaTime();if(now-_lastDiagnosticSave>=2||![status isEqual:@"Listening"]){_lastDiagnosticSave=now;NSData *json=[NSJSONSerialization dataWithJSONObject:record options:NSJSONWritingPrettyPrinted error:nil];[json writeToFile:[_folder stringByAppendingPathComponent:@"AudioDiagnostics.json"] options:NSDataWritingAtomic error:nil];}
}
- (void)microphone {
    NSDictionary *state=_audioDiagnostics?:_audio.diagnostics,*runtime=state[@"runtime"]?:@{};
    NSString *text=[NSString stringWithFormat:@"%@\nInput: %@ Hz / %@ channel(s)\nMicrophone callbacks: %@\nConverted frames: %@\nAnalysis blocks: %@\n%@",state[@"status"]?:@"Stopped",state[@"inputSampleRate"]?:@0,state[@"inputChannels"]?:@0,state[@"inputCallbacks"]?:@0,state[@"convertedFrames"]?:@0,runtime[@"processedBlocks"]?:@0,state[@"lastError"]?:@""];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Microphone" message:text preferredStyle:UIAlertControllerStyleAlert];__weak TLMain *weak=self;
    [a addAction:[UIAlertAction actionWithTitle:@"Restart microphone" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){TLMain *s=weak;if(!s)return;s->_tone=NO;s->_measuring=NO;[s->_audio stop];[s->_audio listen];[s refresh];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Copy diagnostics" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){NSData *json=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil];UIPasteboard.generalPasteboard.string=[[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];[[self presenter] presentViewController:a animated:YES completion:nil];
}
- (void)receive:(NSDictionary*)state {
    if(!_foreground)return;
    _phase.phase=[state[@"phase"][0] unsignedIntValue];int display=[state[@"phaseDisplayState"] intValue];_phase.blanked=display==0;_phase.beamColor=display==2?UIColor.blackColor:([state[@"velocity"] intValue]>0?RGB(0x28a828):RGB(0x66a0b4));[_phase setNeedsDisplay];
    if(state[@"autoNote"]){int n=[state[@"autoNote"] intValue];if(n>=0&&n<88&&n!=_note){_note=n;_partial=[_document[@"partials"][n] intValue];[self refresh];}}
    if(state[@"autoPartial"]&&!_measuring&&_opMode==0){int p=[state[@"autoPartial"] intValue];if(p>0&&p<=16&&p!=_partial){_partial=p;if([_preferences[@"persistent"] boolValue])_document[@"partials"][_note]=@(p);[self refresh];}}
    if(_locked&&state[@"lockError"]){int trigger=[state[@"triggerCount"] intValue],lockState=[state[@"lockState"] intValue];if(trigger!=_lastTrigger||lockState!=_lastLockState){_lockFrames=0;_lastTrigger=trigger;_lastLockState=lockState;}else{_lockGain=_lockFrames?.9291609f*_lockGain:.01f;_lockFrames++;float next=_temporaryOffset+[state[@"lockError"] intValue]*_lockGain;if(std::isfinite(next)&&fabs(next)<=500){_temporaryOffset=next;[self refresh];}}}
    if(_opMode==1&&state[@"premeasurement"]&&[state[@"premeasurement"] floatValue]!=-99999){_document[@"premeasure"][@(_note).stringValue]=state[@"premeasurement"];int mask[]={1,0,1,3,0,1,0,3,1,0,3,0},n=_note+1;while(n<88&&!(mask[n%12]&2))n++;if(n<88){_note=n;_partial=[_document[@"partials"][n] intValue];}else{_opMode=2;[_runtime call:@"CPcomm" arguments:@[@102,@2]];}[self refresh];[self save];}
    CFTimeInterval now=CACurrentMediaTime();if(now-_lastSpectrum>.08){_lastSpectrum=now;[_spectrum setNeedsDisplay];}
}
- (void)pan:(UIPanGestureRecognizer*)gesture {
    if(gesture.state!=UIGestureRecognizerStateEnded)return;CGPoint p=[gesture translationInView:_phase];if(fabs(p.x)>fabs(p.y)){_note=MAX(0,MIN(87,_note+(p.x<0?1:-1)));_partial=[_document[@"partials"][_note] intValue];}else{_partial=MAX(1,MIN(16,_partial+(p.y<0?1:-1)));if([_preferences[@"persistent"] boolValue])_document[@"partials"][_note]=@(_partial);}[self refresh];[self save];
}
- (void)pickNote {
    NSMutableArray *notes=[NSMutableArray new];for(int i=0;i<88;i++)[notes addObject:Note(i)];__weak TLMain *weak=self;TLPage *p=[self list:@"Select note" items:notes choose:^(NSInteger n){TLMain *s=weak;if(!s)return;s->_note=int(n);s->_partial=[s->_document[@"partials"][n] intValue];[s refresh];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];[p.table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:_note inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
}
- (void)partials {__weak TLMain *weak=self;NSMutableArray *items=[NSMutableArray new];for(int p=1;p<=16;p++)[items addObject:[NSString stringWithFormat:@"%@%d",p==_partial?@"✓ ":@"",p]];[self list:@"Select partial" items:items choose:^(NSInteger i){TLMain *s=weak;if(!s)return;s->_partial=int(i)+1;if([s->_preferences[@"persistent"] boolValue])s->_document[@"partials"][s->_note]=@(i+1);[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];}
- (void)offset {__weak TLMain *weak=self;[self list:@"Offset" items:@[@"Enter offset in cents",@"Enter A4 frequency",@"Zero offset",@"Microphone calibration"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i==0)[s number:@"Offset (cents)" value:[s->_document[@"basicOffset"] floatValue] min:-500 max:500 apply:^(float f){s->_document[@"basicOffset"]=@(f);s->_temporaryOffset=0;[s refresh];[s save];}];if(i==1)[s number:@"A4 frequency (Hz)" value:440*expf([s->_document[@"basicOffset"] floatValue]/1200*logf(2)) min:330 max:550 apply:^(float f){s->_document[@"basicOffset"]=@(1200*log2f(f/440));s->_temporaryOffset=0;[s refresh];[s save];}];if(i==2){s->_temporaryOffset=0;s->_document[@"basicOffset"]=@0;[s refresh];[s save];}if(i==3)[s calibration];}];}
- (void)lock {if(_tone){_tone=NO;[_audio stop];[_audio listen];}_locked=!_locked;_lockFrames=0;[_runtime call:@"GetPitch" arguments:@[@(_locked?61:62)]];[self refresh];}
- (void)measure {if(_measuring){[_runtime cancelMeasurement];_measuring=NO;}else{if(_tone){_tone=NO;[_audio stop];}if(!_audio.listening)[_audio listen];_measuring=YES;[_runtime beginMeasurement];}[self refresh];}
- (void)measured:(NSDictionary*)state {
    _measuring=NO;_lastMeasurement=state;[self refresh];float h=[state[@"ih"] floatValue];if(!std::isfinite(h)||h<=0||h>20){[self message:@"Inharmonicity" text:@"No valid inharmonicity result. Strike the note again and repeat the measurement."];return;}
    NSMutableString *text=[NSMutableString stringWithFormat:@"%@   IH = %.6f\n\n",Note([state[@"note"] intValue]),h];for(NSDictionary *p in state[@"partials"])[text appendFormat:@"%2d: %8.3f ¢   amplitude %.5g\n",[p[@"partial"] intValue],[p[@"offset"] floatValue],[p[@"amplitude"] floatValue]];
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Inharmonicity Results" message:text preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"Discard" style:UIAlertActionStyleCancel handler:nil]];__weak TLMain *weak=self;[a addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){TLMain *s=weak;if(!s)return;NSString *key=[state[@"note"] stringValue];s->_document[@"ih"][key]=@(h);NSMutableArray *off=[NSMutableArray new];for(NSDictionary *p in state[@"partials"])[off addObject:p[@"offset"]];s->_document[@"ihOffsets"][key]=off;s->_document[@"fver"]=@([s->_document[@"fver"] intValue]|2);[s applyModel];[s->_runtime call:@"DoAdjust" arguments:@[@2,@0,@0,@0,@0]];[s captureTemplate];[s refresh];[s save];}]];[[self presenter] presentViewController:a animated:YES completion:nil];
}
- (void)playTone {float hz=_target*expf(([_document[@"basicOffset"] floatValue]+_temporaryOffset+[_preferences[@"calibration"] floatValue])*5.776227E-4f);float increment=hz*float(4294967296.0/22050.0);NSMutableArray *increments=[Zeros(16) mutableCopy],*amplitudes=[Zeros(16) mutableCopy];increments[0]=@(increment);amplitudes[0]=@10000;[_audio playWithIncrements:increments amplitudes:amplitudes];UIApplication.sharedApplication.idleTimerDisabled=YES;}
- (void)tone {_tone=!_tone;_locked=NO;[_runtime call:@"GetPitch" arguments:@[@62]];if(_tone)_measuring=NO;else{[_audio stop];[_audio listen];}[self refresh];}
- (void)captureTemplate {NSMutableArray *t=[NSMutableArray new];for(int i=1008;i<=1011;i++)[t addObject:[_runtime call:@"IHform" arguments:@[@(i)]]];_document[@"template"]=t;}
- (void)curve {
    NSMutableArray *values=[NSMutableArray new];for(int n=0;n<88;n++)[values addObject:[_runtime call:@"TStretchForPartial" arguments:@[@(n),@1]]];
    TLCurve *graph=[TLCurve new];graph.values=values;graph.caption=@"Tuning curve – all fundamentals";TLPage *page=[TLPage new];page.title=@"Tuning Curve";page.content=graph;page.modalPresentationStyle=UIModalPresentationFullScreen;[[self presenter] presentViewController:page animated:YES completion:^{UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:@"Adjust" forState:UIControlStateNormal];b.frame=CGRectMake(0,0,80,44);[b addTarget:self action:@selector(adjustCurve) forControlEvents:UIControlEventTouchUpInside];[graph addSubview:b];b.frame=CGRectMake(MAX(0,graph.bounds.size.width-80),0,80,44);b.autoresizingMask=UIViewAutoresizingFlexibleLeftMargin;}];
}
- (void)adjustCurve {
    __weak TLMain *weak=self;[self list:@"Tuning Curve Adjustment" items:@[@"Auto adjust",@"3-part tuning",@"Bass amplitude",@"Bass shape",@"Treble amplitude",@"Treble shape"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i==0){[s->_runtime call:@"DoAdjust" arguments:@[@2,@0,@0,@0,@0]];[s captureTemplate];[s refresh];[s save];[s message:@"Auto adjust" text:@"The tuning curve has been adjusted to the saved IH constants."];}else if(i==1)[s threePart];else{int index=int(i)-2;[s number:@[@"Bass amplitude",@"Bass shape",@"Treble amplitude",@"Treble shape"][index] value:[s->_document[@"template"][index] floatValue] min:index%2?6:0 max:100 apply:^(float f){NSMutableArray *t=[s->_document[@"template"] mutableCopy];t[index]=@(f);s->_document[@"template"]=t;[s applyModel];[s refresh];[s save];}];}}];
}
- (void)threePart {
    __weak TLMain *weak=self;[self list:@"3-part tuning" items:@[@"Enable / disable",@"Bass interval",@"Middle interval",@"Treble interval",@"Middle start note"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i==0){s->_document[@"useThree"]=@(![s->_document[@"useThree"] boolValue]);[s applyModel];[s refresh];[s save];return;}if(i==4){[s number:@"Middle start note (22–44)" value:[s->_document[@"three"][6] floatValue] min:22 max:44 apply:^(float f){NSMutableArray *t=[s->_document[@"three"] mutableCopy];t[6]=@(int(f));s->_document[@"three"]=t;[s applyModel];[s refresh];[s save];}];return;}[s list:@"Select interval" items:Intervals() choose:^(NSInteger choice){const int a[]={2,4,6,8,10,12,4,8,12,3,6,3,6,8,9,6},b[]={1,2,3,4,5,6,1,2,3,1,2,2,4,1,3,1};NSMutableArray *t=[s->_document[@"three"] mutableCopy];t[(i-1)*2]=@(a[choice]);t[(i-1)*2+1]=@(b[choice]);s->_document[@"three"]=t;[s applyModel];[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];}];
}
- (void)zoom {__weak TLMain *weak=self;[self list:@"Spectrum zoom" items:@[@"Wide spectrum",@"±260 cents",@"±130 cents",@"±50 cents",@"±260 cents with wide middle",@"±130 cents with wide middle"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;s->_preferences[@"zoom"]=@(i);[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];}
- (void)autoNote {__weak TLMain *weak=self;[self list:@"Auto note switching" items:@[@"Manual Note",@"Auto Up",@"Auto Down",@"Auto Both",@"Auto All",@"Only change note on trigger"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i==5)s->_preferences[@"triggerOnly"]=@(![s->_preferences[@"triggerOnly"] boolValue]);else{s->_preferences[@"auto"]=@(i?1:0);if(i)s->_preferences[@"autoType"]=@(i);}[s configureAuto];[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];}
- (void)settings {
    NSData *data=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Original/settings_items.json"]];NSMutableArray *items=[[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] mutableCopy];items[12]=[_preferences[@"persistent"] boolValue]?@"Persistent Partials (yes)":@"Persistent Partials (no)";items[18]=@[@"Spectrum traces: Thin",@"Spectrum traces: Medium Thick",@"Spectrum traces: Extra Thick"][MAX(0,MIN(2,[_preferences[@"thickness"] intValue]))];
    __weak TLMain *weak=self;TLPage *page=[self list:@"Settings" items:items choose:^(NSInteger i){[weak setting:i];}];page.icons=@[@"zoom",@"autonote",@"",@"overpull",@"",@"unequal",@"",@"ihconstants",@"measuresequence",@"",@"partialtable",@"autopartial",@"save120",@"",@"customoffsets",@"calibration",@"exam",@"licensing",@"zoom",@"phasevel",@"help",@"darkmode",@"specrate"];
}
- (void)setting:(NSInteger)i {
    __weak TLMain *weak=self;
    switch(i){
    case 0:[self zoom];break;case 1:[self autoNote];break;case 3:[self overpull];break;case 5:[self temperaments];break;case 7:[self editIH];break;case 8:[self sequence];break;case 10:[self editTable:NO];break;
    case 11:{[self list:@"Auto partial selection" items:@[@"Disable auto partial selection",@"Lowest note",@"Maximum partial",@"Multiple partials"] choose:^(NSInteger n){TLMain *s=weak;if(!s)return;if(n==0){s->_preferences[@"autoPartialBelow"]=@0;[s configureAuto];[s save];}else if(n==3)[s multi];else[s number:n==1?@"Lowest note (0–87)":@"Maximum partial (1–16)" value:[s->_preferences[n==1?@"autoPartialBelow":@"autoPartialMax"] floatValue] min:n==1?0:1 max:n==1?87:16 apply:^(float f){s->_preferences[n==1?@"autoPartialBelow":@"autoPartialMax"]=@(int(f));[s configureAuto];[s save];}];}];break;}
    case 12:_preferences[@"persistent"]=@(![_preferences[@"persistent"] boolValue]);[self save];((TLPage*)[self presenter]).items=[self updatedSettings];[((TLPage*)[self presenter]).table reloadData];break;
    case 14:[self editTable:YES];break;case 15:[self calibration];break;
    case 16:[self message:@"PTG Tuning Exam" text:@"The PTG exam workflow is not available in this iOS alpha. It has not yet passed the original application's interaction and scoring comparisons."];break;
    case 17:[self message:@"Licensing" text:@"This iOS build is ready to use. No activation is required."];break;
    case 18:{[self list:@"Spectrum traces" items:@[@"Thin",@"Medium Thick",@"Extra Thick"] choose:^(NSInteger n){TLMain *s=weak;if(!s)return;s->_preferences[@"thickness"]=@(n);[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];break;}
    case 19:{[self number:@"Phase display speed" value:[_preferences[@"phaseSpeed"] floatValue] min:.1 max:10 apply:^(float f){TLMain *s=weak;if(!s)return;s->_preferences[@"phaseSpeed"]=@(f);[s->_runtime setPhaseSpeed:f];[s save];}];break;}
    case 20:[self message:@"About TuneLab Piano Tuner" text:[NSString stringWithFormat:@"Android source version 3.2\niOS port %@ (build %@)\n\nOriginal name, images, documentation and ARM64 sound-analysis core.\n\nThis is an installable development build. Complete UI and function parity and physical-device validation remain in progress.",[NSBundle.mainBundle objectForInfoDictionaryKey:@"TuneLabPortVersion"],[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]]];break;
    case 21:{[self list:@"Dark Mode" items:@[@"Light",@"Dark"] choose:^(NSInteger n){TLMain *s=weak;if(!s)return;s->_preferences[@"dark"]=@(n!=0);[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];break;}
    case 22:{[self number:@"Spectrum Update Rate (1–10)" value:[_preferences[@"updateRate"] floatValue] min:1 max:10 apply:^(float f){TLMain *s=weak;if(!s)return;s->_preferences[@"updateRate"]=@(int(f));[s configureAuto];[s save];}];break;}
    }
}
- (NSArray*)updatedSettings {NSData *data=[NSData dataWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"Original/settings_items.json"]];NSMutableArray *items=[[NSJSONSerialization JSONObjectWithData:data options:0 error:nil] mutableCopy];items[12]=[_preferences[@"persistent"] boolValue]?@"Persistent Partials (yes)":@"Persistent Partials (no)";return items;}
- (void)editTable:(BOOL)custom {
    NSMutableArray *items=[NSMutableArray new];for(int n=0;n<88;n++)[items addObject:custom?[NSString stringWithFormat:@"%@     %+.2f",Note(n),[_document[@"custom"][n] floatValue]]:[NSString stringWithFormat:@"%@     %@",Note(n),_document[@"partials"][n]]];
    __weak TLMain *weak=self;TLPage *page=[self list:custom?@"Custom offsets":@"Edit table of partials" items:items choose:^(NSInteger n){TLMain *s=weak;if(!s)return;NSString *key=custom?@"custom":@"partials";[s number:[NSString stringWithFormat:@"%@ – %@",Note(int(n)),custom?@"offset (cents)":@"partial"] value:[s->_document[key][n] floatValue] min:custom?-500:1 max:custom?500:16 apply:^(float f){s->_document[key][n]=custom?@(f):@(int(f));if(n==s->_note&&!custom)s->_partial=int(f);[s refresh];[s save];TLPage *p=(TLPage*)[s presenter];NSMutableArray *rows=[p.items mutableCopy];rows[n]=custom?[NSString stringWithFormat:@"%@     %+.2f",Note(int(n)),f]:[NSString stringWithFormat:@"%@     %d",Note(int(n)),int(f)];p.items=rows;[p.table reloadData];}];}];page.rowHeight=44;
}
- (void)editIH {
    NSMutableArray *items=[NSMutableArray new];for(int n=0;n<88;n++){NSNumber *ih=_document[@"ih"][@(n).stringValue];[items addObject:ih?[NSString stringWithFormat:@"%@     %.6f",Note(n),ih.floatValue]:[NSString stringWithFormat:@"%@     —",Note(n)]];}
    __weak TLMain *weak=self;[self list:@"Edit IH Constants" items:items choose:^(NSInteger n){TLMain *s=weak;if(!s)return;[s number:[NSString stringWithFormat:@"%@ IH (0 to delete)",Note(int(n))] value:[s->_document[@"ih"][@(n).stringValue] floatValue] min:0 max:20 apply:^(float f){NSString *key=@(n).stringValue;if(f>0)s->_document[@"ih"][key]=@(f);else{[s->_document[@"ih"] removeObjectForKey:key];[s->_document[@"ihOffsets"] removeObjectForKey:key];}[s applyModel];[s refresh];[s save];TLPage *p=(TLPage*)[s presenter];NSMutableArray *rows=[p.items mutableCopy];rows[n]=[NSString stringWithFormat:@"%@     %.6f",Note(int(n)),f];p.items=rows;[p.table reloadData];}];}];
}
- (void)sequence {
    NSMutableArray *items=[NSMutableArray new];for(NSNumber *n in _preferences[@"sequence"])[items addObject:Note(n.intValue)];[items addObject:@"Add note"];
    __weak TLMain *weak=self;[self list:@"Edit Measure Sequence" items:items choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(NSUInteger(i)<[s->_preferences[@"sequence"] count]){s->_note=[s->_preferences[@"sequence"][i] intValue];s->_partial=[s->_document[@"partials"][s->_note] intValue];[s refresh];[s measure];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}else[s number:@"Add note (A0 = 0, C8 = 87)" value:s->_note min:0 max:87 apply:^(float f){NSMutableArray *seq=[s->_preferences[@"sequence"] mutableCopy];if(![seq containsObject:@(int(f))])[seq addObject:@(int(f))];[seq sortUsingSelector:@selector(compare:)];s->_preferences[@"sequence"]=seq;[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];}];
}
- (void)multi {__weak TLMain *weak=self;[self ask:@"Multiple partials (up to four, e.g. 1 2 3 4)" value:[_preferences[@"multi"] componentsJoinedByString:@" "] multiline:NO apply:^(NSString *text){TLMain *s=weak;if(!s)return;NSArray *tokens=Tokens(text);if(tokens.count>4){[s message:@"Multiple partials" text:@"Enter at most four partial numbers."];return;}NSMutableArray *p=[NSMutableArray new];for(NSString *t in tokens){int value=t.intValue;if(value<1||value>16){[s message:@"Multiple partials" text:@"Partials must be from 1 to 16."];return;}[p addObject:@(value)];}s->_preferences[@"multi"]=p;s->_preferences[@"combined"]=@YES;[s->_runtime setPartials:p combined:YES];[s refresh];[s save];}];}
- (void)overpull {__weak TLMain *weak=self;[self list:@"Over-pull" items:@[@"Normal tuning",@"Begin pre-measurements",@"Over-pull tuning",@"Highest bass bridge note",@"Highest wound string",@"Clear pre-measurements"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i<3){s->_opMode=int(i);[s->_runtime call:@"CPcomm" arguments:@[@102,@(i)]];[s refresh];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}else if(i==5){s->_document[@"premeasure"]=[NSMutableDictionary new];[s save];[s message:@"Over-pull" text:@"Pre-measurements cleared."];}else[s number:i==3?@"Highest bass note (1–86)":@"Highest wound string (0–87)" value:[s->_document[@"opParms"][i-3] floatValue] min:i==3?1:0 max:i==3?86:87 apply:^(float f){NSMutableArray *p=[s->_document[@"opParms"] mutableCopy];p[i-3]=@(int(f));s->_document[@"opParms"]=p;[s refresh];[s save];}];}];}
- (void)calibration {__weak TLMain *weak=self;[self number:@"Microphone calibration offset (cents)" value:[_preferences[@"calibration"] floatValue] min:-100 max:100 apply:^(float f){TLMain *s=weak;if(!s)return;s->_preferences[@"calibration"]=@(f);[s refresh];[s save];}];}
- (void)temperaments {
    NSMutableArray *paths=[NSMutableArray new],*names=[NSMutableArray arrayWithObject:@"Equal temperament"];for(NSString *file in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:Assets() error:nil] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)])if([file.pathExtension.lowercaseString isEqual:@"tem"]){[paths addObject:[Assets() stringByAppendingPathComponent:file]];[names addObject:file.stringByDeletingPathExtension];}
    __weak TLMain *weak=self;[self list:@"Non-equal temperaments" items:names choose:^(NSInteger i){TLMain *s=weak;if(!s)return;NSMutableArray *offsets=[Zeros(12) mutableCopy];if(i>0){NSString *text=[NSString stringWithContentsOfFile:paths[i-1] encoding:NSUTF8StringEncoding error:nil];for(NSString *line in [text componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]){NSArray *t=Tokens(line);if(t.count>=2){int n=ParseNote([t[0] stringByAppendingString:@"0"]);if(n>=0)offsets[n%12]=@([t[1] floatValue]);}}}s->_document[@"temperament"]=offsets;s->_document[@"temperName"]=i?names[i]:@"";[s refresh];[s save];[[s presenter] dismissViewControllerAnimated:YES completion:nil];}];
}
- (NSString*)exportText {
    [self captureTemplate];NSArray *t=_document[@"template"],*three=_document[@"three"];NSMutableString *out=[NSMutableString stringWithFormat:@"Fver %@\nTemplate %.7f %.4f %.7f %.4f\nIntervalSel %@ %@\n",_document[@"fver"],[t[0] floatValue],[t[1] floatValue],[t[2] floatValue],[t[3] floatValue],_document[@"intervals"][0],_document[@"intervals"][1]];if([_document[@"useThree"] boolValue])[out appendFormat:@"ThreePart %@ %@ %@ %@ %@ %@ %@\n",three[0],three[1],three[2],three[3],three[4],three[5],three[6]];
    [out appendFormat:@"BasicOffset %.4f\nOPParms %@ %@\nStruts %@ %@\n",[_document[@"basicOffset"] floatValue],_document[@"opParms"][0],_document[@"opParms"][1],_document[@"struts"][0],_document[@"struts"][1]];
    if([_document[@"temperName"] length]){[out appendFormat:@"TempName %@\n",_document[@"temperName"]];for(int n=0;n<12;n++)[out appendFormat:@"Offset %@ %.4f\n",[Note(n) substringToIndex:Note(n).length-1],[_document[@"temperament"][n] floatValue]];}
    for(int n=0;n<88;n++){NSString *key=@(n).stringValue;NSNumber *ih=_document[@"ih"][key];if(ih){[out appendFormat:@"IHCon %@ %.7g",Note(n),ih.floatValue];NSArray *offsets=_document[@"ihOffsets"][key];if(offsets.count==12){[out appendString:@" off "];for(NSNumber *v in offsets)[out appendString:v.floatValue==-99999?@"* ":[NSString stringWithFormat:@"%.4f ",v.floatValue]];}[out appendString:@"\n"];}}
    for(int n=0;n<88;n++){int p=[_document[@"partials"][n] intValue];float stretch=[[_runtime call:@"TStretchForPartial" arguments:@[@(n),@(p)]] floatValue]+[self temperament:n]+[_document[@"custom"][n] floatValue];[out appendFormat:@"%@ %d %.4f %.4f\n",Note(n),p,stretch,[_document[@"custom"][n] floatValue]];}
    for(NSString *line in [_document[@"notations"] componentsSeparatedByString:@"\n"])if(line.length)[out appendFormat:@"_%@\n",line];return out;
}
- (void)files {__weak TLMain *weak=self;[self list:@"Files" items:@[@"Load tuning",@"Save tuning",@"New tuning",@"Notations",@"Dropbox Ops",@"External Memory Ops"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;if(i==0)[s loadFiles];if(i==1)[s saveFile];if(i==2){[s save];s->_document=[s newDocument];s->_temporaryOffset=0;s->_opMode=0;[s->_runtime call:@"CPcomm" arguments:@[@102,@0]];[s applyModel];[s refresh];[s save];[s message:@"New tuning" text:@"A new tuning has been created. Select a note and measure its inharmonicity."];}if(i==3)[s ask:@"Notations" value:s->_document[@"notations"] multiline:YES apply:^(NSString *text){s->_document[@"notations"]=text;[s save];}];if(i==4)[s message:@"Dropbox Ops" text:@"Dropbox account synchronization is not available in this iOS alpha. Tuning files can be imported and exported with External Memory Ops."];if(i==5)[s list:@"External Memory Ops" items:@[@"Import tuning",@"Export current tuning"] choose:^(NSInteger operation){if(operation==0){UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[UTTypeData] asCopy:YES];picker.delegate=s;[[s presenter] presentViewController:picker animated:YES completion:nil];}else[s exportFile];}];}];}
- (void)loadFiles {
    NSMutableArray *paths=[NSMutableArray new],*names=[NSMutableArray new];for(NSString *dir in @[_folder,Assets()])for(NSString *file in [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil] sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)])if([file.pathExtension.lowercaseString isEqual:@"tun"]){[paths addObject:[dir stringByAppendingPathComponent:file]];[names addObject:file.stringByDeletingPathExtension];}
    __weak TLMain *weak=self;[self list:@"Load tuning" items:names choose:^(NSInteger i){TLMain *s=weak;if(!s)return;[s loadPath:paths[i]];}];
}
- (void)loadPath:(NSString*)path {
    NSError *error=nil;NSString *text=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];NSMutableDictionary *d=text?[self parseTuning:text name:path.lastPathComponent.stringByDeletingPathExtension]:nil;
    if(!d){[self message:@"Load tuning" text:error.localizedDescription?:@"This is not a supported tuning file."];return;}[self save];_document=d;_temporaryOffset=0;_partial=[_document[@"partials"][_note] intValue];_opMode=0;[_runtime call:@"CPcomm" arguments:@[@102,@0]];[self applyModel];[self refresh];[self save];[self.presenter dismissViewControllerAnimated:YES completion:nil];
}
- (void)saveFile {__weak TLMain *weak=self;[self ask:@"Save tuning" value:_document[@"name"] multiline:YES apply:^(NSString *name){TLMain *s=weak;if(!s)return;NSString *safe=[[name lastPathComponent] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];if(!safe.length||[safe hasPrefix:@"."]){[s message:@"Save tuning" text:@"Enter a file name."];return;}if([safe.pathExtension.lowercaseString isEqual:@"tun"])safe=safe.stringByDeletingPathExtension;NSString *path=[s->_folder stringByAppendingPathComponent:[safe stringByAppendingPathExtension:@"tun"]];NSError *error=nil;NSString *text=[s exportText];if(![text writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]){[s message:@"Save tuning" text:error.localizedDescription];return;}s->_document[@"name"]=safe;[s save];[s refresh];[s message:@"Save tuning" text:@"Tuning saved."];}];}
- (void)exportFile {
    NSString *path=[_folder stringByAppendingPathComponent:@"Export.tun"];NSError *error=nil;if(![[self exportText] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]){[self message:@"Export tuning" text:error.localizedDescription];return;}UIDocumentPickerViewController *picker=[[UIDocumentPickerViewController alloc] initForExportingURLs:@[[NSURL fileURLWithPath:path]] asCopy:YES];[[self presenter] presentViewController:picker animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController*)controller didPickDocumentsAtURLs:(NSArray<NSURL*>*)urls {NSURL *url=urls.firstObject;if(!url)return;BOOL scoped=[url startAccessingSecurityScopedResource];[self loadPath:url.path];if(scoped)[url stopAccessingSecurityScopedResource];}
- (void)help {
    __weak TLMain *weak=self;[self list:@"Help" items:@[@"Help topics",@"Help, this page",@"FAQs",@"What's new in this version?"] choose:^(NSInteger i){TLMain *s=weak;if(!s)return;NSArray *files=@[@"help1.html",@"help2.html",@"help36.html",@"help338.html"];NSString *path=[Assets() stringByAppendingPathComponent:files[i]];
        WKWebView *web=[[WKWebView alloc] initWithFrame:CGRectZero];TLPage *page=[TLPage new];page.title=@"TuneLab Help";page.content=web;page.modalPresentationStyle=UIModalPresentationFullScreen;[[s presenter] presentViewController:page animated:YES completion:^{[web loadFileURL:[NSURL fileURLWithPath:path] allowingReadAccessToURL:[NSURL fileURLWithPath:Assets() isDirectory:YES]];}];}];
}
@end

@interface TLAppDelegate:UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation TLAppDelegate
- (BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options {self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[TLMain new];[self.window makeKeyAndVisible];return YES;}
@end
int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(TLAppDelegate.class));}}
