extends Node3D
const Room = preload("res://scripts/lab_room.gd")
const Vessel = preload("res://scripts/vessel.gd")
const Plot = preload("res://scripts/measurement_plot.gd")
var core: LabCore
var lab: Node3D
var ui_theme: Theme
var active := false
var layer := CanvasLayer.new()
var reactor: Node3D
var lid: MeshInstance3D
var gas_cell: MeshInstance3D
var solid: MeshInstance3D
var base_picker: OptionButton
var solid_picker: OptionButton
var boundary_picker: OptionButton
var volume: SpinBox
var concentration: SpinBox
var solid_amount: SpinBox
var gas_amount: SpinBox
var headspace: SpinBox
var external_co2: SpinBox
var measurements: RichTextLabel
var status: Label
var plot: Control
var parameters: Dictionary = {}
var pending_parameters: Dictionary = {}
var samples: Array = []
var bubbles: Array[MeshInstance3D] = []
var bubble_time := 3.0
var barite_mode := false
var regular_controls: VBoxContainer
var precip_controls: VBoxContainer
var ba_volume: SpinBox
var ba_concentration: SpinBox
var sulfate_volume: SpinBox
var sulfate_concentration: SpinBox
var experiment_title: Label
var model_notes: Label

func choice(parent: Node,title: String,items: Array) -> OptionButton:
    lab.label(parent,title,14,Color("a5baaf"))
    var pick := OptionButton.new()
    for item in items:
        pick.add_item(item)
    parent.add_child(pick)
    return pick

func cylinder(radius: float,height: float,pos: Vector3,mat: Material) -> MeshInstance3D:
    var v := MeshInstance3D.new()
    var m := CylinderMesh.new()
    m.top_radius = radius
    m.bottom_radius = radius
    m.height = height
    v.mesh = m
    v.position = pos
    v.material_override = mat
    add_child(v)
    return v

