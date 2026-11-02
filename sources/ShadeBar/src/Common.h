#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <notify.h>
#import "Geometry.h"
static NSString *const SBDomain=@"com.linghe.shadebar";
static const char *SBChanged="com.linghe.shadebar.changed";
static inline NSString *SBT(NSString *en,NSString *zh) {
    NSString *s=NSLocale.preferredLanguages.firstObject.lowercaseString;
    BOOL cn=[s hasPrefix:@"zh-hans"] || [s isEqual:@"zh-cn"] || [s isEqual:@"zh-sg"];
    return cn?zh:en;
}
static inline NSDictionary *SBRead(void) {
    CFPreferencesSynchronize((__bridge CFStringRef)SBDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    NSDictionary *d=CFBridgingRelease(CFPreferencesCopyMultiple(NULL,(__bridge CFStringRef)SBDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost));
    return [d isKindOfClass:NSDictionary.class]?d:@{};
}
static inline void SBWrite(NSDictionary *changes) {
    CFPreferencesSetMultiple((__bridge CFDictionaryRef)changes,NULL,(__bridge CFStringRef)SBDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    CFPreferencesSynchronize((__bridge CFStringRef)SBDomain,kCFPreferencesCurrentUser,kCFPreferencesAnyHost);
    notify_post(SBChanged);
}
static inline BOOL SBBool(NSDictionary *d,NSString *k,BOOL fallback) {
    id v=d[k]; return [v respondsToSelector:@selector(boolValue)]?[v boolValue]:fallback;
}
static inline double SBNumber(NSDictionary *d,NSString *k,double fallback) {
    id v=d[k]; double n=[v respondsToSelector:@selector(doubleValue)]?[v doubleValue]:fallback;
    return isfinite(n)?n:fallback;
}
static inline SBRect SBFrame(NSDictionary *d,BOOL landscape,CGSize size) {
    NSString *p=landscape?@"landscape":@"portrait";
    return SBClamp((SBRect){SBNumber(d,[p stringByAppendingString:@".x"],.1),SBNumber(d,[p stringByAppendingString:@".y"],.35),SBNumber(d,[p stringByAppendingString:@".w"],.8),SBNumber(d,[p stringByAppendingString:@".h"],.12)},size.width,size.height);
}
static inline UIColor *SBColor(NSDictionary *d) {
    NSString *s=[d[@"color"] isKindOfClass:NSString.class]?d[@"color"]:@"000000";
    s=[s stringByReplacingOccurrencesOfString:@"#" withString:@""];
    unsigned n=0; NSScanner *scan=[NSScanner scannerWithString:s];
    if(s.length!=6 || ![scan scanHexInt:&n] || !scan.isAtEnd) n=0;
    return [UIColor colorWithRed:((n>>16)&255)/255.0 green:((n>>8)&255)/255.0 blue:(n&255)/255.0 alpha:1];
}
