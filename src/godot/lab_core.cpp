#include "lab_core.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <chrono>
#include <cmath>

namespace godot {
void LabCore::_bind_methods(){
    ClassDB::bind_method(D_METHOD("initialize","database"),&LabCore::initialize);
    ClassDB::bind_method(D_METHOD("reset_lab"),&LabCore::reset_lab);
    ClassDB::bind_method(D_METHOD("prepare","vessel_id","reagent","concentration","volume_ml","capacity_ml"),&LabCore::prepare);
    ClassDB::bind_method(D_METHOD("add_empty","vessel_id","capacity_ml"),&LabCore::add_empty);
    ClassDB::bind_method(D_METHOD("pour","source","target","amount_ml"),&LabCore::pour);
    ClassDB::bind_method(D_METHOD("is_busy"),&LabCore::is_busy);
    ClassDB::bind_method(D_METHOD("poll"),&LabCore::poll);
    ClassDB::bind_method(D_METHOD("snapshot"),&LabCore::snapshot);
}
LabCore::~LabCore(){if(pending_.valid())pending_.wait();}
bool LabCore::is_busy()const{return pending_.valid();}
void LabCore::initialize(const String& database){database_=database.utf8().get_data();reset_lab();}
bool LabCore::start(const std::function<void(chemlab::Chemistry&,Result&)>& job){
    if(is_busy()||database_.empty())return false;
    const auto previous=vessels_;
    const auto database=database_;
    const auto gen=generation_;
    pending_=std::async(std::launch::async,[previous,database,gen,job]{
        Result result;result.vessels=previous;result.generation=gen;
        const auto begin=std::chrono::steady_clock::now();
        try{chemlab::Chemistry solver(database);job(solver,result);}
        catch(const std::exception&e){result.error=e.what();result.vessels=previous;}
        result.compute_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-begin).count();
        return result;
    });
    return true;
}
bool LabCore::reset_lab(){
    ++generation_;
    if(is_busy()){reset_queued_=true;return true;}
    reset_queued_=false;
    return start([](chemlab::Chemistry& solver,Result&r){
        r.vessels.clear();
        r.vessels[1]={1,0.25,solver.prepare(2,0.001,0.05)};
        r.vessels[2]={2,0.25,solver.prepare(3,0.001,0.05)};
        r.vessels[3]={3,0.25,{}};
        r.vessels[4]={4,0.25,solver.prepare(1,0,0.10)};
        r.operation="reset";
    });
}
bool LabCore::prepare(int id,int reagent,double concentration,double volume_ml,double capacity_ml){
    return start([=](chemlab::Chemistry&solver,Result&r){
        if(id<1||id>12||!std::isfinite(capacity_ml)||capacity_ml<volume_ml||capacity_ml>1000)
            throw std::runtime_error("容器或容量参数不正确");
        r.vessels[id]={id,capacity_ml/1000.0,solver.prepare(reagent,concentration,volume_ml/1000.0)};
        r.operation="prepare";r.to=id;
    });
}
bool LabCore::pour(int from,int to,double amount_ml){
    return start([=](chemlab::Chemistry&solver,Result&r){
        const auto a=r.vessels.find(from),b=r.vessels.find(to);
        if(a==r.vessels.end()||b==r.vessels.end())throw std::runtime_error("请先选择两个有效容器");
        const auto t=chemlab::transfer(solver,a->second,b->second,amount_ml/1000.0);
        r.vessels[from]=t.source;r.vessels[to]=t.target;r.transferred_ml=t.transferred_l*1000;
        r.operation="pour";r.from=from;r.to=to;
    });
}
bool LabCore::add_empty(int id,double capacity_ml){
    return start([=](chemlab::Chemistry&,Result&r){
        if(id<1||id>12||r.vessels.count(id)||!std::isfinite(capacity_ml)||capacity_ml<1||capacity_ml>1000)
            throw std::runtime_error("无法添加此器材：已存在或容量无效");
        r.vessels[id]={id,capacity_ml/1000.0,{}};r.operation="add_empty";r.to=id;
    });
}
Dictionary LabCore::snapshot()const{
    Dictionary result;Array items;
    for(const auto&[id,v]:vessels_){
        Dictionary d;d["id"]=id;d["capacity_ml"]=v.capacity_l*1000;
        const auto&s=v.solution;
        d["volume_ml"]=s.volume_l*1000;d["ph"]=s.empty()?Variant():Variant(s.ph);
        d["water_kg"]=s.water_kg;d["hydrogen_mol"]=s.hydrogen_mol;d["oxygen_mol"]=s.oxygen_mol;
        d["temperature_c"]=25.0;d["charge_eq"]=s.charge_eq;
        Dictionary elements;for(const auto&[e,n]:s.elements)elements[String(e.c_str())]=n;
        Dictionary ingredients;for(const auto&[i,n]:s.ingredients_mol)ingredients[i]=n;
        d["elements_mol"]=elements;d["ingredients_mol"]=ingredients;items.push_back(d);
    }
    result["vessels"]=items;result["revision"]=static_cast<int64_t>(revision_);
    result["model_version"]="aqueous-0.1";result["temperature_c"]=25.0;
    return result;
}
Dictionary LabCore::poll(){
    Dictionary result;result["ready"]=false;
    if(!pending_.valid()||pending_.wait_for(std::chrono::seconds(0))!=std::future_status::ready)return result;
    auto completed=pending_.get();
    if(completed.generation==generation_){
        result["ready"]=true;result["error"]=String(completed.error.c_str());
        if(completed.error.empty()){vessels_=std::move(completed.vessels);++revision_;}
        result["state"]=snapshot();result["operation"]=String(completed.operation.c_str());
        result["from"]=completed.from;result["to"]=completed.to;
        result["transferred_ml"]=completed.transferred_ml;result["compute_ms"]=completed.compute_ms;
    }
    if(reset_queued_)reset_lab();
    return result;
}
}