func _ready() -> void:
    reactor = Vessel.new()
    add_child(reactor)
    reactor.build(0,"烧杯",250)
    reactor.name_label.text = "平衡反应器"
    reactor.position = Vector3(0,0.89,0)
    lid = cylinder(0.036,0.008,Vector3(0,0.994,0),Room.material(Color("4a6260"),0.3,0.6))
    var glass := ShaderMaterial.new()
    glass.shader = preload("res://shaders/glass.gdshader")
    gas_cell = cylinder(0.04,0.1,Vector3(0.16,0.97,0),glass)
    var gas_label := Label3D.new()
    gas_label.text = "CO₂ 顶空"
    gas_label.position = Vector3(0.16,1.10,0)
    gas_label.pixel_size = 0.0003
    gas_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    gas_cell.add_child(gas_label)
    gas_label.position = Vector3(0,0.08,0)
    solid = cylinder(0.020,0.001,Vector3(0,0.894,0),Room.material(Color("ece8db"),0.9))
    solid.visible = false
    for i in range(20):
        var bubble := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.0008+(i%3)*0.0003
        mesh.height = mesh.radius*2
        bubble.mesh = mesh
        bubble.material_override = glass
        bubble.visible = false
        add_child(bubble)
        bubbles.append(bubble)
    add_child(layer)
    var ui := Control.new()
    ui.theme = ui_theme
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(ui)
    var left: VBoxContainer = lab.panel(ui,Vector2(24,108),Vector2(300,752))
    experiment_title = lab.label(left,"溶解与 CO₂ 平衡",21,Color("f4deba"))
    regular_controls = VBoxContainer.new()
    left.add_child(regular_controls)
    base_picker = choice(regular_controls,"底液",["蒸馏水 H₂O","稀盐酸 HCl","NaHCO₃ 溶液","Na₂CO₃ 溶液"])
    volume = lab.number(regular_controls,"底液 / mL",10,250,1,100,"BatchVolume")
    concentration = lab.number(regular_controls,"浓度 / mol·L⁻¹",0.00001,0.01,0.00001,0.001,"BatchConcentration")
    solid_picker = choice(regular_controls,"有限固体",["方解石 CaCO₃","石膏 CaSO₄·2H₂O","不加固体"])
    solid_amount = lab.number(regular_controls,"固体 / mmol",0,5,0.01,2,"BatchSolid")
    boundary_picker = choice(regular_controls,"气相边界",["封闭液固 · 无气相","封闭 CO₂ · 定容顶空","开放 CO₂ · 固定外界条件"])
    gas_amount = lab.number(regular_controls,"加入 CO₂ / mmol",0,1,0.01,0,"BatchCO2")
    headspace = lab.number(regular_controls,"顶空 / mL",50,1000,10,100,"BatchHeadspace")
    external_co2 = lab.number(regular_controls,"外界 CO₂ / atm",0.0001,0.01,0.00001,0.00042,"BatchExternal")
    precip_controls = VBoxContainer.new()
    left.add_child(precip_controls)
    lab.label(precip_controls,"BaCl₂ + Na₂SO₄",20,Color("f4deba"))
    lab.label(precip_controls,"氯化钡水溶液",16)
    ba_volume = lab.number(precip_controls,"体积 / mL",1,125,1,50,"BariumVolume")
    ba_concentration = lab.number(precip_controls,"浓度 / mol·L⁻¹",0.00001,0.01,0.00001,0.001,"BariumConcentration")
    lab.label(precip_controls,"硫酸钠水溶液",16)
    sulfate_volume = lab.number(precip_controls,"体积 / mL",1,125,1,50,"SulfateVolume")
    sulfate_concentration = lab.number(precip_controls,"浓度 / mol·L⁻¹",0.00001,0.01,0.00001,0.001,"SulfateConcentration")
    var explanation: Label = lab.label(precip_controls,"仅选择重晶石 BaSO₄ 固相。
低于饱和条件时不会产生沉淀；
充分平衡，忽略成核与生长速率。
改变任一浓度或体积可检查过量效应。

清液分离后可向空容器分装，
不再模拟悬浊液分离过程。",14,Color("a5baaf"))
    explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    precip_controls.visible = false
    lab.button(left,"重新配料并达到平衡","RunBatch",run_trial)
    lab.button(left,"分离全部清液 → 新烧杯","ExtractBatch",extract)
    status = lab.label(left,"参数每次定义一组新的独立实验。",13,Color("e0cdab"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var right: VBoxContainer = lab.panel(ui,Vector2(1210,108),Vector2(366,750))
    lab.label(right,"最终平衡读数",22,Color("f4deba"))
    measurements = RichTextLabel.new()
    measurements.bbcode_enabled = true
    measurements.custom_minimum_size = Vector2(330,270)
    right.add_child(measurements)
    lab.label(right,"各次试验：加入量 — 剩余/生成固体",15,Color("d1e5d7"))
    plot = Plot.new()
    plot.custom_minimum_size = Vector2(330,145)
    plot.unit = "mmol"
    plot.x_unit = "mmol"
    plot.x_max = 5
    plot.y_max = 5
    right.add_child(plot)
    var notes: Label = lab.label(right,"固定 25°C，只计算最终平衡。\n固体按原料所选晶相达到平衡。\n封闭顶空仅含 CO₂，采用低压理想气体；\n忽略水蒸气、空气和溶液压力修正。\n开放模式记录与外界交换的 CO₂。\n\n白色固体体积由剩余量换算。\n气泡仅示意计算出的逸出量，动画时间\n不是反应时间，也不代表实际气泡个数。\n分离清液结束本次平衡实验。",13,Color("a5baaf"))
    notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    model_notes = notes
    model_notes.set_meta("gas_text",notes.text)
    base_picker.item_selected.connect(func(_i): update_inputs())
    solid_picker.item_selected.connect(func(_i): update_inputs())
    boundary_picker.item_selected.connect(func(_i): update_inputs())
    update_inputs()
    clear_trial()
    set_active(false)

func set_barite(value: bool) -> void:
    if value!=barite_mode:
        clear_trial()
    barite_mode = value
    experiment_title.text = "硫酸钡沉淀" if value else "溶解与 CO₂ 平衡"
    model_notes.text = "固定 25°C，充分混合后的最终平衡。\n仅选择重晶石固相，不模拟成核延迟。\n沉淀量与剩余离子由同一状态计算。\n\n白色沉淀体积按原数据库摩尔体积换算，\n采用薄层形状；不是实际颗粒沉降过程。\n清液分离结束本次平衡实验。" if value else model_notes.get_meta("gas_text")
    regular_controls.visible = not value
    precip_controls.visible = value
    plot.x_max = 1.25 if value else 5
    plot.y_max = 1.25 if value else 5

func update_inputs() -> void:
    concentration.editable = base_picker.selected!=0
    solid_amount.editable = solid_picker.selected<2
    gas_amount.editable = boundary_picker.selected>0
    headspace.editable = boundary_picker.selected==1
    external_co2.editable = boundary_picker.selected==2

func clear_trial() -> void:
    parameters.clear()
    pending_parameters.clear()
    samples.clear()
    plot.points.clear()
    plot.queue_redraw()
    reactor.update_state({"volume_ml":0,"ph":null})
    solid.visible = false
    gas_cell.visible = false
    lid.visible = false
    bubble_time = 3
    measurements.text = "选择条件并重新配料，
查看最终平衡状态。"
    status.text = "每次配料定义新的独立实验。"

func set_active(value: bool) -> void:
    active = value
    visible = value
    layer.visible = value

func run_trial() -> void:
    if core.is_busy():
        status.text = "请等待当前操作完成。"
        return
    var next := {"base_reagent":[1,2,8,9][base_picker.selected],"concentration":concentration.value,"volume_ml":volume.value,
        "solid_reagent":[18,19,0][solid_picker.selected],"solid_mmol":solid_amount.value if solid_picker.selected<2 else 0,
        "gas_boundary":boundary_picker.selected,"co2_mmol":gas_amount.value if boundary_picker.selected>0 else 0,
        "headspace_ml":headspace.value,"external_co2_atm":external_co2.value}
    if barite_mode:
        next = {"barite":true,"base_reagent":25,"concentration":ba_concentration.value,"volume_ml":ba_volume.value,
            "sulfate_concentration":sulfate_concentration.value,"sulfate_ml":sulfate_volume.value,
            "solid_mmol":sulfate_concentration.value*sulfate_volume.value,"solid_reagent":0,"gas_boundary":0,"co2_mmol":0,"headspace_ml":100}
    if core.run_batch(next):
        pending_parameters = next
        status.text = "正在计算最终平衡；完成后更新反应器。"

func extract() -> void:
    if parameters.is_empty():
        status.text = "请先完成当前实验的配料和平衡。"
        return
    if core.is_busy():
        return
    var id := 1
    while lab.states.has(id):
        id += 1
    if id>12:
        status.text = "实验台已满。"
        return
    core.extract_batch(id)

func accept_result(result: Dictionary) -> void:
    if not result.error.is_empty():
        status.text = result.error
        return
    var r := core.batch_snapshot()
    if r.is_empty():
        return
    reactor.update_state(r)
    if result.operation=="extract_batch":
        measurements.text += "\n\n[color=#efc782]清液已分离至烧杯 %d；本次平衡实验结束。[/color]"%result.to
        status.text = "清液已分离；切换化学实验可测量与转移。固体和气相留在反应器。"
        return
    parameters = pending_parameters.duplicate(true)
    samples.append({"parameters":parameters.duplicate(true),"reading":r.duplicate(true)})
    plot.points.append(Vector2(parameters.solid_mmol,r.solid_remaining_mmol))
    plot.queue_redraw()
    measurements.text = "[font_size=25]pH %.2f  ·  %.2f mL[/font_size]\n\n"%[r.ph,r.volume_ml]
    measurements.text += "固体加入  %.3f mmol\n固体剩余  %.3f mmol\n液相 Ca  %.3f mmol\n"%[parameters.solid_mmol,r.solid_remaining_mmol,r.elements_mol.get("Ca",0)*1000]
    if r.mineral=="Barite":
        measurements.text = "[font_size=25]pH %.2f  ·  %.2f mL[/font_size]\n\n"%[r.ph,r.volume_ml]
        measurements.text += "BaCl₂ 加入  %.3f mmol\nNa₂SO₄ 加入  %.3f mmol\n\nBaSO₄ 沉淀  %.4f mmol\n溶液 Ba  %.4f mmol\n溶液 S  %.4f mmol\n"%[parameters.concentration*parameters.volume_ml,parameters.solid_mmol,r.solid_remaining_mmol,r.elements_mol.get("Ba",0)*1000,r.elements_mol.get("S",0)*1000]
    if parameters.gas_boundary==1:
        measurements.text += "\n顶空 CO₂  %.4f mmol\nCO₂ 压力  %.5f atm\n"%[r.gas_co2_mmol,r.gas_pressure_atm]
    elif parameters.gas_boundary==2:
        measurements.text += "\n向外界释放 CO₂  %.4f mmol\n（负值表示从外界吸收）\n"%r.co2_to_environment_mmol
    measurements.text += "\n[color=#98cbb0]元素与 H / O 收支通过[/color]"
    lid.visible = parameters.gas_boundary!=2
    gas_cell.visible = parameters.gas_boundary==1
    gas_cell.mesh.height = parameters.headspace_ml*0.000001/(PI*0.04*0.04)
    gas_cell.position.y = 0.89+gas_cell.mesh.height/2
    solid.visible = r.solid_remaining_mmol>0.000001
    var molar_volume := 52.9 if r.mineral=="Barite" else 36.9 if parameters.solid_reagent==18 else 73.9
    var solid_height: float = r.solid_remaining_mmol/1000*molar_volume*0.000001/(PI*0.02*0.02)
    solid.mesh.height = maxf(solid_height,0.000001)
    solid.position.y = 0.8931+solid_height/2
    bubble_time = 0
    var evolved: float = maxf(0,r.co2_to_environment_mmol) if parameters.gas_boundary==2 else maxf(0,r.gas_co2_mmol-parameters.co2_mmol)
    for i in bubbles.size():
        bubbles[i].visible = i<mini(20,int(ceil(evolved*1000)))
    status.text = "本次平衡已完成；可改变加入量重复试验，或分离清液。"

func _process(delta: float) -> void:
    if not active:
        return
    bubble_time += delta
    for i in bubbles.size():
        if bubble_time>2:
            bubbles[i].visible = false
        if bubbles[i].visible:
            var t := fmod(bubble_time*0.6+i*0.13,1.0)
            bubbles[i].position = Vector3(sin(i*2.4)*0.018,0.894+reactor.liquid_height*t,cos(i*2.4)*0.018)
