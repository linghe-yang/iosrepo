#include "../src/Tempo.hpp"
#include <cassert>
#include <cstdio>
#include <limits>
static int failAt,call,freed,removed;
static float ratio;
static int created,attached;
static int create(void*,int,void** out){if(++call==failAt)return 9;++created;*out=(void*)3;return 0;}
static int param(void*,int index,float v){if(index==0){assert(v>=.5f && v<=2);ratio*=v;}return ++call==failAt?9:0;}
static int attach(void*,void*,void**){if(++call==failAt)return 9;++attached;return 0;}
static int release(void*){++freed;return 0;}
static int removeFx(void*){++removed;return 0;}
int main() {
    PitchBackend api{create,param,attach,removeFx,release};
    for (int thousandths=100;thousandths<=2000;++thousandths) {
        float rate=thousandths/1000.f;
        Tempo t{rate};PitchSession fx;
        failAt=0; call=freed=removed=created=attached=0;ratio=1;
        assert(fx.start(api,(void*)1,(void*)2,11,t)==0);
        assert(std::fabs(440*rate*ratio-440)<.001);
        for(double wall=0;wall<300;wall+=.037) {
            double song=wall*rate;
            assert(std::fabs(t.wallDuration(song)-wall)<.00005);
            // Allow two float roundings: input wall seconds and the product.
            const double rounding = 2 * std::numeric_limits<float>::epsilon() * song;
            assert(std::fabs(t.chartDelta(wall)-song)<=rounding);
        }
        assert(attached>=1 && attached<=4);
        assert(fx.latencySeconds(48000)>0);
        fx.stop(api);fx.stop(api);assert(freed==created && removed==attached);
    }
    for(int bad=1;bad<=16;++bad){
        PitchSession fx;failAt=bad;call=freed=removed=created=attached=0;ratio=1;
        assert(fx.start(api,(void*)1,(void*)2,11,{.1f})!=0);
        fx.stop(api);assert(freed==created && removed==attached);
    }
    puts("PASS: 1901 rates from 0.100 through 2.000, 5-minute clock conversion, effect setup rollback, idempotent release");
}
