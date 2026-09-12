#pragma once
#include <map>
#include <string>
#include <vector>

namespace chemlab {
struct Solution {
    bool isolated_batch_sample = false;
    bool pitzer = false;
    // Empirical density / conserved stock inventory; no quantitative pH or rate.
    bool empirical_stock = false;
    double halite_si = -99.99, sylvite_si = -99.99;
    double h_molar = 0, oh_molar = 0, gamma_h = 1, ionic_strength = 0;
    double ph = 0;
    double volume_l = 0;
    double water_kg = 0;
    double charge_eq = 0;
    double hydrogen_mol = 0;
    double oxygen_mol = 0;
    std::map<std::string, double> elements;
    std::map<std::string, double> valence_mol;
    std::string raw;
    std::string composition_key;
    // Input provenance for permitted combinations; current phase inventory is
    // elements/valence_mol, not undissociated original reagent molecules.
    std::map<int, double> ingredients_mol;
    bool empty() const { return volume_l <= 1e-12; }
};

enum class GasBoundary { None, ClosedVolume, FixedCO2 };
struct BatchConditions {
    int solid_reagent = 0; // 18 Calcite, 19 Gypsum; no other candidate solids.
    double solid_mol = 0;
    GasBoundary gas = GasBoundary::None;
    double co2_added_mol = 0;
    double headspace_l = 0.1;
    double external_co2_atm = 0.00042;
};
struct BatchResult {
    Solution solution;
    std::string mineral;
    double solid_remaining_mol = 0;
    double gas_co2_mol = 0;
    double gas_pressure_atm = 0;
    double co2_to_environment_mol = 0; // Negative means uptake.
    double solid_saturation_index = 0;
    double carbon_residual_mol = 0;
    double calcium_residual_mol = 0;
    double barium_residual_mol = 0;
    double sulfur_residual_mol = 0;
};

// One owner thread per instance. No Godot types, graphics, or UI dependencies.
class Chemistry {
public:
    explicit Chemistry(const std::string& database, bool database_is_text = false, const std::string& pitzer_database = "");
    ~Chemistry();
    Chemistry(const Chemistry&) = delete;
    Chemistry& operator=(const Chemistry&) = delete;
    Solution prepare(int reagent, double concentration_mol_l, double volume_l);
    BatchResult precipitate_barite(const Solution& barium_chloride, const Solution& sodium_sulfate);
    BatchResult equilibrate(const Solution& solution, const BatchConditions& conditions);
    Solution mix(const Solution& a, double af, const Solution& b, double bf);
    static bool supported(int reagent);
    static void validate_combination(const Solution& a, const Solution& b);
private:
    int id_ = -1;
    int pitzer_id_ = -1;
    Solution solve(const std::string& input, bool use_pitzer = false, bool inventory_only = false);
};

struct Vessel {
    int id = 0;
    double capacity_l = 0.25;
    Solution solution;
};

struct TransferResult {
    Vessel source;
    Vessel target;
    double transferred_l = 0;
};
TransferResult transfer(Chemistry& solver, const Vessel& source, const Vessel& target, double requested_l);
}
