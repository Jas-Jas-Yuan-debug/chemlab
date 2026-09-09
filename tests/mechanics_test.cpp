#include "science/mechanics.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace chemlab;
void near(double a,double b,double eps,const char*why){if(!std::isfinite(a)||std::abs(a-b)>eps)throw std::runtime_error(why);}
int main(){try{
    for(double h:{0.1,1.0,2.0})for(double g:{0.1,9.80665,20.0}){
        FreeFall fall;fall.configure(h,g);fall.start();
        fall.advance(0.05);
        auto r=fall.reading();
        near(r.time_s,0.05,1e-12,"time");
        near(r.height_m,h-0.5*g*0.05*0.05,1e-12,"analytic height");
        near(r.velocity_m_s,-g*0.05,1e-12,"analytic velocity");
        fall.pause();fall.advance(5);
        near(fall.reading().time_s,r.time_s,1e-12,"paused clock");
        fall.start();fall.advance(10);
        r=fall.reading();
        if(!r.landed||r.running)throw std::runtime_error("Landing state");
        near(r.height_m,0,1e-12,"floor clamp");
        near(r.time_s,std::sqrt(2*h/g),1e-12,"exact impact event");
        near(r.impact_speed_m_s,std::sqrt(2*g*h),1e-12,"impact speed vs post-impact velocity");
        near(r.velocity_m_s,0,1e-12,"inelastic rest after impact");
        fall.reset();near(fall.reading().height_m,h,1e-12,"reset");
    }
    double reference=-1;
    for(int fps:{30,60,144}){
        FreeFall fall;fall.configure(2,9.80665);fall.start();
        for(int f=0;f<fps/2;++f)fall.advance(1.0/fps);
        auto r=fall.reading();
        near(r.time_s,0.5,1e-12,"Frame-independent time");
        if(reference<0)reference=r.height_m;
        near(r.height_m,reference,1e-12,"30/60/144 FPS invariant trajectory");
    }
    std::cout<<"PASS: free-fall analytic trajectory, exact impact, pause/reset, 30/60/144 FPS invariance\n";
    return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}}
