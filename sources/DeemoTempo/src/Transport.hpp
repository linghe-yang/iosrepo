#pragma once
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_set>
#include <vector>

namespace practice {
struct Note {
    uintptr_t id;
    float time;
    bool scored;
};
struct Decision {
    uintptr_t id;
    float time;
    float ratio;
};

// A seek branches the current run. Repeated forward/backward drags cannot
// duplicate a chord, resurrect a discarded future, or turn backing notes into misses.
struct Journal {
    std::vector<Decision> decisions;
    std::unordered_set<uintptr_t> done;
    bool record(uintptr_t id,float time,float ratio) {
        if (!id || !std::isfinite(time) || !std::isfinite(ratio) || !done.insert(id).second) return false;
        decisions.push_back({id,time,ratio});
        return true;
    }
    void move(float from,float to,const std::vector<Note>& notes) {
        if (to<from) {
            decisions.erase(std::remove_if(decisions.begin(),decisions.end(),
                [&](const Decision& e){return e.time>to;}),decisions.end());
            done.clear();
            for (auto e:decisions) done.insert(e.id);
        } else if (to>from) {
            for (const auto& n:notes) {
                if (n.time>=to) break;
                // An overdue, still-unjudged note in the original timing window
                // is also passed when skipping. Previously recorded hits win.
                if (n.scored) record(n.id,std::nextafter(std::max(n.time,from),to),0);
            }
        }
    }
};

inline double follow(double current,double target,double length,double dt) {
    if (!(length>0 && std::isfinite(target) && std::isfinite(dt) && dt>0)) return current;
    target=std::clamp(target,0.,length);
    double gap=target-current, distance=std::abs(gap);
    double fraction=distance/length;
    // Song seconds per real second. Close to thumb: precise, far away: accelerate.
    double speed=std::min(90.,.35+length*(.18*fraction+6*fraction*fraction));
    return current+std::copysign(std::min(distance,speed*std::min(dt,.05)),gap);
}
}
