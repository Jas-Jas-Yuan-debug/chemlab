extends Node3D

const SessionIO = preload("res://scripts/session_io.gd")
const Room = preload("res://scripts/lab_room.gd")
const VesselView = preload("res://scripts/vessel.gd")
const Plot = preload("res://scripts/ph_plot.gd")
const Indicators = preload("res://scripts/indicators.gd")
const FallExperiment = preload("res://scripts/fall_experiment.gd")
var core: LabCore
var camera := Camera3D.new()
var views: Dictionary = {}
var states: Dictionary = {}
var selected_id := 1
var target_id := 3
var chosen_reagent := 2
var catalog: Array = []
var orbit := Vector2(0.10,0.50)
var distance := 0.92
var focus := Vector3(0,0.94,0)
var dragging := false
var drag_offset := Vector3.ZERO
var pouring := false
var paused := false
var pour_clock := 0.0
var elapsed := 0.0
var stream: MeshInstance3D
var last_transfer_ms := 0
var total_added: Dictionary = {}
var curves: Dictionary = {}
var records: Array = []
var operation_times: Array[float] = []
var pending_session := {}
var dialog_action := ""
var indicator_by_vessel: Dictionary = {}
var indicator_picker: OptionButton
var pending_context: Dictionary = {}
var next_kind := "烧杯"
var status: Label
var selected_title: Label
var readout: RichTextLabel
var reagent_title: Label
var source_title: Label
var status_badge: Label
var target_picker: OptionButton
var search: LineEdit
var category: OptionButton
var reagent_list: VBoxContainer
var concentration: SpinBox
var volume: SpinBox
var amount: SpinBox
var rate: SpinBox
var plot: Control
var pause_button: Button
var pour_button: Button
var file_dialog: FileDialog
var chemistry_panels: Array[Control] = []
var physics_mode := false
var fall_experiment: Node3D
var ui_theme: Theme
var batch_experiment: Node3D
var batch_mode := false
var bench_experiment: Node3D
var bench_mode := false

func _ready() -> void:
    add_child(Room.new())
    camera.fov = 42
    camera.near = 0.005
    camera.far = 30
    camera.current = true
    add_child(camera)
    update_camera()
    catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/reagents.json")).reagents
    build_ui()
    stream = MeshInstance3D.new()
    var flow_mesh := CylinderMesh.new()
    flow_mesh.top_radius = 0.0017
    flow_mesh.bottom_radius = 0.0012
    flow_mesh.height = 1
    stream.mesh = flow_mesh
    stream.material_override = Room.material(Color("a6d5d8"),0.1)
    stream.visible = false
    add_child(stream)
    core = LabCore.new()
    core.initialize("res://data/phreeqc.dat")
    fall_experiment = FallExperiment.new()
    fall_experiment.core = core
    fall_experiment.lab = self
    fall_experiment.ui_theme = ui_theme
    add_child(fall_experiment)
    batch_experiment = preload("res://scripts/batch_experiment.gd").new()
    batch_experiment.core = core
    batch_experiment.lab = self
    batch_experiment.ui_theme = ui_theme
    add_child(batch_experiment)
    bench_experiment = preload("res://scripts/physics_experiment.gd").new()
    bench_experiment.core = core
    bench_experiment.lab = self
    bench_experiment.ui_theme = ui_theme
    add_child(bench_experiment)
    set_status("正在准备实验台…")

