#include "Geometry.h"
#include <math.h>
SBPoint SBPointInFixedScreen(SBPoint p,int orientation,double w,double h) {
    switch(orientation) {
        case 2: return (SBPoint){w-p.x,h-p.y};
        // UIInterfaceOrientationLandscapeRight=3: device home edge is on the right.
        case 3: return (SBPoint){w-p.y,p.x};
        case 4: return (SBPoint){p.y,h-p.x};
        default: return p;
    }
}
SBRect SBNormalizeRect(SBRect r) {
    if(!isfinite(r.w)) r.w=.8;
    if(!isfinite(r.h)) r.h=.2;
    r.w=fmin(1.2,fmax(.01,r.w));r.h=fmin(1.2,fmax(.01,r.h));
    if(!isfinite(r.x)) r.x=.5-r.w/2;
    if(!isfinite(r.y)) r.y=.5-r.h/2;
    // Positions deliberately remain unconstrained, including completely off screen.
    return r;
}
SBRect SBCenteredRect(double cx,double cy,double w,double h) {
    SBRect r=SBNormalizeRect((SBRect){0,0,w,h});
    r.x=(isfinite(cx)?cx:.5)-r.w/2;r.y=(isfinite(cy)?cy:.5)-r.h/2;
    return r;
}
SBRect SBPixelRect(SBRect r,double width,double height) {
    r=SBNormalizeRect(r);
    return (SBRect){r.x*width,r.y*height,r.w*width,r.h*height};
}
SBRect SBDrag(SBRect r,double dx,double dy) {
    r=SBNormalizeRect(r);
    if(isfinite(dx) && isfinite(r.x+dx)) r.x+=dx;
    if(isfinite(dy) && isfinite(r.y+dy)) r.y+=dy;
    return r;
}
bool SBVisible(bool enabled,bool locked,bool restricted,bool frontKnown,bool selected,bool switcherVisible) {
    // A per-app profile requires a known foreground application even without a whitelist.
    return enabled && !locked && !switcherVisible && frontKnown && (!restricted || selected);
}
