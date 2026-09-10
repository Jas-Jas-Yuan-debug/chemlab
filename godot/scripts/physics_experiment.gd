extends Node3D
const Room = preload("res://scripts/lab_room.gd")
const Plot = preload("res://scripts/measurement_plot.gd")
const Heater = preload("res://scripts/heater_apparatus.gd")
const KINDS = ["spring","pendulum","heat","circuit","lens","heater"]
const NAMES = ["弹簧简谐运动","小角度单摆","隔离体系热交换","直流电路","薄透镜成像","加热与搅拌"]
# key, label, min, max, step, default
const FIELDS = [
    [["mass_kg","质量 / kg",0.05,2,0.05,0.2],["stiffness_n_m","劲度 / N·m⁻¹",0.5,50,0.5,8],["amplitude_m","振幅 / m",0.01,0.2,0.01,0.1]],
    [["length_m","摆长 / m",0.1,1.5,0.05,0.8],["gravity_m_s2","重力 / m·s⁻²",0.1,20,0.01,9.80665],["angle_deg","初始角 / °",1,10,0.5,8],["mass_kg","质量 / kg",0.05,1,0.05,0.2]],
    [["mass1_kg","水 1 / kg",0.05,1,0.05,0.1],["mass2_kg","水 2 / kg",0.05,1,0.05,0.1],["temperature1_c","初温 1 / °C",5,90,1,70],["temperature2_c","初温 2 / °C",5,90,1,20],["conductance_w_k","热导 / W·K⁻¹",0.1,20,0.1,10]],
    [["voltage_v","电压 / V",0,12,0.1,6],["resistance1_ohm","电阻 1 / Ω",1,1000,1,100],["resistance2_ohm","电阻 2 / Ω",1,1000,1,200]],
    [["focal_m","焦距 / m",-0.5,0.5,0.01,0.2],["object_m","物距 / m",0.1,1,0.01,0.5],["object_height_m","物高 / m",0.01,0.1,0.01,0.05]],
    [["mass_kg","水质量 / kg",0.05,0.25,0.01,0.1],["initial_temperature_c","水初温 / °C",5,90,1,20],["target_c","目标水温 / °C",25,95,1,60],["power_w","有效热功率 / W",50,1000,10,250],["stir_rpm","搅拌 / rpm",0,600,10,300],["fuel_mass_g","每种燃料储量 / g",1,1000,1,50]]
]
const NOTES = [
    "水平弹簧，质量集中于滑块。\n无摩擦、无阻尼，弹簧无质量。\nx 从平衡点向右为正。\nω = √(k/m)，x = A cos(ωt)。\n弹簧线圈形状是视觉近似。",
    "摆长为支点到小球质心的距离。\n初始角限制在 1–10°。\n采用 sin θ ≈ θ 的小角度模型，\n忽略空气阻力与支点摩擦。\n图中能量采用同一线性近似。",
    "两个内部温度均匀的液态水体，\n外界绝热，热导固定。\n比热近似为 4186 J/(kg·K)，\n忽略容器热容、蒸发和相变。\n颜色表示温度；容器为示意。\n热量来自独立能量收支。",
    "理想直流电源与两个欧姆电阻，\n导线电阻、电源内阻忽略。\n可切换串联与并联。\n断开时电流为零，累计耗能保留。\n不模拟电阻升温后的阻值变化。",
    "空气中的薄透镜、近轴光线。\n正焦距会聚，负焦距发散。\n|f| 限 0.05–0.5 m；物距为正。\n1/f = 1/u + 1/v；放大率 = −v/u。\n虚像用反向延长线表示。\n曲线记录每次应用参数的成像结果。",
    "水温设定 25–95°C，探头理想控温。\n有效功率指传入水的热量；\n火焰：燃料守恒与高温平衡产物。\n空气 / 氧气供给系数 1.2，常压。\n水捕获燃烧可用热量的 35%。\n水体均温，比热取 4186 J/(kg·K)。\n环境 20°C，散热热导 0.6 W/K。\n忽略杯体热容、蒸发与搅拌生热。\n转速为驱动设定，不求解流场。\n独立水实验；化学保持 25°C。"
]
var lab: Node3D
var core: LabCore
var ui_theme: Theme
var active := false
var kind_index := 0
var picker: OptionButton
var fields := {}
var field_box: VBoxContainer
var topology: OptionButton
var heater_controls: VBoxContainer
var heat_source: OptionButton
var heater_switch: Button
var stir_switch: Button
var flame_switch: CheckButton
var wind: SpinBox
var field_readout: Label
var heater_view: Node3D
var speed: SpinBox
var notes: Label
var measurements: RichTextLabel
var status: Label
var primary_title: Label
var secondary_title: Label
var first_plot: Control
var second_plot: Control
var pause_button: Button
var layer := CanvasLayer.new()
var geometry := Node3D.new()
var lines: MeshInstance3D
var moving: MeshInstance3D
var reservoirs: Array[MeshInstance3D] = []
var samples: Array = []
var last_sample := -1.0
var applied := {}

