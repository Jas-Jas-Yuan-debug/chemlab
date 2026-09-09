extends Node3D
# Prescribed heat-source appearance, never a combustion/species calculation.
const Vessel = preload("res://scripts/vessel.gd")
const Room = preload("res://scripts/lab_room.gd")
const SOURCES = ["电热板","酒精灯","本生灯","氢氧焰","乙炔氧焰","酒精喷灯"]
var source_id := -1
var amount_ml := 100.0
var equipment := Node3D.new()
var beaker: Node3D
var rotor: Node3D
var flame: Node3D
var display: Label3D
var heat_light: MeshInstance3D
func _ready() -> void:
    add_child(equipment)
func shape(mesh: Mesh,pos: Vector3,color: Color,metal: float = 0.0,parent: Node3D = null) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.position = pos
    node.material_override = Room.material(color,0.3,metal)
    if parent==null:
        parent = equipment
    parent.add_child(node)
    return node
func cylinder(radius: float,height: float,pos: Vector3,color: Color,metal: float = 0.0,parent: Node3D = null) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 32
    return shape(mesh,pos,color,metal,parent)
func block(size: Vector3,pos: Vector3,color: Color,parent: Node3D = null) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return shape(mesh,pos,color,0,parent)
func make_source(index: int) -> void:
    for child in equipment.get_children():
        equipment.remove_child(child)
        child.queue_free()
    source_id = index
    var cup_y := 0.955 if index==0 else 1.125
    block(Vector3(0.34,0.025,0.25),Vector3(0,0.9025,0),Color("d8ded8"))
    if index==0:
        block(Vector3(0.19,0.035,0.17),Vector3(0,0.928,0),Color("516360"))
        cylinder(0.075,0.014,Vector3(0,0.948,0),Color("cacdc5"),0.65)
        heat_light = cylinder(0.005,0.005,Vector3(0.07,0.948,0.064),Color("604632"))
    else:
        for x in [-0.06,0.06]:
            cylinder(0.004,0.205,Vector3(x,1.017,0.055),Color("83908b"),0.6)
        cylinder(0.004,0.205,Vector3(0,1.017,-0.065),Color("83908b"),0.6)
        block(Vector3(0.145,0.007,0.135),Vector3(0,1.12,0),Color("a9b2a7"))
        var nozzle_y := 1.035
        if index==1:
            cylinder(0.029,0.055,Vector3(0,0.9425,0),Color("b9c9ba"),0.15)
            cylinder(0.011,0.012,Vector3(0,0.976,0),Color("b09363"),0.7)
            cylinder(0.0025,0.009,Vector3(0,0.985,0),Color("e9d5ab"))
            nozzle_y = 0.99
        elif index==2:
            cylinder(0.025,0.008,Vector3(0,0.919,0),Color("4f6059"),0.7)
            cylinder(0.007,0.11,Vector3(0,0.978,0),Color("a69476"),0.7)
            cylinder(0.01,0.017,Vector3(0,0.94,0),Color("566a65"),0.5)
        elif index in [3,4]:
            var nozzle = cylinder(0.007,0.1,Vector3(-0.035,0.995,0),Color("ad8c5f"),0.75)
            nozzle.rotation.z = -0.6
            block(Vector3(0.07,0.024,0.026),Vector3(-0.10,0.955,0),Color("344b45"))
            for i in range(2):
                block(Vector3(0.11,0.007,0.007),Vector3(-0.13,0.946,-0.012+i*0.024),Color("ba795f") if i==0 else Color("658b9b"))
        else:
            cylinder(0.024,0.065,Vector3(-0.055,0.9475,0),Color("b09155"),0.65)
            var nozzle = cylinder(0.006,0.08,Vector3(-0.022,0.999,0),Color("b59a70"),0.8)
            nozzle.rotation.z = -0.5
            cylinder(0.007,0.027,Vector3(-0.082,0.985,0),Color("78847b"),0.6)
        flame = Node3D.new()
        flame.position = Vector3(0,nozzle_y,0)
        equipment.add_child(flame)
        for inner in [false,true]:
            var cone := CylinderMesh.new()
            cone.bottom_radius = 0.007 if inner else 0.012
            cone.top_radius = 0.0005
            cone.height = (1.113-nozzle_y)*(0.65 if inner else 1.0)
            var color := Color(0.55,0.8,1.0,0.72) if inner else Color(0.18,0.43,0.95,0.32)
            if index==1 and not inner:
                color = Color(0.93,0.66,0.3,0.35)
            var node := shape(cone,Vector3(0,cone.height/2,0),color,0,flame)
            node.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            node.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    beaker = Vessel.new()
    equipment.add_child(beaker)
    beaker.build(0,"烧杯",250)
    beaker.position = Vector3(0,cup_y,0)
    beaker.name_label.text = "水 · %.0f mL"%amount_ml
    beaker.update_state({"volume_ml":amount_ml,"ph":null})
    beaker.set_indicator(Color(0.68,0.86,0.91,0.28))
    # Overhead paddle keeps stirring available independently of flame/electric heat.
    cylinder(0.005,0.42,Vector3(0.12,1.125,-0.06),Color("8c9b94"),0.65)
    block(Vector3(0.13,0.012,0.018),Vector3(0.06,1.325,-0.01),Color("83998f"))
    block(Vector3(0.055,0.05,0.05),Vector3(0,1.325,0),Color("3f625a"))
    rotor = Node3D.new()
    rotor.position = Vector3(0,cup_y+0.012,0)
    equipment.add_child(rotor)
    var shaft_height := 1.30-rotor.position.y
    cylinder(0.0015,shaft_height,Vector3(0,shaft_height/2,0),Color("c4d0c5"),0.6,rotor)
    block(Vector3(0.043,0.005,0.009),Vector3.ZERO,Color("ebe6cf"),rotor)
    block(Vector3(0.008,0.006,0.01),Vector3(0.015,0,0),Color("769285"),rotor)
    # Immersed feedback probe; setpoint belongs to water, not flame temperature.
    cylinder(0.0016,0.08,Vector3(0.015,cup_y+0.05,0.009),Color("9fb7b1"),0.6)
    display = Label3D.new()
    display.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    display.font_size = 32
    display.pixel_size = 0.00036
    display.position = Vector3(-0.15,cup_y+0.14,0)
    equipment.add_child(display)
func update_state(r: Dictionary) -> void:
    if source_id!=int(r.source):
        make_source(int(r.source))
    rotor.rotation.y = fmod(r.stir_turns,1.0)*TAU
    if source_id>0:
        flame.visible = r.running>0 and r.power_w>0
        flame.scale.y = 0.4+0.6*clampf(r.power_w/1000.0,0,1)
    else:
        heat_light.material_override.albedo_color = Color("e0a568") if r.power_w>0 else Color("604632")
    display.text = "%s\n水温 %.1f°C  /  设定 %.0f°C\n搅拌 %.0f rpm"%[SOURCES[source_id],r.temperature_c,r.target_c,r.stir_rpm]
