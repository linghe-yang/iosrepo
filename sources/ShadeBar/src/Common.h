#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import "Geometry.h"
#import "Interaction.h"
#import "Store.h"
#import "TextModel.h"
static NSString *const SBDomain=@"com.linghe.shadebar";
static const char *SBChanged="com.linghe.shadebar.changed";
static inline NSString *SBT(NSString *en,NSString *zh) {
    NSString *s=NSLocale.preferredLanguages.firstObject.lowercaseString;
    BOOL cn=[s hasPrefix:@"zh-hans"] || [s isEqual:@"zh-cn"] || [s isEqual:@"zh-sg"];
    return cn?zh:en;
}
static inline NSDictionary *SBRead(void) {
    NSDictionary *d=CFBridgingRelease(SBStoreCopy());
    return [d isKindOfClass:NSDictionary.class]?d:@{};
}
static inline BOOL SBWrite(NSDictionary *changes) {
    BOOL success=SBStoreWrite((__bridge CFDictionaryRef)changes);
    if(success) notify_post(SBChanged);
    return success;
}
static inline BOOL SBBool(NSDictionary *d,NSString *k,BOOL fallback) {
    id v=d[k]; return [v respondsToSelector:@selector(boolValue)]?[v boolValue]:fallback;
}
static inline double SBNumber(NSDictionary *d,NSString *k,double fallback) {
    id v=d[k]; double n=[v respondsToSelector:@selector(doubleValue)]?[v doubleValue]:fallback;
    return isfinite(n)?n:fallback;
}
static inline NSString *SBProfileKey(NSString *bundle,NSString *field) {
    return [NSString stringWithFormat:@"profile.%@.%@",bundle,field];
}
static inline BOOL SBApplicationEnabled(NSDictionary *settings,NSString *bundle) {
    if(!bundle.length) return NO;
    id override=settings[SBProfileKey(bundle,@"enabled")];
    BOOL hasOverride=[override respondsToSelector:@selector(boolValue)];
    id apps=settings[@"apps"];
    BOOL selected=[apps isKindOfClass:NSArray.class] && [apps containsObject:bundle];
    return SBAppEnabled(hasOverride,hasOverride?[override boolValue]:NO,SBBool(settings,@"restricted",NO),selected);
}
static inline NSDictionary *SBProfile(NSDictionary *settings,NSString *bundle) {
    NSMutableDictionary *profile=[@{@"width":@.8,@"height":@.2,@"opacity":@1,@"color":@"000000",@"barVisible":@YES,@"interactive":@YES,@"iconEnabled":@YES,@"portrait.cx":@.5,@"portrait.cy":@.5,@"landscape.cx":@.5,@"landscape.cy":@.5,@"portrait.icon.cx":@.88,@"portrait.icon.cy":@.2,@"landscape.icon.cx":@.88,@"landscape.icon.cy":@.2} mutableCopy];
    [profile addEntriesFromDictionary:@{@"textEnabled":@NO,@"textLines":@[],@"textSpacing":@4,@"textHorizontal":@1,@"textVertical":@1}];
    for(NSString *field in profile.allKeys) {
        id value=settings[SBProfileKey(bundle,field)];
        if(value) profile[field]=value;
    }
    // Normalize old zero-opacity profiles on read, including gesture cancellation restores.
    profile[@"opacity"]=@(SBOpacity(SBNumber(profile,@"opacity",1)));
    profile[@"textLines"]=SBTextLines(profile[@"textLines"]);
    profile[@"textSpacing"]=@(SBTextSpacing(SBNumber(profile,@"textSpacing",4)));
    for(NSString *field in @[@"textHorizontal",@"textVertical"]) profile[field]=@(SBTextAlignment(SBNumber(profile,field,1)));
    return profile;
}
static inline BOOL SBWriteProfile(NSString *bundle,NSDictionary *changes) {
    if(!bundle.length) return NO;
    NSMutableDictionary *flat=[NSMutableDictionary new];
    for(NSString *field in changes) {
        id value=changes[field];
        if([field isEqual:@"opacity"]) value=@(SBOpacity(SBNumber(changes,field,1)));
        else if([field isEqual:@"textLines"]) value=SBTextLines(value);
        else if([field isEqual:@"textSpacing"]) value=@(SBTextSpacing(SBNumber(changes,field,4)));
        else if([field isEqual:@"textHorizontal"] || [field isEqual:@"textVertical"]) value=@(SBTextAlignment(SBNumber(changes,field,1)));
        flat[SBProfileKey(bundle,field)]=value;
    }
    // Flat keys let the shared-store lock merge unrelated app/field edits safely.
    return SBWrite(flat);
}
static inline SBRect SBFrame(NSDictionary *d,BOOL landscape) {
    NSString *p=landscape?@"landscape":@"portrait";
    return SBCenteredRect(SBNumber(d,[p stringByAppendingString:@".cx"],.5),SBNumber(d,[p stringByAppendingString:@".cy"],.5),SBNumber(d,@"width",.8),SBNumber(d,@"height",.2));
}
static inline UIColor *SBColor(NSDictionary *d) {
    NSString *s=[d[@"color"] isKindOfClass:NSString.class]?d[@"color"]:@"000000";
    s=[s stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned n=0; NSScanner *scan=[NSScanner scannerWithString:s];
    if(s.length!=6 || ![scan scanHexInt:&n] || !scan.isAtEnd) n=0;
    return [UIColor colorWithRed:((n>>16)&255)/255.0 green:((n>>8)&255)/255.0 blue:(n&255)/255.0 alpha:1];
}
