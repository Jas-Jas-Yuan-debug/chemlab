extends RefCounted
const FORMAT = "ChemLab"
const KIND_CAPACITY = {"烧杯":250.0,"试剂瓶":250.0,"量筒":100.0,"滴管":5.0}
const KIND_RADIUS = {"烧杯":0.033,"试剂瓶":0.032,"量筒":0.020,"滴管":0.008}

static func finite(value: Variant) -> bool:
    return typeof(value) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(value))

static func make_document(lab: Node3D) -> Dictionary:
    var equipment := []
    for id in lab.views:
        var v = lab.views[id]
        equipment.append({"id":id,"kind":v.kind,"position":[v.position.x,v.position.y,v.position.z],"indicator":lab.indicator_by_vessel.get(id,0)})
    var fall_times := []
    for sample in lab.fall_experiment.samples:
        fall_times.append({"time_s":sample.time_s,"running":sample.running})
    var bench_history := []
    for sample in lab.bench_experiment.samples:
        bench_history.append({"parameters":sample.parameters.duplicate(true),"time_s":sample.time_s,"running":sample.running})
    var mode := "bench" if lab.bench_mode else "fall" if lab.physics_mode else "barite" if lab.batch_mode and lab.batch_experiment.barite_mode else "batch" if lab.batch_mode else "chemistry"
    return {"format":FORMAT,"view_schema":1,"science":lab.core.save_session(),"view":{
        "equipment":equipment,"selected_id":lab.selected_id,"target_id":lab.target_id,"mode":mode,
        "elapsed_s":lab.elapsed,"operation_times":lab.operation_times.duplicate(),
        "focus":[lab.focus.x,lab.focus.y,lab.focus.z],"orbit":[lab.orbit.x,lab.orbit.y],"distance":lab.distance,
        "fall_times":fall_times,"bench_history":bench_history}}

