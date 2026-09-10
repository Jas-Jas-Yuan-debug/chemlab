#pragma once
#include <array>
#include <string>
namespace chemlab {
// Constant-pressure ideal-gas equilibrium, with NASA7 thermochemistry.
// Species order is fixed by combustion_data.inc; amounts are per mol of feed fuel.
struct CombustionResult {
    double temperature_k=298.15, lhv_j_mol=0, fuel_molar_mass_g=0, oxygen_mol=0, nitrogen_mol=0;
    double enthalpy_residual_j=0, element_residual_mol=0;
    std::array<double,16> products{};
};
CombustionResult combustion_equilibrium(int source,double excess=1.2);
const char* combustion_species_name(int index);
}
