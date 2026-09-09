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
 {"lens",{{"focal_m",-0.5,0.5,0.2},{"object_m",0.1,1,0.5},{"object_height_m",0.01,0.1,0.05}}},
 {"heater",{{"mass_kg",0.05,0.25,0.1},{"initial_temperature_c",5,90,20},{"target_c",25,95,60},{"power_w",50,1000,250},{"stir_rpm",0,600,300},{"source",0,5,0}}}
};
void validate_control(const Scalars& c){
 const std::vector<Field> fields={{"time_s",0,86400,0},{"target_c",25,95,60},{"power_w",50,1000,250},{"stir_rpm",0,600,300},{"heat_enabled",0,1,0},{"stir_enabled",0,1,0},{"source",0,5,0}};
 if(c.size()!=fields.size())throw std::invalid_argument("加热控制记录字段不完整");
 for(const auto& f:fields){auto it=c.find(f.key);if(it==c.end()||!std::isfinite(it->second)||it->second<f.lower||it->second>f.upper)throw std::invalid_argument("加热控制参数超出范围");}
 for(const auto* key:{"heat_enabled","stir_enabled","source"})if(c.at(key)!=std::floor(c.at(key)))throw std::invalid_argument("加热器材或开关值无效");
}
// Lumped liquid-water model with ideal temperature feedback. The specified
// power is heat delivered to the water, not an inferred fuel combustion rate.
struct HeatedWater { double temperature, input=0, loss=0, turns=0, power=0; };
void heat_segment(HeatedWater& s,const Scalars& c,double seconds,double capacity){
 constexpr double ambient=20,conductance=0.6;
 const double initial=s.temperature, target=c.at("target_c");
 const bool on=c.at("heat_enabled")==1;
 double duration=seconds, input=0;
 if(on&&std::abs(initial-target)<1e-10){s.temperature=target;s.power=conductance*(target-ambient);input=s.power*duration;}
 else {
  const double power=on&&initial<target?c.at("power_w"):0;
  const double equilibrium=ambient+power/conductance;
  double hit=seconds+1;
  if(on)hit=-capacity/conductance*std::log((target-equilibrium)/(initial-equilibrium));
  const bool reaches=on&&std::isfinite(hit)&&hit>=0&&hit<=seconds;
  duration=reaches?hit:seconds;
  s.temperature=equilibrium+(initial-equilibrium)*std::exp(-conductance*duration/capacity);
  input=power*duration;s.power=power;
  if(reaches){s.temperature=target;s.power=conductance*(target-ambient);input+=s.power*(seconds-duration);}
 }
 s.input+=input;s.loss+=input-capacity*(s.temperature-initial);
 if(c.at("stir_enabled")==1)s.turns+=seconds*c.at("stir_rpm")/60;
}
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
 if(kind=="heater"&&p.at("source")!=std::floor(p.at("source")))throw std::invalid_argument("加热器材编号无效");
 kind_=kind;parameters_=p;reset();
}
void PhysicsExperiment::start(){running_=true;}
void PhysicsExperiment::pause(){running_=false;}
void PhysicsExperiment::reset(){
 ticks_=0;remainder_=0;running_=false;heater_controls_.clear();
 if(kind_=="heater")heater_controls_.push_back({{"time_s",0},{"target_c",parameters_.at("target_c")},{"power_w",parameters_.at("power_w")},{"stir_rpm",parameters_.at("stir_rpm")},{"source",parameters_.at("source")},{"heat_enabled",0},{"stir_enabled",0}});
}
void PhysicsExperiment::control_heater(const Scalars& change){
 if(kind_!="heater")throw std::invalid_argument("请先选择加热搅拌实验");
 if(heater_controls_.size()>=512)throw std::invalid_argument("控制记录已达 512 项，请保存后重新开始");
 Scalars control=heater_controls_.back();control["time_s"]=ticks_*step_s;
 for(const auto&[key,value]:change){if(key=="time_s"||!control.count(key))throw std::invalid_argument("不支持的加热控制参数");control[key]=value;}
 validate_control(control);heater_controls_.push_back(std::move(control));
}
void PhysicsExperiment::restore_heater_controls(const std::vector<Scalars>& controls){
 if(kind_!="heater"||controls.empty()||controls.size()>512)throw std::invalid_argument("加热控制记录无效");
 double previous=0;
 for(const auto& c:controls){validate_control(c);if(c.at("time_s")<previous)throw std::invalid_argument("加热控制时间顺序无效");previous=c.at("time_s");}
 if(controls.front().at("time_s")!=0)throw std::invalid_argument("缺少加热初始控制状态");
 auto canonical=controls;
 for(auto& c:canonical){
  const double tick=std::round(c.at("time_s")/step_s)*step_s;
  if(std::abs(tick-c.at("time_s"))>1e-8)throw std::invalid_argument("加热控制时间不在模拟时钟刻度上");
  c["time_s"]=tick;
 }
 heater_controls_=std::move(canonical);
}
void PhysicsExperiment::advance(double elapsed){
 if(!std::isfinite(elapsed)||elapsed<0||elapsed>60)throw std::invalid_argument("物理模拟时间步无效");
 if(!running_)return;
 remainder_+=elapsed;
 auto steps=static_cast<uint64_t>(std::floor((remainder_+1e-12)/step_s));
 ticks_+=steps;remainder_=std::max(0.0,remainder_-steps*step_s);
}
void PhysicsExperiment::restore(double elapsed){
 if(!std::isfinite(elapsed)||elapsed<0||elapsed>86400)throw std::invalid_argument("保存的物理实验时间无效");
 ticks_=static_cast<uint64_t>(std::llround(elapsed/step_s));remainder_=0;running_=false;
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
 }else if(kind_=="heater"){
  const double capacity=4186*p("mass_kg");HeatedWater s{p("initial_temperature_c")};
  size_t active=0;
  for(size_t i=0;i<heater_controls_.size();++i){
   const auto& c=heater_controls_[i];if(c.at("time_s")>t+1e-10)break;
   const double end=i+1<heater_controls_.size()?std::min(t,heater_controls_[i+1].at("time_s")):t;
   heat_segment(s,c,std::max(0.0,end-c.at("time_s")),capacity);active=i;
  }
  const auto& c=heater_controls_[active];
  r["temperature_c"]=s.temperature;r["target_c"]=c.at("target_c");r["power_limit_w"]=c.at("power_w");
  r["power_w"]=running_?s.power:0;r["energy_j"]=capacity*(s.temperature-p("initial_temperature_c"));
  r["input_energy_j"]=s.input;r["ambient_loss_j"]=s.loss;r["energy_residual_j"]=s.input-s.loss-r["energy_j"];
  r["stir_rpm"]=running_&&c.at("stir_enabled")==1?c.at("stir_rpm"):0;
  r["stir_setpoint_rpm"]=c.at("stir_rpm");r["stir_turns"]=s.turns;
  r["heat_enabled"]=c.at("heat_enabled");r["stir_enabled"]=c.at("stir_enabled");r["source"]=c.at("source");
  r["at_target"]=std::abs(s.temperature-c.at("target_c"))<1e-8?1:0;r["heater_control_count"]=active+1;
 }
 return r;
}
}