static func validate(document: Variant,lab: Node3D) -> Dictionary:
    if not document is Dictionary or document.get("format")!=FORMAT or document.get("view_schema")!=1 or not document.get("science") is Dictionary or not document.get("view") is Dictionary:
        return {"error":"不是兼容的 ChemLab 实验文件。"}
    var science: Dictionary = document.science
    var v: Dictionary = document.view
    if not science.get("commands") is Array or not science.get("fall") is Dictionary or not science.get("bench") is Dictionary:
        return {"error":"科学状态不完整。"}
    if not v.get("equipment") is Array or v.equipment.size()>12 or v.equipment.size()<4:
        return {"error":"器材记录不完整或超出数量限制。"}
    var expected := {1:250.0,2:250.0,3:250.0,4:250.0}
    for command in science.commands:
        if not command is Dictionary or not command.get("parameters") is Dictionary:
            return {"error":"操作记录格式错误。"}
        if command.get("operation") in ["prepare","add_empty","extract_batch"]:
            var id = command.parameters.get("to") if command.operation=="extract_batch" else command.parameters.get("id")
            if not finite(id) or id!=floor(id) or id<1 or id>12:
                return {"error":"操作记录包含无效器材编号。"}
            expected[int(id)] = 250 if command.operation=="extract_batch" else command.parameters.get("capacity_ml",0)
    var positions := {}
    var radii := {}
    for item in v.equipment:
        if not item is Dictionary or not finite(item.get("id")) or item.id!=floor(item.id) or not KIND_CAPACITY.has(item.get("kind")):
            return {"error":"器材类型或编号无效。"}
        var id := int(item.id)
        if positions.has(id) or not expected.has(id) or expected[id]!=KIND_CAPACITY[item.kind]:
            return {"error":"器材容量或编号与科学状态不匹配。"}
        if not item.get("position") is Array or item.position.size()!=3:
            return {"error":"器材位置格式错误。"}
        for x in item.position:
            if not finite(x):
                return {"error":"器材位置不是有效数值。"}
        var point := Vector3(item.position[0],item.position[1],item.position[2])
        if abs(point.x)>0.581 or point.z< -0.261 or point.z>0.291 or abs(point.y-0.89)>0.00001:
            return {"error":"器材位置超出实验台范围。"}
        if not finite(item.get("indicator")) or item.indicator!=floor(item.indicator) or item.indicator<0 or item.indicator>3:
            return {"error":"指示剂记录无效。"}
        for other in positions:
            if point.distance_to(positions[other])<KIND_RADIUS[item.kind]+radii[other]+0.013:
                return {"error":"保存文件中的器材发生重叠。"}
        positions[id] = point
        radii[id] = KIND_RADIUS[item.kind]
    if not finite(v.get("selected_id")) or not finite(v.get("target_id")) or v.selected_id!=floor(v.selected_id) or v.target_id!=floor(v.target_id):
        return {"error":"器材选择编号无效。"}
    if positions.size()!=expected.size() or not positions.has(int(v.selected_id)) or not positions.has(int(v.target_id)):
        return {"error":"器材选择或清单不完整。"}
    if v.get("mode") not in ["chemistry","fall","batch","barite","bench"] or not finite(v.get("elapsed_s")) or v.elapsed_s<0 or v.elapsed_s>86400:
        return {"error":"实验模式或时间无效。"}
    if not v.get("operation_times") is Array or v.operation_times.size()!=science.commands.size():
        return {"error":"操作时间记录不完整。"}
    var last_time := 0.0
    for t in v.operation_times:
        if not finite(t) or t<last_time or t>v.elapsed_s+0.01:
            return {"error":"操作时间顺序无效。"}
        last_time = t
    if not v.get("focus") is Array or v.focus.size()!=3 or not v.get("orbit") is Array or v.orbit.size()!=2 or not finite(v.get("distance")) or v.distance<0.25 or v.distance>6:
        return {"error":"观察视角记录无效。"}
    for x in v.focus+v.orbit:
        if not finite(x) or abs(x)>1000:
            return {"error":"观察视角超出范围。"}
    if not v.get("fall_times") is Array or v.fall_times.size()>2400 or not v.get("bench_history") is Array or v.bench_history.size()>1200:
        return {"error":"曲线记录超出范围。"}
    var f: Dictionary = science.fall
    if not finite(f.get("initial_height_m")) or not finite(f.get("gravity_m_s2")) or not finite(f.get("time_s")):
        return {"error":"自由落体参数不完整。"}
    var fall_history := []
    for item in v.fall_times:
        if not item is Dictionary or not item.get("running") is bool or not finite(item.get("time_s")):
            return {"error":"自由落体曲线记录无效。"}
        var t: float = item.time_s
        if not finite(t) or t<0 or t>f.time_s+0.00001:
            return {"error":"自由落体曲线时间无效。"}
        var r: Dictionary = lab.core.preview_fall(f.initial_height_m,f.gravity_m_s2,t)
        if r.has("error"):
            return {"error":r.error}
        r.running = item.running
        fall_history.append(r)
    var b: Dictionary = science.bench
    if not b.get("kind") is String:
        return {"error":"物理实验类型缺失。"}
    var bench_history := []
    for item in v.bench_history:
        if not item is Dictionary or not item.get("parameters") is Dictionary or not finite(item.get("time_s")) or not finite(item.get("running")) or (item.running!=0 and item.running!=1):
            return {"error":"物理曲线记录无效。"}
        var r: Dictionary = lab.core.preview_bench(b.kind,item.parameters,item.time_s,bool(item.running))
        if r.has("error"):
            return {"error":r.error}
        bench_history.append(r)
    return {"error":"","document":document,"fall_history":fall_history,"bench_history":bench_history}

static func restore(lab: Node3D,validated: Dictionary,state: Dictionary) -> void:
    var v: Dictionary = validated.document.view
    for view in lab.views.values():
        lab.remove_child(view)
        view.queue_free()
    lab.views.clear()
    lab.states.clear()
    lab.indicator_by_vessel.clear()
    var equipment := {}
    for item in v.equipment:
        equipment[int(item.id)] = item
    for s in state.vessels:
        var item: Dictionary = equipment[int(s.id)]
        lab.pending_context = {"kind":item.kind}
        lab.ensure_view(s)
        lab.states[int(s.id)] = s
        lab.views[int(s.id)].update_state(s)
        lab.views[int(s.id)].position = Vector3(item.position[0],item.position[1],item.position[2])
        lab.indicator_by_vessel[int(s.id)] = int(item.indicator)
    lab.pending_context = {}
    lab.elapsed = v.elapsed_s
    lab.operation_times.assign(v.operation_times)
    lab.curves.clear()
    lab.total_added.clear()
    lab.records.clear()
    var native: Dictionary = lab.core.save_session()
    var batch_parameters := {}
    var batch_history := []
    for i in native.events.size():
        var event: Dictionary = native.events[i]
        var parameters: Dictionary = native.commands[i].parameters
        if event.operation=="prepare":
            lab.curves[int(event.to)] = []
            lab.total_added[int(event.to)] = 0.0
        elif event.operation=="pour":
            var id := int(event.to)
            lab.total_added[id] = lab.total_added.get(id,0.0)+event.transferred_ml
            if not lab.curves.has(id):
                lab.curves[id] = []
            if event.readings.has("ph"):
                lab.curves[id].append(Vector2(lab.total_added[id],event.readings.ph))
        elif event.operation=="batch":
            batch_parameters = parameters
            batch_history.append({"parameters":parameters,"reading":event.readings})
    lab.selected_id = int(v.selected_id)
    lab.target_id = int(v.target_id)
    lab.paused = true
    lab.pouring = false
    lab.dragging = false
    lab.pause_button.text = "继续实验"
    match v.mode:
        "fall": lab.switch_experiment(true)
        "batch": lab.switch_batch(false)
        "barite": lab.switch_batch(true)
        "bench": lab.switch_bench()
        _: lab.switch_experiment(false)
    lab.fall_experiment.restore_view(lab.core.fall_snapshot(),validated.fall_history)
    lab.bench_experiment.restore_view(lab.core.bench_snapshot(),validated.bench_history)
    lab.batch_experiment.restore_view(batch_parameters,batch_history)
    lab.focus = Vector3(v.focus[0],v.focus[1],v.focus[2])
    lab.orbit = Vector2(v.orbit[0],v.orbit[1])
    lab.distance = v.distance
    lab.update_camera()
    lab.select_vessel(lab.selected_id)
    lab.update_targets()
    lab.apply_indicators()

