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
static inline double SBOpacity(double value) {
    return isfinite(value)?fmax(.1,fmin(1,value)):1;
}
static inline double SBPinchOpacity(double initial,double scale) {
    double base=SBOpacity(initial);
    return isfinite(scale)?SBOpacity(base+1-fmax(0,scale)):base;
}
static inline double SBIconCoordinate(double fraction,double length) {
    if(!isfinite(length)||length<=0) return 0;
    if(!isfinite(fraction)) fraction=.5;
    // 32-point icon: its center may approach 1 point from an edge (15 points outside).
    double inset=fmin(1,length/2);return fmax(inset,fmin(length-inset,fraction*length));
}
static inline int SBPanelOrientation(int device,int previous,int interfaceOrientation) {
    // UIKit's device and interface constants have the same physical numeric mapping;
    // the landscape *names* are opposite. Face up/down must not invent a direction.
    if(device>=1 && device<=4) return device;
    if(previous>=1 && previous<=4) return previous;
    return interfaceOrientation>=1 && interfaceOrientation<=4?interfaceOrientation:1;
}
