#pragma once
#include "chemistry.hpp"
#include "physics_models.hpp"
#include <optional>
#include <vector>
namespace chemlab {
struct Command { std::string operation; Scalars parameters; };
struct Event {
    std::string operation;
    int from=0,to=0;
    double transferred_ml=0;
    Scalars readings;
};
struct LabSession {
    std::map<int,Vessel> vessels;
    std::optional<BatchResult> batch;
    std::vector<Command> journal;
    std::vector<Event> events;
    void reset(Chemistry& solver);
    Event apply(Chemistry& solver,const Command& command);
};
}