static func save(lab: Node3D,path: String) -> String:
    var text := JSON.stringify(make_document(lab),"\t",true,true)
    var temporary := path+".chemlab-tmp-%d"%Time.get_ticks_usec()
    var file := FileAccess.open(temporary,FileAccess.WRITE)
    if file==null:
        return "无法写入保存文件。"
    file.store_string(text)
    file.flush()
    var error := file.get_error()
    file.close()
    if error!=OK:
        return "写入未完成；上一份保存文件保留。"
    error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
    return "" if error==OK else "无法完成保存文件替换，临时文件已保留。"

static func export_csv(lab: Node3D,path: String) -> String:
    var native: Dictionary = lab.core.save_session()
    var rows := []
    for i in native.events.size():
        var e: Dictionary = native.events[i]
        var row: Dictionary = e.readings.duplicate(true)
        row.merge({"section":"chemistry","step":i+1,"operation":e.operation,"from":e.from,"to":e.to,
            "time_s":lab.operation_times[i],"transferred_ml":e.transferred_ml,"parameters_json":parameters_json(native.commands[i].parameters)},true)
        rows.append(row)
    for r in lab.fall_experiment.samples:
        var row: Dictionary = r.duplicate(true)
        row.section = "free_fall"
        rows.append(row)
    for r in lab.bench_experiment.samples:
        var row: Dictionary = r.duplicate(true)
        row.section = r.kind
        row.parameters_json = parameters_json(row.parameters)
        row.erase("parameters")
        rows.append(row)
    var headings: Array[String] = ["section","step","operation","from","to","time_s","transferred_ml","volume_ml","ph","temperature_c","parameters_json"]
    for row in rows:
        for key in row:
            if key not in headings:
                headings.append(key)
    headings.append("model_version")
    headings.append("database_sha256")
    var temporary := path+".chemlab-tmp-%d"%Time.get_ticks_usec()
    var file := FileAccess.open(temporary,FileAccess.WRITE)
    if file==null:
        return "无法写入 CSV。"
    file.store_csv_line(PackedStringArray(headings))
    for row in rows:
        row.model_version = native.model_version
        row.database_sha256 = native.database_sha256
        var values := PackedStringArray()
        for key in headings:
            var value = row.get(key,"")
            values.append(csv_number(value) if finite(value) else str(value))
        file.store_csv_line(values)
    file.flush()
    var error := file.get_error()
    file.close()
    if error!=OK:
        return "CSV 写入失败；原文件保留。"
    error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
    return "" if error==OK else "CSV 临时文件已保存，但替换目标失败。"

# Stable, at most ten significant digits for CSV; model precision is separate.
static func csv_number(value: float) -> String:
    if value==0:
        return "0"
    var exponent := int(floor(log(absf(value))/log(10.0)))
    var mantissa := value/pow(10.0,exponent)
    var text := String.num(mantissa,9)
    if absf(float(text))>=10.0:
        text = "1" if value>0 else "-1"
        exponent += 1
    return text+"e"+str(exponent)

static func parameters_json(parameters: Dictionary) -> String:
    var keys := parameters.keys()
    keys.sort()
    var entries := PackedStringArray()
    for key in keys:
        var value = parameters[key]
        entries.append(JSON.stringify(key)+":"+(csv_number(float(value)) if finite(value) or value is bool else JSON.stringify(value)))
    return "{"+",".join(entries)+"}"
