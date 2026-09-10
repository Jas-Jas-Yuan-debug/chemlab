#pragma once
#include "chemistry.hpp"
#include <array>
namespace chemlab {
// Two stirred control volumes with finite inter-zone exchange. H+ + OH- <=> H2O
// is integrated analytically, not by interpolating pH to an equilibrium target.
class NeutralizationKinetics {
public:
    static constexpr double recombination_k=1.4e11; // L mol^-1 s^-1, 25 C, Eigen 1967
    struct Zone { double volume_l=0,h_mol=0,oh_mol=0; };
    static bool supports(const Solution& s);
    void initialize(const Solution& s);
    void add(const NeutralizationKinetics& aliquot,const Solution& equilibrium);
    NeutralizationKinetics withdraw(double fraction);
    void advance(double seconds,double exchange_ml_s);
    double ph(int zone=1) const;
    double h_total() const;
    double oh_total() const;
    double volume() const;
    double time() const{return time_s_;}
    double rate() const{return rate_mol_s_;}
    double reacted() const{return reacted_mol_;}
    double equivalent_error() const{return h_total()-oh_total()-equivalent_mol_;}
    double mixing_fraction() const;
    bool dilute_rate() const{return dilute_;}
    std::vector<double> save() const;
    void load(const std::vector<double>& state);
    const std::array<Zone,2>& zones() const{return zones_;}
    static double react(Zone& zone,double dt,double kw);
private:
    std::array<Zone,2> zones_{};
    double kw_=1e-14,gamma_h_=1,time_s_=0,rate_mol_s_=0,reacted_mol_=0,equivalent_mol_=0;
    bool dilute_=true;
    void set_thermodynamics(const Solution& equilibrium);
};
}
