#pragma once
#include "combustion.hpp"
#include <vector>
#include <cstdint>
namespace chemlab {
// Reduced, low-Mach educational reactive flow. Conservative donor-cell transport
// of fuel, oxidizer and sensible energy; projected velocity and buoyancy.
// This is not a detailed-kinetics or certified burner-design solver.
class FlameField {
public:
 static constexpr int nx=16,ny=28,nz=16,count=nx*ny*nz;
 static constexpr double dx=0.006,step=1.0/120;
 FlameField();
 void reset(int source);
 void advance(double elapsed,double fuel_mol_s,double wind_m_s);
 std::vector<uint8_t> atlas()const;
 std::vector<double> save()const;
 void load(const std::vector<double>&state);
 int source()const{return source_;}
 double peak_temperature()const;
 double burned_mol()const{return burned_;}
 double fuel_balance_error()const;
 double time()const{return ticks_*step;}
 double energy_balance_error()const;
 double max_speed()const;
private:
 int source_=1;
 uint64_t ticks_=0;
 double remainder_=0,injected_=0,burned_=0,escaped_=0,heat_out_=0;
 double heat_capacity_=1200,stoich_=3,lhv_kg_=2.7e7,molar_kg_=0.046,ambient_oxygen_=0.28;
 std::vector<double> fuel_,oxygen_,heat_,product_,u_,v_,w_,inert_;
 double feed_oxygen_=0,feed_inert_=0;
 double temperature(int i)const;
 void tick(double flow,double wind);
 void transport(std::vector<double>&field,double exterior,double& escaped);
 void project();
};
}
