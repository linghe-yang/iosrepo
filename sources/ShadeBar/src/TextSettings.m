#import "Common.h"
#import "TextSettings.h"

static void SBTextSaveError(UIViewController *controller) {
    controller.navigationItem.prompt=SBT(@"Could not save. Please retry.",@"保存失败，请重试。");
}
static NSString *SBTextFontName(NSDictionary *line) {
    NSString *name=line[@"font"];return name.length?name:SBT(@"System (multilingual)",@"系统字体（多语言）");
}
static NSString *SBTextColorHex(UIColor *color) {
    CGFloat r=0,g=0,b=0,a=1;[color getRed:&r green:&g blue:&b alpha:&a];
    return [NSString stringWithFormat:@"%02X%02X%02X",(unsigned)lround(r*255),(unsigned)lround(g*255),(unsigned)lround(b*255)];
}
static UITableViewCell *SBTextSliderCell(NSString *name,double value,double minimum,double maximum,id target,SEL changed,SEL finished) {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.selectionStyle=UITableViewCellSelectionStyleNone;CGFloat width=cell.contentView.bounds.size.width-32;
    UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(16,7,width,25)];label.tag=101;
    label.font=[UIFont preferredFontForTextStyle:UIFontTextStyleBody];label.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    label.text=[NSString stringWithFormat:@"%@: %.0f pt",name,value];[cell.contentView addSubview:label];
    UISlider *slider=[[UISlider alloc] initWithFrame:CGRectMake(16,38,width,32)];slider.autoresizingMask=UIViewAutoresizingFlexibleWidth;
    slider.minimumValue=minimum;slider.maximumValue=maximum;slider.value=value;slider.accessibilityLabel=name;
    slider.accessibilityValue=[NSString stringWithFormat:@"%.0f pt",value];
    [slider addTarget:target action:changed forControlEvents:UIControlEventValueChanged];
    [slider addTarget:target action:finished forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    [cell.contentView addSubview:slider];return cell;
}
static void SBTextUpdateSlider(UISlider *slider) {
    slider.value=roundf(slider.value);slider.accessibilityValue=[NSString stringWithFormat:@"%.0f pt",slider.value];
    ((UILabel *)[slider.superview viewWithTag:101]).text=[NSString stringWithFormat:@"%@: %@",slider.accessibilityLabel,slider.accessibilityValue];
}

@interface ShadeTextLineSettings : UITableViewController <UIColorPickerViewControllerDelegate,UIFontPickerViewControllerDelegate>
@property(nonatomic,copy) NSString *bundle,*lineID;
@property(nonatomic,strong) NSDictionary *line;
@property(nonatomic,strong) NSNumber *pendingSize;
- (instancetype)initWithBundle:(NSString *)bundle lineID:(NSString *)lineID;
@end

@interface ShadeTextSettings ()
@property(nonatomic,copy) NSString *bundle;
@property(nonatomic,strong) NSDictionary *profile;
@property(nonatomic,strong) NSNumber *pendingSpacing;
@end
@implementation ShadeTextSettings
- (instancetype)initWithBundle:(NSString *)bundle {
    if((self=[super initWithStyle:UITableViewStyleInsetGrouped])) self.bundle=bundle;return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=SBT(@"Bar text",@"遮挡条文字");self.navigationItem.rightBarButtonItem=self.editButtonItem;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appResigned:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appActivated:) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)dealloc {[[NSNotificationCenter defaultCenter] removeObserver:self];}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self refresh];}
