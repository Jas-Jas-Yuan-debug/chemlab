#include "chemistry.hpp"
#include <IPhreeqc.h>
#include <phrqtype.h>
#include <Solution.h>
#include <Parser.h>
#include <algorithm>
#include <cmath>
#include <iomanip>
#include <regex>
#include <sstream>
#include <stdexcept>

namespace chemlab {
namespace {
const std::vector<std::string> element_names = {"Na","Cl","K","Ca","Mg","C","S","N","Ba","Fe","Cu"};
const std::vector<std::string> valence_names = {"N(5)","N(-3)","N(0)","S(6)","S(-2)","Fe(2)","Fe(3)","C(4)","C(-4)","Cu(1)","Cu(2)"};
void check(bool ok, const std::string& text) { if (!ok) throw std::runtime_error(text); }
std::string num(double value) { std::ostringstream s; s << std::setprecision(17) << value; return s.str(); }
std::string renamed(const Solution& s, int number) {
    check(s.raw.rfind("SOLUTION_RAW", 0) == 0, "缺少有效的溶液状态");
    return std::regex_replace(s.raw, std::regex("^SOLUTION_RAW\\s+[0-9]+"), "SOLUTION_RAW " + std::to_string(number));
}
std::string selected() {
    std::string s = "SELECTED_OUTPUT 1\n-reset false\n-high_precision true\nUSER_PUNCH 1\n-headings ph volume water charge h o";
    for (const auto& name : element_names) s += " " + name;
    for(const auto&name:valence_names)s+=" "+name;
    s += "\n-start\n10 PUNCH -LA(\"H+\"), SOLN_VOL, TOT(\"water\"), CHARGE_BALANCE, TOTMOLE(\"H\"), TOTMOLE(\"O\")\n20 PUNCH ";
    for (size_t i=0; i<element_names.size(); ++i) s += (i ? ", " : "") + std::string("TOTMOLE(\"") + element_names[i] + "\")";
    for(const auto&name:valence_names)s+=", TOTMOLE(\""+name+"\")";
    return s + "\n-end\n";
}
double value(int id, int row, int col) {
    VAR v; VarInit(&v);
    const auto result = GetSelectedOutputValue(id, row, col, &v);
    const bool valid = v.type == TT_DOUBLE || v.type == TT_LONG;
    const double x = v.type == TT_DOUBLE ? v.dVal : (v.type == TT_LONG ? v.lVal : 0);
    VarClear(&v);
    check(result == 0 && valid && std::isfinite(x), "求解结果缺失或非有限数值");
    return x;
}
void balance(double actual, double expected, double absolute, const std::string& name) {
    check(std::abs(actual-expected) <= absolute + std::abs(expected)*1e-9, name+"物质收支未通过，操作已取消");
}
Solution scaled(const Solution& original,double fraction){
    if(fraction<=0||original.empty())return {};
    Solution s=original;
    s.volume_l*=fraction;s.water_kg*=fraction;s.charge_eq*=fraction;
    s.hydrogen_mol*=fraction;s.oxygen_mol*=fraction;
    for(auto&[name,n]:s.elements)n*=fraction;
    for(auto&[name,n]:s.valence_mol)n*=fraction;
    for(auto&[id,n]:s.ingredients_mol)n*=fraction;
    // Use the pinned upstream state schema and extensive-quantity multiplier.
    // This is homogeneous sampling, so intensive state and redox stay unchanged.
    std::istringstream source(original.raw);CParser parser(source);parser.set_echo_file(CParser::EO_NONE);parser.get_line();
    cxxSolution raw;raw.read_raw(parser);
    check(parser.get_input_error()==0&&raw.Get_base_error_count()==0,"无法读取分样状态");
    raw.multiply(fraction);
    raw.Set_total_h(s.hydrogen_mol);raw.Set_total_o(s.oxygen_mol);
    raw.Set_mass_water(s.water_kg);raw.Set_soln_vol(s.volume_l);raw.Set_cb(s.charge_eq);
    std::ostringstream output;int id=3;raw.dump_raw(output,0,&id);
    s.raw=output.str();
    // Upstream dump uses 14 digits. Keep our authoritative double H/O/water
    // values at round-trip precision before any later chemical solve.
    for(const auto&[key,x]:std::map<std::string,double>{{"total_h",s.hydrogen_mol},{"total_o",s.oxygen_mol},{"mass_water",s.water_kg},{"soln_vol",s.volume_l},{"cb",s.charge_eq}})
        s.raw=std::regex_replace(s.raw,std::regex("(-"+key+"[ \\t]+)[^\\n]+"),"-"+key+" "+num(x));
    return s;
}

}

Chemistry::Chemistry(const std::string& database) : id_(CreateIPhreeqc()) {
    check(id_ >= 0, "无法创建化学求解器");
    if (LoadDatabase(id_,database.c_str()) != 0) {
        const std::string error = GetErrorString(id_); DestroyIPhreeqc(id_); id_ = -1;
        throw std::runtime_error("无法加载数据库："+error);
    }
    SetDumpStringOn(id_, 1);
    SetDumpFileOn(id_, 0);
    SetSelectedOutputFileOn(id_, 0);
    SetOutputFileOn(id_, 0);
}
Chemistry::~Chemistry() { if (id_ >= 0) DestroyIPhreeqc(id_); }
bool Chemistry::supported(int reagent) {
    return (reagent>=1&&reagent<=9)||reagent==11||(reagent>=14&&reagent<=16)||reagent==25;
}

Solution Chemistry::solve(const std::string& input) {
    const std::string script = "DELETE\n-all\nEND\nKNOBS\n-convergence_tolerance 1e-12\n\n" + selected() + input + "DUMP\n-solution 3\nEND\n";
    const int errors = RunString(id_,script.c_str());
    check(errors == 0, "化学求解失败："+std::string(GetErrorString(id_)));
    check(GetWarningStringLineCount(id_) == 0, "化学求解警告："+std::string(GetWarningString(id_)));
    SetCurrentSelectedOutputUserNumber(id_,1);
    const int row = GetSelectedOutputRowCount(id_)-1;
    check(row > 0 && GetSelectedOutputColumnCount(id_) == 6+int(element_names.size()+valence_names.size()), "化学读数不完整: row="+std::to_string(row)+", columns="+std::to_string(GetSelectedOutputColumnCount(id_)));
    Solution s;
    s.ph=value(id_,row,0); s.volume_l=value(id_,row,1); s.water_kg=value(id_,row,2);
    s.charge_eq=value(id_,row,3); s.hydrogen_mol=value(id_,row,4); s.oxygen_mol=value(id_,row,5);
    for (size_t i=0; i<element_names.size(); ++i) {
        s.elements[element_names[i]]=value(id_,row,int(i)+6);
        check(s.elements[element_names[i]] >= -1e-15, "出现负物质的量");
    }
    for(size_t i=0;i<valence_names.size();++i)s.valence_mol[valence_names[i]]=value(id_,row,int(i+element_names.size())+6);
    s.raw=GetDumpString(id_);
    const auto start=s.raw.find("SOLUTION_RAW");
    check(start != std::string::npos, "求解器未保存溶液状态");
    s.raw=s.raw.substr(start);
    s.composition_key=s.raw;
    check(s.water_kg>0 && s.volume_l>0 && s.ph>=0 && s.ph<=14.5, "结果超出已验证的稀溶液范围");
    check(std::abs(s.charge_eq)<1e-9, "电荷收支未通过");
    return s;
}

Solution Chemistry::prepare(int reagent, double concentration, double volume) {
    check(supported(reagent), "此原料尚未支持操作");
    check(std::isfinite(volume) && volume>=0.001 && volume<=0.250, "初始体积限 1–250 mL");
    check(std::isfinite(concentration) && (reagent==1 ? concentration==0 : concentration>=1e-5 && concentration<=0.01), "浓度限 0.00001–0.01 mol/L；蒸馏水为 0");
    const double moles=concentration*volume;
    double water=volume*0.9970474;
    Solution result;
    for (int iteration=0; iteration<8; ++iteration) {
        const double molality=moles/water;
        std::string body="SOLUTION 3\n-temp 25\n-pressure 1\n-units mol/kgw\n-water "+num(water)+"\npH 7 charge\n";
        const auto add=[&body,molality](const std::string& element,double ratio) { body+=element+" "+num(molality*ratio)+"\n"; };
        switch(reagent) {
            case 1:break;
            case 2:add("Cl",1);break;
            case 3:add("Na",1);break;
            case 4:add("Na",1);add("Cl",1);break;
            case 5:add("K",1);break;
            case 6:add("K",1);add("Cl",1);break;
            case 7:add("Ca",1);add("Cl",2);break;
            case 8:add("Na",1);add("C(4)",1);break;
            case 9:add("Na",2);add("C(4)",1);break;
            case 11:add("S(6)",1);break;
            case 14:add("Na",2);add("S(6)",1);break;
            case 15:add("Mg",1);add("Cl",2);break;
            case 16:add("Mg",1);add("S(6)",1);break;
            case 25:add("Ba",1);add("Cl",2);break;
        }
        result=solve(body+"END\n");
        if (std::abs(result.volume_l-volume)<1e-10) break;
        water+=(volume-result.volume_l)*0.9970474;
        check(water>0, "体积与溶剂质量换算失败");
    }
    check(std::abs(result.volume_l-volume)<1e-8, "配液体积未收敛");
    if (reagent != 1) result.ingredients_mol[reagent]=moles;
    return result;
}

BatchResult Chemistry::equilibrate(const Solution& base,const BatchConditions& c) {
    check(!base.empty(),"请先加入水溶液");
    for(auto [id,n]:base.ingredients_mol)
        check(n<=0||id==2||id==8||id==9,"此反应器仅验证水、稀盐酸和单独碳酸钠/碳酸氢钠底液");
    check(c.solid_reagent==0||c.solid_reagent==18||c.solid_reagent==19,"此固相尚未验证");
    check(std::isfinite(c.solid_mol)&&c.solid_mol>=0&&c.solid_mol<=0.005,"固体加入量限 0–5 mmol");
    check(c.solid_reagent!=0||c.solid_mol==0,"未选择固体");
    check(std::isfinite(c.co2_added_mol)&&c.co2_added_mol>=0&&c.co2_added_mol<=0.001,"CO₂ 加入量限 0–1 mmol");
    check(c.gas!=GasBoundary::None||c.co2_added_mol==0,"CO₂ 需要选择气相边界");
    check(std::isfinite(c.headspace_l)&&c.headspace_l>=0.05&&c.headspace_l<=1,"顶空限 50–1000 mL");
    check(std::isfinite(c.external_co2_atm)&&c.external_co2_atm>=0.0001&&c.external_co2_atm<=0.01,"外界 CO₂ 分压限 0.0001–0.01 atm");
    check(base.volume_l>=0.01-1e-8&&base.volume_l<=0.25+1e-8,"反应器底液限 10–250 mL");
    const std::string phase=c.solid_reagent==18?"Calcite":"Gypsum";
    std::string input=renamed(base,3)+"\nEND\nMIX 3\n3 1\n";
    if(c.solid_reagent||c.gas==GasBoundary::FixedCO2){
        input+="EQUILIBRIUM_PHASES 3\n";
        if(c.solid_reagent)input+=phase+" 0 "+num(c.solid_mol)+"\n";
        // A finite 1 mol reservoir approximates a fixed external boundary here.
        // Depletion is checked; its signed change is included in the ledger.
        if(c.gas==GasBoundary::FixedCO2)input+="CO2(g) "+num(std::log10(c.external_co2_atm))+" 1\n";
    }
    if(c.gas==GasBoundary::ClosedVolume)
        input+="GAS_PHASE 3\n-fixed_volume\n-volume "+num(c.headspace_l)+"\n-temperature 25\nCO2_ideal(g) 0\n";
    if(c.co2_added_mol>0)input+="REACTION 3\nCO2 1\n"+num(c.co2_added_mol)+" moles\n";
    const std::string extra="SELECTED_OUTPUT 2\n-reset false\n-high_precision true\nUSER_PUNCH 2\n-headings solid gas pressure reservoir si\n-start\n10 PUNCH EQUI(\""+phase+"\"), GAS(\"CO2_ideal(g)\"), GAS_P, EQUI(\"CO2(g)\"), SI(\""+phase+"\")\n-end\n";
    BatchResult r;
    // Preserve the exact CO2 equilibrium expression from the pinned database;
    // omit only critical EOS parameters for an explicit ideal-gas approximation.
    // The upstream PR path clips molar volume at 1e4 L/mol at very low pressure.
    const std::string ideal="PHASES\nCO2_ideal(g)\nCO2 = CO2\n-log_k -1.468\n-delta_h -4.776 kcal\n-analytic 10.5624 -2.3547e-2 -3972.8 0 5.8746e5 1.9194e-5\nEND\n";
    r.solution=solve(ideal+extra+input+"SAVE solution 3\nEND\n");
    SetCurrentSelectedOutputUserNumber(id_,2);
    const int row=GetSelectedOutputRowCount(id_)-1;
    r.solid_remaining_mol=c.solid_reagent?value(id_,row,0):0;
    r.gas_co2_mol=c.gas==GasBoundary::ClosedVolume?value(id_,row,1):0;
    r.gas_pressure_atm=c.gas==GasBoundary::ClosedVolume?value(id_,row,2):0;
    r.co2_to_environment_mol=c.gas==GasBoundary::FixedCO2?value(id_,row,3)-1:0;
    r.solid_saturation_index=c.solid_reagent?value(id_,row,4):0;
    check(c.gas!=GasBoundary::FixedCO2||value(id_,row,3)>0.99,"外界 CO₂ 储库超出已验证收支范围");
    check(r.gas_pressure_atm<=1.0,"气相压力超过 1 atm 的验证范围");
    const double reacted=c.solid_mol-r.solid_remaining_mol;
    auto initial=[&](const std::string&e){auto it=base.elements.find(e);return it==base.elements.end()?0:it->second;};
    r.carbon_residual_mol=r.solution.elements["C"]+r.gas_co2_mol+r.co2_to_environment_mol-initial("C")-c.co2_added_mol-(c.solid_reagent==18?reacted:0);
    r.calcium_residual_mol=r.solution.elements["Ca"]-initial("Ca")-reacted;
    r.sulfur_residual_mol=r.solution.elements["S"]-initial("S")-(c.solid_reagent==19?reacted:0);
    check(std::abs(r.carbon_residual_mol)<1e-9&&std::abs(r.calcium_residual_mol)<1e-9&&std::abs(r.sulfur_residual_mol)<1e-9,"气液固物质收支未通过");
    balance(r.solution.hydrogen_mol,base.hydrogen_mol+(c.solid_reagent==19?4*reacted:0),1e-8,"H");
    balance(r.solution.oxygen_mol+2*(r.gas_co2_mol+r.co2_to_environment_mol),base.oxygen_mol+2*c.co2_added_mol+(c.solid_reagent==19?6*reacted:3*reacted),1e-8,"O");
    r.mineral=c.solid_reagent?phase:"";
    r.solution.isolated_batch_sample=true;
    r.solution.ingredients_mol=base.ingredients_mol;
    // Provenance describes dissolved additions only; solids and headspace stay
    // in the reactor and are not implicitly poured with a liquid aliquot.
    if(c.solid_reagent&&reacted>0)r.solution.ingredients_mol[c.solid_reagent]+=reacted;
    if(c.gas!=GasBoundary::None)r.solution.ingredients_mol[10]+=std::max(0.0,c.co2_added_mol-r.gas_co2_mol-r.co2_to_environment_mol);

    return r;
}

BatchResult Chemistry::precipitate_barite(const Solution&a,const Solution&b){
    check(!a.empty()&&!b.empty(),"需要两份溶液");
    check(a.ingredients_mol.size()==1&&a.ingredients_mol.count(25)&&b.ingredients_mol.size()==1&&b.ingredients_mol.count(14),"此实验仅验证 BaCl₂ 与 Na₂SO₄ 预配液");
    check(a.volume_l+b.volume_l<=0.250+1e-8,"混合前总体积限 250 mL");
    const std::string extra="SELECTED_OUTPUT 2\n-reset false\n-high_precision true\nUSER_PUNCH 2\n-headings barite si\n-start\n10 PUNCH EQUI(\"Barite\"), SI(\"Barite\")\n-end\n";
    BatchResult r;r.mineral="Barite";
    r.solution=solve(extra+renamed(a,1)+"\nEND\n"+renamed(b,2)+"\nEND\nMIX 3\n1 1\n2 1\nEQUILIBRIUM_PHASES 3\nBarite 0 0\nSAVE solution 3\nEND\n");
    SetCurrentSelectedOutputUserNumber(id_,2);
    const int row=GetSelectedOutputRowCount(id_)-1;
    r.solid_remaining_mol=value(id_,row,0);r.solid_saturation_index=value(id_,row,1);
    const double solid=r.solid_remaining_mol;
    check(solid>=-1e-14,"出现负沉淀量");
    for(const auto&name:element_names){
        const double expected=a.elements.at(name)+b.elements.at(name)-(name=="Ba"||name=="S"?solid:0);
        balance(r.solution.elements[name],expected,1e-11,name);
    }
    balance(r.solution.hydrogen_mol,a.hydrogen_mol+b.hydrogen_mol,1e-8,"H");
    balance(r.solution.oxygen_mol+4*solid,a.oxygen_mol+b.oxygen_mol,1e-8,"O");
    for(const auto&name:valence_names)
        balance(r.solution.valence_mol[name],a.valence_mol.at(name)+b.valence_mol.at(name)-(name=="S(6)"?solid:0),1e-12,name+"价态");
    r.barium_residual_mol=r.solution.elements["Ba"]+solid-a.elements.at("Ba")-b.elements.at("Ba");
    r.sulfur_residual_mol=r.solution.elements["S"]+solid-a.elements.at("S")-b.elements.at("S");
    r.solution.ingredients_mol=a.ingredients_mol;
    for(auto[id,n]:b.ingredients_mol)r.solution.ingredients_mol[id]+=n;
    r.solution.isolated_batch_sample=true;
    return r;
}

void Chemistry::validate_combination(const Solution& a,const Solution& b) {
    if(a.empty()||b.empty())return;
    check(!a.isolated_batch_sample&&!b.isolated_batch_sample,"分离清液目前仅支持向空容器分装；再次混合或稀释尚未验证");
    // Monovalent strong electrolytes can share the tested acid/base model.
    // Calcium and carbonate initially permit only self-mixing and water dilution.
    int special=0;
    for (const auto* s : {&a,&b}) for (auto [id,moles] : s->ingredients_mol) {
        if (moles<=0) continue;
        if (id>=7&&id!=11&&id!=14) { check(special==0 || special==id,"此原料组合尚未验证：沉淀或气液行为未启用"); special=id; }
    }
    if (special) for (const auto* s : {&a,&b}) for (auto [id,moles] : s->ingredients_mol)
        check(moles<=0 || id==special,"此原料目前仅支持自身混合和蒸馏水稀释");
}

Solution Chemistry::mix(const Solution& a,double af,const Solution& b,double bf) {
    check(std::isfinite(af)&&std::isfinite(bf)&&af>=0&&af<=1&&bf>=0&&bf<=1,"转移比例无效");
    if ((a.empty()||af==0)&&(b.empty()||bf==0)) return {};
    validate_combination(a,b);
    if(a.empty()||af==0)return scaled(b,bf);
    if(b.empty()||bf==0)return scaled(a,af);
    if(!a.composition_key.empty()&&a.composition_key==b.composition_key)
        return scaled(a,af+bf*b.volume_l/a.volume_l);
    std::string input;
    if (!a.empty()&&af>0) input+=renamed(a,1)+"\nEND\n";
    if (!b.empty()&&bf>0) input+=renamed(b,2)+"\nEND\n";
    input+="MIX 3\n";
    if (!a.empty()&&af>0) input+="1 "+num(af)+"\n";
    if (!b.empty()&&bf>0) input+="2 "+num(bf)+"\n";
    Solution r=solve(input+"SAVE solution 3\nEND\n");
    r.isolated_batch_sample=a.isolated_batch_sample||b.isolated_batch_sample;
    for(auto [id,n]:a.ingredients_mol) if(n*af>0) r.ingredients_mol[id]+=n*af;
    for(auto [id,n]:b.ingredients_mol) if(n*bf>0) r.ingredients_mol[id]+=n*bf;
    for (const auto& name:element_names) {
        auto get=[&name](const Solution& s){auto i=s.elements.find(name);return i==s.elements.end()?0:i->second;};
        balance(r.elements[name],get(a)*af+get(b)*bf,1e-11,name);
    }
    for(const auto&name:valence_names){
        auto get=[&](const Solution&s){auto i=s.valence_mol.find(name);return i==s.valence_mol.end()?0:i->second;};
        balance(r.valence_mol[name],get(a)*af+get(b)*bf,1e-13,name+"价态");
    }
    balance(r.hydrogen_mol,a.hydrogen_mol*af+b.hydrogen_mol*bf,1e-8,"H");
    balance(r.oxygen_mol,a.oxygen_mol*af+b.oxygen_mol*bf,1e-8,"O");
    return r;
}

TransferResult transfer(Chemistry& solver,const Vessel& source,const Vessel& target,double requested) {
    check(source.id!=target.id,"不能向同一个容器倾倒");
    check(std::isfinite(requested)&&requested>=0,"倾倒量必须为非负有限数");
    TransferResult result{source,target,0};
    double amount=std::min({requested,source.solution.volume_l,std::max(0.0,target.capacity_l-target.solution.volume_l)});
    if(amount<1e-10) return result;
    // Include a sub-picolitre floating point remainder in the actual transfer.
    // Do not solve a fictitious 1e-20 L residual or silently discard its matter.
    if(source.solution.volume_l-amount<1e-12)amount=source.solution.volume_l;
    const double fraction=std::clamp(amount/source.solution.volume_l,0.0,1.0);
    result.target.solution=solver.mix(target.solution,1,source.solution,fraction);
    result.source.solution=solver.mix(source.solution,1-fraction,{},0);
    check(result.target.solution.volume_l<=target.capacity_l+1e-8,"混合体积超过容器容量");
    result.transferred_l=amount;
    return result;
}
}
