#pragma once
#include "Geometry.h"
#include <math.h>
#include <stddef.h>
enum { SBTextMaxLines=100 };
typedef struct { double width,height; } SBTextMetric;
static inline double SBTextFontSize(double n) {return isfinite(n)?fmax(6,fmin(200,n)):24;}
static inline double SBTextSpacing(double n) {return isfinite(n)?fmax(0,fmin(100,n)):4;}
static inline int SBTextAlignment(double n) {return isfinite(n)&&n>=0&&n<=2?(int)n:1;}
static inline double SBTextOffset(double container,double content,int alignment) {
    // Negative offsets are intentional: oversized centered/right/bottom content clips.
    return alignment==0?0:alignment==2?container-content:(container-content)/2;
}
static inline void SBTextArrange(double width,double height,const SBTextMetric *lines,size_t count,double spacing,int horizontal,int vertical,SBRect *out) {
    double gap=SBTextSpacing(spacing),block=count?gap*(count-1):0;
    for(size_t i=0;i<count;i++) block+=lines[i].height;
    double y=SBTextOffset(height,block,vertical);
    for(size_t i=0;i<count;i++) {
        out[i]=(SBRect){SBTextOffset(width,lines[i].width,horizontal),y,lines[i].width,lines[i].height};
        y+=lines[i].height+gap;
    }
}
