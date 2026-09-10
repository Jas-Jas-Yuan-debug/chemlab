#include "science/reaction_kinetics.hpp"
#include <cmath>
#include <iostream>
#include <stdexcept>
using namespace chemlab;
void check(bool b,const char*m){if(!b)throw std::runtime_error(m);}
int main(int argc,char**argv){
    if(argc!=3)return 2;
    // Independent integrated second-order irreversible limit over nanoseconds.
    NeutralizationKinetics::Zone z{1,0.001,0.001};
    NeutralizationKinetics::react(z,1e-8,1e-14);
    const double expected=0.001/(1+1.4e11*0.001*1e-8);
    check(std::abs(z.h_mol-expected)<1e-10,"Nanosecond rate does not match independent second-order law");
    Chemistry solver(argv[1],false,argv[2]);
    for(int reagent:{2,3,4,5,6})for(double c:{0.001,0.01,0.1,1.0}){
        const auto s=solver.prepare(reagent,c,0.05);
        check(std::abs(s.volume_l-0.05)<1e-8,"High concentration molarity/volume");
        check(s.pitzer==(c>0.01),"Wrong activity model");
        check(std::abs(s.charge_eq)<1e-9,"High concentration charge balance");
        const char*e=(reagent==2)?"Cl":(reagent==3||reagent==4)?"Na":"K";
        check(std::abs(s.elements.at(e)-c*0.05)<1e-10,"High concentration stoichiometry");
        check(s.gamma_h>0&&std::isfinite(s.ph),"Invalid nonideal pH");
        if(reagent==2)check(s.ph<3.1,"Acid sign");
        if(reagent==3||reagent==5)check(s.ph>10.8,"Base sign");
        std::cout<<"prepare "<<reagent<<" "<<c<<" M pH="<<s.ph<<" I="<<s.ionic_strength<<"\n";
    }
    for(double c:{0.001,0.1,1.0}){
        auto a=solver.prepare(2,c,0.05),b=solver.prepare(5,c,0.05);
        auto final=solver.mix(a,1,b,1);
        check(final.ph>6.7&&final.ph<7.3,"Equimolar concentrated HCl/KOH neutralization");
        NeutralizationKinetics ka,kb;ka.initialize(a);kb.initialize(b);ka.add(kb,final);
        auto slower=ka,faster=ka,partition=ka;
        for(int i=0;i<600;++i){slower.advance(1./60,0.1);faster.advance(1./60,80);}
        for(int i=0;i<300;++i)partition.advance(1./30,80);
        check(std::abs(faster.ph()-final.ph)<0.08,"Finite mixing did not approach equilibrium");
        check(std::abs(slower.ph()-final.ph)>0.5,"Mixing rate has no physical effect");
        check(std::abs(partition.ph()-faster.ph())<1e-9,"30/60 FPS partition changed kinetics");
        check(std::abs(faster.equivalent_error())<1e-11,"Acid/base equivalents lost");
        NeutralizationKinetics restored;restored.load(slower.save());restored.advance(0.1,5);slower.advance(0.1,5);
        check(restored.save()==slower.save(),"Kinetic save did not restore exact continuation");
        const double h=faster.h_total(),oh=faster.oh_total();auto aliquot=faster.withdraw(0.25);
        check(std::abs(h-faster.h_total()-aliquot.h_total())<1e-12&&std::abs(oh-faster.oh_total()-aliquot.oh_total())<1e-12,"Dynamic aliquot lost ions");
        auto water=solver.prepare(1,0,0.05);auto diluted=solver.mix(a,1,water,1);
        check(diluted.pitzer==a.pitzer&&std::abs(diluted.elements.at("Cl")-a.elements.at("Cl"))<1e-11,"Pitzer dilution changed inventory");
    }
    std::cout<<"PASS: physical neutralization timescale, finite mixing, conservation, high-concentration Pitzer prepare/mix/dilute and exact dynamic restore\n";
}
