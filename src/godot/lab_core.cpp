#include "lab_core.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/array.hpp>
#include <chrono>
#include <cmath>

namespace godot {
void LabCore::_bind_methods(){
    ClassDB::bind_method(D_METHOD("run_batch","parameters"),&LabCore::run_batch);
    ClassDB::bind_method(D_METHOD("extract_batch","vessel_id"),&LabCore::extract_batch);
    ClassDB::bind_method(D_METHOD("batch_snapshot"),&LabCore::batch_snapshot);
    ClassDB::bind_method(D_METHOD("initialize","database"),&LabCore::initialize);
    ClassDB::bind_method(D_METHOD("reset_lab"),&LabCore::reset_lab);
    ClassDB::bind_method(D_METHOD("prepare","vessel_id","reagent","concentration","volume_ml","capacity_ml"),&LabCore::prepare);
    ClassDB::bind_method(D_METHOD("add_empty","vessel_id","capacity_ml"),&LabCore::add_empty);
    ClassDB::bind_method(D_METHOD("pour","source","target","amount_ml"),&LabCore::pour);
    ClassDB::bind_method(D_METHOD("is_busy"),&LabCore::is_busy);
    ClassDB::bind_method(D_METHOD("poll"),&LabCore::poll);
    ClassDB::bind_method(D_METHOD("snapshot"),&LabCore::snapshot);
    ClassDB::bind_method(D_METHOD("configure_fall","height_m","gravity_m_s2"),&LabCore::configure_fall);
    ClassDB::bind_method(D_METHOD("start_fall"),&LabCore::start_fall);
    ClassDB::bind_method(D_METHOD("pause_fall"),&LabCore::pause_fall);
    ClassDB::bind_method(D_METHOD("reset_fall"),&LabCore::reset_fall);
    ClassDB::bind_method(D_METHOD("advance_fall","elapsed_s"),&LabCore::advance_fall);
    ClassDB::bind_method(D_METHOD("fall_snapshot"),&LabCore::fall_snapshot);
}
LabCore::~LabCore(){if(pending_.valid())pending_.wait();}
String LabCore::configure_fall(double h,double g){try{fall_.configure(h,g);return "";}catch(const std::exception&e){return String(e.what());}}
void LabCore::start_fall(){fall_.start();}
void LabCore::pause_fall(){fall_.pause();}
void LabCore::reset_fall(){fall_.reset();}
Dictionary LabCore::fall_snapshot()const{
    const auto r=fall_.reading();Dictionary d;
    d["time_s"]=r.time_s;d["height_m"]=r.height_m;d["velocity_m_s"]=r.velocity_m_s;
    d["impact_time_s"]=r.impact_time_s;d["impact_speed_m_s"]=r.impact_speed_m_s;
    d["landed"]=r.landed;d["running"]=r.running;return d;
}
Dictionary LabCore::advance_fall(double elapsed){
    try{fall_.advance(elapsed);}catch(const std::exception&e){Dictionary d=fall_snapshot();d["error"]=String(e.what());return d;}
    return fall_snapshot();
}
bool LabCore::is_busy()const{return pending_.valid();}
void LabCore::initialize(const String& database){database_=database.utf8().get_data();reset_lab();}
bool LabCore::start(const std::function<void(chemlab::Chemistry&,Result&)>& job){
    if(is_busy()||database_.empty())return false;
    const auto previous=vessels_;
    const auto batch=batch_;
    const auto database=database_;
    const auto gen=generation_;
    pending_=std::async(std::launch::async,[previous,batch,database,gen,job]{
        Result result;result.vessels=previous;result.generation=gen;result.batch=batch;
        const auto begin=std::chrono::steady_clock::now();
        try{chemlab::Chemistry solver(database);job(solver,result);}
        catch(const std::exception&e){result.error=e.what();result.vessels=previous;result.batch=batch;}
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
        r.batch.reset();
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
bool LabCore::run_batch(const Dictionary&p){
    const int reagent=p.get("base_reagent",1), solid=p.get("solid_reagent",18), boundary=p.get("gas_boundary",0);
    const double concentration=p.get("concentration",0.001),volume=p.get("volume_ml",100.0);
    chemlab::BatchConditions c;c.solid_reagent=solid;c.solid_mol=double(p.get("solid_mmol",2.0))/1000;
    c.co2_added_mol=double(p.get("co2_mmol",0.0))/1000;c.headspace_l=double(p.get("headspace_ml",100.0))/1000;
    c.external_co2_atm=p.get("external_co2_atm",0.00042);c.gas=static_cast<chemlab::GasBoundary>(boundary);
    return start([=](chemlab::Chemistry&solver,Result&r){
        r.operation="batch";
        if(boundary<0||boundary>2)throw std::runtime_error("气相边界无效");
        auto base=solver.prepare(reagent,reagent==1?0:concentration,volume/1000);
        r.batch=solver.equilibrate(base,c);r.operation="batch";
    });
}
bool LabCore::extract_batch(int to){
    return start([=](chemlab::Chemistry&,Result&r){
        r.operation="extract_batch";
        if(!r.batch||r.batch->solution.empty())throw std::runtime_error("反应器中没有可分离的液体");
        if(to<1||to>12||r.vessels.count(to))throw std::runtime_error("需要一个新的接收容器");
        // Separate all liquid from the retained solid/headspace. This ends the
        // equilibrium trial; later air exchange/reequilibration is not implied.
        const auto solution=r.batch->solution;
        if(solution.volume_l>0.250)throw std::runtime_error("液体超过接收烧杯的 250 mL 容量");
        r.vessels[to]={to,0.25,solution};r.batch->solution={};
        r.operation="extract_batch";r.to=to;r.transferred_ml=solution.volume_l*1000;
    });
}
Dictionary LabCore::batch_snapshot()const{
    Dictionary d;if(!batch_)return d;
    const auto&r=*batch_;const auto&s=r.solution;
    d["volume_ml"]=s.volume_l*1000;d["ph"]=s.empty()?Variant():Variant(s.ph);
    d["solid_remaining_mmol"]=r.solid_remaining_mol*1000;
    d["gas_co2_mmol"]=r.gas_co2_mol*1000;d["gas_pressure_atm"]=r.gas_pressure_atm;
    d["co2_to_environment_mmol"]=r.co2_to_environment_mol*1000;
    d["solid_si"]=r.solid_saturation_index;
    d["carbon_residual_mol"]=r.carbon_residual_mol;d["calcium_residual_mol"]=r.calcium_residual_mol;d["sulfur_residual_mol"]=r.sulfur_residual_mol;
    Dictionary elements;for(const auto&[e,n]:s.elements)elements[String(e.c_str())]=n;
    d["elements_mol"]=elements;return d;
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
    result["model_version"]="aqueous-0.2+batch-0.1";result["temperature_c"]=25.0;
    return result;
}
Dictionary LabCore::poll(){
    Dictionary result;result["ready"]=false;
    if(!pending_.valid()||pending_.wait_for(std::chrono::seconds(0))!=std::future_status::ready)return result;
    auto completed=pending_.get();
    if(completed.generation==generation_){
        result["ready"]=true;result["error"]=String(completed.error.c_str());
        if(completed.error.empty()){vessels_=std::move(completed.vessels);batch_=std::move(completed.batch);++revision_;}
        result["state"]=snapshot();result["operation"]=String(completed.operation.c_str());
        result["from"]=completed.from;result["to"]=completed.to;
        result["transferred_ml"]=completed.transferred_ml;result["compute_ms"]=completed.compute_ms;
    }
    if(reset_queued_)reset_lab();
    return result;
}
}
