#pragma once
#include <cstdint>
extern "C" {
void TLNativeInitialize();
void* TLNativeEnvironment();
void* TLNativeAddress(uint32_t originalAddress);
struct TLNativeBitmap {uint32_t width,height,stride,format,flags;void* pixels;};
void TLOriginal_AddIHConstant(void* env,void* object ,int i,float f);
void TLOriginal_AddIHOffsets(void* env,void* object ,int i);
void TLOriginal_AddThisIHOffset(void* env,void* object ,int i,int i2,float f);
float TLOriginal_AnalyzeForIH(void* env,void* object);
float TLOriginal_BetaNative(void* env,void* object ,int i);
int TLOriginal_CPcomm(void* env,void* object ,int i,int i2);
void TLOriginal_CalcDemodParms(void* env,void* object ,float f);
void TLOriginal_CalcPhaseIncrement(void* env,void* object ,float f,float f2);
void TLOriginal_ClearIHConstant(void* env,void* object ,int i);
void TLOriginal_ClearIHOffsets(void* env,void* object);
float TLOriginal_DeltaForPartialNative(void* env,void* object ,int i,int i2);
void TLOriginal_DoAdjust(void* env,void* object ,int i,float f,float f2,float f3,float f4);
int TLOriginal_GetIHConstantExists(void* env,void* object ,int i);
float TLOriginal_GetIHConstantValue(void* env,void* object ,int i);
float TLOriginal_GetIHOffset(void* env,void* object ,int i,int i2);
float TLOriginal_GetOneIHResultAmp(void* env,void* object ,int i);
float TLOriginal_GetOneIHResultOffset(void* env,void* object ,int i);
int TLOriginal_GetPitch(void* env,void* object ,int i);
float TLOriginal_IHform(void* env,void* object ,int i);
int TLOriginal_IncrBK(void* env,void* object ,int i,float f);
float TLOriginal_ModelCents(void* env,void* object ,int i);
void TLOriginal_Set3partParms(void* env,void* object ,int i,int i2,int i3,int i4,int i5,int i6);
void TLOriginal_SetAdjustmentParms(void* env,void* object ,int i,int i2,int i3,float f,int i4,int i5);
void TLOriginal_SetAutoNoteParms(void* env,void* object);
int TLOriginal_SetMeasureState(void* env,void* object ,int i);
void TLOriginal_SetNote(void* env,void* object ,int i,float f,int i2);
float TLOriginal_TStretchForPartial(void* env,void* object ,int i,int i2);
float TLOriginal_drawSpectrumGraph(void* env,void* object ,void* bitmap);
void TLOriginal_flashTallyRect(void* env,void* object ,int i,int i2);
int TLOriginal_mparAvgVelQual(void* env,void* object);
int TLOriginal_mparVelQual(void* env,void* object ,int i);
int TLOriginal_processAudioBuffer(void* env,void* object ,int i);
int TLOriginal_processForAutoNote(void* env,void* object);
int TLOriginal_setAudioBlockAddress(void* env,void* object ,void* shortBuffer,float f);
int TLOriginal_setFilesDir(void* env,void* object ,void* str);
int TLOriginal_setupPartials(void* env,void* object ,int i,int i2,int i3,int i4);
void TLOriginal_setupSpectrumGraph(void* env,void* object ,int i,int i2,int i3,float f,int i4,int i5,int i6,int i7);
}
