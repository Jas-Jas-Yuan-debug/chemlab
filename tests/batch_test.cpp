#include "science/chemistry.hpp"
#include <iostream>
#include <cmath>
#include <limits>
#include <stdexcept>
using namespace chemlab;
void need(bool ok,const char*message){if(!ok)throw std::runtime_error(message);}
void near(double a,double b,double tolerance,const char*message){need(std::isfinite(a)&&std::abs(a-b)<tolerance,message);}
int main(int argc,char**argv){
 try{
  need(argc==2,"database required");Chemistry solver(argv[1]);
  int count=0;
  for(int base:{1,2,8,9})for(double volume:{0.01,0.1,0.25})for(int solid:{0,18,19})for(auto gas:{GasBoundary::None,GasBoundary::ClosedVolume,GasBoundary::FixedCO2}){
   auto stock=solver.prepare(base,base==1?0:0.001,volume);
   BatchConditions c;c.solid_reagent=solid;c.solid_mol=solid?0.002:0;c.gas=gas;c.co2_added_mol=gas==GasBoundary::ClosedVolume?0.0001:0;
   auto r=solver.equilibrate(stock,c);
   need(r.solid_remaining_mol>=-1e-12,"nonnegative solid");
   if(r.solid_remaining_mol>1e-8)near(r.solid_saturation_index,0,1e-6,"present solid saturation");
   if(gas==GasBoundary::ClosedVolume)near(r.gas_pressure_atm*c.headspace_l,r.gas_co2_mol*0.082057366*298.15,2e-7,"ideal gas PV=nRT, including very low pressure");
   auto aliquot=solver.mix(r.solution,0.25,{},0);
   near(aliquot.ph,r.solution.ph,1e-6,"separated aliquot pH");
   for(auto [e,n]:r.solution.elements)near(aliquot.elements.at(e),n*0.25,1e-10,"aliquot element conservation");
   auto repeated=solver.equilibrate(stock,c);
   near(repeated.solution.ph,r.solution.ph,1e-8,"repeatable pH");
   near(repeated.solid_remaining_mol,r.solid_remaining_mol,1e-10,"repeatable solid");
   ++count;
  }
  auto water=solver.prepare(1,0,0.1);
  BatchConditions c;c.solid_reagent=19;c.solid_mol=0.002;
  auto gypsum=solver.equilibrate(water,c);
  // USGS PHREEQC 3 Example 2: 15.1 mmol/kgw at 25 C. Database revisions and
  // finite crystal water cause small differences; tolerance 0.3 mmol/kgw.
  near(gypsum.solution.elements.at("Ca")/gypsum.solution.water_kg,0.0151,0.0003,"USGS gypsum solubility reference");
  c.solid_mol=0.00001;
  auto exhausted=solver.equilibrate(water,c);
  near(exhausted.solid_remaining_mol,0,1e-12,"finite undersaturated solid dissolves completely");
  near(exhausted.solution.elements.at("Ca"),0.00001,1e-10,"finite calcium dose");
  c.solid_reagent=18;c.solid_mol=0.002;
  auto calcite=solver.equilibrate(water,c);
  need(calcite.solid_remaining_mol>0.0019,"calcite not assumed fully soluble");
  auto acid=solver.equilibrate(solver.prepare(2,0.01,0.1),c);
  need(acid.solid_remaining_mol<calcite.solid_remaining_mol-0.0004,"acid increases calcite dissolution");
  c.gas=GasBoundary::FixedCO2;
  auto open=solver.equilibrate(water,c);
  need(open.co2_to_environment_mol<0&&open.solution.ph<calcite.solution.ph,"open CO2 uptake changes calcite pH");
  c.solid_reagent=0;c.solid_mol=0;
  auto co2=solver.equilibrate(water,c);
  // Independent dilute Henry + first dissociation approximation.
  double h=std::sqrt(std::pow(10.0,-1.468)*c.external_co2_atm*std::pow(10.0,-6.35));
  near(co2.solution.ph,-std::log10(h),0.03,"Henry/Ka open CO2 pH reference");
  c.solid_reagent=19;c.solid_mol=0.002;c.gas=GasBoundary::None;
  auto normal=solver.equilibrate(water,c);
  for(double bad:{-1.0,std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()}){
   c.solid_mol=bad;bool rejected=false;try{solver.equilibrate(water,c);}catch(...){rejected=true;}need(rejected,"invalid dose rejection");
  }
  bool rejected=false;try{solver.mix(normal.solution,1,water,1);}catch(...){rejected=true;}need(rejected,"unvalidated sample dilution rejected");
  std::cout<<"PASS: "<<count<<" aqueous/solid/gas condition sets, repeat/aliquot conservation, finite exhaustion, acid dissolution, gypsum reference, Henry/Ka reference, low-pressure ideal gas, invalid input\n";return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<"\n";return 1;}
}
