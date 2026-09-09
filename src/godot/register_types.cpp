#include "lab_core.hpp"
#include <godot_cpp/godot.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;
void initialize_chemlab(ModuleInitializationLevel level){
    if(level==MODULE_INITIALIZATION_LEVEL_SCENE)ClassDB::register_class<LabCore>();
}
void uninitialize_chemlab(ModuleInitializationLevel){}
extern "C" {
GDExtensionBool GDE_EXPORT chemlab_library_init(GDExtensionInterfaceGetProcAddress get_proc_address,
    GDExtensionClassLibraryPtr library,GDExtensionInitialization* initialization){
    GDExtensionBinding::InitObject init(get_proc_address,library,initialization);
    init.register_initializer(initialize_chemlab);
    init.register_terminator(uninitialize_chemlab);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
}