func style(bg: Color, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_color = border
    s.set_border_width_all(1 if border.a>0 else 0)
    s.set_corner_radius_all(12)
    s.content_margin_left = 16
    s.content_margin_right = 16
    s.content_margin_top = 12
    s.content_margin_bottom = 12
    return s

func label(parent: Node, text: String, font_size: int = 16, color: Color = Color("dce6df")) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size",font_size)
    l.add_theme_color_override("font_color",color)
    parent.add_child(l)
    return l

func button(parent: Node,text: String,node_name: String,action: Callable) -> Button:
    var b := Button.new()
    b.name = node_name
    b.text = text
    b.custom_minimum_size.y = 38
    b.pressed.connect(action)
    parent.add_child(b)
    return b

func number(parent: Node,title: String,min_value: float,max_value: float,step: float,value: float,node_name: String) -> SpinBox:
    var row := HBoxContainer.new()
    parent.add_child(row)
    var l := label(row,title,14,Color("aabeb4"))
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var input := SpinBox.new()
    input.name = node_name
    input.min_value = min_value
    input.max_value = max_value
    input.step = step
    input.value = value
    input.custom_minimum_size = Vector2(140,36)
    row.add_child(input)
    return input

func panel(parent: Node,pos: Vector2,extent: Vector2) -> VBoxContainer:
    var p := PanelContainer.new()
    p.position = pos
    p.size = extent
    p.add_theme_stylebox_override("panel",style(Color(0.065,0.095,0.092,0.96),Color(0.6,0.8,0.7,0.16)))
    parent.add_child(p)
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation",10)
    p.add_child(box)
    return box

func build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var ui := Control.new()
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(ui)
    var theme := Theme.new()
    var font := SystemFont.new()
    font.font_names = PackedStringArray(["PingFang SC","Heiti SC"])
    theme.default_font = font
    theme.default_font_size = 15
    theme.set_stylebox("normal","Button",style(Color("233a34")))
    theme.set_stylebox("hover","Button",style(Color("355a4e"),Color("90cdb1")))
    theme.set_stylebox("pressed","Button",style(Color("476d5b")))
    theme.set_stylebox("disabled","Button",style(Color("202927")))
    theme.set_color("font_color","Button",Color("e8eee6"))
    theme.set_color("font_disabled_color","Button",Color("697c75"))
    ui.theme = theme
    ui_theme = theme
    var header := panel(ui,Vector2(24,20),Vector2(1552,70))
    var row := HBoxContainer.new()
    header.add_child(row)
    var name_text := label(row,"观物实验室  /  CHEMLAB",24,Color("f5e6c9"))
    name_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button(row,"化学实验","ChemistryTab",func(): switch_experiment(false))
    button(row,"自由落体","FreeFallTab",func(): switch_experiment(true))
    button(row,"溶解与气液","BatchTab",func(): switch_batch(false))
    button(row,"沉淀实验","PrecipitationTab",func(): switch_batch(true))
    button(row,"更多物理","PhysicsBenchTab",switch_bench)
    status_badge = label(row,"水溶液平衡  ·  25 °C  ·  已验证 17 / 30 项原料",14,Color("9ecdb8"))
    var left := panel(ui,Vector2(24,108),Vector2(274,822))
    chemistry_panels.append(left.get_parent())
    label(left,"实验材料",20,Color("f5e6c9"))
    label(left,"按名称、化学式或组别查找",13,Color("96aaa1"))
    search = LineEdit.new()
    search.name = "ReagentSearch"
    search.placeholder_text = "搜索，例如 HCl / 盐酸"
    search.custom_minimum_size.y = 36
    search.text_changed.connect(func(_text): refresh_reagents())
    left.add_child(search)
    category = OptionButton.new()
    for group in ["全部原料","基础组","扩展组","进阶组"]:
        category.add_item(group)
    category.item_selected.connect(func(_index): refresh_reagents())
    left.add_child(category)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(238,300)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left.add_child(scroll)
    reagent_list = VBoxContainer.new()
    reagent_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(reagent_list)
    label(left,"器材",18,Color("f5e6c9"))
    var equipment := GridContainer.new()
    equipment.columns = 2
    left.add_child(equipment)
    for kind in ["烧杯","量筒","滴管","试剂瓶"]:
        var b := button(equipment,"＋ "+kind,"Add"+kind,func(): add_vessel(kind))
        b.custom_minimum_size.x = 111
    label(left,"搅拌棒：暂仅可观察\n温度计 / pH 计：见对象读数",13,Color("96aaa1"))
    indicator_picker = OptionButton.new()
    for text in ["不加指示剂","酚酞","甲基橙","溴百里酚蓝"]:
        indicator_picker.add_item(text)
    indicator_picker.item_selected.connect(func(index):
        indicator_by_vessel[selected_id] = index
        apply_indicators()
        set_status("指示剂颜色为近似；忽略微量加入对溶液的影响。")
    )
    left.add_child(indicator_picker)
    var reset := button(left,"重新开始实验","ResetExperiment",reset_lab)
    reset.add_theme_color_override("font_color",Color("f1cea0"))
    var right := panel(ui,Vector2(1244,108),Vector2(332,822))
    chemistry_panels.append(right.get_parent())
    selected_title = label(right,"烧杯 1",21,Color("f5e6c9"))
    readout = RichTextLabel.new()
    readout.bbcode_enabled = true
    readout.custom_minimum_size = Vector2(298,64)
    readout.fit_content = true
    right.add_child(readout)
    source_title = label(right,"源：烧杯 1",14,Color("9ecdb8"))
    var target_row := HBoxContainer.new()
    right.add_child(target_row)
    label(target_row,"倒入",14)
    target_picker = OptionButton.new()
    target_picker.name = "TransferTarget"
    target_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    target_picker.item_selected.connect(func(index): target_id = target_picker.get_item_id(index))
    target_row.add_child(target_picker)
    amount = number(right,"单次加入 / mL",0.05,250,0.05,5,"AliquotMl")
    button(right,"加入指定体积","TransferAliquot",pour_once)
    rate = number(right,"倾倒流量 / mL·s⁻¹",0.1,20,0.1,5,"PourRate")
    pour_button = button(right,"按住连续倾倒","ContinuousPour",func(): pass)
    pour_button.button_down.connect(func(): pouring = true; pour_clock = 0.0)
    pour_button.button_up.connect(func(): pouring = false)
    pause_button = button(right,"暂停实验","PauseExperiment",toggle_pause)
    reagent_title = label(right,"配制：盐酸 HCl",16,Color("f5e6c9"))
    concentration = number(right,"浓度 / mol·L⁻¹",0.00001,0.01,0.00001,0.001,"Concentration")
    volume = number(right,"初始体积 / mL",1,250,1,50,"InitialVolume")
    button(right,"重新配制所选容器","PrepareSolution",prepare_selected)
    label(right,"pH — 累计加入体积",15,Color("f5e6c9"))
    plot = Plot.new()
    plot.custom_minimum_size = Vector2(298,132)
    right.add_child(plot)
    label(right,"固定 25°C · 充分混合后的平衡\n不模拟反应速率；暂不交换空气",12,Color("96aaa1"))
    var footer := panel(ui,Vector2(320,874),Vector2(902,94))
    status = label(footer,"",14,Color("e7e1d1"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label(footer,"左键选择并拖动  ·  右键环绕  ·  滚轮缩放  ·  F 聚焦所选器材",13,Color("9eb3a8"))
    var record_panel := panel(ui,Vector2(354,110),Vector2(842,62))
    var record_row := HBoxContainer.new()
    record_panel.add_child(record_row)
    label(record_row,"实验记录",15,Color("d1e5d7"))
    button(record_row,"保存","SaveSession",func(): open_session_dialog("save"))
    button(record_row,"加载","LoadSession",func(): open_session_dialog("load"))
    button(record_row,"导出 CSV","ExportCSV",func(): open_session_dialog("csv"))
    file_dialog = FileDialog.new()
    file_dialog.access = FileDialog.ACCESS_FILESYSTEM
    file_dialog.file_selected.connect(file_selected)
    ui.add_child(file_dialog)
    refresh_reagents()

func refresh_reagents() -> void:
    for child in reagent_list.get_children():
        reagent_list.remove_child(child)
        child.queue_free()
    var query := search.text.strip_edges().to_lower()
    for item in catalog:
        if category.selected>0 and item.category != category.get_item_text(category.selected):
            continue
        var searchable: String = (item.name_zh+" "+item.formula+" "+item.formula_ascii+" "+item.category).to_lower()
        if not query.is_empty() and query not in searchable:
            continue
        var b := button(reagent_list,item.name_zh+"  "+item.formula,"Reagent%d"%item.id,func(): choose_reagent(int(item.id)))
        b.alignment = HORIZONTAL_ALIGNMENT_LEFT
        b.disabled = not item.validation.operational
        b.tooltip_text = item.applicability
        if b.disabled:
            b.text += "  · 未支持"

func choose_reagent(id: int) -> void:
    if id in [10,18,19]:
        switch_batch()
        batch_experiment.solid_picker.selected = 2 if id==10 else 0 if id==18 else 1
        batch_experiment.boundary_picker.selected = 1 if id==10 else 0
        batch_experiment.gas_amount.value = 0.1 if id==10 else 0
        batch_experiment.update_inputs()
        return
    chosen_reagent = id
    var item: Dictionary = catalog[id-1]
    reagent_title.text = "配制："+item.name_zh+" "+item.formula
    concentration.editable = id!=1
    if id==1:
        set_status("蒸馏水预设：不含空气中的 CO₂，固定 25°C。")
    elif id>=7 and id not in [11,14]:
        set_status(item.name_zh+"目前仅支持预配稀溶液、自身混合与蒸馏水稀释。")
    else:
        set_status("已选择 "+item.name_zh+"，点击“重新配制所选容器”开始独立配液。")

func set_status(text: String) -> void:
    if status:
        status.text = text

func switch_experiment(physics: bool) -> void:
    bench_mode = false
    if bench_experiment:
        bench_experiment.set_active(false)
    batch_mode = false
    if batch_experiment:
        batch_experiment.set_active(false)
    pouring = false
    dragging = false
    physics_mode = physics
    for p in chemistry_panels:
        p.visible = not physics
    for v in views.values():
        v.visible = not physics
    fall_experiment.set_active(physics)
    focus = Vector3(0,1.85,0) if physics else Vector3(0,0.94,0)
    orbit = Vector2(0.1,0.18) if physics else Vector2(0.1,0.50)
    distance = 3.8 if physics else 0.92
    update_camera()
    status_badge.text = "力学实验  ·  忽略空气阻力" if physics else "水溶液平衡  ·  25 °C  ·  已验证 17 / 30 项原料"
    set_status("设置高度与重力，应用参数后释放小球。" if physics else "选择原料与器材，继续水溶液实验。")

func switch_batch(barite: bool = false) -> void:
    switch_experiment(false)
    batch_mode = true
    for p in chemistry_panels:
        p.visible = false
    for v in views.values():
        v.visible = false
    batch_experiment.set_barite(barite)
    batch_experiment.set_active(true)
    focus = Vector3(0.06,0.96,0)
    distance = 0.70
    update_camera()
    status_badge.text = "气液固平衡 · 25°C"
    set_status("每次配料定义独立试验；固体、清液和 CO₂ 分别记账。")

func switch_bench() -> void:
    switch_experiment(false)
    bench_mode = true
    for p in chemistry_panels:
        p.visible = false
    for v in views.values():
        v.visible = false
    bench_experiment.set_active(true)
    status_badge.text = "物理实验 · 独立模型"
    set_status("选择实验、应用参数，然后开始测量。")

func update_camera() -> void:
    camera.position = focus+Vector3(sin(orbit.x)*cos(orbit.y),sin(orbit.y),cos(orbit.x)*cos(orbit.y))*distance
    camera.look_at(focus,Vector3.UP)

func add_vessel(kind: String) -> void:
    if core.is_busy():
        set_status("请等待当前操作完成。")
        return
    if views.size()>=12:
        set_status("实验台最多放置 12 件容器。")
        return
    var id := 1
    while views.has(id):
        id+=1
    next_kind = kind
    var cap := 5.0 if kind=="滴管" else 100.0 if kind=="量筒" else 250.0
    pending_context = {"kind":kind,"id":id}
    core.add_empty(id,cap)

func ensure_view(state: Dictionary) -> void:
    var id: int = state.id
    if views.has(id):
        return
    var v := VesselView.new()
    var kind: String = pending_context.get("kind","试剂瓶" if id==4 else "烧杯")
    add_child(v)
    v.build(id,kind,state.capacity_ml)
    var column: int = (id-1)%4
    var row: int = (id-1)/4
    v.position = Vector3((column-1.5)*0.12,0.89,0.10-row*0.13)
    views[id] = v
    v.visible = not physics_mode

func select_vessel(id: int) -> void:
    selected_id = id
    for key in views:
        views[key].set_selected(key==id)
    if views.has(id):
        selected_title.text = "%s %d"%[views[id].kind,id]
        source_title.text = "源："+selected_title.text
        volume.max_value = min(250,views[id].capacity_ml)
    update_readout()
    indicator_picker.select(indicator_by_vessel.get(id,0))

func update_readout() -> void:
    if not states.has(selected_id):
        return
    var s: Dictionary = states[selected_id]
    var ph_text := "—" if s.ph==null else "%.2f"%s.ph
    readout.text = "[font_size=27][color=#cce8dc]%.2f mL[/color]   [color=#f0d39d]pH %s[/color][/font_size]\n[color=#a5b9ae]容量 %.0f mL    温度 25.0 °C[/color]"%[s.volume_ml,ph_text,s.capacity_ml]
    if indicator_by_vessel.get(selected_id,0)==1 and s.ph!=null and (s.ph<2 or s.ph>11.5):
        readout.text += "\n[color=#f0b785]酚酞：此 pH 的颜色未支持[/color]"
    plot.points.assign(curves.get(selected_id,[]))
    plot.queue_redraw()

func update_targets() -> void:
    target_picker.clear()
    for id in views:
        target_picker.add_item("%s %d"%[views[id].kind,id],id)
    var index := target_picker.get_item_index(target_id)
    if index>=0:
        target_picker.select(index)

func prepare_selected() -> void:
    if core.is_busy() or not views.has(selected_id):
        set_status("请等待当前操作完成。")
        return
    pouring = false
    var c := 0.0 if chosen_reagent==1 else concentration.value
    pending_context = {"reagent":chosen_reagent,"concentration":c,"volume_ml":volume.value,"id":selected_id}
    if core.prepare(selected_id,chosen_reagent,c,volume.value,views[selected_id].capacity_ml):
        set_status("正在配制…")

func pour_once() -> void:
    if paused:
        set_status("实验已暂停，继续后可加入。")
        return
    request_pour(amount.value)

func request_pour(ml: float) -> void:
    if selected_id==target_id:
        set_status("请选择另一个接收容器。")
        pouring = false
        return
    if core.is_busy():
        return
    pending_context = {}
    core.pour(selected_id,target_id,ml)

func toggle_pause() -> void:
    paused = not paused
    pouring = false
    pause_button.text = "继续实验" if paused else "暂停实验"
    set_status("实验已暂停。" if paused else "实验已继续。")

func reset_lab() -> void:
    pouring = false
    paused = false
    pending_context = {}
    core.reset_lab()
    pause_button.text = "暂停实验"
    set_status("正在重置实验…")

func apply_result(result: Dictionary) -> void:
    if result.operation=="load":
        if not result.error.is_empty():
            set_status("加载失败，原实验保留："+result.error)
        else:
            SessionIO.restore(self,pending_session,result.state)
            set_status("实验已恢复。已应用参数与状态均处于暂停，点击继续可运行。")
        pending_session = {}
        return
    if result.error.is_empty() and result.operation!="reset":
        operation_times.append(elapsed)
    if result.operation in ["batch","extract_batch"] or (batch_mode and not result.error.is_empty()):
        batch_experiment.accept_result(result)
        if result.operation=="batch" or not result.error.is_empty():
            return
    if not result.error.is_empty():
        pouring = false
        set_status(result.error)
        return
    if result.operation=="reset":
        batch_experiment.clear_trial()
        for v in views.values():
            v.queue_free()
        views.clear()
        curves.clear()
        total_added.clear()
        records.clear()
        operation_times.clear()
        indicator_by_vessel.clear()
        selected_id = 1
        target_id = 3
        elapsed = 0
    states.clear()
    for s in result.state.vessels:
        ensure_view(s)
        states[int(s.id)] = s
        views[int(s.id)].update_state(s)
        views[int(s.id)].visible = not batch_mode and not physics_mode and not bench_mode
    if result.operation=="pour":
        if result.transferred_ml>0:
            last_transfer_ms = Time.get_ticks_msec()
            var id: int = result.to
            total_added[id] = total_added.get(id,0.0)+result.transferred_ml
            if not curves.has(id):
                curves[id] = []
            if states[id].ph!=null:
                curves[id].append(Vector2(total_added[id],states[id].ph))
            records.append({"time_s":elapsed,"operation":"pour","from":result.from,"to":result.to,"volume_ml":result.transferred_ml,"ph":states[id].ph})
            set_status("已加入 %.2f mL → %s %d；接收液 pH %.2f"%[result.transferred_ml,views[id].kind,id,states[id].ph])
        else:
            pouring = false
            set_status("源容器已空或接收容器已满，倾倒已停止。")
    elif result.operation=="prepare":
        curves[result.to] = []
        total_added[result.to] = 0.0
        records.append(pending_context.duplicate())
        set_status("已配制 %.2f mL。当前容器开始一组新的初始条件。"%states[result.to].volume_ml)
    elif result.operation=="reset":
        set_status("实验台已就绪：盐酸与 NaOH 各 50 mL、0.001 mol/L，烧杯 3 为空。")
    elif result.operation=="add_empty":
        select_vessel(result.to)
        set_status("已添加 "+views[result.to].kind+"。")
    if result.operation=="extract_batch":
        for v in views.values():
            v.visible = not batch_mode
    pending_context = {}
    select_vessel(selected_id)
    update_targets()
    apply_indicators()

func apply_indicators() -> void:
    for id in states:
        if states[id].ph!=null:
            views[id].set_indicator(Indicators.color_for(indicator_by_vessel.get(id,0),states[id].ph))
    update_readout()

func _process(delta: float) -> void:
    if not core:
        return
    var result := core.poll()
    if result.get("ready",false):
        apply_result(result)
    if not paused:
        elapsed += delta
    if pouring and not paused:
        pour_clock += delta
        if pour_clock>=0.1 and not core.is_busy():
            request_pour(rate.value*pour_clock)
            pour_clock = 0.0
    if views.has(selected_id):
        for id in views:
            var goal := -0.7 if pouring and id==selected_id else 0.0
            views[id].visual.rotation.z = move_toward(views[id].visual.rotation.z,goal,delta*3)
    stream.visible = pouring and Time.get_ticks_msec()-last_transfer_ms<240 and views.has(target_id) and views.has(selected_id)
    if stream.visible:
        var a: Vector3 = views[selected_id].visual.to_global(Vector3(views[selected_id].radius,views[selected_id].height,0))
        var b: Vector3 = views[target_id].global_position+Vector3(0,0.04,0)
        stream.position = (a+b)/2
        stream.scale.y = a.distance_to(b)
        stream.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func drag_to(screen_position: Vector2) -> void:
    var plane := Plane(Vector3.UP,0.89)
    var point = plane.intersects_ray(camera.project_ray_origin(screen_position),camera.project_ray_normal(screen_position))
    if point==null:
        return
    point += drag_offset
    point.x = clampf(point.x,-0.58,0.58)
    point.z = clampf(point.z,-0.26,0.29)
    for id in views:
        if id!=selected_id and point.distance_to(views[id].position)<views[id].radius+views[selected_id].radius+0.014:
            return
    views[selected_id].position = point

func _input(event: InputEvent) -> void:
    # Observe release even when the pointer ends over a GUI panel.
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
        dragging = false
    elif event is InputEventMouseMotion and dragging and views.has(selected_id):
        drag_to(event.position)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_WHEEL_UP:
            distance = max(0.25,distance*0.9)
            update_camera()
        elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
            distance = min(2.8,distance*1.1)
            update_camera()
        elif event.button_index==MOUSE_BUTTON_LEFT:
            if physics_mode or batch_mode or bench_mode:
                return
            dragging = false
            if event.pressed:
                var origin := camera.project_ray_origin(event.position)
                var query := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*10)
                var hit := get_world_3d().direct_space_state.intersect_ray(query)
                if hit and hit.collider.has_meta("vessel_id"):
                    select_vessel(int(hit.collider.get_meta("vessel_id")))
                    dragging = true
                    var point = Plane(Vector3.UP,0.89).intersects_ray(origin,camera.project_ray_normal(event.position))
                    drag_offset = views[selected_id].position-point if point!=null else Vector3.ZERO
    elif event is InputEventMouseMotion:
        if event.button_mask&MOUSE_BUTTON_MASK_RIGHT:
            orbit += Vector2(-event.relative.x,-event.relative.y)*0.005
            orbit.y = clamp(orbit.y,0.16,1.30)
            update_camera()
    elif event is InputEventKey and event.pressed and event.keycode==KEY_F:
        if bench_mode:
            bench_experiment.frame_camera()
        elif batch_mode:
            focus = Vector3(0.06,0.96,0)
            distance = 0.7
            update_camera()
        elif views.has(selected_id):
            focus = fall_experiment.ball.global_position if physics_mode else views[selected_id].position+Vector3(0,0.045,0)
            distance = 0.60 if physics_mode else 0.38
            update_camera()

func open_session_dialog(action: String) -> void:
    if core.is_busy():
        set_status("请等待当前操作完成，再保存或加载。")
        return
    dialog_action = action
    file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if action=="load" else FileDialog.FILE_MODE_SAVE_FILE
    file_dialog.filters = PackedStringArray(["*.csv ; CSV 数据"] if action=="csv" else ["*.json ; ChemLab 实验"])
    file_dialog.current_file = "chemlab-data.csv" if action=="csv" else "chemlab-session.json"
    file_dialog.title = "导出实验数据" if action=="csv" else "加载实验" if action=="load" else "保存当前实验"
    file_dialog.popup_centered(Vector2i(1000,640))

func file_selected(path: String) -> void:
    if dialog_action=="load":
        load_from_path(path)
    elif dialog_action=="csv":
        export_to_path(path)
    else:
        save_to_path(path)

func save_to_path(path: String) -> bool:
    if core.is_busy():
        set_status("正在计算，请完成后再保存。")
        return false
    var error: String = SessionIO.save(self,path)
    set_status("已保存实验："+path if error.is_empty() else error)
    return error.is_empty()

func export_to_path(path: String) -> bool:
    if core.is_busy():
        set_status("正在计算，请完成后再导出。")
        return false
    var error: String = SessionIO.export_csv(self,path)
    set_status("已导出操作读数与保留的物理曲线："+path if error.is_empty() else error)
    return error.is_empty()

func load_from_path(path: String) -> bool:
    if core.is_busy():
        set_status("请等待当前操作完成后加载。")
        return false
    var file := FileAccess.open(path,FileAccess.READ)
    if file==null or file.get_length()>16*1024*1024:
        set_status("无法读取文件，或文件超过 16 MiB 限制。")
        return false
    var json := JSON.new()
    var error := json.parse(file.get_as_text())
    file.close()
    if error!=OK:
        set_status("JSON 格式错误；原实验保留。")
        return false
    var checked: Dictionary = SessionIO.validate(json.data,self)
    if not checked.error.is_empty():
        set_status(checked.error)
        return false
    var message := core.load_session(checked.document.science)
    if not message.is_empty():
        set_status(message)
        return false
    pending_session = checked
    set_status("正在恢复实验与操作记录…")
    return true
