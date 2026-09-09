#include "science/chemistry.hpp"
#include <cmath>
#include <iostream>
#include <limits>
#include <stdexcept>

using namespace chemlab;
void expect(bool ok,const char* label){if(!ok)throw std::runtime_error(label);}
void close(double a,double b,double tol,const char* label){expect(std::isfinite(a)&&std::abs(a-b)<tol,label);}

int main(int argc,char**argv){
 try {
    expect(argc==2,"Expected database path");
    Chemistry solver(argv[1]);
    int stocks=0;
    for(int reagent=1;reagent<=9;++reagent)for(double volume:{0.001,0.05,0.25})for(double c:{0.00001,0.001,0.01}){
        auto s=solver.prepare(reagent,reagent==1?0:c,volume);
        close(s.volume_l,volume,1e-8,"Molar preparation volume");
        const char* element=reagent==2?"Cl":(reagent==5||reagent==6)?"K":reagent==7?"Ca":"Na";
        if(reagent>1)close(s.elements.at(element),c*volume*(reagent==9?2:1),1e-10,"Molar preparation amount");
        expect(s.water_kg>0,"Positive solvent mass");
        auto half=solver.mix(s,0.5,{},0);
        close(half.volume_l,s.volume_l/2,1e-8,"Aliquot volume");
        close(half.ph,s.ph,1e-6,"Aliquot pH invariant");
        auto water=solver.prepare(1,0,volume);
        auto diluted=solver.mix(half,1,water,0.5);
        for(const auto& [e,n]:s.elements) close(diluted.elements.at(e),n/2,1e-10,"Dilution conserves solutes");
        ++stocks;
    }
    // Independent ideal dilute limits at 25 C, with activity-model tolerances.
    close(solver.prepare(5,0.001,0.05).ph,11,0.08,"KOH strong-base reference");
    close(solver.prepare(4,0.001,0.05).ph,7,0.04,"NaCl neutral salt reference");
    close(solver.prepare(6,0.001,0.05).ph,7,0.04,"KCl neutral salt reference");
    close(solver.prepare(7,0.001,0.05).ph,7,0.20,"Dilute CaCl2 near-neutral reference");
    close(solver.prepare(8,0.001,0.05).ph,(6.35+10.33)/2,0.20,"Bicarbonate amphiprotic reference");
    const double kb=std::pow(10.0,-14+10.33);
    const double oh=(-kb+std::sqrt(kb*kb+4*kb*0.001))/2;
    close(solver.prepare(9,0.001,0.05).ph,14+std::log10(oh),0.15,"Carbonate hydrolysis reference");
    Vessel acid{1,0.25,solver.prepare(2,0.001,0.05)};
    Vessel base{2,0.25,solver.prepare(3,0.001,0.05)};
    Vessel receiver{3,0.25,acid.solution};
    const auto direct=transfer(solver,base,receiver,0.05);
    close(direct.target.solution.ph,7,0.03,"Molar equimolar pH");
    auto source=base;
    for(int i=0;i<10;++i){auto r=transfer(solver,source,receiver,0.005);source=r.source;receiver=r.target;}
    close(receiver.solution.ph,direct.target.solution.ph,1e-6,"Incremental vs single pH");
    expect(source.solution.empty(),"Empty source stops pouring");
    auto empty=transfer(solver,source,receiver,1);
    close(empty.transferred_l,0,1e-12,"Empty source no transfer");
    auto over=transfer(solver,base,Vessel{4,0.25,{}},1);
    close(over.transferred_l,base.solution.volume_l,1e-10,"Overdraw clamped");
    expect(over.source.solution.empty(),"Overdraw no negative state");
    auto full=transfer(solver,base,Vessel{4,0.01,solver.prepare(1,0,0.01)},1);
    close(full.transferred_l,0,1e-10,"Full receiver no transfer");
    for(double bad:{-1.0,std::numeric_limits<double>::quiet_NaN(),std::numeric_limits<double>::infinity()}){
        bool rejected=false;try{transfer(solver,base,receiver,bad);}catch(...){rejected=true;}
        expect(rejected,"Invalid amount rejected");
    }
    bool unsupported=false;
    try{solver.mix(solver.prepare(7,0.001,0.05),1,solver.prepare(9,0.001,0.05),1);}catch(...){unsupported=true;}
    expect(unsupported,"Unverified calcium/carbonate mixture rejected");
    close(base.solution.volume_l,0.05,1e-8,"Inputs unchanged by failed/attempted transactions");
    std::cout<<"PASS: "<<stocks<<" stock/aliquot/dilution cases across 9 reagents; molarity and volume;\n"
        "incremental transfer, empty/full vessels, overdraw, invalid values and unsupported mixtures.\n";
    return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}
}
