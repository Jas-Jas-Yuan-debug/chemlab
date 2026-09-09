#include "lab_core.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>
#include <chrono>
#include <cmath>

namespace godot {
namespace {
const char* database_hash="59373961d648dfbf68a40744060c1d64f57ecbec98f4f5fb89f3a1b4213ccd10";
const char* session_model="aqueous-0.2+batch-0.1+barite-0.1+physics-0.1";
chemlab::Scalars scalars(const Dictionary&d){
    if(d.size()>32)throw std::runtime_error("记录参数过多");
    chemlab::Scalars r;Array keys=d.keys();
    for(int i=0;i<keys.size();++i){
        if(keys[i].get_type()!=Variant::STRING)throw std::runtime_error("记录参数名称无效");
        String key=keys[i];Variant value=d[key];
        if((value.get_type()!=Variant::FLOAT&&value.get_type()!=Variant::INT&&value.get_type()!=Variant::BOOL)||!std::isfinite(double(value)))throw std::runtime_error("记录参数必须为有限数值");
        r[key.utf8().get_data()]=double(value);
    }
    return r;
}
Dictionary dictionary(const chemlab::Scalars&values){Dictionary d;for(auto[key,value]:values)d[String::utf8(key.c_str())]=value;return d;}
}

void LabCore::_bind_methods(){
    ClassDB::bind_method(D_METHOD("preview_bench","kind","parameters","elapsed_s","running"),&LabCore::preview_bench,DEFVAL(false));
    ClassDB::bind_method(D_METHOD("preview_fall","height_m","gravity_m_s2","elapsed_s"),&LabCore::preview_fall);
    ClassDB::bind_method(D_METHOD("save_session"),&LabCore::save_session);
    ClassDB::bind_method(D_METHOD("load_session","document"),&LabCore::load_session);
    ClassDB::bind_method(D_METHOD("configure_bench","kind","parameters"),&LabCore::configure_bench);
    ClassDB::bind_method(D_METHOD("start_bench"),&LabCore::start_bench);
    ClassDB::bind_method(D_METHOD("pause_bench"),&LabCore::pause_bench);
    ClassDB::bind_method(D_METHOD("reset_bench"),&LabCore::reset_bench);
    ClassDB::bind_method(D_METHOD("advance_bench","elapsed_s"),&LabCore::advance_bench);
    ClassDB::bind_method(D_METHOD("bench_snapshot"),&LabCore::bench_snapshot);
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
String LabCore::configure_fall(double h,double g){try{fall_.configure(h,g);return "";}catch(const std::exception&e){return String::utf8(e.what());}}
void LabCore::start_fall(){fall_.start();}
void LabCore::pause_fall(){fall_.pause();}
void LabCore::reset_fall(){fall_.reset();}
Dictionary LabCore::fall_snapshot()const{
    const auto r=fall_.reading();Dictionary d;
    d["time_s"]=r.time_s;d["height_m"]=r.height_m;d["velocity_m_s"]=r.velocity_m_s;
    d["impact_time_s"]=r.impact_time_s;d["impact_speed_m_s"]=r.impact_speed_m_s;
    d["initial_height_m"]=fall_.initial_height();d["gravity_m_s2"]=fall_.gravity();
    d["landed"]=r.landed;d["running"]=r.running;return d;
}
Dictionary LabCore::advance_fall(double elapsed){
    try{fall_.advance(elapsed);}catch(const std::exception&e){Dictionary d=fall_snapshot();d["error"]=String::utf8(e.what());return d;}
    return fall_snapshot();
}
String LabCore::configure_bench(const String&kind,const Dictionary&p){
    chemlab::Scalars values;Array keys=p.keys();
    for(int i=0;i<keys.size();++i){String key=keys[i];values[key.utf8().get_data()]=double(p[key]);}
    try{bench_.configure(kind.utf8().get_data(),values);return "";}catch(const std::exception&e){return String::utf8(e.what());}
}
void LabCore::start_bench(){bench_.start();}
void LabCore::pause_bench(){bench_.pause();}
void LabCore::reset_bench(){bench_.reset();}
Dictionary LabCore::bench_snapshot()const{
    Dictionary d;for(auto[key,value]:bench_.reading())d[String(key.c_str())]=value;
    d["kind"]=String(bench_.kind().c_str());
    Dictionary parameters;for(auto[key,value]:bench_.parameters())parameters[String(key.c_str())]=value;
    d["parameters"]=parameters;return d;
}
Dictionary LabCore::advance_bench(double elapsed){
    try{bench_.advance(elapsed);}catch(const std::exception&e){Dictionary d=bench_snapshot();d["error"]=String::utf8(e.what());return d;}
    return bench_snapshot();
}

bool LabCore::is_busy()const{return pending_.valid();}
void LabCore::initialize(const String& database){
    database_error_.clear();
    if(FileAccess::get_sha256(database)!=database_hash)database_error_="数据库版本或校验值不匹配，无法开始实验";
    const PackedByteArray bytes=FileAccess::get_file_as_bytes(database);
    if(bytes.is_empty())database_.clear();else database_.assign(reinterpret_cast<const char*>(bytes.ptr()),bytes.size());
    if(database_.empty())database_error_="无法读取化学数据库";
    reset_lab();
}
bool LabCore::start(const std::function<void(chemlab::Chemistry&,Result&)>& job){
    if(is_busy()||(database_.empty()&&database_error_.empty()))return false;
    const auto previous=session_;
    const auto database_error=database_error_;
    const auto database=database_;
    const auto gen=generation_;
    pending_=std::async(std::launch::async,[previous,database_error,database,gen,job]{
        Result result;result.session=previous;result.generation=gen;
        const auto begin=std::chrono::steady_clock::now();
        try{if(!database_error.empty())throw std::runtime_error(database_error);chemlab::Chemistry solver(database,true);job(solver,result);}
        catch(const std::exception&e){result.error=e.what();result.session=previous;}
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
        r.session.reset(solver);
        r.operation="reset";
    });
}

bool LabCore::submit(const chemlab::Command&command){
    return start([command](chemlab::Chemistry&solver,Result&r){
        r.operation=command.operation;const auto e=r.session.apply(solver,command);
        r.from=e.from;r.to=e.to;r.transferred_ml=e.transferred_ml;
    });
}
bool LabCore::prepare(int id,int reagent,double concentration,double volume,double capacity){
    return submit({"prepare",{{"id",double(id)},{"reagent",double(reagent)},{"concentration",concentration},{"volume_ml",volume},{"capacity_ml",capacity}}});
}
bool LabCore::pour(int from,int to,double amount){return submit({"pour",{{"from",double(from)},{"to",double(to)},{"amount_ml",amount}}});}
bool LabCore::add_empty(int id,double capacity){return submit({"add_empty",{{"id",double(id)},{"capacity_ml",capacity}}});}
bool LabCore::run_batch(const Dictionary&p){
    try{return submit({"batch",scalars(p)});}catch(const std::exception&e){const std::string error=e.what();return start([error](chemlab::Chemistry&,Result&r){r.operation="batch";throw std::runtime_error(error);});}
}
bool LabCore::extract_batch(int to){return submit({"extract_batch",{{"to",double(to)}}});}

Dictionary LabCore::preview_bench(const String&kind,const Dictionary&p,double elapsed,bool running)const{
    try{chemlab::PhysicsExperiment model;model.configure(kind.utf8().get_data(),scalars(p));model.restore(elapsed);if(running)model.start();Dictionary r=dictionary(model.reading());r["parameters"]=dictionary(model.parameters());r["kind"]=kind;return r;}
    catch(const std::exception&e){Dictionary r;r["error"]=String::utf8(e.what());return r;}
}
Dictionary LabCore::preview_fall(double height,double gravity,double elapsed)const{
    try{chemlab::FreeFall model;model.configure(height,gravity);model.restore(elapsed,std::abs(elapsed-model.reading().impact_time_s)<1e-8);const auto r=model.reading();Dictionary d;d["time_s"]=r.time_s;d["height_m"]=r.height_m;d["velocity_m_s"]=r.velocity_m_s;d["impact_time_s"]=r.impact_time_s;d["impact_speed_m_s"]=r.impact_speed_m_s;d["initial_height_m"]=height;d["gravity_m_s2"]=gravity;d["landed"]=r.landed;d["running"]=false;return d;}
    catch(const std::exception&e){Dictionary r;r["error"]=String::utf8(e.what());return r;}
}
Dictionary LabCore::save_session()const{
    Dictionary d;d["schema_version"]=1;d["model_version"]=session_model;d["database_sha256"]=database_hash;d["iphreeqc_version"]="3.8.6-17100";
    Array commands,events;
    for(const auto&c:session_.journal){Dictionary item;item["operation"]=String(c.operation.c_str());item["parameters"]=dictionary(c.parameters);commands.push_back(item);}
    for(const auto&e:session_.events){Dictionary item;item["operation"]=String(e.operation.c_str());item["from"]=e.from;item["to"]=e.to;item["transferred_ml"]=e.transferred_ml;item["readings"]=dictionary(e.readings);events.push_back(item);}
    d["commands"]=commands;d["events"]=events;d["fall"]=fall_snapshot();d["bench"]=bench_snapshot();return d;
}
String LabCore::load_session(const Dictionary&d){
    if(is_busy())return String::utf8("请等待当前操作完成后再加载");
    try{
        if(int(d.get("schema_version",0))!=1||String(d.get("model_version",""))!=session_model||String(d.get("database_sha256",""))!=database_hash||String(d.get("iphreeqc_version",""))!="3.8.6-17100")throw std::runtime_error("保存文件的模型或数据库版本不兼容");
        if(!d.has("commands")||d["commands"].get_type()!=Variant::ARRAY||!d.has("fall")||d["fall"].get_type()!=Variant::DICTIONARY||!d.has("bench")||d["bench"].get_type()!=Variant::DICTIONARY)throw std::runtime_error("保存文件缺少必要状态");
        Array input=d["commands"];if(input.size()>5000)throw std::runtime_error("保存文件操作数量超出范围");
        std::vector<chemlab::Command> commands;
        for(int i=0;i<input.size();++i){
            if(input[i].get_type()!=Variant::DICTIONARY)throw std::runtime_error("操作记录格式无效");
            Dictionary item=input[i];
            if(!item.has("operation")||item["operation"].get_type()!=Variant::STRING||!item.has("parameters")||item["parameters"].get_type()!=Variant::DICTIONARY)throw std::runtime_error("操作记录缺少必要字段");
            String op=item["operation"];commands.push_back({op.utf8().get_data(),scalars(item["parameters"])});
        }
        Dictionary f=d["fall"],b=d["bench"];
        if(!f.has("initial_height_m")||!f.has("gravity_m_s2")||!f.has("time_s")||!f.has("landed")||!b.has("kind")||!b.has("parameters")||b["parameters"].get_type()!=Variant::DICTIONARY||!b.has("time_s"))throw std::runtime_error("保存文件的物理状态不完整");
        chemlab::Scalars fv=scalars(f);chemlab::FreeFall fall;fall.configure(fv.at("initial_height_m"),fv.at("gravity_m_s2"));fall.restore(fv.at("time_s"),fv.at("landed")!=0);
        if(b["kind"].get_type()!=Variant::STRING||(b["time_s"].get_type()!=Variant::FLOAT&&b["time_s"].get_type()!=Variant::INT))throw std::runtime_error("物理实验类型或时间格式无效");
        chemlab::PhysicsExperiment bench;String kind=b["kind"];bench.configure(kind.utf8().get_data(),scalars(b["parameters"]));bench.restore(b["time_s"]);
        bool started=start([commands,fall,bench](chemlab::Chemistry&solver,Result&r){
            r.operation="load";chemlab::LabSession restored;restored.reset(solver);
            for(const auto&c:commands)restored.apply(solver,c);
            r.session=std::move(restored);r.restored_fall=fall;r.restored_bench=bench;
        });
        if(!started)throw std::runtime_error("无法开始加载");
        return "";
    }catch(const std::exception&e){return String::utf8(e.what());}
}
Dictionary LabCore::batch_snapshot()const{
    Dictionary d;if(!session_.batch)return d;
    const auto&r=*session_.batch;const auto&s=r.solution;
    d["mineral"]=String(r.mineral.c_str());
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
    for(const auto&[id,v]:session_.vessels){
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
        result["ready"]=true;result["error"]=String::utf8(completed.error.c_str());
        if(completed.error.empty()){session_=std::move(completed.session);if(completed.restored_fall)fall_=*completed.restored_fall;if(completed.restored_bench)bench_=*completed.restored_bench;++revision_;}
        result["state"]=snapshot();result["operation"]=String(completed.operation.c_str());
        result["from"]=completed.from;result["to"]=completed.to;
        result["transferred_ml"]=completed.transferred_ml;result["compute_ms"]=completed.compute_ms;
    }
    if(reset_queued_)reset_lab();
    return result;
}
}
