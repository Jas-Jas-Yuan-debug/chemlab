extends Node3D

const Geometry = preload("res://scripts/glass_geometry.gd")
var cavity: Array[Vector2]=[]
var form := "beaker"
var mouth_radius := 0.032
var label_offset := 0.018
var stopper: Node3D
var bottle_label: Label3D
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
var slices: Array[Vector2] = []
var plane_center := 0.0
var liquid_slope := Vector2.ZERO
var last_slope := Vector2(INF,INF)
var last_fill := -1.0

func build(id: int, vessel_kind: String, capacity: float) -> void:
    vessel_id = id
    kind = vessel_kind
    capacity_ml = capacity
    var geometry := Geometry.shape(kind,capacity)
    cavity.assign(geometry.inner)
    form=geometry.form
    radius=geometry.radius
    height=geometry.height
    mouth_radius=cavity[-1].x
    add_child(visual)
    var glass := ShaderMaterial.new()
    glass.shader = preload("res://shaders/glass.gdshader")
    var shell := MeshInstance3D.new()
    shell.mesh=Geometry.shell_mesh(geometry.outer,cavity,form=="beaker" or form=="cylinder")
    shell.material_override=glass
    shell.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    visual.add_child(shell)
    if form=="bottle":
        label_offset=0.04*geometry.scale
        var frosted:=Room.material(Color(0.70,0.80,0.79,0.42),0.34)
        frosted.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
        stopper=Node3D.new();visual.add_child(stopper)
        var plug:=MeshInstance3D.new();var plug_mesh:=CylinderMesh.new()
        plug_mesh.top_radius=mouth_radius*0.94;plug_mesh.bottom_radius=mouth_radius*0.82;plug_mesh.height=0.016*geometry.scale
        plug.mesh=plug_mesh;plug.position.y=height+0.001*geometry.scale;plug.material_override=frosted;plug.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stopper.add_child(plug)
        var grip:=MeshInstance3D.new();var grip_mesh:=CylinderMesh.new()
        grip_mesh.top_radius=mouth_radius*1.30;grip_mesh.bottom_radius=mouth_radius*1.30;grip_mesh.height=0.010*geometry.scale
        grip.mesh=grip_mesh;grip.position.y=height+0.013*geometry.scale;grip.material_override=frosted;grip.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        stopper.add_child(grip)
        bottle_label=Label3D.new();bottle_label.font_size=28;bottle_label.pixel_size=0.00019*geometry.scale
        bottle_label.position=Vector3(0,height*0.42,radius+0.0009);bottle_label.modulate=Color("eff2e9")
        visual.add_child(bottle_label)
    if form=="cylinder":
        var foot:=MeshInstance3D.new();var base:=CylinderMesh.new()
        base.top_radius=radius*1.65;base.bottom_radius=radius*1.75;base.height=0.006;base.radial_segments=6
        foot.mesh=base;foot.position.y=0.003;foot.material_override=glass;visual.add_child(foot)
    liquid=MeshInstance3D.new();liquid.mesh=make_liquid_mesh()
    liquid.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var liquid_mat:=ShaderMaterial.new();liquid_mat.shader=preload("res://shaders/liquid.gdshader")
    liquid_mat.set_shader_parameter("profile_count",cavity.size())
    var shader_profile:=PackedVector2Array(cavity)
    while shader_profile.size()<32:shader_profile.append(cavity[-1])
    liquid_mat.set_shader_parameter("cavity",shader_profile)
    liquid.material_override=liquid_mat;visual.add_child(liquid)
    # Midpoint integration of circular segments for a tilted, shaped cavity.
    for i in range(128):
        var y:=lerpf(cavity[0].y,cavity[-1].y,(i+0.5)/128.0)
        slices.append(Vector2(y,Geometry.radius_at(cavity,y)))
    var body := StaticBody3D.new()
    body.set_meta("vessel_id",id)
    # Zero-ID vessels belong to fixed batch/heating apparatus, not the
    # draggable chemistry inventory. Visibility alone never disables picking.
    if id<=0:
        body.collision_layer = 0
        body.collision_mask = 0
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
    name_label.position.y = height+label_offset
    name_label.modulate = Color("fff6dc")
    add_child(name_label)
    if form in ["beaker","cylinder"]:
        for step in range(1,9):
            var ml:=capacity*step/10.0
            var y:=level_for_volume(ml*0.000001)
            var mark:=Label3D.new();mark.text="— %.0f"%ml;mark.font_size=26
            mark.pixel_size=0.00013;mark.position=Vector3(0,y,radius+0.0009)
            mark.modulate=Color("e2ebe6");visual.add_child(mark)
    if form=="dropper":
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
    liquid_height=level_for_volume(clampf(amount,0,capacity_ml)*0.000001)
    if bottle_label:
        var ingredients: Dictionary=state.get("ingredients_mol",{})
        var labels: Array[String]=[]
        var names: Dictionary={2:"HCl",3:"NaOH",4:"NaCl",5:"KOH",6:"KCl"}
        for key in ingredients:
            if names.has(int(key)):labels.append(names[int(key)])
        bottle_label.text=(" + ".join(labels) if not labels.is_empty() else "H₂O" if amount>0 else "试剂瓶")+"\n%.0f mL"%capacity_ml
    update_liquid_plane(Vector2.ZERO,true)

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
    var gravity_local: Vector3 = visual.global_basis.inverse()*Vector3.UP
    var gravity_slope := -Vector2(gravity_local.x,gravity_local.z)/maxf(0.01,gravity_local.y)
    update_liquid_plane(gravity_slope+wave)

