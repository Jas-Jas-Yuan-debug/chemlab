#pragma once
#include "science/session.hpp"
#include "science/mechanics.hpp"
#include "science/physics_models.hpp"
#include "science/flame_field.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <future>
#include <functional>
#include <optional>

namespace godot {
class LabCore : public RefCounted {
    GDCLASS(LabCore, RefCounted)
    struct Result {
        chemlab::LabSession session;
        std::string error;
        std::string operation;
        double transferred_ml=0;
        double compute_ms=0;
        int from=0,to=0;
        uint64_t generation=0;
        std::optional<chemlab::FreeFall> restored_fall;
        std::optional<chemlab::PhysicsExperiment> restored_bench;
        std::optional<chemlab::FlameField> restored_flame;
    };
    std::string database_;
    chemlab::LabSession session_;
    std::string database_error_;
    std::future<Result> pending_;
    uint64_t generation_=0;
    uint64_t revision_=0;
    bool reset_queued_=false;
    chemlab::FreeFall fall_;
    chemlab::PhysicsExperiment bench_;
    std::optional<chemlab::FlameField> flame_;
    bool submit(const chemlab::Command& command);
    bool start(const std::function<void(chemlab::Chemistry&,Result&)>& job);
protected:
    static void _bind_methods();
public:
    ~LabCore();
    void initialize(const String& database);
    bool reset_lab();
    bool prepare(int vessel_id,int reagent,double concentration,double volume_ml,double capacity_ml);
    bool add_empty(int vessel_id,double capacity_ml);
    bool pour(int source,int target,double amount_ml);
    bool is_busy() const;
    Dictionary poll();
    Dictionary snapshot() const;
    Dictionary save_session() const;
    Dictionary preview_bench(const String& kind,const Dictionary& parameters,double elapsed_s,bool running=false,const Array& heater_controls=Array()) const;
    Dictionary preview_fall(double height_m,double gravity_m_s2,double elapsed_s) const;
    String load_session(const Dictionary& document);
    bool run_batch(const Dictionary& parameters);
    bool extract_batch(int vessel_id);
    Dictionary batch_snapshot() const;
    String configure_bench(const String& kind,const Dictionary& parameters);
    String set_flame_enabled(bool enabled);
    Dictionary advance_flame(double elapsed_s,double wind_m_s);
    Dictionary flame_snapshot() const;
    String control_heater(const Dictionary& control);
    void start_bench();
    void pause_bench();
    void reset_bench();
    Dictionary advance_bench(double elapsed_s);
    Dictionary bench_snapshot() const;
    String configure_fall(double height_m,double gravity_m_s2);
    void start_fall();
    void pause_fall();
    void reset_fall();
    Dictionary advance_fall(double elapsed_s);
    Dictionary fall_snapshot() const;
};
}
