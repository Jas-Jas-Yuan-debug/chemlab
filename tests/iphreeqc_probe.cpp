#include <IPhreeqc.h>

#include <algorithm>
#include <array>
#include <cmath>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>

// Standalone Phase 0 verification. No engine code or engine dependency.
namespace {
struct Row {
    double ph, na, cl, hydrogen, oxygen, water, charge, ah, aoh, temperature;
};

void require(bool ok, const std::string& message) {
    if (!ok) throw std::runtime_error(message);
}

void near(double actual, double expected, double tolerance, const std::string& label) {
    require(std::isfinite(actual) && std::abs(actual - expected) <= tolerance,
            label + ": actual=" + std::to_string(actual) + ", expected=" + std::to_string(expected));
}

class Solver {
public:
    explicit Solver(const char* database) : id_(CreateIPhreeqc()) {
        require(id_ >= 0, "CreateIPhreeqc failed");
        if (LoadDatabase(id_, database) != 0) {
            const std::string error = GetErrorString(id_);
            DestroyIPhreeqc(id_);
            id_ = -1;
            throw std::runtime_error(error);
        }
    }
    ~Solver() { if (id_ >= 0) DestroyIPhreeqc(id_); }
    Solver(const Solver&) = delete;
    Solver& operator=(const Solver&) = delete;

    Row run(const std::string& input) {
        if (RunString(id_, input.c_str()) != 0) throw std::runtime_error(GetErrorString(id_));
        require(std::string(GetWarningString(id_)).empty(), "PHREEQC warning: " + std::string(GetWarningString(id_)));
        const int row = GetSelectedOutputRowCount(id_) - 1;
        require(row > 0 && GetSelectedOutputColumnCount(id_) == 10, "Missing selected output");
        std::array<double, 10> values{};
        for (int c = 0; c < 10; ++c) {
            VAR v;
            VarInit(&v);
            const int rc = GetSelectedOutputValue(id_, row, c, &v);
            const bool numeric = v.type == TT_DOUBLE || v.type == TT_LONG;
            const double number = v.type == TT_DOUBLE ? v.dVal : (v.type == TT_LONG ? v.lVal : 0.0);
            VarClear(&v);
            require(rc == VR_OK && numeric && std::isfinite(number), "Invalid selected value");
            values[c] = number;
        }
        return {values[0], values[1], values[2], values[3], values[4],
                values[5], values[6], values[7], values[8], values[9]};
    }

    bool rejects_invalid_input() {
        return RunString(id_, "SOLUTION 999\npH not_a_number\nEND\n") != 0;
    }

private:
    int id_;
};

const std::string output = R"(
SELECTED_OUTPUT 1
 -reset false
 -high_precision true
USER_PUNCH 1
 -headings pH Na_mol Cl_mol H_mol O_mol water_kg charge_eq aH aOH temp_C
 -start
 10 PUNCH -LA("H+"), TOTMOLE("Na"), TOTMOLE("Cl")
 20 PUNCH TOTMOLE("H"), TOTMOLE("O"), TOT("water"), CHARGE_BALANCE
 30 PUNCH ACT("H+"), ACT("OH-"), TC
 -end
)";

std::string stock(int id, bool acid) {
    return "SOLUTION " + std::to_string(id) + "\n -units mmol/kgw\n -temp 25\n -pressure 1\n"
           " -water 0.05\n pH " + (acid ? std::string("3 charge\n Cl 1\n") : std::string("11 charge\n Na 1\n")) + "END\n";
}

void verify_state(const Row& r) {
    require(r.water > 0 && r.na >= 0 && r.cl >= 0, "Invalid nonnegative state");
    near(r.charge, 0, 1e-10, "Electroneutrality (eq)");
    near(r.ph, -std::log10(r.ah), 1e-10, "pH activity definition");
    near(r.temperature, 25, 1e-10, "Isothermal temperature (C)");
    // External dilute-water reference, 25 C. Database-specific constants may differ slightly.
    near(-std::log10(r.ah * r.aoh), 14.0, 0.02, "Water ion product pKw at 25 C");
}

void conservation(const Row& mixed, const Row& a, const Row& b, double af, double bf) {
    near(mixed.na, af*a.na + bf*b.na, 1e-11, "Na conservation (mol)");
    near(mixed.cl, af*a.cl + bf*b.cl, 1e-11, "Cl conservation (mol)");
    near(mixed.hydrogen, af*a.hydrogen + bf*b.hydrogen, 1e-8, "H conservation (mol)");
    near(mixed.oxygen, af*a.oxygen + bf*b.oxygen, 1e-8, "O conservation (mol)");
}

