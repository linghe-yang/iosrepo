#pragma once
#include <algorithm>
#include <array>
#include <cstddef>
#include <cstdint>
namespace tl {
// Hardware tap sizes and SRC output sizes are not fixed. The original library
// must always see a complete 2048-sample block at the same registered address.
struct PCMBlocks {
    std::array<int16_t,2048> frame{};
    size_t used=0;
    int16_t* data(){return frame.data();}
    void reset(){used=0;}
    template<class Callback> void append(const int16_t *source,size_t count,Callback complete){
        while(count){size_t take=std::min(count,frame.size()-used);std::copy_n(source,take,frame.data()+used);source+=take;count-=take;used+=take;if(used==frame.size()){used=0;complete();}}
    }
};
}
