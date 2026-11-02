#pragma once
#import <UIKit/UIKit.h>
#import "TextLayout.h"
static inline NSString *SBTextSingleLine(id value) {
    if(![value isKindOfClass:NSString.class]) return @"";
    NSString *text=[[value componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet] componentsJoinedByString:@" "];
    // Keep Unicode graphemes intact, including composed emoji and combining accents.
    if(text.length>2048) text=[text substringWithRange:[text rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,2048)]];
    return text;
}
static inline NSArray<NSDictionary *> *SBTextLines(id value) {
    if(![value isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *lines=[NSMutableArray new];NSMutableSet *ids=[NSMutableSet new];
    for(id entry in value) {
        if(![entry isKindOfClass:NSDictionary.class]) continue;
        NSString *identifier=[entry[@"id"] isKindOfClass:NSString.class]?entry[@"id"]:@"";
        if(!identifier.length || [ids containsObject:identifier]) identifier=[NSString stringWithFormat:@"legacy-%lu",(unsigned long)lines.count];
        [ids addObject:identifier];
        NSString *color=[entry[@"color"] isKindOfClass:NSString.class]?[entry[@"color"] uppercaseString]:@"FFFFFF";
        unsigned number=0;NSScanner *scan=[NSScanner scannerWithString:color];
        if(color.length!=6 || ![scan scanHexInt:&number] || !scan.isAtEnd) color=@"FFFFFF";
        id size=entry[@"size"];double points=[size respondsToSelector:@selector(doubleValue)]?[size doubleValue]:24;
        NSString *font=[entry[@"font"] isKindOfClass:NSString.class]?entry[@"font"]:@"";
        if(font.length>256) font=@"";
        [lines addObject:@{@"id":identifier,@"text":SBTextSingleLine(entry[@"text"]),@"color":color,@"size":@(SBTextFontSize(points)),@"font":font}];
        if(lines.count>=SBTextMaxLines) break;
    }
    return lines;
}
static inline UIFont *SBTextFont(NSDictionary *line) {
    CGFloat size=SBTextFontSize([line[@"size"] doubleValue]);
    NSString *name=line[@"font"];
    return (name.length?[UIFont fontWithName:name size:size]:nil)?:[UIFont systemFontOfSize:size];
}
