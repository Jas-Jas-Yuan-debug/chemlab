extends RefCounted
# Called by the isolated headless driver with a fresh real laboratory scene.
# Every round uses existing control signals or application APIs and records
# observable facts, rather than counting repeated invocations of a whole suite.
const SessionIO = preload("res://scripts/session_io.gd")
var round_id: int
var actions: Array[String] = []
var checks: Array[String] = []
var facts: Dictionary = {}

func check(ok: bool, message: String) -> void:
    if not ok: push_error("Round %d: %s" % [round_id, message])
    assert(ok, "Round %d: %s" % [round_id, message])
    if ok: checks.append(message)

func idle(lab: Node3D) -> void:
    var deadline = Time.get_ticks_msec() + 15000
    while lab.core.is_busy() and Time.get_ticks_msec() < deadline:
        await lab.get_tree().process_frame
    check(not lab.core.is_busy(), "Native science operation finishes within 15 seconds")
    await lab.get_tree().process_frame

func click(lab: Node3D, name_value: String) -> void:
    var control = lab.get_tree().root.find_child(name_value, true, false)
    check(control is Button, "Actual control exists: " + name_value)
    actions.append("Press " + name_value)
    control.pressed.emit()
    await lab.get_tree().process_frame

func beginner(lab: Node3D) -> Variant:
    await click(lab, "BeginnerMode")
    lab.paused = true
    lab.beginner.sync_vessels()
    check(lab.beginner.active and not lab.main_ui.visible, "Beginner controls become active")
    return lab.beginner

func add_card(lab: Node3D, mode: Variant, definition: String) -> String:
    check(mode.definitions.has(definition), "Catalog definition exists: " + definition)
    mode.search.text = mode.definitions[definition].name
    mode.search.text_changed.emit(mode.search.text)
    var card = mode.cards.find_child("Card_" + definition, true, false)
    check(card is Button, "Actual catalog card exists: " + definition)
    actions.append("Choose catalog card " + definition)
    card.pressed.emit()
    await idle(lab)
    mode.sync_vessels()
    return mode.selected

func definition_named(mode: Variant, name_value: String) -> String:
    for item in mode.catalog:
        if item.name == name_value: return str(item.id)
    check(false, "Catalog contains " + name_value)
    return ""

func prepare(lab: Node3D, id: int, reagent: int, concentration: float, ml: float) -> void:
    lab.select_vessel(id)
    lab.choose_reagent(reagent)
    lab.concentration.value = concentration
    lab.volume.value = ml
    await click(lab, "PrepareSolution")
    await idle(lab)
    lab.paused = true
    check(lab.status.text.begins_with("已配制"), "Preparation completes through controls")

func pour(lab: Node3D, source: int, receiver: int, ml: float) -> void:
    lab.select_vessel(source)
    lab.target_id = receiver
    lab.amount.value = ml
    lab.paused = false
    await click(lab, "TransferAliquot")
    await idle(lab)
    lab.paused = true

func inventory_matches(before: Dictionary, after: Dictionary) -> void:
    check(before.vessels.size() == after.vessels.size(), "Vessel count survives operation")
    for i in before.vessels.size():
        var a = before.vessels[i]
        var b = after.vessels[i]
        check(a.id == b.id and abs(a.volume_ml - b.volume_ml) < 1e-7, "Canonical vessel identity and volume preserved")
        check(a.empirical_stock == b.empirical_stock, "Stock versus quantitative model preserved")
        check((a.ph == null) == (b.ph == null), "Availability of pH preserved")
        if a.ph != null: check(abs(a.ph - b.ph) < 1e-6, "Equilibrium pH preserved")
        for element in a.elements_mol:
            check(abs(a.elements_mol[element] - b.elements_mol[element]) < 1e-9, "Independent element inventory preserved: " + str(element))

func write_json(path: String, document: Dictionary) -> void:
    var file = FileAccess.open(path, FileAccess.WRITE)
    check(file != null, "Isolated evidence document can be written")
    file.store_string(JSON.stringify(document, "", true, true))
    file.close()