func _ready() -> void:
    add_child(geometry)
    add_child(layer)
    var ui := Control.new()
    ui.theme = ui_theme
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(ui)
    var left_panel: VBoxContainer = lab.panel(ui,Vector2(24,108),Vector2(336,780))
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(302,744)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    left_panel.add_child(scroll)
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation",7)
    scroll.add_child(left)
    lab.label(left,"物理实验台",23,Color("f4deba"))
    picker = OptionButton.new()
    picker.name = "PhysicsModel"
    for title in NAMES:
        picker.add_item(title)
    picker.item_selected.connect(select_model)
    left.add_child(picker)
    field_box = VBoxContainer.new()
    left.add_child(field_box)
    topology = OptionButton.new()
    topology.add_item("串联")
    topology.add_item("并联")
    left.add_child(topology)
    heater_controls = VBoxContainer.new()
    left.add_child(heater_controls)
    heat_source = OptionButton.new()
    heat_source.name = "HeaterSource"
    for title in Heater.SOURCES:
        heat_source.add_item(title)
    heater_controls.add_child(heat_source)
    lab.button(heater_controls,"应用温度 / 功率 / 转速（不重置）","ApplyHeaterControl",apply_heater_control)
    var switches := HBoxContainer.new()
    heater_controls.add_child(switches)
    heater_switch = lab.button(switches,"开启加热","ToggleHeater",func(): toggle_heater("heat_enabled"))
    stir_switch = lab.button(switches,"开启搅拌","ToggleStirrer",func(): toggle_heater("stir_enabled"))
    flame_switch=CheckButton.new()
    flame_switch.name="Flame3D"
    flame_switch.text="三维简化燃烧模拟"
    flame_switch.toggled.connect(func(enabled):
        var error: String=core.set_flame_enabled(enabled)
        if not error.is_empty():
            flame_switch.set_pressed_no_signal(false)
            status.text=error)
    heater_controls.add_child(flame_switch)
    lab.button(heater_controls,"燃烧产物与能量","CombustionReport",show_combustion_report)
    wind=lab.number(heater_controls,"侧向气流 / m·s⁻¹",-0.12,0.12,0.01,0,"FlameWind")
    field_readout=lab.label(heater_controls,"关闭空间场可减少计算量；整体燃烧继续。",12)
    field_readout.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    speed = lab.number(left,"时间倍率",1,20,1,1,"PhysicsSpeed")
    lab.button(left,"应用参数并重置","ConfigureBench",configure)
    lab.button(left,"开始 / 接通","StartBench",start)
    pause_button = lab.button(left,"暂停 / 断开","PauseBench",pause)
    lab.button(left,"重复本次实验","RepeatBench",repeat_trial)
    notes = lab.label(left,"",14,Color("a5baaf"))
    notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status = lab.label(left,"",13,Color("edc38b"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var right: VBoxContainer = lab.panel(ui,Vector2(1220,108),Vector2(356,750))
    lab.label(right,"测量与记录",22,Color("f4deba"))
    measurements = RichTextLabel.new()
    measurements.bbcode_enabled = true
    measurements.custom_minimum_size = Vector2(322,185)
    right.add_child(measurements)
    primary_title = lab.label(right,"",17,Color("d1e5d7"))
    first_plot = Plot.new()
    first_plot.custom_minimum_size = Vector2(322,190)
    right.add_child(first_plot)
    secondary_title = lab.label(right,"",17,Color("e5ccaa"))
    second_plot = Plot.new()
    second_plot.custom_minimum_size = Vector2(322,190)
    second_plot.line_color = Color("e3bd87")
    right.add_child(second_plot)
    select_model(0)
    set_active(false)

func set_active(value: bool) -> void:
    active = value
    visible = value
    layer.visible = value
    if not value:
        core.pause_bench()
    elif applied:
        frame_camera()

func frame_camera() -> void:
    lab.focus = Vector3(0,1.72,0) if kind_index==1 else Vector3(0,1.0,0)
    lab.orbit = Vector2(0.02,0.12) if kind_index in [1,4] else Vector2(0.10,0.65)
    lab.distance = 3.2 if kind_index==1 else 2.05 if kind_index==4 else 1.65
    lab.update_camera()

func select_model(index: int,apply_parameters: bool = true) -> void:
    core.pause_bench()
    kind_index = index
    fields.clear()
    for child in field_box.get_children():
        field_box.remove_child(child)
        child.queue_free()
    for field in FIELDS[index]:
        fields[field[0]] = lab.number(field_box,field[1],field[2],field[3],field[4],field[5],field[0])
    topology.visible = index==3
    heater_controls.visible = index==5
    picker.selected = index
    speed.editable = index!=4
    notes.text = NOTES[index]
    samples.clear()
    first_plot.points.clear()
    second_plot.points.clear()
    if apply_parameters:
        configure()

func configure() -> void:
    var p := {}
    for key in fields:
        p[key] = fields[key].value
    if kind_index==3:
        p.parallel = topology.selected
    elif kind_index==5:
        p.source = heat_source.selected
    var error := core.configure_bench(KINDS[kind_index],p)
    if not error.is_empty():
        status.text = error
        return
    applied = core.bench_snapshot().parameters
    if kind_index!=4:
        samples.clear()
        first_plot.points.clear()
        second_plot.points.clear()
    last_sample = -1
    build_geometry()
    if active:
        frame_camera()
    update_reading(core.bench_snapshot(),true)
    status.text = "参数已应用；可开始、暂停和重复。" if kind_index!=4 else "光路与像的位置已更新。"

func apply_heater_control() -> void:
    var error := core.control_heater({"target_c":fields.target_c.value,"power_w":fields.power_w.value,"stir_rpm":fields.stir_rpm.value,"source":heat_source.selected})
    if not error.is_empty():
        status.text = error
        return
    update_reading(core.bench_snapshot(),true)
    status.text = "温度、功率和转速已更新；水温与累计能量保留。"

func toggle_heater(key: String) -> void:
    var r := core.bench_snapshot()
    var error := core.control_heater({key:0 if r[key]>0 else 1})
    if not error.is_empty():
        status.text = error
        return
    core.start_bench()
    update_reading(core.bench_snapshot(),true)
    status.text = "加热和搅拌独立控制；关闭加热后按环境散热。"

func start() -> void:
    core.start_bench()
    status.text = "实验进行中。时间倍率 ×%.0f。"%speed.value

func pause() -> void:
    core.pause_bench()
    update_reading(core.bench_snapshot(),false)
    status.text = "已暂停 / 断开，实验时间不变。"

func repeat_trial() -> void:
    # Repeat the applied parameters even if uncommitted input fields changed.
    var old := core.bench_snapshot()
    core.reset_bench()
    if kind_index==5:
        core.control_heater({"target_c":old.target_c,"power_w":old.power_limit_w,"stir_rpm":old.stir_setpoint_rpm,"source":old.source,"heat_enabled":old.heat_enabled,"stir_enabled":old.stir_enabled})
    samples.clear()
    first_plot.points.clear()
    second_plot.points.clear()
    last_sample = -1
    start()

func mesh_node(mesh: Mesh,pos: Vector3,color: Color,metal: float = 0.0) -> MeshInstance3D:
    var v := MeshInstance3D.new()
    v.mesh = mesh
    v.position = pos
    v.material_override = Room.material(color,0.3,metal)
    geometry.add_child(v)
    return v

func box(extent: Vector3,pos: Vector3,color: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = extent
    return mesh_node(mesh,pos,color)

func tag(text: String,pos: Vector3) -> void:
    var label := Label3D.new()
    label.text = text
    label.position = pos
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.font_size = 32
    label.pixel_size = 0.0006
    geometry.add_child(label)

func build_geometry() -> void:
    for child in geometry.get_children():
        geometry.remove_child(child)
        child.queue_free()
    reservoirs.clear()
    lines = MeshInstance3D.new()
    lines.mesh = ImmediateMesh.new()
    var mat := Room.material(Color.WHITE)
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.vertex_color_use_as_albedo = true
    lines.material_override = mat
    geometry.add_child(lines)
    if kind_index==0:
        box(Vector3(0.8,0.025,0.15),Vector3(0,0.9025,0),Color("465957"))
        box(Vector3(0.025,0.13,0.12),Vector3(-0.38,0.955,0),Color("7b9290"))
        moving = box(Vector3(0.08,0.09,0.08),Vector3(0,0.96,0),Color("c49258"))
        tag("x = 0",Vector3(0,0.94,0.10))
    elif kind_index==1:
        box(Vector3(0.025,1.65,0.025),Vector3(0.30,1.71,0),Color("809593"))
        box(Vector3(0.35,0.025,0.03),Vector3(0.14,2.44,0),Color("809593"))
        var sphere := SphereMesh.new()
        sphere.radius = 0.025
        sphere.height = 0.05
        moving = mesh_node(sphere,Vector3.ZERO,Color("c28c54"),0.6)
        tag("支点",Vector3(0,2.49,0))
    elif kind_index==2:
        for i in range(2):
            var pos := Vector3(-0.18+i*0.36,0.98,0)
            box(Vector3(0.17,0.18,0.16),pos,Color("d2d7cc"))
            var mesh := CylinderMesh.new()
            mesh.top_radius = 0.06
            mesh.bottom_radius = 0.06
            mesh.height = 0.13
            reservoirs.append(mesh_node(mesh,pos+Vector3(0,0.03,0),Color("719eac")))
            tag("水 %d"%(i+1),pos+Vector3(0,0.16,0))
        box(Vector3(0.20,0.025,0.06),Vector3(0,0.98,0),Color("ad8560"))
    elif kind_index==3:
        box(Vector3(0.70,0.035,0.42),Vector3(0,0.912,0),Color("305046"))
        box(Vector3(0.06,0.07,0.10),Vector3(-0.27,0.96,0),Color("9f6248"))
        for i in range(2):
            var pos := Vector3(-0.10+i*0.20,0.956,-0.13) if applied.parallel==0 else Vector3(0,0.956,-0.13+i*0.20)
            box(Vector3(0.11,0.04,0.04),pos,Color("c5ad7e"))
            tag("R%d"%(i+1),pos+Vector3(0,0.06,0))
        tag("＋  电源  −",Vector3(-0.28,1.07,0))
    elif kind_index==5:
        heater_view = Heater.new()
        geometry.add_child(heater_view)
        heater_view.amount_ml = applied.mass_kg*1000
    else:
        box(Vector3(1.5,0.02,0.06),Vector3(0,0.90,0),Color("4a6360"))
        box(Vector3(1.50,0.45,0.018),Vector3(0,1.12,-0.035),Color("162724"))
        box(Vector3(0.008,0.16,0.02),Vector3(0,0.99,0),Color("8da29b"))
        var lens := SphereMesh.new()
        lens.radius = 0.085
        lens.height = 0.17
        var node := mesh_node(lens,Vector3(0,1.10,0),Color(0.53,0.81,0.86,0.16))
        node.scale.x = 0.065
        node.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        tag("会聚透镜" if applied.focal_m>0 else "发散透镜（示意）",Vector3(0,1.24,0))
        tag("物",Vector3(-applied.object_m,1.05,0))

func line(a: Vector3,b: Vector3,color: Color) -> void:
    lines.mesh.surface_set_color(color)
    lines.mesh.surface_add_vertex(a)
    lines.mesh.surface_add_vertex(b)

func arrow(x: float,height: float,color: Color) -> void:
    line(Vector3(x,1.10,0),Vector3(x,1.10+height,0),color)
    var sign_value := signf(height)
    line(Vector3(x,1.10+height,0),Vector3(x-0.012,1.10+height-sign_value*0.015,0),color)
    line(Vector3(x,1.10+height,0),Vector3(x+0.012,1.10+height-sign_value*0.015,0),color)

func draw_state(r: Dictionary) -> void:
    lines.mesh.clear_surfaces()
    lines.mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    if kind_index==0:
        moving.position.x = r.position_m
        var previous := Vector3(-0.36,0.98,0)
        for i in range(129):
            var t := i/128.0
            var point := Vector3(lerpf(-0.36,r.position_m-0.04,t),0.98+0.018*sin(t*TAU*12),0.018*cos(t*TAU*12))
            line(previous,point,Color("c6d9d4"))
            previous = point
    elif kind_index==1:
        var pivot := Vector3(0,2.44,0)
        moving.position = pivot+Vector3(applied.length_m*sin(r.angle_rad),-applied.length_m*cos(r.angle_rad),0)
        line(pivot,moving.position,Color("d6dfd8"))
    elif kind_index==2:
        for i in range(2):
            var temp: float = r.temperature1_c if i==0 else r.temperature2_c
            reservoirs[i].material_override.albedo_color = Color("497fb0").lerp(Color("dc7551"),(temp-5)/85)
        line(Vector3(-0.1,1.01,0),Vector3(0.1,1.01,0),Color("dbc398"))
    elif kind_index==3:
        var color := Color("ebc679") if r.running>0 else Color("6b847b")
        line(Vector3(-0.27,0.956,-0.13),Vector3(0.27,0.956,-0.13),color)
        line(Vector3(0.27,0.956,-0.13),Vector3(0.27,0.956,0.14),color)
        line(Vector3(0.27,0.956,0.14),Vector3(-0.24,0.956,0.14),color)
        line(Vector3(-0.27,0.956,-0.13),Vector3(-0.27,0.956,0.11),color)
        if r.running>0:
            line(Vector3(-0.27,0.956,0.11),Vector3(-0.24,0.956,0.14),color)
        if applied.parallel==1:
            line(Vector3(-0.27,0.956,0.07),Vector3(0.27,0.956,0.07),color)
    elif kind_index==5:
        heater_view.update_state(r)
        line(Vector3(-0.17,0.916,0.126),Vector3(0.17,0.916,0.126),Color("9fbaa9"))
    else:
        var u: float = applied.object_m
        var h: float = applied.object_height_m
        var f: float = applied.focal_m
        line(Vector3(-1,1.10,0),Vector3(0.75,1.10,0),Color("729488"))
        arrow(-u,h,Color("e6bb73"))
        line(Vector3(-u,1.10+h,0),Vector3(0,1.10+h,0),Color("f2d28b"))
        line(Vector3(0,1.10+h,0),Vector3(0.7,1.10+h-0.7*h/f,0),Color("f2d28b"))
        line(Vector3(-u,1.10+h,0),Vector3(0.7,1.10-0.7*h/u,0),Color("82d6c1"))
        if r.at_infinity==0 and abs(r.image_m)<=0.75 and abs(r.image_height_m)<=0.40:
            arrow(r.image_m,r.image_height_m,Color("a7bcf0"))
            if r.virtual>0:
                for i in range(12):
                    var a := i/12.0
                    var b := (i+0.5)/12.0
                    line(Vector3(lerpf(0,r.image_m,a),1.10+lerpf(h,r.image_height_m,a),0),Vector3(lerpf(0,r.image_m,b),1.10+lerpf(h,r.image_height_m,b),0),Color("bac3d9"))
    lines.mesh.surface_end()

func update_reading(r: Dictionary,record: bool) -> void:
    draw_state(r)
    measurements.text = "[font_size=25]%.2f s[/font_size]\n\n"%r.time_s
    var x: float = r.time_s
    var a := 0.0
    var b := 0.0
    var limit := 1.0
    if kind_index==0:
        a = r.position_m
        b = r.velocity_m_s
        limit = applied.amplitude_m
        measurements.text += "位移  %.3f m\n速度  %.3f m/s\n周期  %.3f s\n机械能  %.4f J"%[a,b,r.period_s,r.energy_j]
        first_plot.unit = "m"
        second_plot.unit = "m/s"
        primary_title.text = "位移 — 时间"
        secondary_title.text = "速度 — 时间"
        second_plot.y_max = TAU*applied.amplitude_m/r.period_s
    elif kind_index==1:
        a = r.angle_deg
        b = r.angular_velocity_rad_s
        limit = applied.angle_deg
        measurements.text += "摆角  %.2f°\n角速度  %.3f rad/s\n周期  %.3f s\n近似机械能  %.4f J"%[a,b,r.period_s,r.energy_j]
        first_plot.unit = "deg"
        second_plot.unit = "rad/s"
        primary_title.text = "摆角 — 时间"
        secondary_title.text = "角速度 — 时间"
        second_plot.y_max = deg_to_rad(applied.angle_deg)*TAU/r.period_s
    elif kind_index==2:
        a = r.temperature1_c
        b = r.temperature2_c
        limit = 90
        measurements.text += "水 1  %.2f°C\n水 2  %.2f°C\n最终平衡  %.2f°C\n传给水 2  %.1f J\n当前热流  %.2f W"%[a,b,r.equilibrium_c,r.heat_to_2_j,r.heat_flow_w]
        first_plot.unit = "°C"
        second_plot.unit = "°C"
        primary_title.text = "水 1 温度 — 时间"
        secondary_title.text = "水 2 温度 — 时间"
        second_plot.y_max = 90
    elif kind_index==3:
        a = r.current_a
        b = r.energy_j
        limit = maxf(applied.voltage_v/r.resistance_ohm*1.1,0.001)
        measurements.text += "总电流  %.4f A\nR₁ / R₂ 电流  %.4f / %.4f A\nR₁ / R₂ 电压  %.2f / %.2f V\n功率  %.3f W\n累计耗能  %.3f J"%[a,r.current1_a,r.current2_a,r.voltage1_v,r.voltage2_v,r.power_w,b]
        first_plot.unit = "A"
        second_plot.unit = "J"
        primary_title.text = "电流 — 时间"
        secondary_title.text = "耗能 — 时间"
        second_plot.y_max = maxf(1,b*1.1)
    elif kind_index==5:
        a = r.temperature_c
        b = r.input_energy_j
        limit = 100
        measurements.text = "[font_size=25]水温 %.1f°C[/font_size]   设定 %.0f°C\n%.1f s · %s\n热功率 %.1f / %.0f W\n搅拌 %.0f rpm\n输入 %.1f J · 散热 %.1f J\n水内能变化 %.1f J"%[a,r.target_c,r.time_s,"保温" if r.at_target>0 and r.heat_enabled>0 else "升温" if r.power_w>0 else "停止加热 / 散热",r.power_w,r.power_limit_w,r.stir_rpm,b,r.ambient_loss_j,r.energy_j]
        first_plot.unit = "°C"
        second_plot.unit = "J"
        primary_title.text = "实际水温 — 时间"
        secondary_title.text = "累计输入热量 — 时间"
        second_plot.y_max = maxf(1,b*1.1)
        heater_switch.text = "关闭加热" if r.heat_enabled>0 else "开启加热"
        stir_switch.text = "关闭搅拌" if r.stir_enabled>0 else "开启搅拌"
    else:
        x = applied.object_m
        first_plot.unit = "m"
        second_plot.unit = "×"
        primary_title.text = "像距 — 物距（应用参数记录）"
        secondary_title.text = "放大率 — 物距"
        limit = 1
        second_plot.y_max = 5
        measurements.text = "[font_size=24]薄透镜成像[/font_size]\n\n"
        if r.at_infinity>0:
            measurements.text += "物体位于焦平面\n出射光平行，像在无穷远。"
            record = false
        else:
            a = r.image_m
            b = r.magnification
            measurements.text += "像距  %.3f m\n放大率  %.3f\n%s · %s"%[a,b,"虚像" if r.virtual>0 else "实像","正立" if b>0 else "倒立"]
            if abs(a)>0.75 or abs(r.image_height_m)>0.4:
                measurements.text += "\n像的位置超出三维显示范围。"
            limit = maxf(1,abs(a)*1.1)
            second_plot.y_max = maxf(5,abs(b)*1.1)
    first_plot.y_max = limit
    first_plot.y_min = -limit if kind_index in [0,1,4] else 0.0
    second_plot.y_min = -second_plot.y_max if kind_index in [0,1,4] else 0.0
    first_plot.x_unit = "m" if kind_index==4 else "s"
    second_plot.x_unit = first_plot.x_unit
    first_plot.x_max = 1.0 if kind_index==4 else maxf(5,x)
    second_plot.x_max = first_plot.x_max
    if record and (kind_index==4 or r.time_s>=last_sample+0.05 or (kind_index==5 and not samples.is_empty() and r.heater_control_count!=samples[-1].heater_control_count)):
        samples.append(r.duplicate(true))
        first_plot.points.append(Vector2(x,a))
        second_plot.points.append(Vector2(x,b))
        last_sample = r.time_s
        # Bounded display history; CSV/session recording is handled separately.
        if samples.size()>1200:
            samples.pop_front()
            first_plot.points.pop_front()
            second_plot.points.pop_front()
    first_plot.queue_redraw()
    second_plot.queue_redraw()

func _process(delta: float) -> void:
    if active and kind_index==5 and heater_view:
        var field: Dictionary=core.advance_flame(minf(delta,0.1),wind.value)
        flame_switch.set_pressed_no_signal(field.get("enabled",false))
        speed.editable=not field.get("enabled",false)
        if field.get("enabled",false):speed.value=1
        if field.get("enabled",false):
            heater_view.update_flame_field(field)
            field_readout.text="空间场最高 %.0f °C · 流速 %.2f m/s\n混合受限反应；不预测爆燃、烟炱或细致火焰速度。"%[field.peak_temperature_k-273.15,field.max_speed_m_s]
            if field.has("error"):status.text=field.error;core.pause_bench()
        else:heater_view.clear_flame_field()
    if active:
        var r := core.advance_bench(delta*speed.value)
        if r.has("error"):
            status.text = r.error
            core.pause_bench()
        update_reading(r,kind_index!=4)

func restore_view(reading: Dictionary,history: Array) -> void:
    var index := KINDS.find(reading.kind)
    picker.selected = index
    select_model(index,false)
    applied = reading.parameters.duplicate(true)
    for key in fields:
        fields[key].value = applied[key]
    if kind_index==3:
        topology.selected = int(applied.parallel)
    build_geometry()
    samples.clear()
    first_plot.points.clear()
    second_plot.points.clear()
    last_sample = -1
    for sample in history:
        applied = sample.parameters.duplicate(true)
        update_reading(sample,true)
    applied = reading.parameters.duplicate(true)
    if kind_index==5:
        fields.target_c.value = reading.target_c
        fields.power_w.value = reading.power_limit_w
        fields.stir_rpm.value = reading.stir_setpoint_rpm
        heat_source.selected = int(reading.source)
    update_reading(reading,false)
    status.text = "已恢复，实验处于暂停状态。"

func show_combustion_report() -> void:
    var r: Dictionary=core.bench_snapshot()
    if r.kind!="heater":return
    var dialog := AcceptDialog.new()
    dialog.title="燃烧产物与能量"
    var text := "电热板不消耗燃料。"
    if r.source>0:
        text="常压 · 25°C 进料 · 供氧系数 1.2\n乙醇使用液态进料，已扣除汽化耗热。\n\n绝热平衡温度 %.0f °C（不等于实测火焰温度）\n燃料剩余 %.3f g · 消耗 %.6f mol\n已释放可用热 %.3f kJ · 排气 / 未捕获 %.3f kJ\n供氧累计 %.6f mol\n\n每摩尔燃料的热平衡产物：\n"%[r.flame_adiabatic_k-273.15,r.fuel_remaining_g,r.fuel_consumed_mol,r.chemical_energy_j/1000,r.exhaust_energy_j/1000,r.oxygen_consumed_mol]
        for species in ["CO2","H2O","CO","H2","O2","N2","H","O","OH","NO"]:
            var amount: float=r.get("hot_"+species+"_mol_per_fuel_mol",0.0)
            if amount>0.000001:text+="%s    %.6f mol\n"%[species,amount]
        text+="\n整体模型：理想气体平衡与独立水能量收支。\n空间模型：粗网格、预混进料、简化反应 / 传热。\n不预测真实点火延迟、爆燃、烟炱、壁面和细致火焰速度。"
    dialog.dialog_text=text
    lab.add_child(dialog)
    dialog.popup_centered(Vector2i(820,650))
    dialog.visibility_changed.connect(func():if not dialog.visible:dialog.queue_free())
