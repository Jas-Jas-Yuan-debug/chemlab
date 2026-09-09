#pragma once
#include "science/chemistry.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <future>
#include <functional>

namespace godot {
class LabCore : public RefCounted {
    GDCLASS(LabCore, RefCounted)
    struct Result {
        std::map<int,chemlab::Vessel> vessels;
        std::string error;
        std::string operation;
        double transferred_ml=0;
        double compute_ms=0;
        int from=0,to=0;
        uint64_t generation=0;
    };
    std::string database_;
    std::map<int,chemlab::Vessel> vessels_;
    std::future<Result> pending_;
    uint64_t generation_=0;
    uint64_t revision_=0;
    bool reset_queued_=false;
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
};
}
