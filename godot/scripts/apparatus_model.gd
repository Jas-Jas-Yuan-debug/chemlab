extends Node3D
# Original procedural apparatus. All geometry uses metres; labels carry capacity.
const Room = preload("res://scripts/lab_room.gd")
var definition: Dictionary
var content: MeshInstance3D
var caption: Label3D
var metal := Color("a7b6bb")
var glass: ShaderMaterial
var body := Node3D.new()
var nominal_height := 0.14
var nominal_radius := 0.035
var fill_profile: Array[Vector2] = []
var liquid_color := Color(0.45,0.77,0.92,0.48)

func mesh(mesh_value: Mesh, at: Vector3, color: Color, material: Material = null) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh_value
    node.position = at
    node.material_override = material if material else Room.material(color,0.3,0.3 if color==metal else 0.0)
    body.add_child(node)
    return node

func box(at: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
    var m := BoxMesh.new()
    m.size = size_value
    return mesh(m,at,color)

func ball(at: Vector3, radius: float, color: Color, mat: Material = null) -> MeshInstance3D:
    var m := SphereMesh.new()
    m.radius = radius
    m.height = radius*2
    m.radial_segments = 24
    m.rings = 12
    return mesh(m,at,color,mat)

func rod(a: Vector3, b: Vector3, radius: float = 0.002, color: Color = Color("a7b6bb"), mat: Material = null) -> MeshInstance3D:
    var m := CylinderMesh.new()
    m.top_radius = radius
    m.bottom_radius = radius
    m.height = a.distance_to(b)
    m.radial_segments = 12
    var node := mesh(m,(a+b)/2,color,mat)
    node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
    return node

func tube(points: Array, radius: float = 0.004, color: Color = Color("a7b6bb"), mat: Material = null) -> void:
    for i in range(points.size()-1):
        rod(points[i],points[i+1],radius,color,mat)

func ring(at: Vector3, radius: float, color: Color = Color("a7b6bb")) -> MeshInstance3D:
    var m := TorusMesh.new()
    m.inner_radius = radius-0.002
    m.outer_radius = radius+0.002
    m.rings = 24
    m.ring_segments = 8
    return mesh(m,at,color)

func lathe(profile: Array[Vector2], mat: Material) -> MeshInstance3D:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(profile.size()-1):
        for i in range(32):
            var a := TAU*i/32
            var b := TAU*(i+1)/32
            var p := profile[j]
            var q := profile[j+1]
            for v in [Vector3(p.x*cos(a),p.y,p.x*sin(a)),Vector3(q.x*cos(a),q.y,q.x*sin(a)),Vector3(q.x*cos(b),q.y,q.x*sin(b)),Vector3(p.x*cos(a),p.y,p.x*sin(a)),Vector3(q.x*cos(b),q.y,q.x*sin(b)),Vector3(p.x*cos(b),p.y,p.x*sin(b))]:
                surface.add_vertex(v)
    surface.generate_normals()
    return mesh(surface.commit(),Vector3.ZERO,Color.WHITE,mat)

func vessel(profile: Array[Vector2], opaque: bool = false) -> void:
    fill_profile.assign(profile)
    var shell: Array[Vector2] = [Vector2(0,0)]
    shell.append_array(profile)
    for i in range(profile.size()-1,-1,-1):
        shell.append(Vector2(maxf(0,profile[i].x-0.0015),profile[i].y+0.001))
    shell.append(Vector2(0,0.001))
    lathe(shell,Room.material(Color("ecede2")) if opaque else glass)
    nominal_height = profile[-1].y
    nominal_radius = 0
    for p in profile:
        nominal_radius = maxf(nominal_radius,p.x)
    ring(Vector3(0,nominal_height,0),profile[-1].x,Color("d9e5e6"))

func flask(necks: int = 1) -> void:
    var profile: Array[Vector2] = []
    for i in range(13):
        var a := -PI/2+float(i)/12*PI*0.87
        profile.append(Vector2(maxf(0.008,cos(a)*0.043),0.045+sin(a)*0.043))
    profile.append(Vector2(0.013,0.095))
    profile.append(Vector2(0.013,0.165))
    vessel(profile)
    if necks==3:
        for direction in [-1,1]:
            rod(Vector3(direction*0.025,0.075,0),Vector3(direction*0.06,0.135,0),0.011,metal,glass)

func stand() -> void:
    box(Vector3(0,0.006,0),Vector3(0.11,0.012,0.08),Color("455b65"))
    rod(Vector3(-0.035,0.012,0),Vector3(-0.035,0.30,0),0.003)
    if definition.name!="铁架台":
        rod(Vector3(-0.035,0.17,0),Vector3(0.04,0.17,0),0.003)
        ring(Vector3(0.04,0.17,0),0.03)

func build(item: Dictionary) -> void:
    definition = item
    add_child(body)
    glass = ShaderMaterial.new()
    glass.shader = preload("res://shaders/glass.gdshader")
    var type: String = item.model
    match type:
        "beaker","insulated","waste","gasjar","bottle","washbottle":
            var scale_value := pow(float(item.get("capacity_ml",250))/250.0,1.0/3.0)
            var r := 0.037*scale_value
            var h := 0.1*scale_value
            if type in ["bottle","gasjar","washbottle"]:
                vessel([Vector2(r,0),Vector2(r,h*0.8),Vector2(r*0.7,h),Vector2(r*0.7,h*1.15)])
            else:
                vessel([Vector2(r,0),Vector2(r,h)],type in ["insulated","waste"])
            if type=="washbottle":
                tube([Vector3(-0.012,0.03,0),Vector3(-0.012,0.15,0),Vector3(-0.07,0.17,0)],0.003,metal,glass)
                tube([Vector3(0.012,0.1,0),Vector3(0.012,0.16,0),Vector3(0.06,0.16,0)],0.003,metal,glass)
            if type=="beaker":
                rod(Vector3(r, h,0),Vector3(r+0.013,h+0.007,0),0.002)
        "flask","flask3","flaskside","volumetric":
            flask(3 if type=="flask3" else 1)
            if type=="flaskside":
                rod(Vector3(0.014,0.125,0),Vector3(0.073,0.098,0),0.004,metal,glass)
            if type=="volumetric":
                rod(Vector3(0,0.165,0),Vector3(0,0.22,0),0.008,metal,glass)
                ring(Vector3(0,0.19,0),0.008,Color("ffbc75"))
        "testtube","dropper","burette","cylinder","syringe","hardtube":
            var r := 0.009 if type in ["dropper","burette"] else 0.014
            var h := 0.23 if type in ["burette","cylinder"] else 0.14
            vessel([Vector2(0.003,0),Vector2(r,0.008),Vector2(r,h)])
            if type=="dropper": ball(Vector3(0,h+0.013,0),0.014,Color("e26446"))
            if type=="cylinder": ring(Vector3(0,0.002,0),0.027)
            if type=="syringe":
                rod(Vector3(0,0.1,0),Vector3(0,0.18,0),0.004)
                box(Vector3(0,0.18,0),Vector3(0.04,0.004,0.012),Color.WHITE)
                box(Vector3(0,0.14,0),Vector3(0.045,0.003,0.018),Color.WHITE)
            if type=="burette":
                rod(Vector3(-0.015,0.01,0),Vector3(0.015,0.01,0),0.004,Color("dfb96b"))
            if type in ["burette","syringe"]: rod(Vector3(0,0,0),Vector3(0,-0.025,0),0.002,metal,glass)
            for i in range(1,10): rod(Vector3(-r*0.5,h*i/10,r),Vector3(r*0.5,h*i/10,r),0.0006)
        "separatory","funnel":
            if type=="funnel": vessel([Vector2(0.005,0),Vector2(0.005,0.07),Vector2(0.04,0.12)])
            else:
                vessel([Vector2(0.003,0),Vector2(0.004,0.05),Vector2(0.01,0.065),Vector2(0.035,0.11),Vector2(0.025,0.14),Vector2(0.008,0.155)])
                rod(Vector3(-0.022,0.045,0),Vector3(0.022,0.045,0),0.004,Color("daba77"))
                ball(Vector3(0,0.166,0),0.011,metal,glass)
        "crucible","dish","mortar":
            vessel([Vector2(0.023,0),Vector2(0.04,0.025 if type=="dish" else 0.05)],true)
            if type=="mortar": rod(Vector3(0,0.02,0),Vector3(0.075,0.09,0),0.009,Color("e9e4d5"))
        "spotplate":
            box(Vector3(0,0.005,0),Vector3(0.13,0.01,0.04),Color("e5e6de"))
            for i in range(4): ring(Vector3(-0.046+i*0.03,0.012,0),0.011)
        "utube":
            tube([Vector3(-0.024,0.15,0),Vector3(-0.024,0.03,0),Vector3(-0.012,0.01,0),Vector3(0.012,0.01,0),Vector3(0.024,0.03,0),Vector3(0.024,0.15,0)],0.006,metal,glass)
        "tank","bath","collection":
            box(Vector3(0,0.04,0),Vector3(0.16,0.08,0.11),Color(0.4,0.65,0.8,0.45)).material_override = glass
            if type=="collection":
                rod(Vector3(0,0.03,0),Vector3(0,0.17,0),0.025,metal,glass)
                tube([Vector3(-0.08,0.14,0),Vector3(-0.06,0.025,0),Vector3(0,0.025,0)],0.004,Color("cebd82"))
        "stand": stand()
        "clamp","tongs","scissors":
            tube([Vector3(-0.014,0,0),Vector3(0.006,0.06,0),Vector3(-0.025,0.13,0)],0.003)
            tube([Vector3(0.014,0,0),Vector3(-0.006,0.06,0),Vector3(0.025,0.13,0)],0.003)
            if type=="scissors":
                for x in [-0.024,0.024]: ring(Vector3(x,0.14,0),0.012,Color("dbaa45")).rotation.x = PI/2
        "mesh":
            for i in range(9):
                rod(Vector3(-0.055,0.02,-0.055+i*0.014),Vector3(0.055,0.02,-0.055+i*0.014),0.001)
                rod(Vector3(-0.055+i*0.014,0.02,-0.055),Vector3(-0.055+i*0.014,0.02,0.055),0.001)
        "tripod","ring","triangle":
            ring(Vector3(0,0.12,0),0.04)
            if type!="ring":
                for i in range(3):
                    var v := Vector3(cos(i*TAU/3),0,sin(i*TAU/3))
                    rod(v*0.04+Vector3.UP*0.12,v*0.06,0.003)
        "rack":
            for y in [0.006,0.085]: box(Vector3(0,y,0),Vector3(0.17,0.01,0.055),Color("be9656"))
            for x in [-0.08,0.08]: rod(Vector3(x,0,0),Vector3(x,0.1,0),0.006,Color("be9656"))
        "lift","stairs":
            for y in [0.008,0.09]: box(Vector3(0,y,0),Vector3(0.12,0.008,0.09),metal)
            for direction in [-1,1]: rod(Vector3(direction*0.05,0.015,0),Vector3(-direction*0.05,0.085,0),0.003)
        "lamp","bunsen","torch","candle","hotplate","mantle":
            if type in ["hotplate","mantle"]:
                box(Vector3(0,0.015,0),Vector3(0.12,0.03,0.12),Color("e5e6dd"))
                ring(Vector3(0,0.033,0),0.045)
            elif type=="lamp":
                var b := ball(Vector3(0,0.033,0),0.036,metal,glass)
                b.scale.y = 0.65
                rod(Vector3(0,0.05,0),Vector3(0,0.075,0),0.005,Color("dec384"))
            else:
                rod(Vector3.ZERO,Vector3(0,0.1,0),0.014 if type=="candle" else 0.006,Color("d38a65") if type=="candle" else metal)
                ring(Vector3(0,0.007,0),0.035,Color("bd954f"))
        "tube90","tube","bent","hose","tee","wye","stoppertube","valve":
            var c := Color("d3be86") if type=="hose" else metal
            if type=="tube": rod(Vector3.ZERO,Vector3(0,0.15,0),0.004,c,glass)
            elif type in ["tee","wye"]:
                tube([Vector3(0,0,0),Vector3(0,0.07,0),Vector3(-0.055,0.1 if type=="wye" else 0.07,0)],0.004,c,glass)
                rod(Vector3(0,0.07,0),Vector3(0.055,0.1 if type=="wye" else 0.07,0),0.004,c,glass)
            else: tube([Vector3(-0.055,0,0),Vector3(-0.055,0.045,0),Vector3(0.055,0.045,0),Vector3(0.055,0,0)],0.004,c,glass if type!="hose" else null)
            if type in ["stoppertube","valve"]: box(Vector3(0,0.035,0),Vector3(0.035,0.025,0.025),Color("c1a374"))
        "stopper": rod(Vector3.ZERO,Vector3(0,0.025,0),0.018,Color("ceb07a"))
        "rod","wire","spoon","brush","thermometer","match","stirrer":
            rod(Vector3(0,0.008,0),Vector3(0,0.16,0),0.002,Color("d1ba81") if type=="match" else metal,glass if type in ["rod","thermometer"] else null)
            if type in ["spoon","brush","thermometer","match"]:
                var b := ball(Vector3(0,0.012,0),0.008,Color("e38b56") if type!="spoon" else metal)
                b.scale = Vector3(1,2,0.5)
            if type=="stirrer": box(Vector3(0,0.01,0),Vector3(0.065,0.004,0.012),Color("ede7d7"))
        "lens":
            var r := ring(Vector3(0,0.105,0),0.037)
            r.rotation.x = PI/2
            rod(Vector3(0,0.0,0),Vector3(0,0.07,0),0.003)
            ball(Vector3(0,0.105,0),0.035,metal,glass).scale.z = 0.15
        "balance","timer","meter","spectrum","conductivity":
            box(Vector3(0,0.025,0),Vector3(0.13,0.05,0.08),Color("d0dcd8"))
            box(Vector3(0,0.03,0.042),Vector3(0.08,0.027,0.003),Color("1d343d"))
            if type=="balance": rod(Vector3(0,0.05,0),Vector3(0,0.055,0),0.04,metal)
            if type in ["meter","conductivity"]: rod(Vector3(0.09,0.008,0),Vector3(0.09,0.14,0),0.003)
        "dryingtube","condenser","condenserstand":
            tube([Vector3(0,0,0),Vector3(0,0.18,0)],0.013,metal,glass)
            rod(Vector3(0,0,0),Vector3(0,0.18,0),0.005,metal,glass)
            for y in [0.025,0.155]: rod(Vector3(0,y,0),Vector3(0.04,y+0.015,0),0.004,metal,glass)
            if type=="dryingtube": ball(Vector3(0,0.09,0),0.027,metal,glass)
            if type=="condenserstand": stand()
        "generator","kipp","electrolyzer","calorimeter","doublebulb":
            if type=="calorimeter": vessel([Vector2(0.045,0),Vector2(0.045,0.1)],true)
            elif type=="electrolyzer":
                for x in [-0.04,0,0.04]: rod(Vector3(x,0.015,0),Vector3(x,0.2,0),0.011,metal,glass)
                rod(Vector3(-0.04,0.02,0),Vector3(0.04,0.02,0),0.008,metal,glass)
            else:
                flask()
                if type in ["kipp","doublebulb"]: ball(Vector3(0,0.23,0),0.035,metal,glass)
                if type=="generator": stand()
        "balloon": ball(Vector3(0,0.085,0),0.06,Color("da857f"))
        "cotton","paperflower":
            for i in range(6): ball(Vector3(cos(i)*0.022,0.02,sin(i)*0.022),0.02,Color("b8a0cf") if type=="paperflower" else Color("eee6d3"))
        "firework": rod(Vector3.ZERO,Vector3(0,0.15,0),0.018,Color("dbb258"))
        "spray":
            vessel([Vector2(0.027,0),Vector2(0.024,0.1),Vector2(0.01,0.12)])
            box(Vector3(0.013,0.13,0),Vector3(0.07,0.02,0.02),Color("73baca"))
        _:
            box(Vector3(0,0.008,0),Vector3(0.11,0.008,0.07),Color("dbc493") if type=="block" else Color("d1d8d6"))
    caption = Label3D.new()
    caption.text = item.name
    caption.font_size = 30
    caption.pixel_size = 0.00060
    caption.position = Vector3(0,-0.023,0)
    caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    caption.modulate = Color("d7e0e3")
    add_child(caption)

func set_liquid(volume_ml: float, capacity_ml: float, color: Color = Color(0.45,0.77,0.92,0.48)) -> void:
    if content:
        body.remove_child(content)
        content.queue_free()
        content = null
    if volume_ml<=0 or fill_profile.size()<2:
        return
    # Integrate the rotational profile; volume determines height, not a canned pose.
    var volumes: Array[float] = []
    var total := 0.0
    for i in range(fill_profile.size()-1):
        var a := fill_profile[i]
        var b := fill_profile[i+1]
        total += PI*(b.y-a.y)*(a.x*a.x+a.x*b.x+b.x*b.x)/3
        volumes.append(total)
    var wanted := total*clampf(volume_ml/capacity_ml,0,1)
    var p: Array[Vector2] = [Vector2(0,0.002),fill_profile[0]]
    var prior := 0.0
    for i in range(fill_profile.size()-1):
        var a := fill_profile[i]
        var b := fill_profile[i+1]
        if volumes[i]<=wanted:
            p.append(b)
            prior = volumes[i]
        else:
            var lo := 0.0
            var hi := 1.0
            for j in range(22):
                var f := (lo+hi)/2
                var r := lerpf(a.x,b.x,f)
                var v := PI*(b.y-a.y)*f*(a.x*a.x+a.x*r+r*r)/3
                if prior+v<wanted: lo=f
                else: hi=f
            p.append(a.lerp(b,(lo+hi)/2))
            break
    p.append(Vector2(0,p[-1].y))
    var mat := Room.material(color,0.2)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    content = lathe(p,mat)
