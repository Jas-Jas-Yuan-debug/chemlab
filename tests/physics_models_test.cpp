#include "science/physics_models.hpp"
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>
using namespace chemlab;
void near(double a,double b,double tol,const char* m){if(!std::isfinite(a)||std::abs(a-b)>tol)throw std::runtime_error(m);}
int main(){try{
 const double pi=std::acos(-1.0);PhysicsExperiment p;
 p.configure("spring",{{"mass_kg",0.2},{"stiffness_n_m",4*pi*pi*0.2},{"amplitude_m",0.1}});p.start();p.advance(0.25);
 auto r=p.reading();near(r.at("position_m"),0,1e-12,"spring quarter-cycle zero crossing");near(r.at("velocity_m_s"),-0.2*pi,1e-12,"spring quarter-cycle speed");
 double energy=r.at("energy_j");for(int i=0;i<1000;++i){p.advance(0.03);near(p.reading().at("energy_j"),energy,1e-12,"spring conserved energy");}
 p.pause();r=p.reading();p.advance(2);near(p.reading().at("time_s"),r.at("time_s"),1e-12,"pause freezes model time");p.reset();near(p.reading().at("time_s"),0,1e-12,"reset time");
 p.configure("pendulum",{{"length_m",1},{"gravity_m_s2",pi*pi},{"angle_deg",10}});p.start();p.advance(0.5);r=p.reading();near(r.at("period_s"),2,1e-12,"pendulum period");near(r.at("angle_rad"),0,1e-12,"pendulum quarter-cycle");
 energy=r.at("energy_j");for(int i=0;i<1000;++i){p.advance(0.03);near(p.reading().at("energy_j"),energy,1e-12,"linear pendulum energy");}
 p.configure("heat",{{"mass1_kg",0.1},{"mass2_kg",0.1},{"temperature1_c",70},{"temperature2_c",20},{"conductance_w_k",10.465}});p.start();energy=p.reading().at("energy_j");p.advance(20);r=p.reading();near(r.at("equilibrium_c"),45,1e-12,"equal-mass calorimetry");near(r.at("temperature1_c")-r.at("temperature2_c"),50/std::exp(1.0),1e-10,"one thermal time constant");
 for(int i=0;i<100;++i){p.advance(10);near(p.reading().at("energy_j"),energy,1e-8,"thermal energy conservation");}near(p.reading().at("temperature1_c"),45,1e-9,"thermal final equilibrium");
 p.configure("heat",{{"mass1_kg",0.1},{"mass2_kg",0.2},{"temperature1_c",80},{"temperature2_c",20}});near(p.reading().at("equilibrium_c"),40,1e-12,"unequal-mass calorimetry");
 p.configure("circuit",{});p.start();r=p.reading();near(r.at("current_a"),0.02,1e-12,"series Ohm law");near(r.at("voltage1_v")+r.at("voltage2_v"),6,1e-12,"series KVL");
 p.configure("circuit",{{"parallel",1}});p.start();p.advance(10);r=p.reading();near(r.at("current_a"),0.09,1e-12,"parallel current");near(r.at("current1_a")+r.at("current2_a"),r.at("current_a"),1e-12,"parallel KCL");near(r.at("energy_j"),5.4,1e-12,"electrical energy");p.pause();near(p.reading().at("current_a"),0,1e-12,"open circuit zero current");near(p.reading().at("energy_j"),5.4,1e-12,"open circuit retains accumulated energy");
 p.configure("lens",{});r=p.reading();near(r.at("image_m"),1.0/3,1e-12,"real lens image");near(r.at("magnification"),-2.0/3,1e-12,"inverted magnification");
 p.configure("lens",{{"focal_m",-0.2}});r=p.reading();near(r.at("image_m"),-1.0/7,1e-12,"virtual diverging image");near(r.at("virtual"),1,1e-12,"virtual flag");
 p.configure("lens",{{"object_m",0.2}});r=p.reading();near(r.at("at_infinity"),1,1e-12,"focal plane parallel rays");if(r.count("image_m"))throw std::runtime_error("infinite image must not return fake finite position");
 // Independently integrate the prescribed power/loss ODE with a short Euler
 // step, and compare the production piecewise analytic thermostat solution.
 p.configure("heater",{});p.control_heater({{"heat_enabled",1},{"stir_enabled",1}});p.start();p.advance(30);r=p.reading();
 double numerical=20;for(int i=0;i<300000;++i)numerical+=(250-0.6*(numerical-20))*0.0001/418.6;
 near(r.at("temperature_c"),numerical,2e-6,"heater energy ODE");near(r.at("input_energy_j"),7500,1e-8,"heater delivered energy");near(r.at("stir_turns"),150,1e-10,"stirrer RPM turns");near(r.at("energy_residual_j"),0,1e-8,"heater energy budget");
 p.advance(60);r=p.reading();near(r.at("temperature_c"),60,1e-10,"heater reaches setpoint");near(r.at("power_w"),24,1e-10,"holding power balances ambient loss");
 double before=r.at("input_energy_j");p.control_heater({{"target_c",35},{"stir_enabled",0},{"source",4}});r=p.reading();near(r.at("temperature_c"),60,1e-10,"retune preserves water temperature");near(r.at("input_energy_j"),before,1e-8,"retune preserves delivered energy");near(r.at("power_w"),0,1e-12,"lower target turns heat off");
 p.advance(60);r=p.reading();near(r.at("temperature_c"),20+40*std::exp(-36/418.6),1e-10,"passive cooling");near(r.at("stir_turns"),450,1e-10,"stirrer stops without resetting turns");
 auto controls=p.heater_controls();PhysicsExperiment replay;replay.configure("heater",p.parameters());replay.restore_heater_controls(controls);replay.restore(r.at("time_s"));replay.start();for(auto[key,value]:r)near(replay.reading().at(key),value,1e-8,"heater control replay");
 p.pause();r=p.reading();p.advance(10);near(p.reading().at("temperature_c"),r.at("temperature_c"),1e-10,"heater pause freezes thermal time");near(r.at("power_w"),0,1e-12,"paused heater off");
 for(int source=0;source<6;++source){p.configure("heater",{{"source",double(source)},{"target_c",95},{"power_w",1000},{"mass_kg",0.05}});p.control_heater({{"heat_enabled",1}});p.start();p.advance(60);near(p.reading().at("temperature_c"),95,1e-9,"every prescribed heat source obeys temperature cap");near(p.reading().at("energy_residual_j"),0,1e-7,"every heat source conserves energy");}
 for(const std::string kind:{"spring","pendulum","heat","circuit","heater"}){
  Scalars baseline;for(int fps:{30,60,144}){p.configure(kind,{});if(kind=="heater")p.control_heater({{"heat_enabled",1},{"stir_enabled",1}});p.start();for(int i=0;i<fps*2;++i)p.advance(1.0/fps);r=p.reading();if(baseline.empty())baseline=r;else for(auto[key,value]:r)near(value,baseline.at(key),1e-9,"render-step independence");}
 }
 bool control_rejected=false;try{p.control_heater({{"target_c",100}});}catch(...){control_rejected=true;}if(!control_rejected)throw std::runtime_error("unsupported heating temperature accepted");
 bool rejected=false;try{p.configure("spring",{{"mass_kg",std::numeric_limits<double>::quiet_NaN()}});}catch(...){rejected=true;}if(!rejected)throw std::runtime_error("NaN accepted");
 std::cout<<"PASS: spring/pendulum energy and periods, calorimetry, circuits, lens, controlled heating/cooling/stirring and energy budgets, control replay, pause/reset and frame-step independence\n";return 0;
}catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}}
