#include "science/chemistry.hpp"
#include <iostream>
#include <cmath>
#include <stdexcept>
using namespace chemlab;
void near(double a,double b,double tol,const char*message){if(!std::isfinite(a)||std::abs(a-b)>tol)throw std::runtime_error(message);}
int main(int argc,char**argv){
 std::string context;
 try{
  if(argc!=2)return 1;Chemistry solver(argv[1]);int count=0;
  for(int id:{11,14,15,16,25})for(double c:{1e-5,1e-3,1e-2})for(double v:{0.001,0.05,0.25}){
   context="id="+std::to_string(id)+" C="+std::to_string(c)+" V="+std::to_string(v);
   auto s=solver.prepare(id,c,v);
   const char* tracked=id==15||id==16?"Mg":id==25?"Ba":"S";
   near(s.elements.at(tracked),c*v,1e-11,"stock solute amount");
   if(id==14)near(s.elements.at("Na"),2*c*v,1e-11,"Na2SO4 sodium stoichiometry");
   if(id==15||id==25)near(s.elements.at("Cl"),2*c*v,1e-11,"divalent chloride stoichiometry");
   auto half=solver.mix(s,0.5,{},0);
   near(half.ph,s.ph,1e-6,"aliquot pH invariant");
   auto water=solver.prepare(1,0,v);
   auto dilute=solver.mix(s,1,water,1);
   auto reference=solver.prepare(id,c>=2e-5?c/2:c,2*v>0.25?0.25:2*v);
   // Minimum concentration stock limit applies to preparation, not dilution.
   if(c>=2e-5)near(dilute.ph,reference.ph,0.002,"dilution vs independently prepared concentration");
   auto again=solver.mix(half,1,half,1);
   near(again.ph,s.ph,1e-6,"self-mix pH invariant");
   Vessel source{1,1,s},target{2,1,{}};
   for(int i=0;i<10;++i){auto t=transfer(solver,source,target,v/10);source=t.source;target=t.target;}
   near(source.solution.volume_l,0,1e-8,"repeated transfer empties stock");
   near(target.solution.ph,s.ph,1e-6,"repeated transfer pH");
   ++count;
  }
  context="sulfuric neutralization";
  auto sulfuric=solver.prepare(11,0.001,0.05);
  const double ka=0.0102,c=0.001;
  const double second=(-(c+ka)+std::sqrt((c+ka)*(c+ka)+4*ka*c))/2;
  near(sulfuric.ph,-std::log10(c+second),0.06,"sulfuric acid independent two-stage dilute limit");
  auto base=solver.prepare(3,0.002,0.05);
  auto neutral=solver.mix(sulfuric,1,base,1);
  near(neutral.ph,7,0.08,"sulfuric two-equivalent neutralization");
  for(int id:{14,15,16,25})near(solver.prepare(id,0.001,0.05).ph,7,0.1,"dilute salt pH reference");
  for(int id:{12,13,20,21,26,27,28}){
   bool rejected=false;try{solver.prepare(id,0.001,0.05);}catch(...){rejected=true;}
   if(!rejected)throw std::runtime_error("unvalidated redox-sensitive stock must remain unavailable");
  }
  std::cout<<"PASS: "<<count<<" added stock conditions, amounts, aliquots, independent dilution, repeated transfer, sulfate neutralization; unvalidated N/Fe/Cu forms rejected\n";
  return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL: "<<context<<": "<<e.what()<<"\n";return 1;}
}
