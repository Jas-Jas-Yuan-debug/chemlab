#pragma once
#include <cstdint>
#include <map>
#include <string>
#include <vector>
namespace chemlab {
using Scalars = std::map<std::string,double>;
class PhysicsExperiment {
public:
    void configure(const std::string& kind,const Scalars& parameters);
    void start();
    void pause();
    void reset();
    void advance(double elapsed_s);
    Scalars reading() const;
    void restore(double elapsed_s);
    void control_heater(const Scalars& control);
    void restore_heater_controls(const std::vector<Scalars>& controls);
    const std::vector<Scalars>& heater_controls() const { return heater_controls_; }
    const Scalars& parameters() const{return parameters_;}
    const std::string& kind()const{return kind_;}
    static constexpr double step_s=1.0/120.0;
private:
    std::string kind_="spring";
    Scalars parameters_={{"mass_kg",0.2},{"stiffness_n_m",8},{"amplitude_m",0.1}};
    double remainder_=0;
    uint64_t ticks_=0;
    bool running_=false;
    std::vector<Scalars> heater_controls_;
};
}
