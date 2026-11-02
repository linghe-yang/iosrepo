#include "../src/Geometry.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
static void valid(SBRect r) {
    assert(isfinite(r.x)&&isfinite(r.y)&&isfinite(r.w)&&isfinite(r.h));
    assert(r.w>=.01&&r.h>=.01&&r.w<=1.2&&r.h<=1.2);
}
int main(void) {
    for(int bits=0;bits<16;bits++) {
        bool hasOverride=bits&1,overrideEnabled=bits&2,restricted=bits&4,selected=bits&8;
        bool enabled=SBAppEnabled(hasOverride,overrideEnabled,restricted,selected);
        if(hasOverride) assert(enabled==overrideEnabled);
        else assert(enabled==(!restricted || selected));
        // Explicit OFF must hide even in the old unrestricted mode or old allowlist.
        if(hasOverride && !overrideEnabled) assert(!SBVisible(1,0,1,1,enabled,0));
        if(enabled) assert(!SBVisible(1,0,1,1,enabled,1)); // Still hidden in app switcher.
    }
    // All four orientations: each logical corner maps to the expected physical corner.
    const SBPoint expected[4][4]={
        {{0,0},{744,0},{0,1133},{744,1133}},
        {{744,1133},{0,1133},{744,0},{0,0}},
        {{0,1133},{0,0},{744,1133},{744,0}},
        {{744,0},{744,1133},{0,0},{0,1133}}
    };
    for(int orientation=1;orientation<=4;orientation++) {
        double w=orientation>=3?1133:744,h=orientation>=3?744:1133;
        for(int corner=0;corner<4;corner++) {
            SBPoint p=SBPointInFixedScreen((SBPoint){corner&1?w:0,corner&2?h:0},orientation,744,1133);
            assert(p.x==expected[orientation-1][corner].x && p.y==expected[orientation-1][corner].y);
        }
        SBPoint center=SBPointInFixedScreen((SBPoint){w/2,h/2},orientation,744,1133);
        assert(center.x==372 && center.y==566.5);
        // Moving horizontally in the app must preserve physical displacement length.
        SBPoint a=SBPointInFixedScreen((SBPoint){10,20},orientation,744,1133);
        SBPoint b=SBPointInFixedScreen((SBPoint){40,20},orientation,744,1133);
        assert(fabs(hypot(b.x-a.x,b.y-a.y)-30)<1e-9);
    }
    for(int bits=0;bits<64;bits++) {
        bool enabled=bits&1,locked=bits&2,restricted=bits&4,known=bits&8,selected=bits&16,switcher=bits&32;
        bool actual=SBVisible(enabled,locked,restricted,known,selected,switcher);
        if(!enabled||locked||!known||switcher) assert(!actual);
        else if(!restricted) assert(actual);
        else assert(actual==(known&&selected));
    }
    assert(SBVisible(1,0,1,1,1,0));
    assert(!SBVisible(1,0,1,1,0,0)); // Leave selected app: hide.
    assert(!SBVisible(1,0,1,0,1,0)); // Unknown foreground: fail closed.
    // The front app can remain selected throughout app-switcher entry and exit.
    const bool switcherStates[]={false,true,true,false};
    const bool expectedVisible[]={true,false,false,true};
    for(int i=0;i<4;i++) {
        assert(SBVisible(1,0,1,1,1,switcherStates[i])==expectedVisible[i]);
        assert(SBVisible(1,0,0,1,0,switcherStates[i])==expectedVisible[i]);
    }
    SBRect full=SBCenteredRect(.5,.5,1,.2);
    assert(full.x==0 && fabs(full.y-.4)<1e-9);
    SBRect portrait=SBPixelRect(full,744,1133),landscape=SBPixelRect(full,1133,744);
    assert(portrait.w==744 && fabs(portrait.h-226.6)<1e-9);
    assert(landscape.w==1133 && fabs(landscape.h-148.8)<1e-9);
    SBRect oversized=SBCenteredRect(.5,.5,1.2,1.2);
    assert(fabs(oversized.x+.1)<1e-9 && fabs(oversized.y+.1)<1e-9);
    SBRect moved=SBDrag(oversized,-2,3);
    assert(moved.x < -1 && moved.y > 1 && moved.w==oversized.w && moved.h==oversized.h);
    SBRect reset=SBCenteredRect(.5,.5,moved.w,moved.h);
    assert(reset.w==1.2 && reset.h==1.2 && fabs(reset.x+reset.w/2-.5)<1e-9);
    // A saved off-screen center survives relaunch and viewport changes.
    SBRect restored=SBCenteredRect(moved.x+moved.w/2,moved.y+moved.h/2,moved.w,moved.h);
    assert(fabs(restored.x-moved.x)<1e-9 && fabs(restored.y-moved.y)<1e-9);
    valid(SBNormalizeRect((SBRect){NAN,INFINITY,-4,NAN}));
    srand(23);
    for(int i=0;i<50000;i++) {
        double w=(rand()%1500)/1000.,h=(rand()%1500)/1000.;
        double cx=(rand()%8000-4000)/1000.,cy=(rand()%8000-4000)/1000.;
        SBRect before=SBCenteredRect(cx,cy,w,h);valid(before);
        SBRect after=SBDrag(before,.45,-.32);valid(after);
        assert(after.w==before.w && after.h==before.h);
        assert(fabs(after.x-before.x-.45)<1e-9 && fabs(after.y-before.y+.32)<1e-9);
        SBRect p=SBPixelRect(after,744,1133),l=SBPixelRect(after,1133,744);
        assert(fabs(p.w/744-l.w/1133)<1e-9 && fabs(p.h/1133-l.h/744)<1e-9);
        SBRect center=SBCenteredRect(.5,.5,after.w,after.h);
        assert(fabs(center.x+center.w/2-.5)<1e-9 && fabs(center.y+center.h/2-.5)<1e-9);
    }
    puts("PASS: 4 screen directions; 100%x20% and 120% sizes; off-screen dragging, center reset, restoration; 64 policies; 50000 geometry cases");
}
