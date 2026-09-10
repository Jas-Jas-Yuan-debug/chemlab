#include "lab_core.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/variant/array.hpp>
#include <chrono>
#include <cmath>

namespace godot {
namespace {
const char* database_hash="59373961d648dfbf68a40744060c1d64f57ecbec98f4f5fb89f3a1b4213ccd10";
const char* pitzer_hash="06ab2debc0cdb333598118df953165499c2f762a79de5f2df55dec6b78b02589";
const char* session_model="aqueous-0.3+kinetics-0.1+batch-0.1+barite-0.1+physics-0.3+combustion-0.1";
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
std::vector<chemlab::Scalars> heater_controls(const Array& input){
    if(input.size()>512)throw std::runtime_error("加热控制记录过多");
    std::vector<chemlab::Scalars> result;
    for(int i=0;i<input.size();++i){if(input[i].get_type()!=Variant::DICTIONARY)throw std::runtime_error("加热控制记录格式无效");result.push_back(scalars(input[i]));}
    return result;
}
}

void LabCore::_bind_methods(){
    ClassDB::bind_method(D_METHOD("advance_kinetics","seconds","exchange_ml_s"),&LabCore::advance_kinetics);
    ClassDB::bind_method(D_METHOD("kinetics_snapshot"),&LabCore::kinetics_snapshot);
    ClassDB::bind_method(D_METHOD("set_flame_enabled","enabled"),&LabCore::set_flame_enabled);
    ClassDB::bind_method(D_METHOD("advance_flame","elapsed_s","wind_m_s"),&LabCore::advance_flame);
    ClassDB::bind_method(D_METHOD("flame_snapshot"),&LabCore::flame_snapshot);
    ClassDB::bind_method(D_METHOD("preview_bench","kind","parameters","elapsed_s","running","heater_controls"),&LabCore::preview_bench,DEFVAL(false),DEFVAL(Array()));
    ClassDB::bind_method(D_METHOD("preview_fall","height_m","gravity_m_s2","elapsed_s"),&LabCore::preview_fall);
    ClassDB::bind_method(D_METHOD("save_session"),&LabCore::save_session);
    ClassDB::bind_method(D_METHOD("load_session","document"),&LabCore::load_session);
    ClassDB::bind_method(D_METHOD("configure_bench","kind","parameters"),&LabCore::configure_bench);
    ClassDB::bind_method(D_METHOD("control_heater","control"),&LabCore::control_heater);
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
    try{bench_.configure(kind.utf8().get_data(),values);flame_.reset();return "";}catch(const std::exception&e){return String::utf8(e.what());}
}
String LabCore::set_flame_enabled(bool enabled){
    if(!enabled){flame_.reset();return "";}
    if(bench_.kind()!="heater"||bench_.reading().at("source")==0)return String::utf8("请先选择燃烧器材");
    try{if(!flame_){chemlab::FlameField f;f.reset(int(bench_.reading().at("source")));flame_=std::move(f);}return "";}catch(const std::exception&e){return String::utf8(e.what());}
}
Dictionary LabCore::flame_snapshot()const{
    Dictionary r;r["enabled"]=bool(flame_);if(!flame_)return r;
    r["time_s"]=flame_->time();r["peak_temperature_k"]=flame_->peak_temperature();r["burned_mol"]=flame_->burned_mol();r["fuel_residual_kg"]=flame_->fuel_balance_error();r["energy_residual_j"]=flame_->energy_balance_error();r["max_speed_m_s"]=flame_->max_speed();r["source"]=flame_->source();
    const auto bytes=flame_->atlas();PackedByteArray atlas;atlas.resize(bytes.size());std::copy(bytes.begin(),bytes.end(),atlas.ptrw());r["atlas"]=atlas;return r;
}
Dictionary LabCore::advance_flame(double elapsed,double wind){
    if(!flame_)return flame_snapshot();
    try{if(bench_.kind()!="heater"){flame_.reset();return flame_snapshot();}auto r=bench_.reading();int source=int(r.at("source"));if(source==0){flame_.reset();return flame_snapshot();}if(source!=flame_->source())flame_->reset(source);if(r.at("running")>0)flame_->advance(elapsed,r.at("fuel_flow_mol_s"),wind);return flame_snapshot();}
    catch(const std::exception&e){Dictionary d=flame_snapshot();d["error"]=String::utf8(e.what());return d;}
}
void LabCore::start_bench(){bench_.start();}
String LabCore::control_heater(const Dictionary&p){try{bench_.control_heater(scalars(p));if(flame_){const int source=int(bench_.reading().at("source"));if(source==0)flame_.reset();else if(source!=flame_->source())flame_->reset(source);}return "";}catch(const std::exception&e){return String::utf8(e.what());}}
void LabCore::pause_bench(){bench_.pause();}
void LabCore::reset_bench(){bench_.reset();flame_.reset();}
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
    const String pitzer_path="res://data/pitzer.dat";
    if(FileAccess::get_sha256(pitzer_path)!=pitzer_hash)database_error_="Pitzer 数据库校验失败";
    const PackedByteArray pitzer_bytes=FileAccess::get_file_as_bytes(pitzer_path);
    if(pitzer_bytes.is_empty())pitzer_database_.clear();else pitzer_database_.assign(reinterpret_cast<const char*>(pitzer_bytes.ptr()),pitzer_bytes.size());
    reset_lab();
}
bool LabCore::start(const std::function<void(chemlab::Chemistry&,Result&)>& job){
    if(is_busy()||(database_.empty()&&database_error_.empty()))return false;
    const auto previous=session_;
    const auto database_error=database_error_;
    const auto database=database_;
    const auto pitzer_database=pitzer_database_;
    const auto gen=generation_;
    pending_=std::async(std::launch::async,[previous,database_error,database,pitzer_database,gen,job]{
        Result result;result.session=previous;result.generation=gen;
        const auto begin=std::chrono::steady_clock::now();
        try{if(!database_error.empty())throw std::runtime_error(database_error);chemlab::Chemistry solver(database,true,pitzer_database);job(solver,result);}
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

Dictionary LabCore::preview_bench(const String&kind,const Dictionary&p,double elapsed,bool running,const Array& controls)const{
    try{chemlab::PhysicsExperiment model;model.configure(kind.utf8().get_data(),scalars(p));if(kind=="heater")model.restore_heater_controls(heater_controls(controls));model.restore(elapsed);if(running)model.start();Dictionary r=dictionary(model.reading());r["parameters"]=dictionary(model.parameters());r["kind"]=kind;return r;}
    catch(const std::exception&e){Dictionary r;r["error"]=String::utf8(e.what());return r;}
}
Dictionary LabCore::preview_fall(double height,double gravity,double elapsed)const{
    try{chemlab::FreeFall model;model.configure(height,gravity);model.restore(elapsed,std::abs(elapsed-model.reading().impact_time_s)<1e-8);const auto r=model.reading();Dictionary d;d["time_s"]=r.time_s;d["height_m"]=r.height_m;d["velocity_m_s"]=r.velocity_m_s;d["impact_time_s"]=r.impact_time_s;d["impact_speed_m_s"]=r.impact_speed_m_s;d["initial_height_m"]=height;d["gravity_m_s2"]=gravity;d["landed"]=r.landed;d["running"]=false;return d;}
    catch(const std::exception&e){Dictionary r;r["error"]=String::utf8(e.what());return r;}
}
Dictionary LabCore::save_session()const{
    Dictionary d;d["schema_version"]=1;d["model_version"]=session_model;d["database_sha256"]=database_hash;d["pitzer_sha256"]=pitzer_hash;d["iphreeqc_version"]="3.8.6-17100";
    Array commands,events;
    for(const auto&c:session_.journal){Dictionary item;item["operation"]=String(c.operation.c_str());item["parameters"]=dictionary(c.parameters);commands.push_back(item);}
    for(const auto&e:session_.events){Dictionary item;item["operation"]=String(e.operation.c_str());item["from"]=e.from;item["to"]=e.to;item["transferred_ml"]=e.transferred_ml;item["readings"]=dictionary(e.readings);events.push_back(item);}
    d["commands"]=commands;d["events"]=events;d["fall"]=fall_snapshot();Dictionary bench=bench_snapshot();
    if(bench_.kind()=="heater"){Array controls;for(const auto& c:bench_.heater_controls())controls.push_back(dictionary(c));bench["heater_controls"]=controls;}
    d["bench"]=bench;
    Dictionary kinetic_states;for(const auto&[id,k]:kinetics_){Array values;for(double v:k.save())values.push_back(v);kinetic_states[id]=values;}d["kinetics"]=kinetic_states;
    Array field;if(flame_)for(double v:flame_->save())field.push_back(v);d["flame_field"]=field;return d;
}
String LabCore::load_session(const Dictionary&d){
    if(is_busy())return String::utf8("请等待当前操作完成后再加载");
    try{
        if(int(d.get("schema_version",0))!=1||String(d.get("model_version",""))!=session_model||String(d.get("database_sha256",""))!=database_hash||String(d.get("pitzer_sha256",""))!=pitzer_hash||String(d.get("iphreeqc_version",""))!="3.8.6-17100")throw std::runtime_error("保存文件的模型或数据库版本不兼容");
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
        if(kind=="heater"){
            if(!b.has("heater_controls")||b["heater_controls"].get_type()!=Variant::ARRAY)throw std::runtime_error("缺少加热控制历史");
            const auto controls=heater_controls(b["heater_controls"]);bench.restore_heater_controls(controls);
            if(controls.back().at("time_s")>double(b["time_s"])+1e-8)throw std::runtime_error("加热控制记录超过实验时间");
        }
        std::optional<chemlab::FlameField> flame;
        if(d.has("flame_field")){if(d["flame_field"].get_type()!=Variant::ARRAY)throw std::runtime_error("三维场记录无效");Array values=d["flame_field"];if(values.size()>60000)throw std::runtime_error("三维场记录过大");
            if(values.size()){std::vector<double> saved;for(int i=0;i<values.size();++i){if(values[i].get_type()!=Variant::FLOAT&&values[i].get_type()!=Variant::INT)throw std::runtime_error("三维场数值无效");saved.push_back(double(values[i]));}chemlab::FlameField field;field.load(saved);if(kind!="heater"||field.source()!=int(bench.reading().at("source")))throw std::runtime_error("三维场与燃烧源不匹配");flame=std::move(field);}}
        std::map<int,chemlab::NeutralizationKinetics> kinetics;
        if(d.has("kinetics")){
            if(d["kinetics"].get_type()!=Variant::DICTIONARY)throw std::runtime_error("动力学记录无效");
            Dictionary states=d["kinetics"];if(states.size()>12)throw std::runtime_error("动力学器材过多");
            Array ids=states.keys();for(int i=0;i<ids.size();++i){
                String text_id=String(ids[i]);if(!text_id.is_valid_int())throw std::runtime_error("动力学编号无效");const int id=text_id.to_int();
                if(id<1||id>12||states[ids[i]].get_type()!=Variant::ARRAY)throw std::runtime_error("动力学器材无效");
                Array values=states[ids[i]];std::vector<double> saved;
                for(int j=0;j<values.size();++j){if(values[j].get_type()!=Variant::FLOAT&&values[j].get_type()!=Variant::INT)throw std::runtime_error("动力学数值无效");saved.push_back(double(values[j]));}
                chemlab::NeutralizationKinetics k;k.load(saved);kinetics[id]=k;
            }
        }
        bool started=start([commands,fall,bench,flame,kinetics](chemlab::Chemistry&solver,Result&r){
            r.operation="load";chemlab::LabSession restored;restored.reset(solver);
            for(const auto&c:commands)restored.apply(solver,c);
            for(const auto&[id,k]:kinetics){
                if(!restored.vessels.count(id)||!chemlab::NeutralizationKinetics::supports(restored.vessels.at(id).solution))throw std::runtime_error("动力学与化学体系不匹配");
                const auto&s=restored.vessels.at(id).solution;
                chemlab::NeutralizationKinetics equilibrium;equilibrium.initialize(s);
                if(std::abs(k.volume()-s.volume_l)>1e-9||std::abs(k.h_total()-k.oh_total()-equilibrium.h_total()+equilibrium.oh_total())>1e-9)throw std::runtime_error("动力学库存与化学记录不匹配");
                if(!s.empty()&&(std::abs(k.save()[1]/equilibrium.save()[1]-1)>1e-7||std::abs(k.save()[2]/equilibrium.save()[2]-1)>1e-7))throw std::runtime_error("动力学活度参数与科学模型不匹配");
            }
            for(const auto&[id,v]:restored.vessels)if(chemlab::NeutralizationKinetics::supports(v.solution)&&!kinetics.count(id))throw std::runtime_error("缺少动力学容器状态");
            r.restored_kinetics=kinetics;
            r.session=std::move(restored);r.restored_fall=fall;r.restored_bench=bench;r.restored_flame=flame;
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

void LabCore::update_kinetics(const Result&r){
    using K=chemlab::NeutralizationKinetics;
    if(r.operation=="load"){kinetics_=r.restored_kinetics;return;}
    if(r.operation=="reset"){
        kinetics_.clear();for(const auto&[id,v]:r.session.vessels)if(K::supports(v.solution))kinetics_[id].initialize(v.solution);return;
    }
    if(r.operation=="pour"&&r.transferred_ml>0){
        const auto& target=r.session.vessels.at(r.to).solution;
        if(kinetics_.count(r.from)){
            const double f=r.transferred_ml/1000/session_.vessels.at(r.from).solution.volume_l;
            auto aliquot=kinetics_.at(r.from).withdraw(std::clamp(f,0.,1.));
            if(K::supports(target)&&kinetics_.count(r.to))kinetics_.at(r.to).add(aliquot,target);
            else kinetics_.erase(r.to);
        }else kinetics_.erase(r.to);
    }else if(r.to&&r.operation!="pour"){
        const auto&s=r.session.vessels.at(r.to).solution;
        if(K::supports(s))kinetics_[r.to].initialize(s);else kinetics_.erase(r.to);
    }
}
Dictionary LabCore::kinetics_snapshot()const{
    Dictionary all;
    for(const auto&[id,k]:kinetics_){
        Dictionary r;r["volume_ml"]=k.volume()*1000;r["ph"]=k.volume()>1e-12?Variant(k.ph()):Variant();
        r["upper_ph"]=k.volume()>1e-12?Variant(k.ph(0)):Variant();r["rate_mol_s"]=k.rate();r["reacted_mol"]=k.reacted();
        r["time_s"]=k.time();r["equivalent_error_mol"]=k.equivalent_error();r["heterogeneity"]=k.mixing_fraction();
        r["dilute_rate_constant"]=k.dilute_rate();r["k_l_mol_s"]=chemlab::NeutralizationKinetics::recombination_k;
        all[id]=r;
    }return all;
}
Dictionary LabCore::advance_kinetics(double elapsed,double exchange){
    if(is_busy())return kinetics_snapshot();
    try{for(auto&[id,k]:kinetics_)k.advance(elapsed,exchange);return kinetics_snapshot();}
    catch(const std::exception&e){Dictionary d;d["error"]=String::utf8(e.what());return d;}
}

Dictionary LabCore::snapshot()const{
    Dictionary result;Array items;
    for(const auto&[id,v]:session_.vessels){
        Dictionary d;d["id"]=id;d["capacity_ml"]=v.capacity_l*1000;
        const auto&s=v.solution;
        d["volume_ml"]=s.volume_l*1000;d["ph"]=s.empty()?Variant():Variant(s.ph);
        // Atomic masses are those of the pinned PHREEQC database, retaining
        // solvent H/O and every supported solute element in the balance reading.
        double mass=s.hydrogen_mol*1.008+s.oxygen_mol*16.0;
        const std::map<std::string,double> weights={{"Na",22.9898},{"Cl",35.453},{"K",39.102},{"Ca",40.08},{"Mg",24.312},{"C",12.0111},{"S",32.064},{"N",14.0067},{"Ba",137.34},{"Fe",55.847},{"Cu",63.546}};
        for(const auto&[element,n]:s.elements)mass+=n*weights.at(element);
        d["sample_mass_g"]=mass;
        d["activity_model"]=s.pitzer?"Pitzer":"ion association";
        d["h_molar"]=s.h_molar;d["oh_molar"]=s.oh_molar;d["gamma_h"]=s.gamma_h;d["ionic_strength"]=s.ionic_strength;
        d["water_kg"]=s.water_kg;d["hydrogen_mol"]=s.hydrogen_mol;d["oxygen_mol"]=s.oxygen_mol;
        d["temperature_c"]=25.0;d["charge_eq"]=s.charge_eq;
        Dictionary elements;for(const auto&[e,n]:s.elements)elements[String(e.c_str())]=n;
        Dictionary ingredients;for(const auto&[i,n]:s.ingredients_mol)ingredients[i]=n;
        d["elements_mol"]=elements;d["ingredients_mol"]=ingredients;items.push_back(d);
    }
    result["vessels"]=items;result["revision"]=static_cast<int64_t>(revision_);
    result["model_version"]=session_model;result["temperature_c"]=25.0;
    return result;
}
Dictionary LabCore::poll(){
    Dictionary result;result["ready"]=false;
    if(!pending_.valid()||pending_.wait_for(std::chrono::seconds(0))!=std::future_status::ready)return result;
    auto completed=pending_.get();
    if(completed.generation==generation_){
        result["ready"]=true;result["error"]=String::utf8(completed.error.c_str());
        if(completed.error.empty()){update_kinetics(completed);session_=std::move(completed.session);if(completed.restored_fall)fall_=*completed.restored_fall;if(completed.restored_bench)bench_=*completed.restored_bench;if(completed.operation=="load")flame_=std::move(completed.restored_flame);++revision_;}
        result["state"]=snapshot();result["operation"]=String(completed.operation.c_str());
        result["from"]=completed.from;result["to"]=completed.to;
        result["transferred_ml"]=completed.transferred_ml;result["compute_ms"]=completed.compute_ms;
    }
    if(reset_queued_)reset_lab();
    return result;
}
}
