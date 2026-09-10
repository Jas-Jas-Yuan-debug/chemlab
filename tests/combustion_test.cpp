#include "science/combustion.hpp"
#include <iostream>
#include <iomanip>
int main(){std::cout<<std::setprecision(15);for(int s=1;s<=5;++s)for(double excess:{1.,1.2,1.5,2.}){auto r=chemlab::combustion_equilibrium(s,excess);std::cout<<s<<","<<excess<<","<<r.temperature_k<<","<<r.enthalpy_residual_j<<","<<r.element_residual_mol;for(double n:r.products)std::cout<<","<<n;std::cout<<"\n";} }
