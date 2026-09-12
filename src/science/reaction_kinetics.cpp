#include "reaction_kinetics.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>
namespace chemlab {
namespace {
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
double element(const Solution&s,const char* e){auto i=s.elements.find(e);return i==s.elements.end()?0:i->second;}
double positive_root(double d,double kw){const double a=std::sqrt(d*d+4*kw);return d>=0?(a+d)/2:2*kw/(a-d);}
}
bool NeutralizationKinetics::supports(const Solution&s){
    if(s.isolated_batch_sample||s.empirical_stock)return false;
    for(auto[id,n]:s.ingredients_mol)if(n>0&&(id<2||id>6))return false;
    return true;
}
double NeutralizationKinetics::h_total()const{return zones_[0].h_mol+zones_[1].h_mol;}
double NeutralizationKinetics::oh_total()const{return zones_[0].oh_mol+zones_[1].oh_mol;}
double NeutralizationKinetics::volume()const{return zones_[0].volume_l+zones_[1].volume_l;}
void NeutralizationKinetics::set_thermodynamics(const Solution&s){
    if(s.empty())return;
    // The equilibrium solver supplies the bulk water-ion concentration product.
    // A common bulk activity correction is used by both zones; local activity
    // gradients are not independently speciated. Concentrated rates are extrapolations.
    kw_=std::max(1e-18,s.h_molar*s.oh_molar);
    const double d=(element(s,"Cl")-element(s,"Na")-element(s,"K"))/s.volume_l;
    gamma_h_=std::pow(10.,-s.ph)/positive_root(d,kw_);
    dilute_=s.ionic_strength<=0.02;
}
void NeutralizationKinetics::initialize(const Solution&s){
    check(supports(s),"此体系尚无动力学模型");zones_={};time_s_=0;rate_mol_s_=0;reacted_mol_=0;equivalent_mol_=0;
    if(s.empty())return;
    set_thermodynamics(s);
    equivalent_mol_=element(s,"Cl")-element(s,"Na")-element(s,"K");
    const double d=equivalent_mol_/s.volume_l,h=positive_root(d,kw_),oh=positive_root(-d,kw_);
    for(auto& z:zones_)z={s.volume_l/2,h*s.volume_l/2,oh*s.volume_l/2};
}
NeutralizationKinetics NeutralizationKinetics::withdraw(double f){
    check(std::isfinite(f)&&f>=0&&f<=1,"动力学取样比例无效");
    NeutralizationKinetics a=*this;
    for(size_t i=0;i<2;++i){a.zones_[i].volume_l*=f;a.zones_[i].h_mol*=f;a.zones_[i].oh_mol*=f;zones_[i].volume_l*=1-f;zones_[i].h_mol*=1-f;zones_[i].oh_mol*=1-f;}
    a.equivalent_mol_*=f;equivalent_mol_*=1-f;
    a.reacted_mol_=0;a.rate_mol_s_=0;
    return a;
}
void NeutralizationKinetics::add(const NeutralizationKinetics&a,const Solution&s){
    if(a.volume()<=1e-15)return;
    const double prior=volume();
    zones_[0].volume_l+=a.volume();zones_[0].h_mol+=a.h_total();zones_[0].oh_mol+=a.oh_total();
    equivalent_mol_+=a.h_total()-a.oh_total();
    // Incoming liquid enters the upper zone; displaced liquid carries all its
    // ions into the lower zone. No mass or concentration is created by regridding.
    const double excess=zones_[0].volume_l-(prior+a.volume())/2;
    const double f=excess/zones_[0].volume_l;
    zones_[1].volume_l+=excess;zones_[1].h_mol+=zones_[0].h_mol*f;zones_[1].oh_mol+=zones_[0].oh_mol*f;
    zones_[0].h_mol*=1-f;zones_[0].oh_mol*=1-f;zones_[0].volume_l-=excess;
    // PHREEQC includes the small mixing/reaction change in solution volume.
    const double scale=s.volume_l/volume();for(auto&z:zones_)z.volume_l*=scale;
    set_thermodynamics(s);
}
double NeutralizationKinetics::react(Zone&z,double dt,double kw){
    if(z.volume_l<=1e-15||dt<=0)return 0;
    const double h=z.h_mol/z.volume_l,oh=z.oh_mol/z.volume_l,d=h-oh;
    // y=min(H,OH) obeys dy/dt=-k(y^2+|d|y-Kw); use its two roots.
    const double span=std::sqrt(d*d+4*kw),a=2*kw/(span+std::abs(d)),b=-(span+std::abs(d))/2;
    const double y=std::min(h,oh),r=(y-a)/(y-b)*std::exp(-recombination_k*span*dt);
    const double next=std::max(0.,(a-r*b)/(1-r));
    const double extent=(y-next)*z.volume_l;
    z.h_mol=(next+std::max(d,0.))*z.volume_l;z.oh_mol=(next+std::max(-d,0.))*z.volume_l;
    return extent;
}
void NeutralizationKinetics::advance(double dt,double exchange_ml_s){
    check(std::isfinite(dt)&&dt>=0&&dt<=1&&std::isfinite(exchange_ml_s)&&exchange_ml_s>=0&&exchange_ml_s<=100,"动力学时间或混合交换流量无效");
    if(volume()<=1e-15||dt==0)return;
    // Symmetric splitting and analytic pairwise exchange preserve positivity.
    const int steps=std::max(1,int(std::ceil(dt*240)));const double h=dt/steps;double extent=0;
    for(int i=0;i<steps;++i){
        for(auto&z:zones_)extent+=react(z,h/2,kw_);
        const double v0=zones_[0].volume_l,v1=zones_[1].volume_l;
        if(v0>1e-15&&v1>1e-15){
            const double decay=std::exp(-exchange_ml_s/1000*(1/v0+1/v1)*h);
            for(int species=0;species<2;++species){
                double&n0=species==0?zones_[0].h_mol:zones_[0].oh_mol;
                double&n1=species==0?zones_[1].h_mol:zones_[1].oh_mol;
                const double total=n0+n1,difference=n0/v0-n1/v1;
                n0=(total+v1*difference*decay)*v0/(v0+v1);n1=total-n0;
            }
        }
        for(auto&z:zones_)extent+=react(z,h/2,kw_);
    }
    time_s_+=dt;reacted_mol_+=extent;rate_mol_s_=extent/dt;
    check(std::abs(equivalent_error())<1e-10,"动力学酸碱当量收支失败");
}
double NeutralizationKinetics::ph(int i)const{
    const auto&z=zones_.at(i);return -std::log10(std::max(1e-30,gamma_h_*z.h_mol/std::max(z.volume_l,1e-30)));
}
double NeutralizationKinetics::mixing_fraction()const{
    if(volume()<=1e-15)return 0;
    const double a=zones_[0].h_mol-zones_[0].oh_mol,b=zones_[1].h_mol-zones_[1].oh_mol;
    return std::abs(a-b)/std::max(1e-14,std::abs(a)+std::abs(b));
}
std::vector<double> NeutralizationKinetics::save()const{
    std::vector<double>s={1,kw_,gamma_h_,time_s_,rate_mol_s_,reacted_mol_,equivalent_mol_,double(dilute_)};
    for(const auto&z:zones_){s.push_back(z.volume_l);s.push_back(z.h_mol);s.push_back(z.oh_mol);}return s;
}
void NeutralizationKinetics::load(const std::vector<double>&s){
    check(s.size()==14,"动力学记录尺寸无效");for(double x:s)check(std::isfinite(x),"动力学记录数值无效");
    check(s[0]==1&&s[1]>=1e-18&&s[1]<=1e-9&&s[2]>0&&s[2]<100&&s[3]>=0&&s[3]<=86400&&(s[7]==0||s[7]==1),"动力学参数超出范围");
    NeutralizationKinetics c;c.kw_=s[1];c.gamma_h_=s[2];c.time_s_=s[3];c.rate_mol_s_=s[4];c.reacted_mol_=s[5];c.equivalent_mol_=s[6];c.dilute_=bool(s[7]);
    for(int i=0;i<2;++i){const int j=8+3*i;check(s[j]>=0&&s[j]<=1&&s[j+1]>=0&&s[j+1]<=2&&s[j+2]>=0&&s[j+2]<=2,"动力学库存超出范围");c.zones_[i]={s[j],s[j+1],s[j+2]};}
    check(std::abs(c.equivalent_error())<1e-10,"动力学记录当量不守恒");*this=c;
}
}
