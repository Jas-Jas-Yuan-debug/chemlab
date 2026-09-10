#include "science/flame_field.hpp"
#include <iostream>
#include <cmath>
#include <stdexcept>
void check(bool c,const char* m){if(!c)throw std::runtime_error(m);}
int main(){
 for(int source=1;source<=5;++source){auto chemistry=chemlab::combustion_equilibrium(source);chemlab::FlameField a,b;a.reset(source);b.reset(source);const double flow=250/(0.35*chemistry.lhv_j_mol);
  for(int i=0;i<240;++i)a.advance(1./60,flow,0.04);
  for(int i=0;i<120;++i)b.advance(1./30,flow,0.04);
  auto av=a.save(),bv=b.save(); for(size_t j=0;j<av.size();++j)check(std::abs(av[j]-bv[j])<1e-10,"Render frame rate must not affect field integration");
  check(a.peak_temperature()>700&&a.peak_temperature()<4500&&a.burned_mol()>0,"Reactive field must ignite");
  check(std::abs(a.fuel_balance_error())<1e-10,"Conservative field fuel balance");
  check(std::abs(a.energy_balance_error())<1e-6,"Conservative field energy balance");
  chemlab::FlameField copy;copy.load(a.save());check(copy.save()==a.save(),"Exact field save/restore");
  double before=a.peak_temperature();for(int i=0;i<480;++i)a.advance(1./60,0,0.04);
  check(a.peak_temperature()<before,"Extinguished field must cool");
  std::cout<<"PASS: source "<<source<<" temperature "<<before<<" K, fuel residual "<<a.fuel_balance_error()<<", energy residual "<<a.energy_balance_error()<<" J\n";
 }
}