func level_for_volume(volume: float) -> float:
    var low:=cavity[0].y;var high:=cavity[-1].y
    for i in range(26):
        var mid:=(low+high)/2
        if Geometry.profile_volume(cavity,mid)<volume:low=mid
        else:high=mid
    return (low+high)/2

func make_liquid_mesh() -> ArrayMesh:
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var profile: Array[Vector2]=[Vector2(0,cavity[0].y)]
    profile.append_array(cavity)
    for j in range(profile.size()-1):
        var p:=profile[j];var q:=profile[j+1]
        for i in range(96):
            var a:=TAU*i/96;var b:=TAU*(i+1)/96
            var pts: Array[Vector3]=[Vector3(p.x*cos(a),p.y,p.x*sin(a)),Vector3(q.x*cos(a),q.y,q.x*sin(a)),Vector3(q.x*cos(b),q.y,q.x*sin(b)),Vector3(p.x*cos(b),p.y,p.x*sin(b))]
            for tri in [[0,1,2],[0,2,3]]:
                if (pts[tri[1]]-pts[tri[0]]).cross(pts[tri[2]]-pts[tri[0]]).length_squared()<1e-22:continue
                for k in tri:
                    var angle:=a if k<2 else b
                    surface.set_uv(Vector2.ZERO)
                    surface.set_normal(Vector3((q.y-p.y)*cos(angle),p.x-q.x,(q.y-p.y)*sin(angle)).normalized())
                    surface.add_vertex(pts[k])
    # Single planar free surface; fragments clip it to the actual bottle cavity.
    for i in range(96):
        var a:=TAU*i/96;var b:=TAU*(i+1)/96
        for v in [Vector3.ZERO,Vector3(radius*cos(b),0,radius*sin(b)),Vector3(radius*cos(a),0,radius*sin(a))]:
            surface.set_uv(Vector2(1,0));surface.set_normal(Vector3.UP);surface.add_vertex(v)
    return surface.commit()

func volume_below(center: float,slope_length: float) -> float:
    if slope_length<1e-8:return Geometry.profile_volume(cavity,center)
    var total:=0.0
    var dy:=(cavity[-1].y-cavity[0].y)/slices.size()
    for sample in slices:
        var r:=sample.y
        var cut:=(sample.x-center)/slope_length
        if cut<=-r:total+=PI*r*r*dy
        elif cut<r:total+=(r*r*acos(cut/r)-cut*sqrt(maxf(0,r*r-cut*cut)))*dy
    return total

func mean_fill(center: float,slope_length: float) -> float:
    return volume_below(center,slope_length)/(PI*pow(radius-0.0014,2))

func update_liquid_plane(slope: Vector2,force: bool = false) -> void:
    if not force and slope.distance_to(last_slope)<0.003 and abs(last_fill-liquid_height)<0.000001:return
    liquid_slope=slope;last_slope=slope;last_fill=liquid_height
    plane_center=liquid_height
    if slope.length()>1e-8:
        var low:=cavity[0].y-slope.length()*radius
        var high:=cavity[-1].y+slope.length()*radius
        var volume: float=clampf(reading.get("volume_ml",0),0,capacity_ml)*0.000001
        for i in range(22):
            var mid:=(low+high)/2
            if volume_below(mid,slope.length())<volume:low=mid
            else:high=mid
        plane_center=(low+high)/2
    liquid.material_override.set_shader_parameter("plane_center",plane_center)
    liquid.material_override.set_shader_parameter("slope",slope)

func set_open(value: bool) -> void:
    if stopper:stopper.position=Vector3(radius*1.8,0,0) if value else Vector3.ZERO

func pour_lip() -> Vector3:
    return Vector3(mouth_radius+(0.008 if form=="beaker" else 0),height,0)

func pour_angle() -> float:
    var low:=0.0;var high:=1.55
    for i in range(18):
        var angle:=(low+high)/2
        var center:=height-pour_lip().x*tan(angle)
        if volume_below(center,tan(angle))>reading.get("volume_ml",0)*0.000001:low=angle
        else:high=angle
    return (low+high)/2