void record(std::ostream& out, const std::string& name, const Row& r) {
    out << std::setprecision(15) << name << ',' << r.ph << ',' << r.na << ',' << r.cl << ','
        << r.hydrogen << ',' << r.oxygen << ',' << r.water << ',' << r.charge << ','
        << r.ah << ',' << r.aoh << ',' << r.temperature << '\n';
}
}

int main(int argc, char** argv) {
    try {
        require(argc == 3, "Usage: iphreeqc_probe DATABASE CSV_OUTPUT");
        std::ofstream csv(argv[2]);
        require(csv.good(), "Cannot open CSV output");
        csv << "case,pH,Na_mol,Cl_mol,H_mol,O_mol,water_kg,charge_eq,aH,aOH,temperature_C\n";
        Solver solver(argv[1]);
        const auto water = solver.run(output + "SOLUTION 10\n-temp 25\n-pressure 1\n-water 0.1\npH 7 charge\nEND\n");
        verify_state(water);
        near(water.ph, 7, 0.02, "CO2-free pure water pH");
        record(csv, "pure_water", water);
        const auto acid = solver.run(stock(1, true));
        const auto base = solver.run(stock(2, false));
        verify_state(acid); verify_state(base);
        near(acid.ph, 3, 0.08, "1 mmol/kg HCl vs ideal dilute limit");
        near(base.ph, 11, 0.08, "1 mmol/kg NaOH vs ideal dilute limit");
        near(acid.cl, 0.00005, 1e-11, "HCl stock chloride amount");
        near(base.na, 0.00005, 1e-11, "NaOH stock sodium amount");
        record(csv, "acid_stock", acid); record(csv, "base_stock", base);

        const auto neutral = solver.run("MIX 3\n1 1\n2 1\nSAVE solution 3\nEND\n");
        verify_state(neutral); conservation(neutral, acid, base, 1, 1);
        near(neutral.ph, 7, 0.03, "Equimolar neutralization");
        record(csv, "equimolar", neutral);
        const auto acid_excess = solver.run("MIX 4\n1 1\n2 0.5\nEND\n");
        verify_state(acid_excess); conservation(acid_excess, acid, base, 1, 0.5);
        near(acid_excess.ph, -std::log10(0.001 / 3), 0.08, "Acid excess vs ideal limit");
        record(csv, "acid_excess", acid_excess);
        const auto base_excess = solver.run("MIX 5\n1 0.5\n2 1\nEND\n");
        verify_state(base_excess); conservation(base_excess, acid, base, 0.5, 1);
        near(base_excess.ph, 14 + std::log10(0.001 / 3), 0.08, "Base excess vs ideal limit");
        record(csv, "base_excess", base_excess);

        auto previous = solver.run("MIX 6\n1 1\nSAVE solution 6\nEND\n");
        for (int i = 1; i <= 10; ++i) {
            const auto next = solver.run("MIX 6\n6 1\n2 0.1\nSAVE solution 6\nEND\n");
            verify_state(next); conservation(next, previous, base, 1, 0.1);
            require(next.ph >= previous.ph, "Titration should be monotonic");
            record(csv, "increment_" + std::to_string(i), next);
            previous = next;
        }
        near(previous.ph, neutral.ph, 1e-6, "Repeated vs single addition pH");
        near(previous.na, neutral.na, 1e-11, "Repeated vs single addition Na");
        near(previous.cl, neutral.cl, 1e-11, "Repeated vs single addition Cl");

        const auto diluted = solver.run("MIX 7\n1 1\n10 1\nEND\n");
        verify_state(diluted); conservation(diluted, acid, water, 1, 1);
        near(diluted.ph, -std::log10(0.001 / 3), 0.08, "Acid dilution vs ideal limit");
        record(csv, "acid_dilution", diluted);
        require(solver.rejects_invalid_input(), "Solver must report invalid chemistry input");
        csv.flush();
        require(csv.good(), "CSV write failed");
        std::cout << "PASS: 17 computed states; dilute references, activity pH, charge and Na/Cl/H/O balances,\n"
                     "10 incremental additions, dilution, invalid-input rejection.\n"
                     "Phase 0 standalone verification only; product-supported reagents: 0/30.\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "FAIL: " << error.what() << '\n';
        return 1;
    }
}
