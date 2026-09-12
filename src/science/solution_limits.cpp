#include "solution_limits.hpp"
#include "solution_limits_data.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace chemlab {
const SolutionLimit* solution_limit(int reagent) {
    auto i=solution_limits.find(reagent);
    return i==solution_limits.end()?nullptr:&i->second;
}
double maximum_concentration(int reagent) {
    if(reagent==1)return 0;
    const auto* p=solution_limit(reagent);
    return p?p->maximum_mol_l:0.01;
}
double stock_density(int reagent,double w) {
    const auto* p=solution_limit(reagent);
    if(!p||p->density_kg_l.empty()||!std::isfinite(w)||w<0||w>p->maximum_mass_fraction+1e-10)
        throw std::runtime_error("配液质量分数超出 25°C 物性数据上限");
    const auto& points=p->density_kg_l;
    for(size_t i=1;i<points.size();++i)if(w<=points[i].first)
        return points[i-1].second+(points[i].second-points[i-1].second)*(w-points[i-1].first)/(points[i].first-points[i-1].first);
    return points.back().second;
}
double stock_mass_fraction(int reagent,double c) {
    const auto* p=solution_limit(reagent);
    if(!p||!std::isfinite(c)||c<0||c>p->maximum_mol_l)
        throw std::runtime_error("浓度超出该物质的配制上限");
    double lo=0,hi=p->maximum_mass_fraction;
    for(int i=0;i<60;++i){
        const double w=(lo+hi)/2;
        if(1000*stock_density(reagent,w)*w/p->molar_mass_g_mol<c)lo=w;else hi=w;
    }
    return (lo+hi)/2;
}
}