func roundtrip(lab: Node3D, suffix: String, compare_csv: bool = true) -> void:
    var path = "user://fifty-round-%d-%s.json" % [round_id, suffix]
    var csv_before = "user://fifty-round-%d-%s-before.csv" % [round_id, suffix]
    var csv_after = "user://fifty-round-%d-%s-after.csv" % [round_id, suffix]
    lab.paused = true
    lab.core.pause_bench()
    lab.core.pause_fall()
    var before = lab.core.snapshot()
    check(lab.save_to_path(path), "Save succeeds in isolated storage")
    if compare_csv: check(lab.export_to_path(csv_before), "CSV exports before reload")
    actions.append("Save, reload and compare " + suffix)
    check(lab.load_from_path(path), "Saved document starts loading")
    await idle(lab)
    check(lab.status.text.begins_with("实验已恢复"), "Saved document restores without error")
    inventory_matches(before, lab.core.snapshot())
    if compare_csv:
        check(lab.export_to_path(csv_after), "CSV exports after reload")
        check(FileAccess.get_file_as_string(csv_before) == FileAccess.get_file_as_string(csv_after), "CSV is byte-identical after actual save/load")
    facts["saved_path"] = path

func run_round(id: int, lab: Node3D) -> Dictionary:
    round_id = id
    actions.clear(); checks.clear(); facts.clear()
    await idle(lab)
    lab.paused = true
    var name_value = ""
    match id:
        37:
            name_value = "Beginner catalog search and unsupported preparation"
            var mode = await beginner(lab)
            check(mode.catalog.size() == 346, "All 173 apparatus, 143 dry materials and 30 reagents are browsable")
            mode.search.text = "圆底烧瓶"
            mode.search.text_changed.emit(mode.search.text)
            check(mode.cards.get_child_count() == 1, "Chinese apparatus search filters to the real flask")
            mode.search.text = "KOH"
            mode.search.text_changed.emit(mode.search.text)
            check(mode.cards.find_child("Card_reagent5", true, false) != null, "Formula search finds the aqueous KOH card")
            var before = lab.core.save_session().commands.size()
            await add_card(lab, mode, "reagent20")
            mode.select_object("v3")
            await click(lab, "BeginnerPrepare")
            await idle(lab)
            check(lab.core.save_session().commands.size() == before and lab.states[3].volume_ml == 0, "Unsupported ammonia preparation does not fabricate a scientific state")
            facts = {"catalog_count": mode.catalog.size(), "formula_search": "KOH", "unsupported_reagent": 20, "journal_count": before, "actual_scope_message": mode.message.text, "catalog_scope": mode.definitions.reagent20.scope}
            check(not mode.definitions.reagent20.operational and mode.definitions.reagent20.scope in mode.message.text and "尚未支持" in mode.message.text, "Unsupported preparation shows its boundary and declared scientific scope")
        38:
            name_value = "Dry material transfer, rotation, processing and balance reading"
            var mode = await beginner(lab)
            var stock = await add_card(lab, mode, "solid001")
            mode.chosen_target = "v3"; mode.dose.value = 2
            await click(lab, "BeginnerUse")
            check(abs(mode.objects[stock].state.mass_g - 8) < 1e-12 and abs(mode.objects.v3.state.contents.solid001 - 2) < 1e-12, "Two grams move from the ten-gram bottle into an empty vessel")
            await click(lab, "BeginnerRotate")
            check(abs(mode.objects[stock].state.rotation - PI / 4) < 1e-12, "Rotation changes the saved and actual apparatus orientation")
            var cutter = await add_card(lab, mode, "eq036")
            mode.chosen_target = "v3"
            await click(lab, "BeginnerUse")
            check(mode.objects.v3.state.scale == 0.5 and mode.objects.v3.state.contents.solid001 == 2, "Processing changes grain scale while retaining dry mass")
            var balance = await add_card(lab, mode, "eq061")
            mode.chosen_target = "v3"
            await click(lab, "BeginnerUse")
            check("2.00 g" in mode.message.text, "Real balance control reports the conserved two-gram sample")
            facts = {"source_mass_g": mode.objects[stock].state.mass_g, "sample_mass_g": mode.objects.v3.state.contents.solid001, "scale": mode.objects.v3.state.scale, "reading": mode.message.text, "tools": [cutter, balance]}
        39:
            name_value = "Scoop rejects unsolved solid into an occupied solution"
            var mode = await beginner(lab)
            var stock = await add_card(lab, mode, "solid001")
            mode.chosen_target = "v3"; mode.dose.value = 2
            await click(lab, "BeginnerUse")
            var spoon = await add_card(lab, mode, "eq016")
            mode.chosen_target = "v3"; mode.dose.value = 1
            await click(lab, "BeginnerUse")
            check(mode.objects[spoon].state.contents.solid001 == 1, "Scoop actually withdraws one gram")
            var native_before = lab.core.snapshot()
            mode.chosen_target = "v4"
            await click(lab, "BeginnerUse")
            check(mode.objects.v4.state.contents.is_empty(), "Occupied aqueous receiver does not acquire an unsolved solid")
            check(mode.objects[spoon].state.contents.solid001 == 1, "Rejected deposit retains the scoop inventory")
            inventory_matches(native_before, lab.core.snapshot())
            var dry_receiver = await add_card(lab, mode, definition_named(mode, "烧杯100mL"))
            mode.select_object(spoon); mode.chosen_target = dry_receiver
            await click(lab, "BeginnerUse")
            check(mode.objects[spoon].state.contents.is_empty() and mode.objects[dry_receiver].state.contents.solid001 == 1, "Scoop can still deposit into an empty dry receiver")
            check(mode.objects[stock].state.mass_g + mode.objects.v3.state.contents.solid001 + mode.objects[dry_receiver].state.contents.solid001 == 10, "Dry inventory remains ten grams through rejection and recovery")
            facts = {"wet_receiver_ml": lab.states[4].volume_ml, "wet_receiver_contents": mode.objects.v4.state.contents.duplicate(true), "original_dry_mass_g": mode.objects.v3.state.contents.solid001, "recovered_dry_mass_g": mode.objects[dry_receiver].state.contents.solid001, "recovery_receiver": dry_receiver}
        40:
            name_value = "Interface graph enforces duplicate and port capacity limits"
            var mode = await beginner(lab)
            var tube = await add_card(lab, mode, "eq019")
            mode.chosen_target = "v1"
            await click(lab, "BeginnerConnect")
            check(mode.links.size() == 1, "Tube connects to one vessel opening")
            await click(lab, "BeginnerConnect")
            check(mode.links.size() == 1, "Duplicate interface connection is rejected")
            var second = await add_card(lab, mode, "eq020")
            mode.chosen_target = "v1"
            await click(lab, "BeginnerConnect")
            check(mode.links.size() == 1, "Full receiving vessel opening rejects a second tube")
            mode.select_object(tube); mode.chosen_target = "v2"
            await click(lab, "BeginnerConnect")
            check(mode.links.size() == 2, "The second tube port supports another vessel")
            mode.chosen_target = "v3"
            await click(lab, "BeginnerConnect")
            check(mode.links.size() == 2, "A two-port tube rejects a third connection")
            await click(lab, "BeginnerDisconnect")
            check(mode.links.is_empty(), "Disconnect removes all connections of the selected apparatus")
            check(mode.validate_view(mode.save_view()).is_empty(), "Resulting interface graph is serializable")
            facts = {"first_tube": tube, "second_tube": second, "final_links": mode.links.duplicate(true)}
        41:
            name_value = "Transient pH measurement, attached-tool removal and workspace capacity"
            await prepare(lab, 1, 2, 0.001, 50)
            await prepare(lab, 2, 3, 0.001, 50)
            lab.mix_exchange.value = 0
            var mode = await beginner(lab)
            mode.select_object("v1"); mode.chosen_target = "v2"; mode.dose.value = 50
            await click(lab, "BeginnerUse")
            await idle(lab); lab.paused = true
            lab.kinetic_readings = lab.core.kinetics_snapshot()
            var probe = lab.kinetic_readings[2].ph
            var equilibrium = lab.states[2].ph
            check(abs(probe - equilibrium) > 1, "Zero-exchange sample has a distinguishable local and final-equilibrium pH")
            mode.select_object("v2"); mode.update_detail()
            check(("%.2f" % probe) in mode.reading.text, "Vessel detail uses the actual local probe")
            var meter = await add_card(lab, mode, "eq099")
            mode.chosen_target = "v2"
            await click(lab, "BeginnerUse")
            check(("pH %.2f" % probe) in mode.message.text, "The pH meter agrees with the current local probe, rather than final equilibrium")
            var stand = await add_card(lab, mode, "eq011")
            mode.chosen_target = meter
            await click(lab, "BeginnerAttach")
            check(meter in mode.objects[stand].state.attachments, "Measurement tool attaches to its stand")
            mode.select_object(meter)
            await click(lab, "BeginnerRemove")
            check(not mode.objects.has(meter) and meter not in mode.objects[stand].state.attachments, "Removing an attached empty tool clears every attachment reference")
            check(mode.validate_view(mode.save_view()).is_empty(), "Workspace still passes actual save validation after attached-tool removal")
            await roundtrip(lab, "attached-meter", false)
            mode = lab.beginner
            while mode.objects.size() < 59:
                await add_card(lab, mode, "eq016")
            var prior_count = lab.core.snapshot().vessels.size()
            var first_definition = definition_named(mode, "烧杯100mL")
            var second_definition = definition_named(mode, "烧杯250mL")
            mode.search.text = "烧杯"; mode.search.text_changed.emit(mode.search.text)
            var first_card = mode.cards.find_child("Card_" + first_definition, true, false)
            var second_card = mode.cards.find_child("Card_" + second_definition, true, false)
            check(first_card is Button and second_card is Button, "Two real vessel cards are available for pending-operation boundary")
            first_card.pressed.emit()
            check(lab.core.is_busy(), "First vessel creation occupies the actual native worker")
            second_card.pressed.emit()
            check(mode.pending_definition.id == first_definition, "Second vessel click while busy preserves the accepted apparatus definition")
            actions.append("At 59 objects choose 100mL then immediately 250mL while science worker is pending")
            await idle(lab); mode.sync_vessels()
            var count = lab.core.snapshot().vessels.size()
            check(mode.objects.size() == 60 and count == prior_count + 1 and lab.views[5].kind == "烧杯100mL", "Only the accepted vessel is created at the sixty-object boundary")
            await add_card(lab, mode, definition_named(mode, "烧杯100mL"))
            check(mode.objects.size() == 60 and lab.core.snapshot().vessels.size() == count, "Vessel creation respects the same sixty-object workspace limit")
            check(mode.validate_view(mode.save_view()).is_empty(), "Maximum-capacity workspace remains saveable")
            mode.select_object(stand);mode.chosen_target="v5"
            await click(lab,"BeginnerAttach")
            check("v5" in mode.objects[stand].state.attachments,"The extra scientific vessel can be supported")
            await click(lab,"AdvancedMode")
            lab.reset_lab();lab.paused=true;await idle(lab)
            await click(lab,"Add烧杯")
            await idle(lab);mode.sync_vessels()
            check(lab.states.size()==5 and mode.objects.size()==60,"Professional reset frees the stale vessel slot before another addition")
            check("v5" not in mode.objects[stand].state.attachments,"Reset removes obsolete scientific-vessel attachment references before ID reuse")
            check(mode.validate_view(mode.save_view()).is_empty(),"Reset and re-add leave a loadable attachment graph")
            await click(lab, "AdvancedMode")
            await click(lab, "Add烧杯"); await idle(lab)
            check(mode.objects.size() == 60 and lab.core.snapshot().vessels.size() == count, "Professional vessel-add control cannot bypass the shared workspace capacity")
            facts = {"local_probe_ph": probe, "equilibrium_ph": equilibrium, "remaining_attachment_count": mode.objects[stand].state.attachments.size(), "workspace_objects": mode.objects.size(), "native_vessels": count, "pending_creation_kind": lab.views[5].kind, "professional_cap_enforced": true}
        42:
            name_value = "Attachment reparenting forms a directed acyclic graph"
            var mode = await beginner(lab)
            var first = await add_card(lab, mode, "eq011")
            var second = await add_card(lab, mode, "eq009")
            var spoon = await add_card(lab, mode, "eq016")
            mode.select_object(first); mode.chosen_target = spoon
            await click(lab, "BeginnerAttach")
            mode.select_object(second); mode.chosen_target = spoon
            await click(lab, "BeginnerAttach")
            check(spoon not in mode.objects[first].state.attachments and spoon in mode.objects[second].state.attachments, "Reattachment gives an apparatus exactly one support")
            mode.select_object(second); mode.chosen_target = first
            await click(lab, "BeginnerAttach")
            var graph = mode.save_view().objects.duplicate(true)
            mode.select_object(first); mode.chosen_target = second
            await click(lab, "BeginnerAttach")
            check(mode.objects[first].state.attachments == graph[first].attachments and mode.objects[second].state.attachments == graph[second].attachments, "A cyclic support relation is rejected without changing the graph")
            check(mode.validate_view(mode.save_view()).is_empty(), "The real attached graph survives validation")
            await roundtrip(lab, "attachments", false)
            facts = {"first_support": first, "second_support": second, "child": spoon, "attachments": [{"id": first, "children": mode.objects[first].state.attachments.duplicate()}, {"id": second, "children": mode.objects[second].state.attachments.duplicate()}]}
        43:
            name_value = "Beginner, chemistry and physics mode switches preserve scientific inventory"
            await pour(lab, 1, 3, 12.5)
            var before = lab.core.snapshot()
            var mode = await beginner(lab)
            mode.select_object("v3")
            await click(lab, "BeginnerIndicator")
            await click(lab, "AdvancedMode")
            check(not mode.active and lab.main_ui.visible, "Advanced control returns to the professional workspace")
            await click(lab, "FreeFallTab")
            check(lab.physics_mode and not lab.views[3].visible, "Free-fall tab activates its real scene")
            await click(lab, "PhysicsBenchTab")
            check(lab.bench_mode and not lab.physics_mode, "Physics bench switches from free fall")
            await click(lab, "ChemistryTab")
            inventory_matches(before, lab.core.snapshot())
            check(lab.views[3].visible and lab.indicator_by_vessel[3] == 1, "Returning to chemistry retains vessel state and indicator")
            facts = {"volume_ml": lab.states[3].volume_ml, "indicator": lab.indicator_by_vessel[3], "chemistry_visible": lab.views[3].visible}
        44:
            name_value = "Professional drag collision, table bounds and release capture"
            lab.select_vessel(1); lab.drag_offset = Vector3.ZERO
            var original = lab.views[1].position
            lab.drag_to(lab.camera.unproject_position(lab.views[2].position))
            check(lab.views[1].position.distance_to(original) < 1e-8, "Dragging onto another vessel is rejected by actual collision logic")
            lab.drag_to(lab.camera.unproject_position(Vector3(2, 0.89, -2)))
            var placed = lab.views[1].position
            check(abs(placed.x) <= 0.580001 and placed.z >= -0.260001 and placed.z <= 0.290001 and abs(placed.y - 0.89) < 1e-7, "Off-table drag is clamped to the work surface")
            check(placed.distance_to(original) > 0.01, "Safe bounded drag actually moves the vessel")
            lab.dragging = true
            var release = InputEventMouseButton.new()
            release.button_index = MOUSE_BUTTON_LEFT; release.pressed = false
            lab._input(release)
            check(not lab.dragging, "Release ends dragging even when observed before GUI handling")
            check(SessionIO.validate(SessionIO.make_document(lab), lab).error.is_empty(), "Actual dragged geometry meets session placement constraints")
            var large_mode=await beginner(lab)
            await add_card(lab,large_mode,definition_named(large_mode,"烧杯1000mL"))
            await add_card(lab,large_mode,definition_named(large_mode,"烧杯1000mL"))
            await click(lab,"AdvancedMode")
            check(lab.views[5].position.distance_to(lab.views[6].position)>=lab.views[5].radius+lab.views[6].radius+0.013,"Large beakers receive distinct positions outside the saved collision footprints")
            await roundtrip(lab,"large-vessels",false)
            facts = {"start": [original.x, original.y, original.z], "placed": [placed.x, placed.y, placed.z], "dragging": lab.dragging}
        45:
            name_value = "Chemistry session and deterministic CSV roundtrip"
            await prepare(lab, 1, 2, 0.003, 40)
            await prepare(lab, 2, 3, 0.002, 60)
            await pour(lab, 1, 3, 20)
            await pour(lab, 2, 3, 30)
            lab.indicator_by_vessel[3] = 3
            lab.apply_indicators()
            check(abs(lab.states[3].elements_mol.Cl - 0.00006) < 1e-10 and abs(lab.states[3].elements_mol.Na - 0.00006) < 1e-10, "Aliquots deliver independently computed equal Na/Cl amounts")
            check(abs(lab.states[3].ph - 7) < 0.03, "Equal strong-electrolyte equivalents give neutral final equilibrium")
            await roundtrip(lab, "chemistry")
            check(lab.indicator_by_vessel[3] == 3 and lab.curves[3].size() == 2, "Indicator and two measured titration points restore")
            facts["receiver_ml"] = lab.states[3].volume_ml
            facts["equilibrium_ph"] = lab.states[3].ph
            facts["native_events"] = lab.core.save_session().events.size()
        46:
            name_value = "Initial, no-op and depleted titration baselines survive reload"
            # The receiving NaOH is untouched since the native reset. Its actual
            # x=0 reading must survive even though reset is absent from the journal.
            var initial_ph = lab.states[2].ph
            await pour(lab, 1, 2, 10)
            var curve = lab.curves[2].duplicate(true)
            var source = lab.curve_sources[2]
            var added = lab.total_added[2]
            check(curve.size() == 2 and curve[0].x == 0 and abs(curve[0].y - initial_ph) < 1e-6, "Untouched receiving solution contributes its actual initial x=0 reading")
            await roundtrip(lab, "initial-baseline")
            check(lab.curves[2] == curve, "Reset-defined initial baseline survives a journal-based reload")
            await pour(lab, 3, 2, 5)
            check(lab.curves[2] == curve and lab.curve_sources[2] == source and lab.total_added[2] == added, "Live no-op from another source leaves titration history unchanged")
            check(lab.core.save_session().events[-1].transferred_ml == 0, "The attempted empty pour is independently present as a zero-transfer event")
            await roundtrip(lab, "noop-curve")
            check(lab.curves[2] == curve and lab.curve_sources[2] == source and lab.total_added[2] == added, "Reload preserves the same source, curve and cumulative added amount after a no-op")
            await pour(lab, 2, 3, 250)
            check(lab.states[2].volume_ml == 0, "Receiver can be completely depleted through a bounded overdraw")
            await pour(lab, 4, 2, 5)
            var refilled = lab.curves[2].duplicate(true)
            check(refilled.size() == 1 and refilled[0].x > 0, "Refilling an empty receiver creates no invented initial pH reading")
            await roundtrip(lab, "depleted-refill")
            check(lab.curves[2] == refilled and lab.curves[2][0].x > 0, "Reload does not resurrect an old baseline after depletion and refill")
            facts["curve_points"] = curve.size()
            facts["curve_source"] = source
            facts["cumulative_ml"] = added
            facts["refilled_points"] = refilled.size()
            facts["refilled_first_volume_ml"] = refilled[0].x
        47:
            name_value = "Mixed stock, quantitative and non-equilibrium session restoration"
            await prepare(lab, 1, 5, 14.96, 25)
            await prepare(lab, 2, 2, 0.005, 50)
            await prepare(lab, 3, 3, 0.005, 50)
            lab.mix_exchange.value = 0
            await pour(lab, 2, 4, 20)
            await pour(lab, 3, 4, 20)
            lab.kinetic_readings = lab.core.kinetics_snapshot()
            var kinetic: Dictionary = lab.core.save_session().kinetics.duplicate(true)
            var local = lab.kinetic_readings[4].ph
            check(lab.states[1].empirical_stock and lab.states[1].ph == null, "Concentrated KOH stock exposes inventory without fictitious pH")
            check(lab.core.kinetics_snapshot().has(4) and not lab.core.kinetics_snapshot().has(1), "Only supported aqueous sample has dynamic state")
            await roundtrip(lab, "stock-dynamics")
            var restored_kinetic: Dictionary=lab.core.save_session().kinetics
            check(restored_kinetic.keys()==kinetic.keys(),"The same supported vessels restore kinetic state")
            var differences=[]
            for vessel_id in kinetic:
                for component in kinetic[vessel_id].size():
                    if kinetic[vessel_id][component]!=restored_kinetic[vessel_id][component]:
                        differences.append({"vessel":vessel_id,"component":component,"before":kinetic[vessel_id][component],"after":restored_kinetic[vessel_id][component]})
            facts["kinetic_roundtrip_differences"]=differences
            for difference in differences:
                check(abs(difference.before-difference.after)<=maxf(1e-20,absf(difference.before)*1e-12),"Kinetic component survives JSON within double precision: vessel %d component %d"%[difference.vessel,difference.component])
            check(abs(lab.kinetic_readings[4].ph - local) < 1e-10, "Local probe restores independently of final equilibrium")
            facts["stock_concentration_mol_l"] = 14.96
            facts["probe_ph"] = local
            facts["equilibrium_ph"] = lab.states[4].ph
        48:
            name_value = "Native model identity and failed replay preserve prior experiment"
            await pour(lab, 1, 3, 8)
            var original = lab.core.save_session()
            var before = lab.core.snapshot()
            for field in ["model_version", "database_sha256", "pitzer_sha256", "iphreeqc_version"]:
                var bad = original.duplicate(true)
                bad[field] = "corrupted"
                check(not lab.core.load_session(bad).is_empty(), "Native loader rejects incompatible " + field)
                check(lab.core.snapshot().revision == before.revision and not lab.core.is_busy(), "Rejected identity leaves revision and worker unchanged")
            var broken = original.duplicate(true)
            broken.commands.append({"operation": "pour", "parameters": {"from": 55, "to": 3, "amount_ml": 10}})
            check(lab.core.load_session(broken).is_empty(), "Structurally valid bad replay enters the real background worker")
            await idle(lab)
            check(lab.status.text.begins_with("加载失败"), "Background replay error reaches actual application status")
            inventory_matches(before, lab.core.snapshot())
            check(lab.core.snapshot().revision == before.revision and lab.core.save_session().commands.size() == original.commands.size(), "Failed replay retains journal and revision atomically")
            actions.append("Submit four incompatible identities and one invalid background replay")
            facts = {"revision": before.revision, "retained_commands": original.commands.size(), "status": lab.status.text}
        49:
            name_value = "Corrupt view files fail before changing live state"
            var mode = await beginner(lab)
            var valid = SessionIO.make_document(lab)
            check(SessionIO.validate(valid, lab).error.is_empty(), "Current real application document is valid")
            var before = lab.core.snapshot()
            var bad_documents: Array = []
            var missing = valid.duplicate(true)
            missing.view.beginner.objects.v1.attachments.append("missing-apparatus")
            bad_documents.append(missing)
            var outside = valid.duplicate(true)
            outside.view.equipment[0].position = [10, 0.89, 0]
            bad_documents.append(outside)
            var bad_curve = valid.duplicate(true)
            bad_curve.view.kinetic_history = {"1": [{"time_s": 0, "ph": 100, "upper_ph": 7, "rate_mol_s": 0}]}
            bad_documents.append(bad_curve)
            var bad_time = valid.duplicate(true)
            bad_time.view.elapsed_s = -1
            bad_documents.append(bad_time)
            for index in bad_documents.size():
                var path = "user://fifty-round-49-invalid-%d.json" % index
                write_json(path, bad_documents[index])
                check(not lab.load_from_path(path), "Actual file loader rejects corrupt view case %d" % index)
                check(not lab.core.is_busy() and lab.core.snapshot().revision == before.revision, "View rejection starts no science work and changes no revision")
                inventory_matches(before, lab.core.snapshot())
                check(mode.active and mode.objects.size() == 4, "Rejected file leaves the current beginner workspace intact")
            actions.append("Load attachment, placement, curve and time corruptions from isolated JSON files")
            facts = {"rejected_files": bad_documents.size(), "revision": before.revision, "workspace_objects": mode.objects.size()}
        50:
            name_value = "Repeated multi-mode use, reset and reload with stable scene ownership"
            var node_counts: Array[int] = []
            var journals: Array[int] = []
            for cycle in range(6):
                var mode = await beginner(lab)
                await click(lab, "BeginnerReset"); await idle(lab)
                lab.paused = true
                check(mode.objects.size() == 4 and mode.links.is_empty(), "Workspace reset removes prior auxiliary objects and links")
                mode.select_object("v1"); mode.chosen_target = "v3"; mode.dose.value = 2 + cycle
                await click(lab, "BeginnerUse"); await idle(lab); lab.paused = true
                check(abs(lab.states[3].volume_ml - (2 + cycle)) < 1e-7, "Each soak cycle transfers its own distinct aliquot")
                await add_card(lab, mode, "eq016")
                await click(lab, "AdvancedMode")
                await click(lab, "FreeFallTab")
                lab.fall_experiment.height_input.value = 0.5 + cycle * 0.1
                await click(lab, "ConfigureFall")
                await click(lab, "ReleaseBall")
                lab.core.pause_fall()
                await click(lab, "PhysicsBenchTab")
                lab.bench_experiment.picker.select(cycle % 5)
                lab.bench_experiment.picker.item_selected.emit(cycle % 5)
                await click(lab, "StartBench")
                await click(lab, "PauseBench")
                # Compare ownership in a common scene after exercising a
                # different model; geometry counts intentionally differ by model.
                lab.bench_experiment.picker.select(0)
                lab.bench_experiment.picker.item_selected.emit(0)
                await click(lab, "ChemistryTab")
                await roundtrip(lab, "soak-%d" % cycle, false)
                check(lab.paused and lab.states.size() == 4 and lab.beginner.objects.size() == 5, "Reload preserves this cycle and pauses all user state")
                journals.append(lab.core.save_session().commands.size())
                await lab.get_tree().process_frame
                await lab.get_tree().process_frame
                node_counts.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
            check(node_counts.max() - node_counts.min() < 50, "Scene ownership stays bounded across six complete use/reset/load cycles")
            check(journals.min() == 1 and journals.max() == 1, "Reset clears old native command history rather than accumulating prior cycles")
            facts = {"cycles": 6, "node_counts": node_counts, "native_journal_counts": journals, "renderer": DisplayServer.get_name(), "scope": "Headless controls, scientific state and scene ownership; rendered appearance/FPS not measured"}
        _:
            check(false, "Workflow round must be in 37..50")
    return {"id": id, "name": name_value, "actions": actions.duplicate(), "facts": facts.duplicate(true), "checks": checks.duplicate()}
