#include "mechanics.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace chemlab {
void FreeFall::configure(double height,double gravity){
    if(!std::isfinite(height)||height<0.1||height>2.0||!std::isfinite(gravity)||gravity<0.1||gravity>20)
        throw std::invalid_argument("高度限 0.1–2 m，重力限 0.1–20 m/s²");
    initial_height_=height;gravity_=gravity;reset();
}
void FreeFall::start(){if(!reading().landed)running_=true;}
void FreeFall::pause(){running_=false;}
void FreeFall::reset(){ticks_=0;remainder_=0;running_=false;}
void FreeFall::advance(double elapsed){
    if(!std::isfinite(elapsed)||elapsed<0||elapsed>60)throw std::invalid_argument("模拟时间步无效");
    if(!running_)return;
    remainder_+=elapsed;
    const auto steps=static_cast<uint64_t>(std::floor((remainder_+1e-12)/timestep_s));
    ticks_+=steps;
    remainder_=std::max(0.0,remainder_-steps*timestep_s);
    if(reading().landed)running_=false;
}
FallReading FreeFall::reading()const{
    const double impact=std::sqrt(2*initial_height_/gravity_);
    const double time=std::min(ticks_*timestep_s,impact);
    const bool landed=ticks_*timestep_s>=impact;
    return {time,std::max(0.0,initial_height_-0.5*gravity_*time*time),landed?0.0:-gravity_*time,
        impact,gravity_*impact,landed,running_};
}
}
