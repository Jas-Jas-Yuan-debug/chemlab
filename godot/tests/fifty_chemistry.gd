extends RefCounted

# Each round receives a new, instantiated laboratory. The driver owns isolation,
# result persistence and scene disposal; this module never opens a window/file.
var lab: Node3D
var report: Dictionary

func check(ok: bool, description: String) -> void:
    report.checks.append({"ok":ok,"description":description})
    if not ok:
        push_error("Round %d: %s" % [report.id,description])
        assert(ok,description)

func near(actual: float, expected: float, tolerance: float, description: String) -> void:
    check(is_finite(actual) and abs(actual-expected)<=tolerance,description)

func idle() -> void:
    var deadline: int=Time.get_ticks_msec()+30000
    while lab.core.is_busy() and Time.get_ticks_msec()<deadline:
        await lab.get_tree().process_frame
    check(not lab.core.is_busy(),"Background chemistry completes within 30 seconds")
    await lab.get_tree().process_frame

func prepare(id: int,reagent: int,c: float,ml: float) -> void:
    lab.select_vessel(id)
    lab.choose_reagent(reagent)
    lab.concentration.value=c
    lab.volume.value=ml
    lab.prepare_selected()
    await idle()
    check(lab.status.text.begins_with("已配制"),"Actual preparation control succeeds")
    report.actions.append("Prepare vessel %d: reagent %d, %.8f mol/L, %.8f mL" % [id,reagent,c,ml])

func pour(source: int,target: int,ml: float) -> void:
    lab.select_vessel(source)
    lab.target_id=target
    lab.request_pour(ml)
    await idle()
    report.actions.append("Transfer %.8f mL from vessel %d to %d" % [ml,source,target])

func maximum(reagent: int) -> float:
    lab.choose_reagent(reagent)
    lab.concentration_max_button.pressed.emit()
    var cap: float=lab.catalog[reagent-1].preparation_limit.maximum_mol_l
    near(lab.concentration.value,cap,1e-9,"Maximum preset preserves the catalog physical limit")
    return cap

func inventory(s: Dictionary,element: String) -> float:
    return float(s.elements_mol.get(element,0.0))

func ion_totals(saved: Array) -> Array:
    # GDScript floats are doubles; Vector2 components may use single precision.
    return [float(saved[9])+float(saved[12]),float(saved[10])+float(saved[13])]

func neutral_pair(acid_ml: float=50.0,base_ml: float=50.0) -> void:
    await prepare(3,2,0.001,acid_ml)
    await prepare(2,3,0.001,base_ml)
    await pour(2,3,base_ml)

func advance(seconds: float,q: float) -> Dictionary:
    var remaining: float=seconds
    var all: Dictionary={}
    while remaining>1e-12:
        var step: float=min(1.0,remaining)
        all=lab.core.advance_kinetics(step,q)
        check(not all.has("error"),"Finite-rate integration accepts the physical step and flow")
        remaining-=step
    lab.kinetic_readings=all
    report.actions.append("Advance %.8f s with mixing exchange %.8f mL/s" % [seconds,q])
    return all

func batch(solid: int,boundary: int,base: int=0,c: float=0.001,dose_mmol: float=2.0) -> Dictionary:
    lab.switch_batch(false)
    var e: Node3D=lab.batch_experiment
    e.base_picker.selected=base
    e.concentration.value=c
    e.volume.value=100
    e.solid_picker.selected=solid
    e.solid_amount.value=dose_mmol
    e.boundary_picker.selected=boundary
    e.gas_amount.value=0.1 if boundary==1 else 0.0
    e.headspace.value=100
    e.external_co2.value=0.00042
    e.update_inputs()
    e.run_trial()
    await idle()
    var r: Dictionary=lab.core.batch_snapshot()
    check(not r.is_empty() and r.volume_ml>0,"Actual batch controls produce a liquid equilibrium result")
    report.actions.append("Batch: solid index %d, gas boundary %d, base index %d, %.8f mmol solid" % [solid,boundary,base,dose_mmol if solid<2 else 0.0])
    return r

