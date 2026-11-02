#include "../src/Geometry.h"
#include "../src/Interaction.h"
#include "../src/TextLayout.h"
#include "../src/StoreLimits.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
static void valid(SBRect r) {
    assert(isfinite(r.x)&&isfinite(r.y)&&isfinite(r.w)&&isfinite(r.h));
    assert(r.w>=.01&&r.h>=.01&&r.w<=1.2&&r.h<=1.2);
}
int main(void) {
    // Multi-app text profiles beyond the old read limit remain readable; oversized
    // writes must be rejected before replacing the last valid settings file.
    assert(SBStoreSizeAllowed(1024*1024+1));
    assert(SBStoreSizeAllowed(16*1024*1024));
    assert(!SBStoreSizeAllowed(0) && !SBStoreSizeAllowed(16*1024*1024+1));
    // Mixed font metrics: line heights and widths remain fixed across all nine alignments.
    const SBTextMetric lines[]={{240,30},{60,18},{0,24}};
    for(int horizontal=0;horizontal<3;horizontal++) for(int vertical=0;vertical<3;vertical++) {
        SBRect large[3],small[3];
        SBTextArrange(300,120,lines,3,7,horizontal,vertical,large);
        SBTextArrange(40,20,lines,3,7,horizontal,vertical,small);
        const double xLarge[]={0,30,60},xSmall[]={0,-100,-200};
        const double yLarge[]={0,17,34},ySmall[]={0,-33,-66}; // Block height 86, including empty line.
        assert(large[0].x==xLarge[horizontal] && small[0].x==xSmall[horizontal]);
        assert(large[0].y==yLarge[vertical] && small[0].y==ySmall[vertical]);
        for(int i=0;i<3;i++) {
            assert(large[i].w==lines[i].width && small[i].w==lines[i].width);
            assert(large[i].h==lines[i].height && small[i].h==lines[i].height);
            if(i) assert(small[i].y-small[i-1].y-small[i-1].h==7);
        }
        // Moving the entire bar offscreen must also move its text offscreen.
        if(horizontal==0) assert(-150+large[0].x==-150);
    }
    SBRect result[3];SBTextArrange(1,1,NULL,0,4,1,1,result);
    assert(SBTextFontSize(0)==6 && SBTextFontSize(250)==200 && SBTextFontSize(NAN)==24);
    assert(SBTextSpacing(-1)==0 && SBTextSpacing(200)==100 && SBTextSpacing(NAN)==4);
    assert(SBTextAlignment(NAN)==1 && SBTextAlignment(-1)==1 && SBTextAlignment(2)==2);
    // Actual hit-routing policy used by ShadeWindow, including full-screen bars.
    for(int flags=0;flags<32;flags++) {
        bool eligible=flags&1,bar=flags&2,icon=flags&4,panel=flags&8,interactive=flags&16;
        SBOverlayState state=SBOverlayVisibility(eligible,bar,icon,panel,interactive);
        if(!eligible) assert(!state.window && !state.bar && !state.icon && !state.panel);
        if(eligible && panel) assert(state.panel && !state.icon && !state.barHit);
        if(eligible && !panel && icon) assert(state.icon && state.window);
        if(!bar || !interactive) assert(!state.barHit);
        for(int points=0;points<8;points++) {
            bool inBar=points&1,inIcon=points&2,inPanel=points&4;
            int route=SBOverlayHit(state,inBar,inIcon,inPanel);
            if(!eligible) assert(route==SBHitNone);
            else if(panel) assert(route==(inPanel?SBHitPanel:SBHitMask));
            else if(icon && inIcon) assert(route==SBHitIcon); // Icon wins even over an opaque full-screen bar.
            else if(bar && interactive && inBar) assert(route==SBHitBar);
            else assert(route==SBHitNone); // Disabled interaction must not swallow app touches.
        }
    }
    SBOverlayState minimized=SBOverlayVisibility(1,0,1,0,1);
    assert(!minimized.bar && minimized.icon && minimized.window);
    assert(SBOverlayHit(minimized,1,0,0)==SBHitNone);
    assert(!SBOverlayVisibility(1,0,0,0,1).window);
    assert(fabs(SBPinchOpacity(.5,.7)-.8)<1e-9);
    assert(fabs(SBPinchOpacity(.5,1.3)-.2)<1e-9);
    assert(SBPinchOpacity(.5,1)==.5 && SBPinchOpacity(1,.1)==1 && SBPinchOpacity(0,2)==.1);
    assert(SBPinchOpacity(.5,NAN)==.5 && SBPinchOpacity(.5,100)==.1);
    assert(SBOpacity(0)==.1 && SBOpacity(-1)==.1 && SBOpacity(2)==1 && SBOpacity(NAN)==1);
    assert(SBPinchOpacity(0,.8)>.1 && SBPinchOpacity(.1,.8)>.1); // Old zero profiles recover.
    for(int i=0;i<1000;i++) {
        double start=.1+.9*i/999.;
        assert(SBPinchOpacity(start,.6)>=start && SBPinchOpacity(start,1.4)<=start);
    }
    for(int i=0;i<2;i++) {
        double w=i?1133:744,h=i?744:1133;
        assert(SBIconCoordinate(-4,w)==1 && SBIconCoordinate(8,w)==w-1);
        assert(SBIconCoordinate(0,w)-16==-15 && SBIconCoordinate(1,w)+16==w+15);
        assert(SBIconCoordinate(.88,w)>40 && SBIconCoordinate(.2,h)>40);
    }
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
        {{744,0},{744,1133},{0,0},{0,1133}},
        {{0,1133},{0,0},{744,1133},{744,0}}
    };
    for(int orientation=1;orientation<=4;orientation++) {
        // Device home edge: bottom, top, right, left. Text's down axis must
        // point with gravity in fixed portrait coordinates, never opposite it.
        const SBPoint gravity[]={{0,1},{0,-1},{-1,0},{1,0}};
        SBPoint o=SBPointInFixedScreen((SBPoint){0,0},orientation,744,1133);
        SBPoint down=SBPointInFixedScreen((SBPoint){0,1},orientation,744,1133);
        assert(down.x-o.x==gravity[orientation-1].x && down.y-o.y==gravity[orientation-1].y);
        for(int app=1;app<=4;app++) {
            assert(SBPanelOrientation(orientation,0,app)==orientation);
            for(int flat=5;flat<=6;flat++) assert(SBPanelOrientation(flat,orientation,app)==orientation);
            assert(SBPanelOrientation(0,0,app)==app);
        }
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
    puts("PASS: 9 fixed-size text alignments, overflow and spacing; 256 overlay hit routes; bar hiding, pass-through and icon recovery; pinch opacity bounds; 4 directions; 64 app policies; 50000 geometry cases");
}
