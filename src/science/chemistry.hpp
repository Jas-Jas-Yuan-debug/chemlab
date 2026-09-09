#pragma once
#include <map>
#include <string>
#include <vector>

namespace chemlab {
struct Solution {
    double ph = 0;
    double volume_l = 0;
    double water_kg = 0;
    double charge_eq = 0;
    double hydrogen_mol = 0;
    double oxygen_mol = 0;
    std::map<std::string, double> elements;
    std::string raw;
    std::map<int, double> ingredients_mol;
    bool empty() const { return volume_l <= 1e-12; }
};

// One owner thread per instance. No Godot types, graphics, or UI dependencies.
class Chemistry {
public:
    explicit Chemistry(const std::string& database);
    ~Chemistry();
    Chemistry(const Chemistry&) = delete;
    Chemistry& operator=(const Chemistry&) = delete;
    Solution prepare(int reagent, double concentration_mol_l, double volume_l);
    Solution mix(const Solution& a, double af, const Solution& b, double bf);
    static bool supported(int reagent);
    static void validate_combination(const Solution& a, const Solution& b);
private:
    int id_ = -1;
    Solution solve(const std::string& input);
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
