#pragma once
#include <cstdint>

namespace chemlab {
struct FallReading {
    double time_s;
    double height_m;
    double velocity_m_s;
    double impact_time_s;
    double impact_speed_m_s;
    bool landed;
    bool running;
};
class FreeFall {
public:
    static constexpr double timestep_s=1.0/120.0;
    void configure(double height_m,double gravity_m_s2);
    void start();
    void pause();
    void reset();
    void advance(double elapsed_s);
    FallReading reading() const;
    double initial_height()const{return initial_height_;}
    double gravity()const{return gravity_;}
    void restore(double time_s,bool landed);
private:
    double initial_height_=1.0;
    double gravity_=9.80665;
    double remainder_=0.0;
    uint64_t ticks_=0;
    bool running_=false;
};
}
