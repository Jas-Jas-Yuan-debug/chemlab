#include "session.hpp"
#include <cmath>
#include <set>
#include <stdexcept>
namespace chemlab {
namespace {
void require(bool ok,const char*msg){if(!ok)throw std::runtime_error(msg);}
Scalars measurements(const Solution&s){
 Scalars r={{"volume_ml",s.volume_l*1000},{"temperature_c",25},{"water_kg",s.water_kg},{"hydrogen_mol",s.hydrogen_mol},{"oxygen_mol",s.oxygen_mol}};
 r["empirical_stock"]=s.empirical_stock?1:0;
 if(!s.empty()&&!s.empirical_stock)r["ph"]=s.ph;
 for(auto[e,n]:s.elements)r[e+"_mol"]=n;
 return r;
}
}
void LabSession::reset(Chemistry&solver){
 std::map<int,Vessel> fresh;
 fresh[1]={1,0.25,solver.prepare(2,0.001,0.05)};
 fresh[2]={2,0.25,solver.prepare(3,0.001,0.05)};
 fresh[3]={3,0.25,{}};
 fresh[4]={4,0.25,solver.prepare(1,0,0.1)};
 vessels=std::move(fresh);batch.reset();journal.clear();events.clear();
}
Event LabSession::apply(Chemistry&solver,const Command&command){
 require(journal.size()<5000,"本次实验已达 5000 条操作，请保存后重新开始");
 const auto&p=command.parameters;const auto&op=command.operation;
 const std::map<std::string,std::set<std::string>> allowed={
  {"prepare",{"id","reagent","concentration","volume_ml","capacity_ml"}},
  {"add_empty",{"id","capacity_ml"}}, {"pour",{"from","to","amount_ml"}},
  {"extract_batch",{"to"}},
  {"batch",{"barite","sulfate_concentration","sulfate_ml","base_reagent","solid_reagent","gas_boundary","concentration","volume_ml","solid_mmol","co2_mmol","headspace_ml","external_co2_atm"}}
 };
 auto supported=allowed.find(op);require(supported!=allowed.end(),"记录包含不支持的操作");
 for(auto[key,v]:p)require(supported->second.count(key)&&std::isfinite(v),"记录包含无效或未知参数");
 auto value=[&](const char*key,double fallback){auto i=p.find(key);return i==p.end()?fallback:i->second;};
 auto required=[&](const char*key){auto i=p.find(key);require(i!=p.end(),"操作记录缺少必要参数");return i->second;};
 auto integer=[&](const char*key,double fallback){double v=value(key,fallback);require(v==std::floor(v)&&v>=-10000&&v<=10000,"编号必须为有效整数");return int(v);};
 Event e;e.operation=op;
 if(op=="prepare"){
  int id=integer("id",0),reagent=integer("reagent",0);double capacity=required("capacity_ml"),volume=required("volume_ml");
  require(id>=1&&id<=12&&capacity>=volume&&capacity<=1000,"容器或容量参数不正确");
  auto s=solver.prepare(reagent,required("concentration"),volume/1000);
  vessels[id]={id,capacity/1000,s};e.to=id;
 }else if(op=="add_empty"){
  int id=integer("id",0);double capacity=required("capacity_ml");
  require(id>=1&&id<=12&&!vessels.count(id)&&capacity>=1&&capacity<=1000,"无法添加此器材：已存在或容量无效");
  vessels[id]={id,capacity/1000,{}};e.to=id;
 }else if(op=="pour"){
  int from=integer("from",0),to=integer("to",0);
  require(vessels.count(from)&&vessels.count(to),"请先选择两个有效容器");
  auto t=transfer(solver,vessels.at(from),vessels.at(to),required("amount_ml")/1000);
  vessels[from]=t.source;vessels[to]=t.target;e.from=from;e.to=to;e.transferred_ml=t.transferred_l*1000;
 }else if(op=="batch"){
  const bool barite=value("barite",0)==1;require(value("barite",0)==0||barite,"沉淀模式无效");
  const int reagent=integer("base_reagent",1),boundary=integer("gas_boundary",0);
  require(boundary>=0&&boundary<=2,"气相边界无效");
  auto base=solver.prepare(barite?25:reagent,!barite&&reagent==1?0:value("concentration",0.001),value("volume_ml",100)/1000);
  if(barite)batch=solver.precipitate_barite(base,solver.prepare(14,value("sulfate_concentration",0.001),value("sulfate_ml",50)/1000));
  else{
   BatchConditions c;c.solid_reagent=integer("solid_reagent",18);c.solid_mol=value("solid_mmol",2)/1000;
   c.gas=static_cast<GasBoundary>(boundary);c.co2_added_mol=value("co2_mmol",0)/1000;
   c.headspace_l=value("headspace_ml",100)/1000;c.external_co2_atm=value("external_co2_atm",0.00042);
   batch=solver.equilibrate(base,c);
  }
  e.readings=measurements(batch->solution);
  e.readings["solid_mmol"]=batch->solid_remaining_mol*1000;e.readings["gas_co2_mmol"]=batch->gas_co2_mol*1000;
  e.readings["gas_pressure_atm"]=batch->gas_pressure_atm;e.readings["co2_to_environment_mmol"]=batch->co2_to_environment_mol*1000;
 }else if(op=="extract_batch"){
  int to=integer("to",0);
  require(batch.has_value()&&!batch->solution.empty(),"反应器中没有可分离的液体");
  require(to>=1&&to<=12&&!vessels.count(to),"需要一个新的接收容器");
  require(batch->solution.volume_l<=0.250+1e-8,"清液超过接收烧杯的 250 mL 容量");
  vessels[to]={to,0.25,batch->solution};e.to=to;e.transferred_ml=batch->solution.volume_l*1000;
  batch->solution={};
 }
 if(e.to)e.readings=measurements(vessels.at(e.to).solution);
 journal.push_back(command);events.push_back(e);return e;
}
}
