#pragma once
#include <stdbool.h>
#include <math.h>
typedef struct {bool bar,icon,panel,barHit,window;} SBOverlayState;
static inline SBOverlayState SBOverlayVisibility(bool eligible,bool barShown,bool iconEnabled,bool panelOpen,bool interactive) {
    SBOverlayState s={eligible&&barShown,eligible&&iconEnabled&&!panelOpen,eligible&&panelOpen,false,false};
    s.barHit=s.bar&&interactive&&!s.panel;s.window=s.bar||s.icon||s.panel;return s;
}
enum {SBHitNone,SBHitBar,SBHitIcon,SBHitPanel,SBHitMask};
static inline int SBOverlayHit(SBOverlayState s,bool inBar,bool inIcon,bool inPanel) {
    if(!s.window) return SBHitNone;
    if(s.panel) return inPanel?SBHitPanel:SBHitMask;
    if(s.icon&&inIcon) return SBHitIcon;
    return s.barHit&&inBar?SBHitBar:SBHitNone;
}
/* Inward pinch raises opacity; outward stretch lowers it. Never changes visibility. */
static inline double SBPinchOpacity(double initial,double scale) {
    double base=isfinite(initial)?fmax(0,fmin(1,initial)):1;
    return isfinite(scale)?fmax(0,fmin(1,base+1-fmax(0,scale))):base;
}
static inline double SBIconCoordinate(double fraction,double length) {
    if(!isfinite(length)||length<=0) return 0;
    if(!isfinite(fraction)) fraction=.5;
    double inset=fmin(40,length/2);return fmax(inset,fmin(length-inset,fraction*length));
}
