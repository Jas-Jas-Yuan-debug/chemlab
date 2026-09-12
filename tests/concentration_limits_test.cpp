#include "science/chemistry.hpp"
#include "science/solution_limits.hpp"
#include "science/reaction_kinetics.hpp"
#include "science/session.hpp"
#include <cmath>
#include <functional>
#include <iostream>
#include <limits>
#include <stdexcept>
using namespace chemlab;
void check(bool b,const char* m){if(!b)throw std::runtime_error(m);}
void rejects(const std::function<void()>& f){bool caught=false;try{f();}catch(const std::runtime_error&){caught=true;}check(caught,"Out-of-scope preparation or mixing accepted");}
void balance(const Solution&r,const Solution&a,const Solution&b){
    check(std::abs(r.hydrogen_mol-a.hydrogen_mol-b.hydrogen_mol)<1e-8,"H inventory lost");
    check(std::abs(r.oxygen_mol-a.oxygen_mol-b.oxygen_mol)<1e-8,"O inventory lost");
    for(const char* e:{"Na","K","Cl"})check(std::abs(r.elements.at(e)-a.elements.at(e)-b.elements.at(e))<1e-9,"Solute inventory lost");
}
int main(int argc,char**argv){
    if(argc!=3)return 2;
    Chemistry solver(argv[1],false,argv[2]);
    for(int id:{2,3,4,5,6}){
        const double max=maximum_concentration(id);
        for(double v:{0.001,0.05,0.25}){
            const auto s=solver.prepare(id,max,v);
            check(std::abs(s.volume_l-v)<1e-8,"Maximum stock failed final-volume definition");
            check(std::abs(s.ingredients_mol.at(id)-max*v)<1e-11,"Molarity is not amount/final solution volume");
            check(s.empirical_stock==(id==2||id==3||id==5),"Wrong stock/quantitative model boundary");
            check(s.water_kg>0&&std::abs(s.charge_eq)<1e-9,"Invalid solvent/charge");
            check(s.halite_si<=1e-7&&s.sylvite_si<=1e-7,"Prepared a supersaturated salt");
        }
        const auto s=solver.prepare(id,max,0.05);
        rejects([&]{solver.prepare(id,max+0.00001,0.05);});
        rejects([&]{solver.prepare(id,std::numeric_limits<double>::quiet_NaN(),0.05);});
        // Homogeneous transfers must preserve a max-concentration stock exactly.
        const auto t=transfer(solver,{1,0.25,s},{2,0.25,{}},0.02);
        check(std::abs(t.source.solution.ingredients_mol.at(id)+t.target.solution.ingredients_mol.at(id)-s.ingredients_mol.at(id))<1e-11,"Aliquot lost solute");
        check(t.target.solution.empirical_stock==s.empirical_stock,"Aliquot lost stock state");
        check(std::abs(t.target.solution.volume_l-0.02)<1e-10,"Aliquot changed volume");
        // Dilute to <0.1 M and check inventory through the density-model boundary.
        const auto tiny=solver.mix(s,0.01,{},0),water=solver.prepare(1,0,0.25);
        const auto diluted=solver.mix(tiny,1,water,1);
        balance(diluted,tiny,water);
        check(!diluted.empirical_stock&&NeutralizationKinetics::supports(diluted),"Dilution did not restore quantitative chemistry");
        check(diluted.ph>=-2&&diluted.ph<=16,"Diluted pH outside numerical range");
        if(id==2)check(diluted.ph<3,"Diluted acid lost acidity");
        if(id==3||id==5)check(diluted.ph>11,"Diluted base lost alkalinity");
        if(s.empirical_stock){
            check(!NeutralizationKinetics::supports(s),"Invented uncalibrated concentrated kinetics");
            const auto lower=solver.prepare(id,max/2,0.05);
            const auto combined=solver.mix(s,1,lower,1);balance(combined,s,lower);
            check(combined.empirical_stock&&combined.volume_l>0.09&&combined.volume_l<0.11,"Same-solute density mixing failed");
            rejects([&]{solver.mix(s,1,solver.prepare(id==2?3:2,0.001,0.05),1);});
        }else{
            check(std::abs(id==4?s.halite_si:s.sylvite_si)<1e-4,"Salt maximum is not near SI=0");
        }
        std::cout<<"maximum "<<id<<" = "<<max<<" mol/L; 1/50/250 mL, aliquot, dilution and rejection PASS\n";
    }
    // External handbook-density spot checks with deliberate graph-reading tolerance.
    for(auto [id,c,w,rho]:{std::tuple{2,12.0,0.37,1.18},std::tuple{3,19.0,0.50,1.52},std::tuple{5,13.45,0.50,1.51}}){
        const auto s=solver.prepare(id,c,0.1);const double solute=c*0.1*solution_limit(id)->molar_mass_g_mol/1000;
        check(std::abs(solute/(solute+s.water_kg)-w)<0.008,"Wrong mass fraction at independently known concentrated stock");
        check(std::abs((solute+s.water_kg)/s.volume_l-rho)<0.015,"Density diverges from handbook concentrated stock");
    }
    // The two saturated stocks dilute each other's cation; do not assume that
    // every common-ion mixture precipitates. Check the computed final state.
    const auto nacl=solver.prepare(4,maximum_concentration(4),0.05),kcl=solver.prepare(6,maximum_concentration(6),0.05);
    const auto salt_mix=solver.mix(nacl,1,kcl,1);balance(salt_mix,nacl,kcl);
    check(salt_mix.halite_si<=1e-7&&salt_mix.sylvite_si<=1e-7,"Accepted supersaturated salt mixture");
    // Native transaction: rejected reaction may not consume either vessel.
    LabSession session;session.reset(solver);
    session.apply(solver,{"prepare",{{"id",1},{"reagent",5},{"concentration",maximum_concentration(5)},{"volume_ml",50},{"capacity_ml",250}}});
    const auto count=session.journal.size();const double prior=session.vessels.at(1).solution.volume_l;
    rejects([&]{session.apply(solver,{"pour",{{"from",1},{"to",2},{"amount_ml",5}}});});
    check(session.journal.size()==count&&session.vessels.at(1).solution.volume_l==prior,"Rejected pour mutated session");
    std::cout<<"PASS: per-solute near-saturation preparation, density references, conservation, model boundary and transactional rejection\n";
}
