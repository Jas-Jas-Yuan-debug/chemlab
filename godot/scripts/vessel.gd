extends Node3D

const Room = preload("res://scripts/lab_room.gd")
var vessel_id := 0
var kind := "烧杯"
var capacity_ml := 250.0
var radius := 0.033
var height := 0.100
var liquid: MeshInstance3D
var visual := Node3D.new()
var ring: MeshInstance3D
var name_label: Label3D
var reading: Dictionary = {}
var wave := Vector2.ZERO
var wave_velocity := Vector2.ZERO
var previous_position := Vector3.ZERO
var liquid_height := 0.0

func build(id: int, vessel_kind: String, capacity: float) -> void:
    vessel_id = id
    kind = vessel_kind
    capacity_ml = capacity
    if kind == "量筒":
        radius = 0.020
        height = 0.18
    elif kind == "滴管":
        radius = 0.008
        height = 0.10
    elif kind == "试剂瓶":
        radius = 0.032
        height = 0.15
    add_child(visual)
    var glass := ShaderMaterial.new()
    glass.shader = preload("res://shaders/glass.gdshader")
    var profile: Array[Vector2] = [Vector2(0,0),Vector2(radius,0),Vector2(radius,height),Vector2(radius-0.0015,height),Vector2(radius-0.0015,0.003),Vector2(0,0.003)]
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in range(profile.size()-1):
        for step in range(64):
            var a := TAU*step/64.0
            var b := TAU*(step+1)/64.0
            var v0 := Vector3(profile[p].x*cos(a),profile[p].y,profile[p].x*sin(a))
            var v1 := Vector3(profile[p+1].x*cos(a),profile[p+1].y,profile[p+1].x*sin(a))
            var v2 := Vector3(profile[p+1].x*cos(b),profile[p+1].y,profile[p+1].x*sin(b))
            var v3 := Vector3(profile[p].x*cos(b),profile[p].y,profile[p].x*sin(b))
            for point in [v0,v1,v2,v0,v2,v3]:
                surface.add_vertex(point)
    surface.generate_normals()
    var shell := MeshInstance3D.new()
    shell.mesh = surface.commit()
    shell.material_override = glass
    visual.add_child(shell)
    rim(height,Room.material(Color("c5dee1"),0.12,0.25))
    rim(0.002,Room.material(Color("aec7c9"),0.2,0.25))
    liquid = MeshInstance3D.new()
    var liquid_mesh := CylinderMesh.new()
    liquid_mesh.top_radius = radius-0.0018
    liquid_mesh.bottom_radius = radius-0.0018
    liquid_mesh.radial_segments = 64
    liquid_mesh.height = 0.01
    liquid.mesh = liquid_mesh
    var liquid_mat := ShaderMaterial.new()
    liquid_mat.shader = preload("res://shaders/liquid.gdshader")
    liquid.material_override = liquid_mat
    visual.add_child(liquid)
    var body := StaticBody3D.new()
    body.set_meta("vessel_id",id)
    var collider := CollisionShape3D.new()
    var shape := CylinderShape3D.new()
    shape.radius = max(radius,0.018)
    shape.height = height
    collider.shape = shape
    collider.position.y = height/2
    body.add_child(collider)
    add_child(body)
    ring = rim(-0.001,Room.material(Color("e9ba70"),0.5))
    ring.visible = false
    name_label = Label3D.new()
    name_label.text = "%s %d" % [kind,id]
    name_label.font_size = 36
    name_label.pixel_size = 0.00021
    name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    name_label.position.y = height+0.018
    name_label.modulate = Color("fff6dc")
    add_child(name_label)
    for step in range(1,6):
        var mark := Label3D.new()
        mark.text = "— %d" % int(capacity*step/5)
        mark.font_size = 22
        mark.pixel_size = 0.00011
        mark.position = Vector3(0,0.003+capacity*0.000001*step/5/(PI*pow(radius-0.0018,2)), radius+0.0008)
        mark.modulate = Color("eff7f6")
        visual.add_child(mark)
    if kind == "滴管":
        var bulb := MeshInstance3D.new()
        var mesh := SphereMesh.new()
        mesh.radius = 0.014
        mesh.height = 0.036
        bulb.mesh = mesh
        bulb.position.y = height+0.013
        bulb.material_override = Room.material(Color("39494a"))
        visual.add_child(bulb)
    update_state({"volume_ml":0,"ph":null})

func rim(y: float, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius-0.0007
    mesh.outer_radius = radius+0.0007
    mesh.rings = 48
    mesh.ring_segments = 8
    node.mesh = mesh
    node.material_override = mat
    node.position.y = y
    visual.add_child(node)
    return node

func update_state(state: Dictionary) -> void:
    reading = state
    var amount: float = state.get("volume_ml",0.0)
    liquid.visible = amount > 0.0001
    var fill: float = clampf(amount,0,capacity_ml)*0.000001/(PI*pow(radius-0.0018,2))
    liquid_height = fill
    liquid.mesh.height = max(fill,0.00001)
    liquid.position.y = 0.0031+fill/2
    liquid.material_override.set_shader_parameter("fill_height",fill)

func set_selected(yes: bool) -> void:
    ring.visible = yes
    name_label.modulate = Color("ffe0a0") if yes else Color("fff6dc")

func set_indicator(color: Color) -> void:
    liquid.material_override.set_shader_parameter("tint",color)

func _process(delta: float) -> void:
    if not liquid:
        return
    # Bounded, damped visual motion; no chemistry or numerical volume changes.
    var motion := global_position-previous_position
    previous_position = global_position
    wave_velocity += Vector2(motion.x,motion.z).limit_length(0.02)*18.0
    var dt := minf(delta,0.033)
    wave_velocity += (-wave*110.0-wave_velocity*9.0)*dt
    wave += wave_velocity*dt
    var margin := minf(liquid_height*0.35,maxf(0.0,height-0.004-liquid_height)*0.35)
    wave = wave.limit_length(minf(0.08,margin/maxf(radius,0.001)))
    liquid.material_override.set_shader_parameter("slope",wave)
