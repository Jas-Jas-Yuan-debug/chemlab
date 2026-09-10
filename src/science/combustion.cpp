#include "combustion.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <vector>
namespace chemlab {
namespace {
constexpr double R=8.31446261815324;
struct ThermoSpecies {const char* name; std::array<double,4> atoms; double middle;std::array<double,7> low,high;};
#include "combustion_data.inc"
double enthalpy(int i,double t){const auto&a=t<=species[i].middle?species[i].low:species[i].high;return R*t*(a[0]+t*(a[1]/2+t*(a[2]/3+t*(a[3]/4+t*a[4]/5)))+a[5]/t);}
double gibbs_rt(int i,double t){const auto&a=t<=species[i].middle?species[i].low:species[i].high;return enthalpy(i,t)/(R*t)-(a[0]*std::log(t)+t*(a[1]+t*(a[2]/2+t*(a[3]/3+t*a[4]/4)))+a[6]);}
using Matrix=std::vector<std::vector<double>>;
std::vector<double> linear(Matrix a,std::vector<double>b){
 const int n=b.size();for(int k=0;k<n;++k){int p=k;for(int j=k+1;j<n;++j)if(std::abs(a[j][k])>std::abs(a[p][k]))p=j;
 if(std::abs(a[p][k])<1e-18)throw std::runtime_error("燃烧平衡矩阵不可解");
 std::swap(a[p],a[k]);std::swap(b[p],b[k]);
 for(int j=k+1;j<n;++j){double f=a[j][k]/a[k][k];for(int z=k;z<n;++z)a[j][z]-=f*a[k][z];b[j]-=f*b[k];}}
 for(int i=n-1;i>=0;--i){for(int j=i+1;j<n;++j)b[i]-=a[i][j]*b[j];b[i]/=a[i][i];}return b;
}
std::array<double,16> equilibrium_tp(double t,const std::array<double,4>&atoms){
 std::vector<int> elements,allowed;for(int e=0;e<4;++e)if(atoms[e]>0)elements.push_back(e);
 for(int i=0;i<16;++i){bool ok=true;for(int e=0;e<4;++e)if(atoms[e]==0&&species[i].atoms[e]>0)ok=false;if(ok)allowed.push_back(i);}
 const int m=elements.size();std::array<double,16> g{},n{};for(int i:allowed)g[i]=gibbs_rt(i,t);
 // Complete products initialize element potentials; all admitted species are then solved.
 const double water=atoms[1]/2,co2=atoms[0],oxygen=std::max(0.02,(atoms[2]-water-2*co2)/2),nitrogen=atoms[3]/2;
 const double total=water+co2+oxygen+nitrogen;
 std::array<double,4> lambda{};
 lambda[2]=(g[4]+std::log(oxygen/total))/2;
 lambda[1]=(g[1]+std::log(water/total)-lambda[2])/2;
 if(co2>0)lambda[0]=g[0]+std::log(co2/total)-2*lambda[2];
 if(nitrogen>0)lambda[3]=(g[5]+std::log(nitrogen/total))/2;
 std::vector<double>x(m+1);for(int e=0;e<m;++e)x[e]=lambda[elements[e]];x[m]=std::log(total);
 auto evaluate=[&](const std::vector<double>&v,Matrix*jac){
  std::vector<double>f(m+1);f[m]=-1;for(int e=0;e<m;++e)f[e]=-1;
  if(jac)jac->assign(m+1,std::vector<double>(m+1));
  for(int i:allowed){double q=-g[i];for(int e=0;e<m;++e)q+=species[i].atoms[elements[e]]*v[e];
   const double fraction=std::exp(std::clamp(q,-700.0,300.0));n[i]=fraction*std::exp(std::clamp(v[m],-100.0,100.0));f[m]+=fraction;
   for(int e=0;e<m;++e){const double a=species[i].atoms[elements[e]],z=a*n[i]/atoms[elements[e]];f[e]+=z;
    if(jac){for(int k=0;k<m;++k)(*jac)[e][k]+=z*species[i].atoms[elements[k]];(*jac)[e][m]+=z;(*jac)[m][e]+=a*fraction;}}
  }return f;
 };
 auto norm=[](const std::vector<double>&f){double out=0;for(double v:f)out+=v*v;return out;};
 for(int iteration=0;iteration<150;++iteration){Matrix j;auto f=evaluate(x,&j);double error=norm(f);if(error<1e-22)return n;
  for(double&v:f)v=-v;auto dx=linear(j,f);double bound=0;for(double d:dx)bound=std::max(bound,std::abs(d));double alpha=std::min(1.0,3/std::max(3.0,bound));
  bool accepted=false;for(int line=0;line<30;++line){auto trial=x;for(int e=0;e<=m;++e)trial[e]+=alpha*dx[e];if(norm(evaluate(trial,nullptr))<error){x=trial;accepted=true;break;}alpha*=0.5;}
  if(!accepted)throw std::runtime_error("燃烧平衡未收敛；保留原状态");
 }
 throw std::runtime_error("燃烧平衡迭代超限");
}
}
const char* combustion_species_name(int index){return species.at(index).name;}
CombustionResult combustion_equilibrium(int source,double excess){
 if(source<1||source>5||!std::isfinite(excess)||excess<1||excess>2)throw std::invalid_argument("燃烧源或供氧系数超出 1–2 范围");
 const int fuel=source==2?13:source==3?3:source==4?14:15;
 const auto a=species[fuel].atoms;const double stoich=a[0]+a[1]/4-a[2]/2;
 CombustionResult r;r.oxygen_mol=stoich*excess;r.nitrogen_mol=(source==3||source==4)?0:r.oxygen_mol*3.76;
 const std::array<double,4>atoms={a[0],a[1],a[2]+2*r.oxygen_mol,2*r.nitrogen_mol};
 // Ethanol liquid feed: subtract saturation vaporization enthalpy at 298.15 K.
 // Majer & Svoboda correlation in NIST SRD69, consistent reference-temperature offset.
 const double tr=298.15/513.9;
 const double vaporization=(fuel==15)?50430*std::exp(0.4475*tr)*std::pow(1-tr,0.4989):0;
 const double initial_h=-vaporization+enthalpy(fuel,298.15)+r.oxygen_mol*enthalpy(4,298.15)+r.nitrogen_mol*enthalpy(5,298.15);
 r.lhv_j_mol=-vaporization+enthalpy(fuel,298.15)+stoich*enthalpy(4,298.15)-a[0]*enthalpy(0,298.15)-a[1]/2*enthalpy(1,298.15);
 r.fuel_molar_mass_g=a[0]*12.011+a[1]*1.008+a[2]*15.999;
 double lo=1200,hi=5500;
 for(int k=0;k<40;++k){r.temperature_k=(lo+hi)/2;r.products=equilibrium_tp(r.temperature_k,atoms);double h=0;for(int i=0;i<16;++i)h+=r.products[i]*enthalpy(i,r.temperature_k);r.enthalpy_residual_j=h-initial_h;if(h>initial_h)hi=r.temperature_k;else lo=r.temperature_k;}
 for(int e=0;e<4;++e){double sum=0;for(int i=0;i<16;++i)sum+=r.products[i]*species[i].atoms[e];r.element_residual_mol=std::max(r.element_residual_mol,std::abs(sum-atoms[e]));}
 if(std::abs(r.enthalpy_residual_j)>0.01||r.element_residual_mol>1e-8)throw std::runtime_error("燃烧平衡守恒核查失败");
 return r;
}
}
