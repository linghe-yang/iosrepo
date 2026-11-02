#include "../src/Geometry.h"
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
static void valid(SBRect r) {
    assert(isfinite(r.x)&&isfinite(r.y)&&isfinite(r.w)&&isfinite(r.h));
    assert(r.x>=0&&r.y>=0&&r.w>0&&r.h>0);
    assert(r.x+r.w<=1.00000001&&r.y+r.h<=1.00000001);
}
int main(void) {
    for(int bits=0;bits<32;bits++) {
        bool enabled=bits&1,locked=bits&2,restricted=bits&4,known=bits&8,selected=bits&16;
        bool actual=SBVisible(enabled,locked,restricted,known,selected);
        if(!enabled||locked) assert(!actual);
        else if(!restricted) assert(actual);
        else assert(actual==(known&&selected));
    }
    assert(SBVisible(1,0,1,1,1));
    assert(!SBVisible(1,0,1,1,0)); // Leave selected app: hide.
    assert(!SBVisible(1,0,1,0,1)); // Unknown foreground: fail closed.
    SBRect base={.1,.2,.6,.3};
    SBRect left=SBResize(base,SBLeft,.1,0,744,1133);
    assert(fabs(left.x-.2)<1e-9&&fabs(left.w-.5)<1e-9);
    assert(fabs(left.x+left.w-base.x-base.w)<1e-9);
    SBRect bottom=SBResize(base,SBBottom,0,.2,744,1133);
    assert(fabs(bottom.h-.5)<1e-9&&bottom.y==base.y);
    SBRect moved=SBDrag(base,5,-5,744,1133);
    assert(fabs(moved.x-.4)<1e-9&&moved.y==0&&moved.w==base.w&&moved.h==base.h);
    valid(SBClamp((SBRect){NAN,INFINITY,-4,NAN},0,0));
    srand(23);
    for(int i=0;i<50000;i++) {
        double width=(i&1)?744:1133,height=(i&1)?1133:744;
        double dx=(rand()%4000-2000)/1000.,dy=(rand()%4000-2000)/1000.;
        SBRect r=SBResize(base,1u<<(i%4),dx,dy,width,height); valid(r);
        r=SBDrag(r,dy,dx,width,height); valid(r);
        valid(SBClamp(r,height,width)); // Orientation change remains on screen.
        base=r;
    }
    puts("PASS: 32 visibility combinations, foreground transitions, geometry edge cases, 50000 resize/move/rotation sequences");
}
