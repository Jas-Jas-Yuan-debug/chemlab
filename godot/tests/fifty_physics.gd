extends RefCounted
# Actual experiment controls and independent analytic invariants, without rendering.
func click(lab: Node3D, node_name: String) -> void:
    var b = lab.get_tree().root.find_child(node_name,true,false)
    assert(b is Button,"Missing control: "+node_name)
    b.pressed.emit()

func near(a: float,b: float,tolerance: float,label: String) -> void:
    assert(is_finite(a) and abs(a-b)<=tolerance,label+": "+str(a)+" versus "+str(b))

func run_round(id: int,lab: Node3D) -> Dictionary:
    lab.switch_bench()
    var e = lab.bench_experiment
    # Deterministic manual time advancement; scene/UI still instantiated and used.
    e.set_process(false)
    var r: Dictionary
    var facts = {}
    var checks = []
    var name = ""
    match id:
        29:
            name="Spring quarter-period and conserved energy"
            e.picker.item_selected.emit(0)
            e.fields.mass_kg.value=0.3;e.fields.stiffness_n_m.value=12;e.fields.amplitude_m.value=0.08
            click(lab,"ConfigureBench");click(lab,"StartBench")
            var initial: Dictionary=lab.core.bench_snapshot()
            lab.core.advance_bench(0.25)
            r=lab.core.bench_snapshot()
            var omega=sqrt(12.0/0.3)
            near(r.position_m,0.08*cos(omega*r.time_s),1e-12,"Spring phase")
            near(r.velocity_m_s,-0.08*omega*sin(omega*r.time_s),1e-12,"Spring velocity")
            near(r.energy_j,0.5*12*pow(0.08,2),1e-12,"Spring energy")
            click(lab,"PauseBench");lab.core.advance_bench(1)
            near(lab.core.bench_snapshot().time_s,r.time_s,1e-12,"Paused clock")
            facts={"time_s":r.time_s,"position_m":r.position_m,"energy_j":r.energy_j,"initial_energy_j":initial.energy_j}
            checks=["Analytic phase/velocity","Mechanical energy","Pause"]
        30:
            name="Pendulum period and geometry at two lengths"
            e.picker.item_selected.emit(1)
            e.fields.length_m.value=0.5;e.fields.angle_deg.value=6;e.fields.gravity_m_s2.value=9.8
            click(lab,"ConfigureBench");click(lab,"StartBench");lab.core.advance_bench(0.3)
            r=lab.core.bench_snapshot()
            near(r.period_s,TAU*sqrt(0.5/9.8),1e-12,"Pendulum period")
            near(r.position_m,0.5*sin(r.angle_rad),1e-12,"Pendulum geometry")
            var first: float=r.period_s
            e.fields.length_m.value=1;click(lab,"ConfigureBench")
            var second: Dictionary=lab.core.bench_snapshot()
            near(second.period_s/first,sqrt(2),1e-12,"Square-root length scaling")
            facts={"short_period_s":first,"long_period_s":second.period_s,"horizontal_m":r.position_m}
            checks=["Small-angle period","Geometry","Length scaling"]
        31:
            name="Unequal-mass heat exchange"
            e.picker.item_selected.emit(2)
            e.fields.mass1_kg.value=0.15;e.fields.mass2_kg.value=0.3
            e.fields.temperature1_c.value=80;e.fields.temperature2_c.value=20;e.fields.conductance_w_k.value=8
            click(lab,"ConfigureBench");var before: Dictionary=lab.core.bench_snapshot()
            click(lab,"StartBench");lab.core.advance_bench(45);r=lab.core.bench_snapshot()
            var eq=(0.15*80+0.3*20)/0.45
            var tau=4186*0.15*0.3/(8*0.45)
            near(r.equilibrium_c,eq,1e-10,"Weighted mean temperature")
            near(r.temperature1_c-r.temperature2_c,60*exp(-r.time_s/tau),1e-10,"Thermal decay")
            near(r.energy_j,before.energy_j,1e-8,"Thermal energy")
            facts={"equilibrium_c":r.equilibrium_c,"temperature1_c":r.temperature1_c,"temperature2_c":r.temperature2_c}
            checks=["Weighted mean","Analytic exponential decay","Energy"]
        32,33:
            name="Series circuit KVL" if id==32 else "Parallel circuit KCL"
            e.picker.item_selected.emit(3)
            e.topology.selected=0 if id==32 else 1
            e.fields.voltage_v.value=9;e.fields.resistance1_ohm.value=150;e.fields.resistance2_ohm.value=300
            click(lab,"ConfigureBench");click(lab,"StartBench");lab.core.advance_bench(2.5);r=lab.core.bench_snapshot()
            if id==32:
                near(r.current_a,9.0/450,1e-12,"Series current")
                near(r.voltage1_v+r.voltage2_v,9,1e-12,"KVL")
            else:
                near(r.current_a,9.0/150+9.0/300,1e-12,"Parallel current")
                near(r.current1_a+r.current2_a,r.current_a,1e-12,"KCL")
            near(r.energy_j,9*r.current_a*r.time_s,1e-12,"Electrical energy")
            facts={"current_a":r.current_a,"energy_j":r.energy_j,"time_s":r.time_s}
            click(lab,"PauseBench");near(lab.core.bench_snapshot().current_a,0,1e-12,"Open circuit")
            checks=["Ohm law","KVL" if id==32 else "KCL","Energy","Open circuit"]
        34:
            name="Lens real, virtual and focal plane transition"
            e.picker.item_selected.emit(4)
            e.fields.focal_m.value=0.25;e.fields.object_m.value=0.75
            click(lab,"ConfigureBench");r=lab.core.bench_snapshot()
            near(r.image_m,0.375,1e-12,"Lens equation")
            near(r.magnification,-0.5,1e-12,"Magnification")
            e.fields.focal_m.value=-0.25;click(lab,"ConfigureBench")
            var virtual: Dictionary=lab.core.bench_snapshot()
            near(virtual.image_m,-0.1875,1e-12,"Virtual image")
            assert(virtual.virtual==1,"Diverging lens virtual flag")
            e.fields.focal_m.value=0.25;e.fields.object_m.value=0.25;click(lab,"ConfigureBench")
            var focal: Dictionary=lab.core.bench_snapshot()
            assert(focal.at_infinity==1 and not focal.has("image_m"),"Focal plane cannot report a finite image")
            facts={"real_image_m":r.image_m,"virtual_image_m":virtual.image_m,"focal_at_infinity":focal.at_infinity}
            checks=["Thin lens equation","Magnification sign","Virtual image","Infinite image"]
        35:
            name="Heater transient, thermostat and retuning"
            e.picker.item_selected.emit(5)
            e.fields.target_c.value=45;e.fields.power_w.value=1000;e.fields.stir_rpm.value=120
            click(lab,"ApplyHeaterControl");click(lab,"ToggleHeater");click(lab,"ToggleStirrer")
            lab.core.advance_bench(5);r=lab.core.bench_snapshot()
            near(r.temperature_c,20+1000/0.6*(1-exp(-0.6*r.time_s/418.6)),1e-9,"Heater ODE")
            near(r.input_energy_j,1000*r.time_s,1e-8,"Prescribed heat")
            lab.core.advance_bench(30);r=lab.core.bench_snapshot()
            near(r.temperature_c,45,1e-8,"Thermostat target");near(r.power_w,15,1e-8,"Holding heat loss")
            near(r.energy_residual_j,0,1e-7,"Energy closure")
            var energy: float=r.input_energy_j
            e.fields.target_c.value=30;click(lab,"ApplyHeaterControl")
            var tuned: Dictionary=lab.core.bench_snapshot()
            near(tuned.temperature_c,45,1e-8,"Retune retains inventory");near(tuned.input_energy_j,energy,1e-8,"Retune retains energy")
            near(tuned.power_w,0,1e-10,"Lower setpoint stops heating")
            facts={"target_temperature_c":r.temperature_c,"energy_j":energy,"holding_power_w":r.power_w,"retuned_power_w":tuned.power_w}
            checks=["Analytic heat ODE","Thermostat","Energy closure","Retune continuity"]
        36:
            name="Finite burner fuel exhaustion and independent stirring"
            e.picker.item_selected.emit(5)
            e.fields.fuel_mass_g.value=1;e.fields.power_w.value=1000;e.fields.target_c.value=95
            e.heat_source.selected=1;click(lab,"ConfigureBench")
            click(lab,"ToggleHeater");click(lab,"ToggleStirrer")
            # Capped advancement avoids a long real-time or rendering loop.
            for step in range(20):lab.core.advance_bench(60)
            r=lab.core.bench_snapshot()
            near(r.fuel_remaining_g,0,1e-8,"Fuel exhaustion");near(r.power_w,0,1e-8,"Empty burner heat")
            near(r.fuel_consumed_mol*r.fuel_molar_mass_g,1,1e-8,"Fuel mass")
            near(r.input_energy_j,0.35*r.chemical_energy_j,1e-6,"Declared capture fraction")
            near(r.energy_residual_j,0,1e-6,"Water energy");near(r.combustion_energy_residual_j,0,1e-6,"Chemical energy")
            assert(r.stir_turns>0,"Fuel depletion cannot stop stirring")
            facts={"fuel_remaining_g":r.fuel_remaining_g,"fuel_consumed_mol":r.fuel_consumed_mol,"stir_turns":r.stir_turns,"energy_residual_j":r.energy_residual_j}
            checks=["Finite fuel inventory","Fuel mass","Heat capture","Water/chemical energy","Stir independence"]
        _:
            assert(false,"Unknown physics round")
    lab.core.pause_bench()
    return {"id":id,"name":name,"actions":["Select actual physics model","Apply controls","Advance model","Read shared state","Review independent invariants"],"facts":facts,"checks":checks}
