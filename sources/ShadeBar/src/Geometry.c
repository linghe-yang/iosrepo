#include "Geometry.h"
#include <math.h>
static double bound(double v, double lo, double hi) { return fmin(hi, fmax(lo, v)); }
SBRect SBClamp(SBRect r, double width, double height) {
    if (!isfinite(width) || width < 1) width=1;
    if (!isfinite(height) || height < 1) height=1;
    if (!isfinite(r.x)) r.x=.1;
    if (!isfinite(r.y)) r.y=.35;
    if (!isfinite(r.w)) r.w=.8;
    if (!isfinite(r.h)) r.h=.12;
    r.w=bound(r.w,fmin(12/width,1),1); r.h=bound(r.h,fmin(12/height,1),1);
    r.x=bound(r.x,0,1-r.w); r.y=bound(r.y,0,1-r.h); return r;
}
SBRect SBDrag(SBRect r,double dx,double dy,double width,double height) {
    r=SBClamp(r,width,height); r.x+=dx; r.y+=dy; return SBClamp(r,width,height);
}
SBRect SBResize(SBRect r,unsigned edges,double dx,double dy,double width,double height) {
    r=SBClamp(r,width,height);
    double right=r.x+r.w, bottom=r.y+r.h;
    double minW=fmin(12/fmax(width,1),1), minH=fmin(12/fmax(height,1),1);
    if(edges&SBLeft) { r.x=bound(r.x+dx,0,right-minW); r.w=right-r.x; }
    if(edges&SBRight) r.w=bound(r.w+dx,minW,1-r.x);
    if(edges&SBTop) { r.y=bound(r.y+dy,0,bottom-minH); r.h=bottom-r.y; }
    if(edges&SBBottom) r.h=bound(r.h+dy,minH,1-r.y);
    return SBClamp(r,width,height);
}
bool SBVisible(bool enabled,bool locked,bool restricted,bool frontKnown,bool selected) {
    return enabled && !locked && (!restricted || (frontKnown && selected));
}
