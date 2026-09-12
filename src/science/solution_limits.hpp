#pragma once
#include <map>
#include <utility>
#include <vector>

namespace chemlab {
struct SolutionLimit {
    double maximum_mol_l, molar_mass_g_mol, maximum_mass_fraction;
    std::vector<std::pair<double,double>> density_kg_l;
};
const SolutionLimit* solution_limit(int reagent);
double maximum_concentration(int reagent);
double stock_density(int reagent, double mass_fraction);
double stock_mass_fraction(int reagent, double concentration_mol_l);
}