func barite(sulfate_ml: float) -> Dictionary:
    lab.switch_batch(true)
    var e: Node3D=lab.batch_experiment
    e.ba_concentration.value=0.001
    e.ba_volume.value=50
    e.sulfate_concentration.value=0.001
    e.sulfate_volume.value=sulfate_ml
    e.run_trial()
    await idle()
    var r: Dictionary=lab.core.batch_snapshot()
    check(not r.is_empty() and r.mineral=="Barite","Actual precipitation controls select the BaSO4 model")
    report.actions.append("Precipitate 50 mL of 1 mmol/L BaCl2 with %.8f mL of 1 mmol/L Na2SO4" % sulfate_ml)
    return r

func batch_balance(r: Dictionary) -> void:
    for key in ["carbon_residual_mol","calcium_residual_mol","sulfur_residual_mol"]:
        near(float(r[key]),0.0,1e-8,"Batch %s closes" % key)

func run_round(id: int,scene: Node3D) -> Dictionary:
    lab=scene
    report={"id":id,"name":"","actions":[],"facts":{},"checks":[]}
    await idle()
    lab.paused=true
    match id:
        1:
            report.name="Reset defaults and independent vessel inventories"
            lab.reset_lab()
            lab.paused=true
            await idle()
            check(lab.states.size()==4,"Reset leaves exactly four default vessels")
            near(lab.states[1].volume_ml,50,1e-6,"Default HCl has 50 mL final volume")
            near(lab.states[2].volume_ml,50,1e-6,"Default NaOH has 50 mL final volume")
            near(inventory(lab.states[1],"Cl"),0.00005,1e-11,"Default acid inventory equals C times final volume")
            near(inventory(lab.states[2],"Na"),0.00005,1e-11,"Default base inventory equals C times final volume")
            near(lab.states[3].volume_ml,0,1e-12,"Receiving beaker starts empty")
            check(lab.states[1].ph<3.1 and lab.states[2].ph>10.8,"Default acid/base signs are physically correct")
            report.actions.append("Reset through the actual laboratory control")
            report.facts={"acid_ph":lab.states[1].ph,"base_ph":lab.states[2].ph,"empty_volume_ml":lab.states[3].volume_ml}
        2,3:
            var reagent: int=2 if id==2 else 3
            var element: String="Cl" if id==2 else "Na"
            report.name="HCl water dilution" if id==2 else "NaOH water dilution"
            await prepare(1,reagent,0.001,50)
            await prepare(3,1,0,50)
            await pour(1,3,50)
            var s: Dictionary=lab.states[3]
            near(inventory(s,element),0.00005,1e-11,"Water dilution preserves every solute equivalent")
            near(s.volume_ml,100,0.02,"Diluted final volume stays near 100 mL with solution-volume correction")
            var predicted_ph: float=-log(0.00005/(s.volume_ml/1000))/log(10.0)
            if id==3:predicted_ph=14-predicted_ph
            near(s.ph,predicted_ph,0.04,"Dilute strong electrolyte pH matches the independent C/V estimate")
            report.facts={"ph":s.ph,"dilute_reference_ph":predicted_ph,"solute_mol":inventory(s,element),"volume_ml":s.volume_ml}
        4,5,6:
            report.name={4:"Equal-equivalent neutralization",5:"Acid-excess neutralization",6:"Base-excess neutralization"}[id]
            var acid_ml: float=25 if id==6 else 50
            var base_ml: float=25 if id==5 else 50
            await neutral_pair(acid_ml,base_ml)
            var s: Dictionary=lab.states[3]
            near(inventory(s,"Cl"),acid_ml*0.000001,1e-11,"Neutralization conserves acid-derived chloride")
            near(inventory(s,"Na"),base_ml*0.000001,1e-11,"Neutralization conserves base-derived sodium")
            var prediction: float=7
            if id!=4:
                var excess: float=abs(acid_ml-base_ml)*0.000001/(s.volume_ml/1000)
                prediction=-log(excess)/log(10.0)
                if id==6:prediction=14-prediction
            near(s.ph,prediction,0.07,"Final equilibrium follows independently counted excess equivalents")
            near(s.charge_eq,0,1e-9,"Final equilibrium retains charge balance")
            report.facts={"equilibrium_ph":s.ph,"independent_reference_ph":prediction,"chloride_mol":inventory(s,"Cl"),"sodium_mol":inventory(s,"Na")}
        7:
            report.name="Maximum HCl stock aliquot and dilution recovery"
            var cap: float=maximum(2)
            await prepare(1,2,cap,10)
            check(lab.states[1].empirical_stock and lab.states[1].ph==null,"Maximum acid stock does not invent calibrated pH")
            await pour(1,4,0.5)
            near(inventory(lab.states[4],"Cl"),cap*0.0005,1e-10,"Acid aliquot carries C times transferred volume")
            near(inventory(lab.states[1],"Cl"),cap*0.0095,1e-10,"Acid source retains the complementary inventory")
            check(not lab.states[4].empirical_stock and lab.core.kinetics_snapshot().has(4),"Dilution restarts quantitative equilibrium and kinetics")
            check(lab.states[4].ph<1.5,"Diluted acid retains acidity")
            report.facts={"maximum_mol_l":cap,"remaining_ml":lab.states[1].volume_ml,"diluted_ph":lab.states[4].ph,"aliquot_chloride_mol":inventory(lab.states[4],"Cl")}
        8:
            report.name="Maximum NaOH same-solute density mixing"
            var cap: float=maximum(3)
            await prepare(1,3,cap,20)
            await prepare(3,3,cap/2,20)
            var prior_h: float=lab.states[1].hydrogen_mol+lab.states[3].hydrogen_mol
            var prior_o: float=lab.states[1].oxygen_mol+lab.states[3].oxygen_mol
            await pour(1,3,20)
            var s: Dictionary=lab.states[3]
            check(s.empirical_stock and s.ph==null,"Concentrated same-solute mixture remains an empirical stock")
            near(inventory(s,"Na"),cap*0.02+cap*0.01,1e-10,"Same-solute mixing preserves separately prepared inventories")
            near(s.hydrogen_mol,prior_h,1e-8,"Density mixing preserves solvent hydrogen")
            near(s.oxygen_mol,prior_o,1e-8,"Density mixing preserves solvent oxygen")
            check(s.volume_ml>38 and s.volume_ml<42,"Density-based mixture has a plausible final volume")
            report.facts={"maximum_mol_l":cap,"mixed_volume_ml":s.volume_ml,"sodium_mol":inventory(s,"Na"),"ph":s.ph}
        9:
            report.name="Water into maximum KOH stock recovers kinetics"
            var cap: float=maximum(5)
            await prepare(1,5,cap,1)
            await prepare(4,1,0,200)
            check(not lab.core.kinetics_snapshot().has(1),"Undiluted concentrated KOH has no uncalibrated kinetic state")
            var initial_h: float=lab.states[1].hydrogen_mol+lab.states[4].hydrogen_mol
            var initial_o: float=lab.states[1].oxygen_mol+lab.states[4].oxygen_mol
            await pour(4,1,200)
            check(not lab.states[1].empirical_stock and lab.core.kinetics_snapshot().has(1),"Reverse dilution creates a quantitative kinetic state")
            near(inventory(lab.states[1],"K"),cap*0.001,1e-10,"Reverse dilution preserves the initial K dose")
            near(lab.states[1].hydrogen_mol,initial_h,1e-8,"Reverse dilution conserves all solvent and solute hydrogen")
            near(lab.states[1].oxygen_mol,initial_o,1e-8,"Reverse dilution conserves all solvent and solute oxygen")
            check(lab.states[1].volume_ml>200 and lab.states[1].volume_ml<201.5,"Reverse dilution retains a plausible near-201 mL volume with density and partial-molar corrections")
            check(lab.states[1].ph>12,"Reverse-diluted KOH remains alkaline")
            report.facts={"maximum_mol_l":cap,"volume_ml":lab.states[1].volume_ml,"ph":lab.states[1].ph,"hydrogen_mol":lab.states[1].hydrogen_mol,"oxygen_mol":lab.states[1].oxygen_mol,"volume_model":"Stock density and quantitative partial-molar-volume corrections; input volumes need not add exactly","kinetic_time_s":lab.core.kinetics_snapshot()[1].time_s}
        10,11:
            var reagent: int=4 if id==10 else 6
            var element: String="Na" if id==10 else "K"
            report.name="Maximum NaCl quantitative stock and upper-bound rollback" if id==10 else "Maximum KCl quantitative stock and upper-bound rollback"
            var cap: float=maximum(reagent)
            await prepare(1,reagent,cap,250)
            var s: Dictionary=lab.states[1]
            near(s.volume_ml,250,1e-5,"Saturated-salt stock uses final solution volume")
            near(inventory(s,element),cap*0.25,1e-9,"Saturated-salt inventory equals physical maximum times final volume")
            near(inventory(s,"Cl"),cap*0.25,1e-9,"Salt cation/chloride inventory is stoichiometric")
            check(not s.empirical_stock and s.activity_model=="Pitzer" and s.ph!=null,"Maximum salt stock retains the quantitative Pitzer model")
            var before: String=JSON.stringify(lab.core.snapshot())
            check(lab.core.prepare(1,reagent,cap+0.001,250,250),"Above-limit native command is submitted for validation")
            await idle()
            check(JSON.stringify(lab.core.snapshot())==before,"Rejected above-limit preparation preserves the entire native state")
            check(not lab.status.text.begins_with("已配制"),"Above-limit preparation exposes its rejection")
            report.actions.append("Submit concentration above physical maximum through the native input boundary")
            report.facts={"maximum_mol_l":cap,"salt_mol":inventory(s,element),"volume_ml":s.volume_ml,"activity_model":s.activity_model,"rejection":lab.status.text}
            if s.has("halite_si") and s.has("sylvite_si"):
                var si: float=s.halite_si if id==10 else s.sylvite_si
                near(si,0,1e-4,"Physical salt maximum lies at its mineral saturation boundary")
                report.facts.saturation_index=si
        12:
            report.name="Common-ion salt balance and rejected stock reaction transaction"
            var na_max: float=maximum(4)
            var k_max: float=maximum(6)
            await prepare(1,4,na_max,50)
            await prepare(3,6,k_max,50)
            await pour(1,3,50)
            near(inventory(lab.states[3],"Na"),na_max*0.05,1e-9,"Common-ion mixing conserves Na")
            near(inventory(lab.states[3],"K"),k_max*0.05,1e-9,"Common-ion mixing conserves K")
            near(inventory(lab.states[3],"Cl"),(na_max+k_max)*0.05,1e-9,"Common-ion mixing conserves shared chloride")
            if lab.states[3].has("halite_si"):
                check(lab.states[3].halite_si<=1e-7 and lab.states[3].sylvite_si<=1e-7,"Accepted common-ion mixture is not supersaturated")
            await prepare(1,5,maximum(5),50)
            await prepare(2,2,0.001,50)
            var before: String=JSON.stringify(lab.core.snapshot())
            var journal_before: int=lab.core.save_session().commands.size()
            await pour(1,2,5)
            check(JSON.stringify(lab.core.snapshot())==before,"Out-of-scope concentrated reaction does not consume either vessel")
            check(lab.core.save_session().commands.size()==journal_before,"Rejected stock reaction does not enter the science journal")
            report.facts={"accepted_common_ion_mixture":true,"rejected_stock_reaction":lab.status.text,"unchanged_journal_entries":journal_before}
        13:
            report.name="Stock boundaries clear quantitative curves and restore fresh history"
            await neutral_pair()
            advance(0.5,20)
            lab.kinetic_history[3]=[{"time_s":0.5,"ph":lab.kinetic_readings[3].ph,"upper_ph":lab.kinetic_readings[3].upper_ph,"rate_mol_s":lab.kinetic_readings[3].rate_mol_s}]
            check(not lab.curves[3].is_empty(),"Neutralization has a real equilibrium-volume history")
            await prepare(3,5,maximum(5),1)
            check(lab.curves[3].is_empty() and not lab.kinetic_history.has(3),"Entering empirical stock clears obsolete curves")
            check(lab.states[3].ph==null and not lab.kinetic_readings.has(3),"Entering stock removes quantitative pH and rates")
            await prepare(4,1,0,200)
            await pour(4,3,200)
            check(not lab.states[3].empirical_stock and lab.core.kinetics_snapshot().has(3),"Dilution recovers a newly initialized quantitative state")
            check(not lab.kinetic_history.has(3),"Old rate samples are not attached to the newly diluted state")
            near(lab.core.kinetics_snapshot()[3].time_s,0,1e-12,"Recovered kinetic state starts with a fresh clock")
            check(lab.curves[3].size()==1,"Recovered equilibrium curve contains only one new observation")
            near(lab.curves[3][0].y,lab.states[3].ph,1e-6,"Recovered equilibrium point matches the new solution within plot-coordinate precision")
            report.facts={"restored_ph":lab.states[3].ph,"equilibrium_points":lab.curves[3].size(),"fresh_kinetic_time_s":lab.core.kinetics_snapshot()[3].time_s}
        14:
            report.name="Empty-source no-op preserves a non-equilibrium kinetic state"
            await pour(1,3,50)
            await pour(2,3,25)
            advance(0.1,0)
            var before: String=JSON.stringify(lab.core.save_session().kinetics)
            var inventory_before: float=inventory(lab.states[3],"Cl")
            await pour(1,3,10)
            check(JSON.stringify(lab.core.save_session().kinetics)==before,"Empty-source transfer cannot homogenize or reset kinetics")
            near(inventory(lab.states[3],"Cl"),inventory_before,1e-12,"Empty-source transfer cannot change solute inventory")
            report.facts={"source_volume_ml":lab.states[1].volume_ml,"target_heterogeneity":lab.core.kinetics_snapshot()[3].heterogeneity,"status":lab.status.text}
        15:
            report.name="Zero exchange retains separated acid/base zones"
            await neutral_pair()
            var first: Dictionary=advance(1,0)[3]
            var second: Dictionary=advance(1,0)[3]
            check(abs(second.ph-second.upper_ph)>3,"Zero exchange does not instantly replace local pH with bulk equilibrium")
            near(first.ph,second.ph,1e-7,"Isolated zones remain stable after their local reaction")
            near(second.equivalent_error_mol,0,1e-10,"Separated zones conserve acid/base equivalents")
            check(abs(second.ph-lab.states[3].ph)>1,"Measured local pH remains distinct from the final equilibrium reference")
            report.facts={"lower_ph":second.ph,"upper_ph":second.upper_ph,"equilibrium_ph":lab.states[3].ph,"heterogeneity":second.heterogeneity,"time_s":second.time_s}
        16:
            report.name="Finite exchange flow changes the reaction timescale"
            await neutral_pair()
            var slow: Dictionary=advance(10,0.1)[3]
            await neutral_pair()
            var fast: Dictionary=advance(10,80)[3]
            check(abs(slow.ph-lab.states[3].ph)>0.5,"Weak mixing does not prematurely reach bulk equilibrium")
            near(fast.ph,lab.states[3].ph,0.08,"Strong finite mixing approaches the independent equilibrium result")
            check(fast.heterogeneity<slow.heterogeneity,"Stronger exchange reduces spatial acid/base separation")
            report.facts={"weak_exchange_ph_after_10s":slow.ph,"strong_exchange_ph_after_10s":fast.ph,"equilibrium_ph":lab.states[3].ph,"weak_heterogeneity":slow.heterogeneity,"strong_heterogeneity":fast.heterogeneity}
        17:
            report.name="Tiny-time mass-action derivative and stoichiometric conservation"
            await neutral_pair()
            var before: Array=lab.core.save_session().kinetics[3]
            var dt: float=1e-13
            var predicted_extent: float=0
            # Saved zone volumes are L, inventories are mol and Kw is (mol/L)^2.
            # Thus k * (n_H*n_OH/V - Kw*V) is mol/s for each zone.
            for zone in [8,11]:
                predicted_extent+=1.4e11*(float(before[zone+1])*float(before[zone+2])/float(before[zone])-float(before[1])*float(before[zone]))*dt
            lab.core.advance_kinetics(dt,0)
            var after: Array=lab.core.save_session().kinetics[3]
            var old_totals: Array=ion_totals(before)
            var new_totals: Array=ion_totals(after)
            var extent: float=float(after[5])-float(before[5])
            near(extent,predicted_extent,max(1e-13,predicted_extent*0.0002),"Tiny-time extent matches the independently evaluated mass-action derivative")
            near(old_totals[0]-new_totals[0],extent,1e-12,"Reaction removes one H+ per neutralization event")
            near(old_totals[1]-new_totals[1],extent,1e-12,"Reaction removes one OH- per neutralization event")
            near(lab.core.kinetics_snapshot()[3].equivalent_error_mol,0,1e-10,"Reaction preserves H+ minus OH- equivalents")
            report.actions.append("Evaluate an independent mass-action derivative, then integrate 1e-13 s without exchange")
            report.facts={"dt_s":dt,"predicted_extent_mol":predicted_extent,"computed_extent_mol":extent,"recombination_k_l_mol_s":1.4e11}
        18:
            report.name="Paused clock and solver waits cannot create kinetic samples"
            await neutral_pair()
            var before: String=JSON.stringify(lab.core.save_session().kinetics)
            lab.refresh_kinetics(0.5)
            check(JSON.stringify(lab.core.save_session().kinetics)==before,"Paused laboratory does not advance chemistry")
            var history_before: String=JSON.stringify(lab.kinetic_history)
            check(lab.core.prepare(4,1,0,100,250),"Background solver job starts")
            lab.paused=false
            lab.refresh_kinetics(0.1)
            lab.paused=true
            check(JSON.stringify(lab.core.save_session().kinetics)==before,"Busy solver does not contribute fictitious reaction time")
            check(JSON.stringify(lab.kinetic_history)==history_before,"Busy solver does not contribute fictitious graph samples")
            await idle()
            report.actions.append("Invoke actual clock refresh while paused and while the native worker is busy")
            report.facts={"target_time_s":lab.core.kinetics_snapshot()[3].time_s,"target_history_points":lab.kinetic_history.get(3,[]).size()}
        19:
            report.name="Reset discards an in-flight preparation result"
            lab.select_vessel(1)
            lab.choose_reagent(5)
            lab.concentration.value=1
            lab.volume.value=200
            lab.prepare_selected()
            check(lab.core.is_busy(),"Preparation is pending when reset is requested")
            lab.reset_lab()
            lab.paused=true
            await idle()
            near(inventory(lab.states[1],"Cl"),0.00005,1e-11,"Queued reset restores default acid rather than stale KOH")
            near(inventory(lab.states[1],"K"),0,1e-12,"Stale worker cannot overwrite the reset vessel")
            check(lab.core.save_session().commands.is_empty(),"Reset drops the superseded science journal")
            check(lab.records.is_empty() and lab.curves.is_empty(),"Reset clears superseded view history")
            report.actions.append("Prepare a new stock and immediately request reset before consuming its result")
            report.facts={"acid_ph":lab.states[1].ph,"journal_entries":lab.core.save_session().commands.size(),"records":lab.records.size()}
        20:
            report.name="Changing titrant and repreparing it isolates volume history"
            await pour(1,3,25)
            await pour(2,3,25)
            check(lab.curve_sources[3]==2,"Switching source selects the new titrant")
            near(lab.total_added[3],25,1e-8,"New titrant volume excludes the prior acid transfer")
            check(lab.curves[3].size()==2 and lab.curves[3][0].x==0,"Changed titrant starts from a measured pre-transfer equilibrium point")
            await prepare(2,3,0.002,50)
            check(lab.curves[3].is_empty() and not lab.curve_sources.has(3),"Repreparing a titrant clears series tied to its old concentration")
            near(lab.total_added[3],0,1e-12,"Reprepared titrant starts at zero cumulative addition")
            report.facts={"reprepared_base_mol":inventory(lab.states[2],"Na"),"remaining_equilibrium_points":lab.curves[3].size(),"cumulative_addition_ml":lab.total_added[3]}
        21:
            report.name="Closed CO2 headspace obeys ideal gas and carbon conservation"
            var r: Dictionary=await batch(2,1)
            near(r.gas_pressure_atm*0.1,r.gas_co2_mmol/1000*0.082057366*298.15,2e-7,"Closed headspace independently obeys PV=nRT at 25 C")
            check(r.gas_co2_mmol>0 and r.gas_co2_mmol<0.1,"Added carbon partitions into both liquid and gas")
            near(inventory(r,"C")+r.gas_co2_mmol/1000,0.0001,1e-8,"Closed CO2 carbon equals the finite introduced dose")
            batch_balance(r)
            report.facts={"pressure_atm":r.gas_pressure_atm,"gas_co2_mmol":r.gas_co2_mmol,"dissolved_carbon_mol":inventory(r,"C"),"ph":r.ph}
        22:
            report.name="Open CO2 water follows an independent Henry-law pH estimate"
            var r: Dictionary=await batch(2,2)
            var h: float=sqrt(pow(10.0,-1.468)*0.00042*pow(10.0,-6.35))
            var predicted_ph: float=-log(h)/log(10.0)
            near(r.ph,predicted_ph,0.03,"Open CO2 pH matches the dilute Henry/first-dissociation approximation")
            check(r.co2_to_environment_mmol<0,"Open initially carbon-free water absorbs environmental carbon")
            near(inventory(r,"C")+r.co2_to_environment_mmol/1000,0,1e-8,"Open-system environmental exchange closes the carbon inventory")
            batch_balance(r)
            report.facts={"ph":r.ph,"independent_reference_ph":predicted_ph,"environment_exchange_mmol":r.co2_to_environment_mmol}
        23:
            report.name="Finite calcite dose exhausts without an infinite mineral reservoir"
            lab.switch_batch(false)
            var p: Dictionary={"base_reagent":1,"concentration":0,"volume_ml":100,"solid_reagent":18,"solid_mmol":0.0001,"gas_boundary":0,"co2_mmol":0,"headspace_ml":100,"external_co2_atm":0.00042}
            check(lab.core.run_batch(p),"Finite-dose native batch command is accepted")
            lab.batch_experiment.pending_parameters=p
            await idle()
            var r: Dictionary=lab.core.batch_snapshot()
            near(r.solid_remaining_mmol,0,1e-9,"Very small calcite dose dissolves completely")
            near(inventory(r,"Ca"),1e-7,1e-10,"Liquid calcium equals the entire finite calcite dose")
            near(inventory(r,"C"),1e-7,1e-10,"Liquid carbon equals the finite calcite dose")
            check(r.solid_si<0,"Exhausted finite calcite does not impose saturation")
            batch_balance(r)
            report.actions.append("Use the native finite-dose boundary for 0.0001 mmol calcite, below the coarse UI increment")
            report.facts={"dose_mmol":0.0001,"remaining_mmol":r.solid_remaining_mmol,"calcium_mol":inventory(r,"Ca"),"saturation_index":r.solid_si}
        24:
            report.name="Gypsum saturation and USGS solubility reference"
            var r: Dictionary=await batch(1,0)
            check(r.solid_remaining_mmol>0,"Finite gypsum stock leaves a solid phase")
            near(r.solid_si,0,1e-6,"Present gypsum is at equilibrium saturation")
            near(inventory(r,"Ca")+r.solid_remaining_mmol/1000,0.002,1e-8,"Gypsum calcium partitions between liquid and finite solid")
            lab.batch_experiment.extract()
            await idle()
            var s: Dictionary=lab.states[5]
            var molality: float=inventory(s,"Ca")/s.water_kg
            near(molality,0.0151,0.0003,"Gypsum matches the USGS PHREEQC Example 2 25 C molality reference")
            batch_balance(r)
            report.actions.append("Extract clear liquid to measure calcium per kilogram of actual solvent")
            report.facts={"calcium_mol_kgw":molality,"USGS_reference_mol_kgw":0.0151,"remaining_solid_mmol":r.solid_remaining_mmol,"solid_si":r.solid_si}
        25:
            report.name="Acid drives additional finite calcite dissolution"
            var water: Dictionary=await batch(0,0)
            var acid: Dictionary=await batch(0,0,1,0.01)
            check(acid.solid_remaining_mmol<water.solid_remaining_mmol-0.4,"Known acid equivalents dissolve more calcite than water")
            near(inventory(acid,"Ca")+acid.solid_remaining_mmol/1000,0.002,1e-8,"Acid dissolution preserves finite calcium inventory")
            near(inventory(acid,"Cl"),0.001,1e-10,"Acid chloride remains in the liquid inventory")
            batch_balance(acid)
            report.facts={"water_remaining_mmol":water.solid_remaining_mmol,"acid_remaining_mmol":acid.solid_remaining_mmol,"acid_ph":acid.ph,"calcium_mol":inventory(acid,"Ca")}
        26,27:
            report.name="Equal-ion barite precipitation with Ksp reference" if id==26 else "Sulfate-excess barite limiting-ion balance"
            var sulfate_ml: float=50 if id==26 else 100
            var r: Dictionary=await barite(sulfate_ml)
            var solid_mol: float=r.solid_remaining_mmol/1000
            check(solid_mol>0 and solid_mol<=0.00005+1e-10,"Barite is bounded by the limiting finite Ba inventory")
            near(inventory(r,"Ba")+solid_mol,0.00005,1e-9,"Barium closes across aqueous and precipitated phases")
            near(inventory(r,"S")+solid_mol,sulfate_ml*0.000001,1e-9,"Sulfur closes across aqueous and precipitated phases")
            near(r.solid_si,0,1e-7,"Present barite is at saturation")
            if id==26:
                var prediction: float=0.00005-sqrt(pow(10.0,-9.97))*0.1
                near(solid_mol,prediction,0.00005*0.03,"Dilute precipitation matches independent Ksp estimate within activity tolerance")
                report.facts.independent_ksp_precipitate_mol=prediction
            else:
                near(inventory(r,"S")-inventory(r,"Ba"),0.00005,1e-9,"Excess sulfate remains as the independently counted surplus")
            batch_balance(r)
            report.facts.merge({"precipitate_mmol":r.solid_remaining_mmol,"aqueous_barium_mol":inventory(r,"Ba"),"aqueous_sulfur_mol":inventory(r,"S"),"solid_si":r.solid_si})
        28:
            report.name="Clear-liquid extraction is finite and cannot be repeated"
            var r: Dictionary=await batch(1,0)
            lab.batch_experiment.extract()
            await idle()
            check(lab.states.has(5),"Extraction creates one receiving vessel")
            near(lab.states[5].volume_ml,r.volume_ml,1e-8,"Extraction transfers the entire clear-liquid volume")
            near(inventory(lab.states[5],"Ca"),inventory(r,"Ca"),1e-10,"Extraction preserves liquid calcium")
            near(lab.core.batch_snapshot().volume_ml,0,1e-12,"Extraction empties the batch liquid inventory")
            near(lab.core.batch_snapshot().solid_remaining_mmol,r.solid_remaining_mmol,1e-10,"Extraction leaves the solid phase in its original reactor")
            var before: String=JSON.stringify(lab.core.snapshot())
            var commands: int=lab.core.save_session().commands.size()
            lab.batch_experiment.extract()
            await idle()
            check(JSON.stringify(lab.core.snapshot())==before,"Repeated extraction cannot duplicate clear liquid")
            check(lab.core.save_session().commands.size()==commands,"Rejected repeated extraction does not enter the journal")
            check(not lab.states.has(6),"Repeated extraction cannot create a second receiving vessel")
            report.actions.append("Extract clear liquid, then request extraction a second time")
            report.facts={"extracted_volume_ml":lab.states[5].volume_ml,"remaining_reactor_volume_ml":lab.core.batch_snapshot().volume_ml,"remaining_solid_mmol":lab.core.batch_snapshot().solid_remaining_mmol,"repeat_rejection":lab.batch_experiment.status.text}
        _:
            check(false,"Chemistry module only handles rounds 1 through 28")
    return report
