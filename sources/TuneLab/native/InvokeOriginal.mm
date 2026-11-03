// Generated from original FFTLib.java; all 37 original signatures retained.
#import <Foundation/Foundation.h>
#include "OriginalDSP.hpp"
id TLInvokeOriginal(NSString *name,NSArray *arguments){
 TLNativeInitialize();void *env=TLNativeEnvironment();
 if([name isEqualToString:@"AddIHConstant"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"AddIHConstant: expected 2 arguments"];
  TLOriginal_AddIHConstant(env,nullptr, [arguments[0] intValue], [arguments[1] floatValue]);return NSNull.null;
 }
 if([name isEqualToString:@"AddIHOffsets"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"AddIHOffsets: expected 1 arguments"];
  TLOriginal_AddIHOffsets(env,nullptr, [arguments[0] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"AddThisIHOffset"]){
  if(arguments.count!=3)[NSException raise:NSInvalidArgumentException format:@"AddThisIHOffset: expected 3 arguments"];
  TLOriginal_AddThisIHOffset(env,nullptr, [arguments[0] intValue], [arguments[1] intValue], [arguments[2] floatValue]);return NSNull.null;
 }
 if([name isEqualToString:@"AnalyzeForIH"]){
  if(arguments.count!=0)[NSException raise:NSInvalidArgumentException format:@"AnalyzeForIH: expected 0 arguments"];
  return @(TLOriginal_AnalyzeForIH(env,nullptr));
 }
 if([name isEqualToString:@"BetaNative"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"BetaNative: expected 1 arguments"];
  return @(TLOriginal_BetaNative(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"CPcomm"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"CPcomm: expected 2 arguments"];
  return @(TLOriginal_CPcomm(env,nullptr, [arguments[0] intValue], [arguments[1] intValue]));
 }
 if([name isEqualToString:@"CalcDemodParms"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"CalcDemodParms: expected 1 arguments"];
  TLOriginal_CalcDemodParms(env,nullptr, [arguments[0] floatValue]);return NSNull.null;
 }
 if([name isEqualToString:@"CalcPhaseIncrement"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"CalcPhaseIncrement: expected 2 arguments"];
  TLOriginal_CalcPhaseIncrement(env,nullptr, [arguments[0] floatValue], [arguments[1] floatValue]);return NSNull.null;
 }
 if([name isEqualToString:@"ClearIHConstant"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"ClearIHConstant: expected 1 arguments"];
  TLOriginal_ClearIHConstant(env,nullptr, [arguments[0] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"ClearIHOffsets"]){
  if(arguments.count!=0)[NSException raise:NSInvalidArgumentException format:@"ClearIHOffsets: expected 0 arguments"];
  TLOriginal_ClearIHOffsets(env,nullptr);return NSNull.null;
 }
 if([name isEqualToString:@"DeltaForPartialNative"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"DeltaForPartialNative: expected 2 arguments"];
  return @(TLOriginal_DeltaForPartialNative(env,nullptr, [arguments[0] intValue], [arguments[1] intValue]));
 }
 if([name isEqualToString:@"DoAdjust"]){
  if(arguments.count!=5)[NSException raise:NSInvalidArgumentException format:@"DoAdjust: expected 5 arguments"];
  TLOriginal_DoAdjust(env,nullptr, [arguments[0] intValue], [arguments[1] floatValue], [arguments[2] floatValue], [arguments[3] floatValue], [arguments[4] floatValue]);return NSNull.null;
 }
 if([name isEqualToString:@"GetIHConstantExists"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"GetIHConstantExists: expected 1 arguments"];
  return @(TLOriginal_GetIHConstantExists(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"GetIHConstantValue"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"GetIHConstantValue: expected 1 arguments"];
  return @(TLOriginal_GetIHConstantValue(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"GetIHOffset"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"GetIHOffset: expected 2 arguments"];
  return @(TLOriginal_GetIHOffset(env,nullptr, [arguments[0] intValue], [arguments[1] intValue]));
 }
 if([name isEqualToString:@"GetOneIHResultAmp"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"GetOneIHResultAmp: expected 1 arguments"];
  return @(TLOriginal_GetOneIHResultAmp(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"GetOneIHResultOffset"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"GetOneIHResultOffset: expected 1 arguments"];
  return @(TLOriginal_GetOneIHResultOffset(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"GetPitch"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"GetPitch: expected 1 arguments"];
  return @(TLOriginal_GetPitch(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"IHform"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"IHform: expected 1 arguments"];
  return @(TLOriginal_IHform(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"IncrBK"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"IncrBK: expected 2 arguments"];
  return @(TLOriginal_IncrBK(env,nullptr, [arguments[0] intValue], [arguments[1] floatValue]));
 }
 if([name isEqualToString:@"ModelCents"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"ModelCents: expected 1 arguments"];
  return @(TLOriginal_ModelCents(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"Set3partParms"]){
  if(arguments.count!=6)[NSException raise:NSInvalidArgumentException format:@"Set3partParms: expected 6 arguments"];
  TLOriginal_Set3partParms(env,nullptr, [arguments[0] intValue], [arguments[1] intValue], [arguments[2] intValue], [arguments[3] intValue], [arguments[4] intValue], [arguments[5] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"SetAdjustmentParms"]){
  if(arguments.count!=6)[NSException raise:NSInvalidArgumentException format:@"SetAdjustmentParms: expected 6 arguments"];
  TLOriginal_SetAdjustmentParms(env,nullptr, [arguments[0] intValue], [arguments[1] intValue], [arguments[2] intValue], [arguments[3] floatValue], [arguments[4] intValue], [arguments[5] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"SetAutoNoteParms"]){
  if(arguments.count!=0)[NSException raise:NSInvalidArgumentException format:@"SetAutoNoteParms: expected 0 arguments"];
  TLOriginal_SetAutoNoteParms(env,nullptr);return NSNull.null;
 }
 if([name isEqualToString:@"SetMeasureState"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"SetMeasureState: expected 1 arguments"];
  return @(TLOriginal_SetMeasureState(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"SetNote"]){
  if(arguments.count!=3)[NSException raise:NSInvalidArgumentException format:@"SetNote: expected 3 arguments"];
  TLOriginal_SetNote(env,nullptr, [arguments[0] intValue], [arguments[1] floatValue], [arguments[2] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"TStretchForPartial"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"TStretchForPartial: expected 2 arguments"];
  return @(TLOriginal_TStretchForPartial(env,nullptr, [arguments[0] intValue], [arguments[1] intValue]));
 }
 if([name isEqualToString:@"drawSpectrumGraph"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"drawSpectrumGraph: expected 1 arguments"];
  if(![arguments[0] isKindOfClass:NSValue.class])[NSException raise:NSInvalidArgumentException format:@"drawSpectrumGraph: native pointer required"];
  return @(TLOriginal_drawSpectrumGraph(env,nullptr, [arguments[0] pointerValue]));
 }
 if([name isEqualToString:@"flashTallyRect"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"flashTallyRect: expected 2 arguments"];
  TLOriginal_flashTallyRect(env,nullptr, [arguments[0] intValue], [arguments[1] intValue]);return NSNull.null;
 }
 if([name isEqualToString:@"mparAvgVelQual"]){
  if(arguments.count!=0)[NSException raise:NSInvalidArgumentException format:@"mparAvgVelQual: expected 0 arguments"];
  return @(TLOriginal_mparAvgVelQual(env,nullptr));
 }
 if([name isEqualToString:@"mparVelQual"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"mparVelQual: expected 1 arguments"];
  return @(TLOriginal_mparVelQual(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"processAudioBuffer"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"processAudioBuffer: expected 1 arguments"];
  return @(TLOriginal_processAudioBuffer(env,nullptr, [arguments[0] intValue]));
 }
 if([name isEqualToString:@"processForAutoNote"]){
  if(arguments.count!=0)[NSException raise:NSInvalidArgumentException format:@"processForAutoNote: expected 0 arguments"];
  return @(TLOriginal_processForAutoNote(env,nullptr));
 }
 if([name isEqualToString:@"setAudioBlockAddress"]){
  if(arguments.count!=2)[NSException raise:NSInvalidArgumentException format:@"setAudioBlockAddress: expected 2 arguments"];
  if(![arguments[0] isKindOfClass:NSValue.class])[NSException raise:NSInvalidArgumentException format:@"setAudioBlockAddress: native pointer required"];
  return @(TLOriginal_setAudioBlockAddress(env,nullptr, [arguments[0] pointerValue], [arguments[1] floatValue]));
 }
 if([name isEqualToString:@"setFilesDir"]){
  if(arguments.count!=1)[NSException raise:NSInvalidArgumentException format:@"setFilesDir: expected 1 arguments"];
  if(![arguments[0] isKindOfClass:NSValue.class])[NSException raise:NSInvalidArgumentException format:@"setFilesDir: native pointer required"];
  return @(TLOriginal_setFilesDir(env,nullptr, [arguments[0] pointerValue]));
 }
 if([name isEqualToString:@"setupPartials"]){
  if(arguments.count!=4)[NSException raise:NSInvalidArgumentException format:@"setupPartials: expected 4 arguments"];
  return @(TLOriginal_setupPartials(env,nullptr, [arguments[0] intValue], [arguments[1] intValue], [arguments[2] intValue], [arguments[3] intValue]));
 }
 if([name isEqualToString:@"setupSpectrumGraph"]){
  if(arguments.count!=8)[NSException raise:NSInvalidArgumentException format:@"setupSpectrumGraph: expected 8 arguments"];
  TLOriginal_setupSpectrumGraph(env,nullptr, [arguments[0] intValue], [arguments[1] intValue], [arguments[2] intValue], [arguments[3] floatValue], [arguments[4] intValue], [arguments[5] intValue], [arguments[6] intValue], [arguments[7] intValue]);return NSNull.null;
 }
 [NSException raise:NSInvalidArgumentException format:@"Unknown original JNI method: %@",name];return nil;
}
