#include "flame_field.hpp"
#include <algorithm>
#include <cmath>
#include <stdexcept>
#include <numeric>
namespace chemlab {
namespace {int at(int x,int y,int z){return (z*FlameField::ny+y)*FlameField::nx+x;}constexpr double cell=FlameField::dx*FlameField::dx*FlameField::dx;}
FlameField::FlameField(){reset(1);}
void FlameField::reset(int source){
 auto thermo=combustion_equilibrium(source);source_=source;ticks_=0;remainder_=injected_=burned_=escaped_=heat_out_=0;
 molar_kg_=thermo.fuel_molar_mass_g/1000;lhv_kg_=thermo.lhv_j_mol/molar_kg_;
 // Reaction uses cold stoichiometric products; dissociation enters the effective
 // mixture heat capacity derived from the independently solved adiabatic state.
 const double stoich_mol=thermo.oxygen_mol/1.2;stoich_=stoich_mol*0.031998/molar_kg_;
 const double feed_mass=molar_kg_+thermo.oxygen_mol*0.031998+thermo.nitrogen_mol*0.028014;
 heat_capacity_=thermo.lhv_j_mol/(feed_mass*(thermo.temperature_k-298.15));
 ambient_oxygen_=(source==3||source==4)?1.2:0.279;
 feed_oxygen_=thermo.oxygen_mol*0.031998/molar_kg_;feed_inert_=thermo.nitrogen_mol*0.028014/molar_kg_;
 inert_.assign(count,1.2-ambient_oxygen_);
 fuel_.assign(count,0);oxygen_.assign(count,ambient_oxygen_);heat_.assign(count,0);product_.assign(count,0);
 u_.assign(count,0);v_.assign(count,0);w_.assign(count,0);
}
void FlameField::advance(double elapsed,double flow,double wind){
 if(!std::isfinite(elapsed)||elapsed<0||elapsed>1||!std::isfinite(flow)||flow<0||flow>0.1||!std::isfinite(wind)||std::abs(wind)>0.12)throw std::invalid_argument("三维燃烧输入超出范围");
 remainder_+=elapsed;while(remainder_+1e-12>=step){tick(flow,wind);remainder_-=step;++ticks_;}
}
void FlameField::transport(std::vector<double>&f,double exterior,double& escaped){
 auto change=std::vector<double>(count,0.0);
 // Each face is processed once. Flux lost by one cell is gained by its neighbor.
 auto face=[&](int a,int b,double velocity){double donor=velocity>=0?(a<0?exterior:f[a]):(b<0?exterior:f[b]);double flux=velocity*step/dx*donor;
 if(a>=0)change[a]-=flux;if(b>=0)change[b]+=flux;
 if(a<0)escaped-=flux*cell;if(b<0)escaped+=flux*cell;};
 for(int z=0;z<nz;++z)for(int y=0;y<ny;++y)for(int x=0;x<=nx;++x){int a=x?at(x-1,y,z):-1,b=x<nx?at(x,y,z):-1;double vel=a<0?u_[b]:b<0?u_[a]:(u_[a]+u_[b])/2;face(a,b,vel);}
 for(int z=0;z<nz;++z)for(int y=0;y<=ny;++y)for(int x=0;x<nx;++x){int a=y?at(x,y-1,z):-1,b=y<ny?at(x,y,z):-1;double vel=a<0?0:b<0?std::max(0.0,v_[a]):(v_[a]+v_[b])/2;face(a,b,vel);}
 for(int z=0;z<=nz;++z)for(int y=0;y<ny;++y)for(int x=0;x<nx;++x){int a=z?at(x,y,z-1):-1,b=z<nz?at(x,y,z):-1;double vel=a<0?w_[b]:b<0?w_[a]:(w_[a]+w_[b])/2;face(a,b,vel);}
 // Conservative, explicit scalar diffusion. Coefficient is a stated effective
 // diffusivity, common to all scalars (unity Lewis number approximation).
 constexpr double k=2e-5*step/(dx*dx);
 for(int z=0;z<nz;++z)for(int y=0;y<ny;++y)for(int x=0;x<nx;++x){int a=at(x,y,z);for(int axis=0;axis<3;++axis){int xx=x+(axis==0),yy=y+(axis==1),zz=z+(axis==2);if(xx>=nx||yy>=ny||zz>=nz)continue;int b=at(xx,yy,zz);double flux=k*(f[a]-f[b]);change[a]-=flux;change[b]+=flux;}}
 for(int i=0;i<count;++i){f[i]+=change[i];if(f[i]<-1e-8||!std::isfinite(f[i]))throw std::runtime_error("三维燃烧时间步失稳");if(f[i]<0)f[i]=0;}
}
void FlameField::project(){
 std::vector<double>p(count,0),next(count,0),div(count,0);
 auto val=[](const std::vector<double>&a,int x,int y,int z){return a[at(std::clamp(x,0,nx-1),std::clamp(y,0,ny-1),std::clamp(z,0,nz-1))];};
 for(int z=1;z<nz-1;++z)for(int y=1;y<ny-1;++y)for(int x=1;x<nx-1;++x)div[at(x,y,z)]=(val(u_,x+1,y,z)-val(u_,x-1,y,z)+val(v_,x,y+1,z)-val(v_,x,y-1,z)+val(w_,x,y,z+1)-val(w_,x,y,z-1))*dx/2;
 for(int k=0;k<24;++k){for(int z=1;z<nz-1;++z)for(int y=1;y<ny-1;++y)for(int x=1;x<nx-1;++x)next[at(x,y,z)]=(val(p,x+1,y,z)+val(p,x-1,y,z)+val(p,x,y+1,z)+val(p,x,y-1,z)+val(p,x,y,z+1)+val(p,x,y,z-1)-div[at(x,y,z)])/6;p.swap(next);}
 for(int z=1;z<nz-1;++z)for(int y=1;y<ny-1;++y)for(int x=1;x<nx-1;++x){int i=at(x,y,z);u_[i]-=(val(p,x+1,y,z)-val(p,x-1,y,z))/(2*dx);v_[i]-=(val(p,x,y+1,z)-val(p,x,y-1,z))/(2*dx);w_[i]-=(val(p,x,y,z+1)-val(p,x,y,z-1))/(2*dx);}
}
void FlameField::tick(double flow,double wind){
 // Convection evolves velocity; pressure projection removes its divergent part.
 auto uu=u_,vv=v_,ww=w_;
 for(int z=1;z<nz-1;++z)for(int y=1;y<ny-1;++y)for(int x=1;x<nx-1;++x){int i=at(x,y,z);auto sample=[&](const std::vector<double>& f){
   const double xx=std::clamp(x-u_[i]*step/dx,0.0,double(nx-1)-1e-8),yy=std::clamp(y-v_[i]*step/dx,0.0,double(ny-1)-1e-8),zz=std::clamp(z-w_[i]*step/dx,0.0,double(nz-1)-1e-8);
   int ix=int(xx),iy=int(yy),iz=int(zz);double result=0;
   for(int c=0;c<8;++c){int a=c&1,b=(c>>1)&1,d=(c>>2)&1;result+=f[at(ix+a,iy+b,iz+d)]*(a?xx-ix:1-xx+ix)*(b?yy-iy:1-yy+iy)*(d?zz-iz:1-zz+iz);}return result;
  };
  uu[i]=sample(u_)*0.995+wind*0.005;ww[i]=sample(w_)*0.995;
  const double advected_v=sample(v_);
  const double t=temperature(i);vv[i]=advected_v*0.995+step*9.80665*(1-298.15/t);
 }
 u_.swap(uu);v_.swap(vv);w_.swap(ww);
 for(int z=0;z<nz;++z)for(int y=0;y<ny;++y){u_[at(0,y,z)]=wind;u_[at(nx-1,y,z)]=wind;}
 project();
 // CFL bound includes every outgoing face and diffusion; no negative inventories.
 for(int i=0;i<count;++i){double sum=std::abs(u_[i])+std::abs(v_[i])+std::abs(w_[i]);if(sum>0.24){double f=0.24/sum;u_[i]*=f;v_[i]*=f;w_[i]*=f;}}
 transport(fuel_,0,escaped_);double dummy=0;transport(oxygen_,ambient_oxygen_,dummy);transport(inert_,1.2-ambient_oxygen_,dummy);transport(product_,0,dummy);transport(heat_,0,heat_out_);
 // Axisymmetric pilot-fed source, resolved in all three dimensions. Inlet flow
 // comes directly from fuel consumed by the independently conserved heater.
 int cells=0;for(int z=0;z<nz;++z)for(int x=0;x<nx;++x)if(std::hypot(x-7.5,z-7.5)<2.5)++cells;
 const double added=flow*molar_kg_*step;injected_+=added;
 for(int z=0;z<nz;++z)for(int x=0;x<nx;++x)if(std::hypot(x-7.5,z-7.5)<2.5){int i=at(x,1,z);fuel_[i]+=added/(cells*cell);oxygen_[i]+=added*feed_oxygen_/(cells*cell);inert_[i]+=added*feed_inert_/(cells*cell);}
 for(int z=0;z<nz;++z)for(int y=0;y<ny;++y)for(int x=0;x<nx;++x){int i=at(x,y,z);const bool pilot=flow>0&&y<=2&&std::hypot(x-7.5,z-7.5)<3;
  const double t=temperature(i);
  if(pilot||t>700){double burn=std::min(fuel_[i],oxygen_[i]/stoich_)*(1-std::exp(-step/0.02));fuel_[i]-=burn;oxygen_[i]-=burn*stoich_;product_[i]+=burn*(1+stoich_);heat_[i]+=burn*lhv_kg_;burned_+=burn*cell/molar_kg_;}
  // Linear wall/radiative loss closure is explicit and included in the budget.
  const double loss=heat_[i]*(1-std::exp(-0.6*step));heat_[i]-=loss;heat_out_+=loss*cell;
 }
}
double FlameField::fuel_balance_error()const{return injected_-escaped_-burned_*molar_kg_-std::accumulate(fuel_.begin(),fuel_.end(),0.0)*cell;}
double FlameField::energy_balance_error()const{return burned_*molar_kg_*lhv_kg_-heat_out_-std::accumulate(heat_.begin(),heat_.end(),0.0)*cell;}
double FlameField::temperature(int i)const{
 const double density=std::max(0.05,inert_[i]+oxygen_[i]+fuel_[i]+product_[i]);
 return 298.15+heat_[i]/(heat_capacity_*density);
}
double FlameField::peak_temperature()const{double out=298.15;for(int i=0;i<count;++i)out=std::max(out,temperature(i));return out;}
double FlameField::max_speed()const{double out=0;for(int i=0;i<count;++i)out=std::max(out,std::sqrt(u_[i]*u_[i]+v_[i]*v_[i]+w_[i]*w_[i]));return out;}
std::vector<uint8_t> FlameField::atlas()const{
 // 16 z slices laid out as a 4x4 atlas. RG encodes normalized temperature,
 // B reaction product; shader uses the solved scalar field, not a noise texture.
 std::vector<uint8_t> bytes(nx*4*ny*4*4,0);
 for(int z=0;z<nz;++z)for(int y=0;y<ny;++y)for(int x=0;x<nx;++x){int i=at(x,y,z),pixel=((z/4*ny+y)*nx*4+z%4*nx+x)*4;double temp=temperature(i)-298.15;int code=int(std::clamp(temp/5000.0,0.0,1.0)*65535);bytes[pixel]=code>>8;bytes[pixel+1]=code&255;bytes[pixel+2]=uint8_t(std::clamp(product_[i],0.0,1.0)*255);bytes[pixel+3]=255;}
 return bytes;
}
std::vector<double> FlameField::save()const{
 std::vector<double>s={1.0,double(source_),double(ticks_),remainder_,injected_,burned_,escaped_,heat_out_};
 for(const auto*f:{&fuel_,&oxygen_,&heat_,&product_,&u_,&v_,&w_,&inert_})s.insert(s.end(),f->begin(),f->end());return s;
}
void FlameField::load(const std::vector<double>&s){
 if(s.size()!=8+8*count||s[0]!=1||s[1]<1||s[1]>5||std::floor(s[1])!=s[1]||s[2]<0||s[2]>86400/step||s[2]!=std::floor(s[2]))throw std::invalid_argument("三维燃烧保存格式无效");
 for(double x:s)if(!std::isfinite(x)||std::abs(x)>1e12)throw std::invalid_argument("三维燃烧保存数值无效");
 if(s[3]<-1e-9||s[3]>step||s[4]<0||s[5]<0||s[6]<-1e-9||s[7]<-1e-8)throw std::invalid_argument("三维燃烧收支无效");
 FlameField restored;restored.reset(int(s[1]));restored.ticks_=uint64_t(s[2]);restored.remainder_=s[3];restored.injected_=s[4];restored.burned_=s[5];restored.escaped_=s[6];restored.heat_out_=s[7];
 int offset=8;for(auto*f:{&restored.fuel_,&restored.oxygen_,&restored.heat_,&restored.product_,&restored.u_,&restored.v_,&restored.w_,&restored.inert_}){std::copy(s.begin()+offset,s.begin()+offset+count,f->begin());offset+=count;}
 for(int i=0;i<count;++i)if(restored.fuel_[i]<0||restored.oxygen_[i]<0||restored.product_[i]<0||restored.heat_[i]<0||restored.inert_[i]<0)throw std::invalid_argument("三维场存在负库存");
 if(std::abs(restored.fuel_balance_error())>1e-7||std::abs(restored.energy_balance_error())>0.01||restored.max_speed()>0.241)throw std::invalid_argument("三维场不满足守恒或速度范围");
 *this=std::move(restored);
}

}
