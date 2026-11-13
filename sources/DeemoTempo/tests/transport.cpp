#include "../src/Transport.hpp"
#include <cassert>
#include <cstdio>
using namespace practice;
int main(){
    // An early hit, a late miss and a chord. Decision time, not nominal
    // beat time, determines what survives a rewind.
    std::vector<Note> chart={{1,1,true},{2,2,true},{3,2,true},{4,2.4f,false},{5,3,true},{6,4,true}};
    Journal j;
    j.record(1,1.05f,1);j.record(2,1.95f,.8f);j.record(3,2.15f,0);
    j.move(2.3f,2.05f,chart);
    assert(j.done.count(2) && !j.done.count(3) && j.decisions.size()==2);
    j.move(2.05f,3,chart);
    assert(j.done.count(3) && !j.done.count(4) && !j.done.count(5));
    j.move(3,2.05f,chart);assert(!j.done.count(3)); // Undo even the overdue synthetic miss.
    j.move(2.05f,3,chart);
    j.move(3,3.5f,chart);
    assert(j.decisions.size()==4 && j.decisions.back().id==5);
    j.move(3.5f,1.96f,chart);
    assert(j.decisions.size()==2 && j.done.count(2));
    j.move(1.96f,0,chart);assert(j.decisions.empty());
    j.move(0,5,chart);assert(j.decisions.size()==5);
    j.move(5,5,chart);assert(j.decisions.size()==5);
    assert(!j.record(1,5,1));
    for(double hz : {15.,30.,60.,120.}){
        double near=follow(10,12,180,1/hz)-10;
        double far=follow(10,150,180,1/hz)-10;
        assert(far>near && near>0 && far<=90/hz+.00001);
        assert(follow(150,10,180,1/hz)<150);
        assert(follow(1,1,180,1/hz)==1);
        double position=1;
        for(int i=0;i<3600;++i) {position=follow(position,2,180,1/hz);assert(position<=2);}
        assert(position==2);
    }
    assert(follow(0,999,10,50)<=10 && follow(1,0,10,50)>=0);
    for(double length : {15.,180.,600.}) for(double fps : {30.,60.,120.}) {
        double dt=1/fps;
        double a=follow(7.0,-50,length,dt);
        double b=follow(length-7,length+50,length,dt);
        assert(std::abs((7-a)-(b-(length-7)))<1e-10);
        assert(std::abs((7-a)-90*dt)<1e-10);
        assert(follow(.15,0,length,dt)==0 && follow(length-.15,length,length,dt)==length);
    }
    auto window=visibleNotes(chart,2,3);
    assert(window.first==1 && window.end==5); // include both halves of chord
    window=visibleNotes(chart,3.1f,3.8f);
    assert(window.first==window.end); // genuinely empty section
    window=visibleNotes(chart,1.99f,2.01f);
    assert(window.first==1 && window.end==3); // chord returns on backwards motion
    puts("PASS: bidirectional follow, frame stalls, early/late judgements, chords, repeated seeks and skipped misses");
}
