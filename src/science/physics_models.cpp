#include "physics_models.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>
namespace chemlab {
namespace {
constexpr double pi=3.14159265358979323846;
struct Field{std::string key;double lower,upper,default_value;};
const std::map<std::string,std::vector<Field>> schema={
 {"spring",{{"mass_kg",0.05,2,0.2},{"stiffness_n_m",0.5,50,8},{"amplitude_m",0.01,0.2,0.1}}},
 {"pendulum",{{"length_m",0.1,1.5,0.8},{"gravity_m_s2",0.1,20,9.80665},{"angle_deg",1,10,8},{"mass_kg",0.05,1,0.2}}},
 {"heat",{{"mass1_kg",0.05,1,0.1},{"mass2_kg",0.05,1,0.1},{"temperature1_c",5,90,70},{"temperature2_c",5,90,20},{"conductance_w_k",0.1,20,10}}},
 {"circuit",{{"voltage_v",0,12,6},{"resistance1_ohm",1,1000,100},{"resistance2_ohm",1,1000,200},{"parallel",0,1,0}}},
 {"lens",{{"focal_m",-0.5,0.5,0.2},{"object_m",0.1,1,0.5},{"object_height_m",0.01,0.1,0.05}}}
};
}
void PhysicsExperiment::configure(const std::string&kind,const Scalars&input){
 auto found=schema.find(kind);if(found==schema.end())throw std::invalid_argument("未知物理实验");
 Scalars p;
 for(auto field:found->second){auto it=input.find(field.key);const double v=it==input.end()?field.default_value:it->second;
  if(!std::isfinite(v)||v<field.lower||v>field.upper)throw std::invalid_argument("参数超出此实验的验证范围");
  p[field.key]=v;
 }
 for(auto[key,v]:input)if(!p.count(key))throw std::invalid_argument("不支持此实验参数");
 if(kind=="lens"&&std::abs(p.at("focal_m"))<0.05)throw std::invalid_argument("焦距绝对值限 0.05–0.5 m");
 if(kind=="circuit"&&p.at("parallel")!=0&&p.at("parallel")!=1)throw std::invalid_argument("电路仅支持串联或并联");
 kind_=kind;parameters_=p;reset();
}
void PhysicsExperiment::start(){running_=true;}
void PhysicsExperiment::pause(){running_=false;}
void PhysicsExperiment::reset(){ticks_=0;remainder_=0;running_=false;}
void PhysicsExperiment::advance(double elapsed){
 if(!std::isfinite(elapsed)||elapsed<0||elapsed>60)throw std::invalid_argument("物理模拟时间步无效");
 if(!running_)return;
 remainder_+=elapsed;
 auto steps=static_cast<uint64_t>(std::floor((remainder_+1e-12)/step_s));
 ticks_+=steps;remainder_=std::max(0.0,remainder_-steps*step_s);
}
Scalars PhysicsExperiment::reading()const{
 const double t=ticks_*step_s;
 Scalars r={{"time_s",t},{"running",running_?1.0:0.0}};
 auto p=[&](const char*key){return parameters_.at(key);};
 if(kind_=="spring"){
  const double w=std::sqrt(p("stiffness_n_m")/p("mass_kg")),a=p("amplitude_m");
  const double x=a*std::cos(w*t),v=-a*w*std::sin(w*t);
  r["position_m"]=x;r["velocity_m_s"]=v;r["period_s"]=2*pi/w;
  r["energy_j"]=0.5*p("mass_kg")*v*v+0.5*p("stiffness_n_m")*x*x;
 }else if(kind_=="pendulum"){
  const double length=p("length_m"),g=p("gravity_m_s2"),w=std::sqrt(g/length),a=p("angle_deg")*pi/180;
  const double angle=a*std::cos(w*t),angular=-a*w*std::sin(w*t);
  r["angle_rad"]=angle;r["angle_deg"]=angle*180/pi;r["angular_velocity_rad_s"]=angular;
  r["position_m"]=length*std::sin(angle);r["velocity_m_s"]=length*angular;
  r["period_s"]=2*pi/w;
  r["energy_j"]=0.5*p("mass_kg")*length*length*angular*angular+0.5*p("mass_kg")*g*length*angle*angle;
 }else if(kind_=="heat"){
  // Two isolated, internally uniform liquid-water reservoirs. Fixed heat
  // capacity 4186 J/(kg K); chosen conductance is an explicit model parameter.
  const double c1=4186*p("mass1_kg"),c2=4186*p("mass2_kg"),k=p("conductance_w_k");
  const double eq=(c1*p("temperature1_c")+c2*p("temperature2_c"))/(c1+c2),tau=c1*c2/(k*(c1+c2));
  const double diff=(p("temperature1_c")-p("temperature2_c"))*std::exp(-t/tau);
  const double t1=eq+c2/(c1+c2)*diff,t2=eq-c1/(c1+c2)*diff;
  r["temperature1_c"]=t1;r["temperature2_c"]=t2;r["equilibrium_c"]=eq;r["time_constant_s"]=tau;
  r["energy_j"]=c1*t1+c2*t2;r["heat_to_2_j"]=c2*(t2-p("temperature2_c"));r["heat_flow_w"]=k*diff;
 }else if(kind_=="circuit"){
  const double a=p("resistance1_ohm"),b=p("resistance2_ohm"),volts=p("voltage_v");const bool parallel=p("parallel")==1;
  const double resistance=parallel?1/(1/a+1/b):a+b,closed_current=volts/resistance;
  const double current=running_?closed_current:0;
  r["resistance_ohm"]=resistance;r["current_a"]=current;
  r["voltage1_v"]=parallel?(running_?volts:0):current*a;
  r["voltage2_v"]=parallel?(running_?volts:0):current*b;
  r["current1_a"]=r["voltage1_v"]/a;r["current2_a"]=r["voltage2_v"]/b;
  r["power_w"]=current*volts;r["energy_j"]=closed_current*volts*t;
 }else if(kind_=="lens"){
  const double f=p("focal_m"),u=p("object_m");
  const bool infinite=std::abs(u-f)<1e-10;
  r["at_infinity"]=infinite?1:0;
  if(!infinite){const double v=f*u/(u-f);r["image_m"]=v;r["magnification"]=-v/u;r["image_height_m"]=-v/u*p("object_height_m");r["virtual"]=v<0?1:0;}
 }
 return r;
}
}
