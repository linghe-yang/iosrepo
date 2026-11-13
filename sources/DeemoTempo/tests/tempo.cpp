#include "../src/Tempo.hpp"
#include <cassert>
#include <cstdio>
static int failAt,call,freed,removed;
static float ratio;
static int create(void*,int,void** out){if(++call==failAt)return 9;*out=(void*)3;return 0;}
static int param(void*,int index,float v){if(index==0)ratio=v;return ++call==failAt?9:0;}
static int attach(void*,void*,void**){return ++call==failAt?9:0;}
static int release(void*){++freed;return 0;}
static int removeFx(void*){++removed;return 0;}
int main() {
    PitchBackend api{create,param,attach,removeFx,release};
    for (float rate : {.5f,.75f,.9f,1.f,1.1f,1.25f,1.5f,2.f}) {
        Tempo t{rate};PitchSession fx;
        failAt=0; call=freed=removed=0;
        assert(fx.start(api,(void*)1,(void*)2,11,t)==0);
        assert(std::fabs(440*rate*ratio-440)<.001);
        for(double wall=0;wall<300;wall+=.037) {
            double song=wall*rate;
            assert(std::fabs(t.wallDuration(song)-wall)<.00005);
            assert(std::fabs(t.chartDelta(wall)-song)<.00005);
        }
        fx.stop(api);fx.stop(api);assert(freed==1 && removed==1);
    }
    for(int bad=1;bad<=4;++bad){
        PitchSession fx;failAt=bad;call=freed=removed=0;
        assert(fx.start(api,(void*)1,(void*)2,11,{.75f})!=0);
        fx.stop(api);assert(freed==(bad!=1) && !removed);
    }
    puts("PASS: eight rates, 5-minute clock conversion, effect setup rollback, idempotent release");
}
