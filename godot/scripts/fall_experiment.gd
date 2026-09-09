extends Node3D

const Room = preload("res://scripts/lab_room.gd")
const Plot = preload("res://scripts/measurement_plot.gd")
var core: LabCore
var lab: Node3D
var ui_theme: Theme
var layer := CanvasLayer.new()
var ball: MeshInstance3D
var active := false
var height_input: SpinBox
var gravity_input: SpinBox
var measurements: RichTextLabel
var height_plot: Control
var speed_plot: Control
var pause_button: Button
var status: Label
var samples: Array = []
var last_sample_time := -1.0
var impact_recorded := false

func _ready() -> void:
    var pole := MeshInstance3D.new()
    var pole_mesh := CylinderMesh.new()
    pole_mesh.top_radius = 0.006
    pole_mesh.bottom_radius = 0.006
    pole_mesh.height = 2.08
    pole.mesh = pole_mesh
    pole.position = Vector3(0.09,1.93,0)
    pole.material_override = Room.material(Color("b6c4c3"),0.25,0.7)
    add_child(pole)
    for i in range(21):
        var tick := MeshInstance3D.new()
        var mesh := BoxMesh.new()
        mesh.size = Vector3(0.035 if i%5==0 else 0.016,0.003,0.010)
        tick.mesh = mesh
        tick.position = Vector3(0.07,0.908+i*0.1,0.002)
        tick.material_override = Room.material(Color("ece7d9"))
        add_child(tick)
        if i%5==0:
            var value := Label3D.new()
            value.text = "%.1f m"%(i*0.1)
            value.position = Vector3(0.145,0.908+i*0.1,0)
            value.font_size = 36
            value.pixel_size = 0.0010
            value.billboard = BaseMaterial3D.BILLBOARD_ENABLED
            add_child(value)
    var sphere := SphereMesh.new()
    sphere.radius = 0.018
    sphere.height = 0.036
    ball = MeshInstance3D.new()
    ball.mesh = sphere
    ball.material_override = Room.material(Color("c7834c"),0.2,0.72)
    add_child(ball)
    add_child(layer)
    var ui := Control.new()
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.theme = ui_theme
    layer.add_child(ui)
    var left: VBoxContainer = lab.panel(ui,Vector2(24,108),Vector2(274,630))
    lab.label(left,"自由落体",22,Color("f4deba"))
    lab.label(left,"小球静止释放，忽略空气阻力",13,Color("a5baaf"))
    height_input = lab.number(left,"高度 / m",0.1,2,0.05,1,"FallHeight")
    gravity_input = lab.number(left,"重力 / m·s⁻²",0.1,20,0.00001,9.80665,"Gravity")
    lab.button(left,"应用参数并重置","ConfigureFall",configure)
    lab.button(left,"释放小球","ReleaseBall",release)
    pause_button = lab.button(left,"暂停","PauseFall",toggle_pause)
    lab.button(left,"重复本次实验","RepeatFall",repeat_trial)
    lab.label(left,"测量约定",17,Color("f4deba"))
    var notes: Label = lab.label(left,"高度为球底到台面的距离。\n落地前：h = h₀ − ½gt²\n速度方向向下。\n\n落地后采用完全非弹性接触：\n小球静止，另记撞击前速度。\n\n设定重力是虚拟实验条件，\n不会改变房间里的其他器材。",14,Color("a5baaf"))
    notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status = lab.label(left,"",14,Color("e0cdab"))
    status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    var right: VBoxContainer = lab.panel(ui,Vector2(1244,108),Vector2(332,720))
    lab.label(right,"运动测量",22,Color("f4deba"))
    measurements = RichTextLabel.new()
    measurements.bbcode_enabled = true
    measurements.custom_minimum_size = Vector2(298,135)
    right.add_child(measurements)
    lab.label(right,"高度 — 时间",17,Color("d1e5d7"))
    height_plot = Plot.new()
    height_plot.custom_minimum_size = Vector2(298,180)
    right.add_child(height_plot)
    lab.label(right,"速率 — 时间（落地前）",17,Color("e1c69f"))
    speed_plot = Plot.new()
    speed_plot.unit = "m/s"
    speed_plot.line_color = Color("e3bd87")
    speed_plot.custom_minimum_size = Vector2(298,180)
    right.add_child(speed_plot)
    lab.label(right,"曲线来自当前实验的测量状态。",13,Color("a5baaf"))
    configure()
    set_active(false)

func set_active(value: bool) -> void:
    active = value
    visible = value
    layer.visible = value
    if not value:
        core.pause_fall()

func configure() -> void:
    var error := core.configure_fall(height_input.value,gravity_input.value)
    if not error.is_empty():
        status.text = error
        return
    samples.clear()
    height_plot.points.clear()
    speed_plot.points.clear()
    last_sample_time = -1
    impact_recorded = false
    height_plot.y_max = height_input.value
    var impact_time := sqrt(2*height_input.value/gravity_input.value)
    height_plot.x_max = impact_time
    speed_plot.x_max = impact_time
    speed_plot.y_max = sqrt(2*height_input.value*gravity_input.value)
    pause_button.text = "暂停"
    status.text = "待释放。每次重置都会保留相同参数。"
    update_reading(core.fall_snapshot())

func release() -> void:
    if core.fall_snapshot().landed:
        status.text = "已落地；点击重复实验重新释放。"
        return
    core.start_fall()
    pause_button.text = "暂停"
    status.text = "正在下落…"

func toggle_pause() -> void:
    if core.fall_snapshot().running:
        core.pause_fall()
        pause_button.text = "继续"
        status.text = "已暂停；模拟时间保持不变。"
    else:
        release()

func repeat_trial() -> void:
    configure()
    release()

func update_reading(r: Dictionary) -> void:
    ball.position = Vector3(0,0.908+r.height_m,0)
    measurements.text = "[font_size=25]%.3f s   ·   %.3f m[/font_size]\n\n当前速率  %.3f m/s\n"%[r.time_s,r.height_m,abs(r.velocity_m_s)]
    if r.landed:
        measurements.text += "[color=#edc38b]撞击前速率  %.3f m/s[/color]"%r.impact_speed_m_s
        status.text = "已落地；撞击前速率已记录，小球按非弹性接触模型静止。"
    if r.time_s>last_sample_time:
        samples.append(r.duplicate())
        height_plot.points.append(Vector2(r.time_s,r.height_m))
        speed_plot.points.append(Vector2(r.time_s,r.impact_speed_m_s if r.landed else abs(r.velocity_m_s)))
        last_sample_time = r.time_s
    height_plot.queue_redraw()
    speed_plot.queue_redraw()

func _physics_process(delta: float) -> void:
    if active:
        update_reading(core.advance_fall(delta))
