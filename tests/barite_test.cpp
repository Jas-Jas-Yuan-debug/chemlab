#include "science/chemistry.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace chemlab;
void need(bool ok,const char*m){if(!ok)throw std::runtime_error(m);}
int main(int argc,char**argv){
 try{
  need(argc==2,"database required");Chemistry solver(argv[1]);int cases=0;
  for(double concentration:{1e-5,1e-3,1e-2})for(double volume:{0.005,0.05,0.125})for(double ratio:{0.5,1.0,2.0}){
   double av=volume*(ratio<=1?ratio:1),bv=volume*(ratio>=1?1/ratio:1);
   auto a=solver.prepare(25,concentration,av),b=solver.prepare(14,concentration,bv);
   auto r=solver.precipitate_barite(a,b);
   need(r.solid_remaining_mol<=std::min(concentration*av,concentration*bv)+1e-10,"precipitate bounded by limiting ion");
   if(concentration==1e-5)need(r.solid_remaining_mol<1e-12,"undersaturation does not precipitate by reagent-name rule");
   if(concentration>=1e-3){need(r.solid_remaining_mol>0,"supersaturation produces solid");need(std::abs(r.solid_saturation_index)<1e-7,"equilibrium saturation");}
   auto half=solver.mix(r.solution,0.5,{},0);
   need(std::abs(half.volume_l-r.solution.volume_l/2)<1e-12,"filtered aliquot volume");
   auto again=solver.precipitate_barite(a,b);
   need(std::abs(again.solid_remaining_mol-r.solid_remaining_mol)<1e-10,"repeatable solid amount");
   if(concentration==1e-3&&ratio==1){
    double ideal=concentration*av-std::sqrt(std::pow(10.0,-9.97))*(av+bv);
    need(std::abs(r.solid_remaining_mol-ideal)<concentration*av*0.03,"ideal dilute Ksp reference with activity tolerance");
   }
   ++cases;
  }
  std::cout<<"PASS: "<<cases<<" Barite cases, undersaturation/supersaturation, limiting-ion/excess, repeat/aliquot and Ksp reference\n";
  return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}
}