- (void)appResigned:(NSNotification *)notification {[self flushSpacing];}
- (void)appActivated:(NSNotification *)notification {[self refresh];}
- (void)viewWillDisappear:(BOOL)animated {[self flushSpacing];[super viewWillDisappear:animated];}
- (void)refresh {self.profile=SBProfile(SBRead(),self.bundle);[self.tableView reloadData];}
- (BOOL)save:(NSDictionary *)changes {
    if(!SBWriteProfile(self.bundle,changes)) {SBTextSaveError(self);return NO;}
    self.navigationItem.prompt=nil;[self refresh];return YES;
}
- (void)flushSpacing {if(self.pendingSpacing && [self save:@{@"textSpacing":self.pendingSpacing}]) self.pendingSpacing=nil;}
- (void)spacingChanged:(UISlider *)slider {SBTextUpdateSlider(slider);self.pendingSpacing=@(slider.value);}
- (void)spacingFinished:(UISlider *)slider {[self flushSpacing];}
- (void)toggle:(UISwitch *)control {[self save:@{@"textEnabled":@(control.on)}];}
- (void)align:(UISegmentedControl *)control {[self save:@{control.accessibilityIdentifier:@(control.selectedSegmentIndex)}];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {return 3;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return section==0?1:section==1?3:[self.profile[@"textLines"] count]+1;}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {return @[SBT(@"Text",@"文字"),SBT(@"Placement and spacing",@"位置与行距"),SBT(@"Lines",@"文字行列表")][section];}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Saved for this app. Hiding the bar also hides its text. Text color is independent of the bar's background opacity.",@"仅保存到此应用。隐藏遮挡条也会隐藏文字，文字颜色不受遮挡条背景不透明度影响。");
    if(section==1) return SBT(@"Alignment is relative to the bar. Spacing is the extra gap between line boxes, in points. Font sizes and spacing stay fixed when the bar resizes or rotates; excess text is clipped.",@"相对于遮挡条对齐。行距是两行之间额外增加的间隔，单位为点。条的尺寸和方向改变时，字号、行距不变；超出边缘的文字裁掉。");
    return SBT(@"One list item is one line. Tap to edit text, color, size and font. Swipe to delete; tap Edit to reorder. Blank items leave an empty line. Long lines never wrap or shrink.",@"每项就是一行。点开设置文字、颜色、字号和字体；左划删除，点“编辑”可拖动排序。空白项保留空行，长行不会自动换行或缩小。");
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)index {return index.section==1&&index.row==2?86:UITableViewAutomaticDimension;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    if(index.section==1 && index.row==2) return SBTextSliderCell(SBT(@"Line spacing",@"行距"),self.pendingSpacing?self.pendingSpacing.doubleValue:SBNumber(self.profile,@"textSpacing",4),0,100,self,@selector(spacingChanged:),@selector(spacingFinished:));
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if(index.section==0) {
        cell.textLabel.text=SBT(@"Show text on bar",@"在遮挡条上显示文字");UISwitch *control=[UISwitch new];control.on=SBBool(self.profile,@"textEnabled",NO);
        [control addTarget:self action:@selector(toggle:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if(index.section==1) {
        cell.textLabel.text=index.row==0?SBT(@"Horizontal",@"水平对齐"):SBT(@"Vertical",@"垂直对齐");
        NSArray *titles=index.row==0?@[SBT(@"Left",@"居左"),SBT(@"Center",@"居中"),SBT(@"Right",@"居右")]:@[SBT(@"Top",@"居上"),SBT(@"Center",@"居中"),SBT(@"Bottom",@"居下")];
        UISegmentedControl *control=[[UISegmentedControl alloc] initWithItems:titles];control.frame=CGRectMake(0,0,200,32);
        control.accessibilityIdentifier=index.row==0?@"textHorizontal":@"textVertical";control.accessibilityLabel=cell.textLabel.text;
        control.selectedSegmentIndex=SBTextAlignment(SBNumber(self.profile,control.accessibilityIdentifier,1));
        [control addTarget:self action:@selector(align:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=control;cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else {
        NSArray *lines=self.profile[@"textLines"];
        if(index.row==(NSInteger)lines.count) {cell.textLabel.text=SBT(@"Add line",@"添加一行");cell.textLabel.textColor=UIColor.systemBlueColor;}
        else {
            NSDictionary *line=lines[index.row];NSString *text=line[@"text"];
            cell.textLabel.text=[NSString stringWithFormat:@"%ld. %@",(long)index.row+1,text.length?text:SBT(@"(Blank line)",@"（空行）")];
            cell.detailTextLabel.text=[NSString stringWithFormat:@"%.0f pt · #%@ · %@",[line[@"size"] doubleValue],line[@"color"],SBTextFontName(line)];
            cell.detailTextLabel.numberOfLines=2;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        }
    }return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];if(index.section!=2) return;[self flushSpacing];
    NSMutableArray *lines=[self.profile[@"textLines"] mutableCopy];NSString *identifier=nil;
    if(index.row==(NSInteger)lines.count) {
        if(lines.count>=SBTextMaxLines) {self.navigationItem.prompt=SBT(@"Up to 100 lines per app.",@"每个应用最多可添加 100 行。");return;}
        identifier=NSUUID.UUID.UUIDString;
        [lines addObject:@{@"id":identifier,@"text":@"",@"color":@"FFFFFF",@"size":@24,@"font":@""}];
        if(![self save:@{@"textLines":lines}]) return;
    } else identifier=lines[index.row][@"id"];
    [self.navigationController pushViewController:[[ShadeTextLineSettings alloc] initWithBundle:self.bundle lineID:identifier] animated:YES];
}
- (BOOL)tableView:(UITableView *)table canEditRowAtIndexPath:(NSIndexPath *)index {return index.section==2 && index.row<(NSInteger)[self.profile[@"textLines"] count];}
- (BOOL)tableView:(UITableView *)table canMoveRowAtIndexPath:(NSIndexPath *)index {return [self tableView:table canEditRowAtIndexPath:index];}
- (NSIndexPath *)tableView:(UITableView *)table targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source toProposedIndexPath:(NSIndexPath *)target {
    NSInteger last=[self.profile[@"textLines"] count]-1;
    return [NSIndexPath indexPathForRow:target.section<2?0:MIN(target.row,last) inSection:2];
}
- (void)tableView:(UITableView *)table moveRowAtIndexPath:(NSIndexPath *)source toIndexPath:(NSIndexPath *)target {
    NSMutableArray *lines=[self.profile[@"textLines"] mutableCopy];id line=lines[source.row];[lines removeObjectAtIndex:source.row];[lines insertObject:line atIndex:target.row];[self save:@{@"textLines":lines}];
}
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)index {
    if(style!=UITableViewCellEditingStyleDelete) return;
    NSMutableArray *lines=[self.profile[@"textLines"] mutableCopy];[lines removeObjectAtIndex:index.row];[self save:@{@"textLines":lines}];
}
@end

@implementation ShadeTextLineSettings
- (instancetype)initWithBundle:(NSString *)bundle lineID:(NSString *)lineID {
    if((self=[super initWithStyle:UITableViewStyleInsetGrouped])) {self.bundle=bundle;self.lineID=lineID;}return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=SBT(@"Text line",@"这一行文字");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appResigned:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appActivated:) name:UIApplicationDidBecomeActiveNotification object:nil];
}
- (void)dealloc {[[NSNotificationCenter defaultCenter] removeObserver:self];}
- (void)viewWillAppear:(BOOL)animated {[super viewWillAppear:animated];[self refresh];}
- (void)appResigned:(NSNotification *)notification {[self flushSize];}
- (void)appActivated:(NSNotification *)notification {[self refresh];}
- (void)viewWillDisappear:(BOOL)animated {[self flushSize];[super viewWillDisappear:animated];}
- (void)refresh {
    self.line=nil;for(NSDictionary *line in SBProfile(SBRead(),self.bundle)[@"textLines"]) if([line[@"id"] isEqual:self.lineID]) {self.line=line;break;}
    [self.tableView reloadData];
}
- (BOOL)saveLine:(NSDictionary *)changes refresh:(BOOL)refresh {
    NSMutableArray *lines=[SBProfile(SBRead(),self.bundle)[@"textLines"] mutableCopy];
    NSUInteger index=[lines indexOfObjectPassingTest:^BOOL(NSDictionary *line,NSUInteger i,BOOL *stop){return [line[@"id"] isEqual:self.lineID];}];
    if(index==NSNotFound) {self.navigationItem.prompt=SBT(@"This line was removed.",@"这一行已被删除。");return NO;}
    NSMutableDictionary *line=[lines[index] mutableCopy];[line addEntriesFromDictionary:changes];lines[index]=line;
    if(!SBWriteProfile(self.bundle,@{@"textLines":lines})) {SBTextSaveError(self);return NO;}
    self.navigationItem.prompt=nil;self.line=SBTextLines(@[line]).firstObject;
    if(refresh) [self.tableView reloadData];return YES;
}
- (void)sizeChanged:(UISlider *)slider {SBTextUpdateSlider(slider);self.pendingSize=@(slider.value);}
- (void)flushSize {if(self.pendingSize && [self saveLine:@{@"size":self.pendingSize} refresh:NO]) self.pendingSize=nil;}
- (void)sizeFinished:(UISlider *)slider {[self flushSize];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)table {return self.line?3:0;}
- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section {return ((NSInteger[]){1,2,3})[section];}
- (NSString *)tableView:(UITableView *)table titleForHeaderInSection:(NSInteger)section {return @[SBT(@"Content",@"内容"),SBT(@"Text color",@"文字颜色"),SBT(@"Font",@"字体")][section];}
- (NSString *)tableView:(UITableView *)table titleForFooterInSection:(NSInteger)section {
    if(section==0) return SBT(@"Type one line in any language. Add another list item for a new line; pasted line breaks become spaces. Up to 2048 text units per item.",@"可输入多国语言文字。需要换行请添加列表项，粘贴的换行会转为空格。每项最多约 2048 字符。");
    if(section==2) return SBT(@"Fixed size in points (6–200). Choose an available device font. Missing fonts use the system font; character coverage depends on installed fonts and system fallback.",@"固定字号，单位为点（6–200）。可选择设备可用字体；字体不可用时使用系统字体。各语言字符的显示取决于已安装字体及系统回退字体。");
    return nil;
}
- (CGFloat)tableView:(UITableView *)table heightForRowAtIndexPath:(NSIndexPath *)index {return index.section==2&&index.row==0?86:UITableViewAutomaticDimension;}
- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)index {
    if(index.section==2 && index.row==0) return SBTextSliderCell(SBT(@"Font size",@"字号"),self.pendingSize?self.pendingSize.doubleValue:[self.line[@"size"] doubleValue],6,200,self,@selector(sizeChanged:),@selector(sizeFinished:));
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.detailTextLabel.numberOfLines=2;
    if(index.section==0) {cell.textLabel.text=SBT(@"Edit text",@"编辑文字");cell.detailTextLabel.text=[self.line[@"text"] length]?self.line[@"text"]:SBT(@"(Blank line)",@"（空行）");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    else if(index.section==1) {
        cell.textLabel.text=index.row==0?SBT(@"Choose color",@"选择颜色"):SBT(@"Color HEX",@"颜色 HEX");cell.detailTextLabel.text=[@"#" stringByAppendingString:self.line[@"color"]];
        UIView *swatch=[[UIView alloc] initWithFrame:CGRectMake(0,0,32,24)];swatch.backgroundColor=SBColor(self.line);swatch.layer.borderWidth=.5;swatch.layer.borderColor=UIColor.separatorColor.CGColor;cell.accessoryView=swatch;
    } else if(index.row==1) {cell.textLabel.text=SBT(@"Choose font",@"选择字体");cell.detailTextLabel.text=SBTextFontName(self.line);cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
    else {cell.textLabel.text=SBT(@"Use system font",@"使用系统字体");cell.textLabel.textColor=UIColor.systemBlueColor;}
    return cell;
}
- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)index {
    [table deselectRowAtIndexPath:index animated:YES];[self flushSize];
    if(index.section==2) {
        if(index.row==2) {[self saveLine:@{@"font":@""} refresh:YES];return;}
        if(index.row==0) return;
        UIFontPickerViewControllerConfiguration *configuration=[UIFontPickerViewControllerConfiguration new];configuration.includeFaces=YES;
        UIFontPickerViewController *picker=[[UIFontPickerViewController alloc] initWithConfiguration:configuration];picker.delegate=self;picker.selectedFontDescriptor=SBTextFont(self.line).fontDescriptor;
        [self presentViewController:picker animated:YES completion:nil];return;
    }
    if(index.section==1 && index.row==0) {
        UIColorPickerViewController *picker=[UIColorPickerViewController new];picker.delegate=self;picker.supportsAlpha=NO;picker.selectedColor=SBColor(self.line);
        [self presentViewController:picker animated:YES completion:nil];return;
    }
    BOOL color=index.section==1;NSString *key=color?@"color":@"text";
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:color?SBT(@"Color HEX",@"颜色 HEX"):SBT(@"Edit this line",@"编辑这一行") message:color?SBT(@"Six digits, for example FF8800.",@"输入六位颜色，例如 FF8800。"):SBT(@"Use a new list item for each new line.",@"需要换行时，请添加新的列表项。") preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.text=self.line[key];if(color) {field.keyboardType=UIKeyboardTypeASCIICapable;field.autocorrectionType=UITextAutocorrectionTypeNo;}}];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Cancel",@"取消") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:SBT(@"Save",@"保存") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        NSString *text=alert.textFields.firstObject.text?:@"";
        if(color) {
            text=[[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByReplacingOccurrencesOfString:@"#" withString:@""];
            unsigned number=0;NSScanner *scan=[NSScanner scannerWithString:text];
            if(text.length!=6 || ![scan scanHexInt:&number] || !scan.isAtEnd) {self.navigationItem.prompt=SBT(@"Enter six hexadecimal digits.",@"请输入六位 HEX 颜色。");return;}
            text=text.uppercaseString;
        } else text=SBTextSingleLine(text);
        [self saveLine:@{key:text} refresh:YES];
    }]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)picker {[self saveLine:@{@"color":SBTextColorHex(picker.selectedColor)} refresh:YES];}
- (void)fontPickerViewControllerDidCancel:(UIFontPickerViewController *)picker {[self dismissViewControllerAnimated:YES completion:nil];}
- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)picker {
    NSString *name=picker.selectedFontDescriptor?[UIFont fontWithDescriptor:picker.selectedFontDescriptor size:24].fontName:nil;
    [self dismissViewControllerAnimated:YES completion:^{if(name) [self saveLine:@{@"font":name} refresh:YES];}];
}
@end
