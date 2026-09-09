extends Node3D

static func material(color: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = roughness
    m.metallic = metallic
    return m

func box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = mat
    node.position = pos
    add_child(node)
    return node

func _ready() -> void:
    var wall := material(Color("c9cdc5"))
    var cream := material(Color("e9e5d9"))
    var oak := material(Color("8b6548"), 0.62)
    var charcoal := material(Color("242c2b"), 0.32)
    var metal := material(Color("7a8989"), 0.24, 0.82)
    var grain := NoiseTexture2D.new()
    grain.width = 256
    grain.height = 256
    var noise := FastNoiseLite.new()
    noise.seed = 2718
    noise.frequency = 0.06
    grain.noise = noise
    var gradient := Gradient.new()
    gradient.set_color(0,Color("78634b"))
    gradient.set_color(1,Color("a78c63"))
    grain.color_ramp = gradient
    oak.albedo_color = Color.WHITE
    oak.albedo_texture = grain
    oak.uv1_scale = Vector3(0.25,5.0,1.0)
    var stone := NoiseTexture2D.new()
    stone.width = 256
    stone.height = 256
    var fine := FastNoiseLite.new()
    fine.seed = 83
    fine.frequency = 0.8
    stone.noise = fine
    var shades := Gradient.new()
    shades.set_color(0,Color("252d2a"))
    shades.set_color(1,Color("323b36"))
    stone.color_ramp = shades
    charcoal.albedo_color = Color.WHITE
    charcoal.albedo_texture = stone
    charcoal.roughness = 0.42
    box(Vector3(5,0.10,5),Vector3(0,-0.05,0),material(Color("b0afa4")))
    # Subtle grout lines preserve scale without large textures.
    for i in range(-5,6):
        box(Vector3(0.005,0.001,5),Vector3(i*0.5,0.001,0),material(Color("858b84")))
        box(Vector3(5,0.001,0.005),Vector3(0,0.001,i*0.5),material(Color("858b84")))
    box(Vector3(5,3,0.12),Vector3(0,1.5,-1.65),wall)
    box(Vector3(0.12,3,4),Vector3(-2.2,1.5,0),cream)
    box(Vector3(2.0,0.07,0.82),Vector3(0,0.855,0),charcoal)
    box(Vector3(1.86,0.045,0.70),Vector3(0,0.805,0),oak)
    for x in [-0.82,0.82]:
        for z in [-0.28,0.28]:
            box(Vector3(0.045,0.80,0.045),Vector3(x,0.40,z),metal)
    # Back counter, cabinets and open shelves.
    box(Vector3(3.2,0.83,0.46),Vector3(0,0.415,-1.34),oak)
    box(Vector3(3.26,0.04,0.51),Vector3(0,0.85,-1.34),cream)
    for x in [-1.16,-0.39,0.39,1.16]:
        box(Vector3(0.72,0.67,0.014),Vector3(x,0.43,-1.099),material(Color("ad9776")))
        box(Vector3(0.19,0.014,0.024),Vector3(x,0.68,-1.074),metal)
    for y in [1.43,1.95]:
        box(Vector3(2.1,0.035,0.24),Vector3(0.45,y,-1.50),oak)
        for x in [-0.35,0.32,0.99]:
            box(Vector3(0.015,0.19,0.18),Vector3(x,y-0.10,-1.52),metal)
    for i in range(8):
        var bottle := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.027
        mesh.bottom_radius = 0.031
        mesh.height = 0.13 + (i%3)*0.017
        bottle.mesh = mesh
        bottle.position = Vector3(-0.40+i*0.21,1.45+mesh.height/2,-1.50)
        bottle.material_override = material(Color("6d4930"),0.18)
        add_child(bottle)
        box(Vector3(0.045,0.055,0.006),bottle.position+Vector3(0,0,0.031),cream)
    # Daylight window and frame, with a bright frosted pane.
    box(Vector3(1.10,1.35,0.04),Vector3(-1.45,1.89,-1.55),metal)
    var sky := material(Color("c4dbdf"),0.24)
    sky.emission_enabled = true
    sky.emission = Color("c4dbdf")
    sky.emission_energy_multiplier = 0.5
    box(Vector3(1.00,1.24,0.045),Vector3(-1.45,1.89,-1.51),sky)
    box(Vector3(0.027,1.25,0.05),Vector3(-1.45,1.89,-1.48),cream)
    box(Vector3(1.02,0.027,0.05),Vector3(-1.45,1.89,-1.48),cream)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48,-24,0)
    sun.light_color = Color("ffe8c7")
    sun.light_energy = 0.9
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 8
    add_child(sun)
    var fill := OmniLight3D.new()
    fill.position = Vector3(0.4,2.1,0.5)
    fill.light_color = Color("d2e6ef")
    fill.light_energy = 0.65
    fill.omni_range = 3.2
    add_child(fill)
    var env := WorldEnvironment.new()
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = Color("b4c7c9")
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("d3e4e5")
    settings.ambient_light_energy = 0.30
    settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.environment = settings
    add_child(env)

    # A real stirring rod prop. Stirring kinetics remain unsupported.
    var rod := MeshInstance3D.new()
    var rod_mesh := CylinderMesh.new()
    rod_mesh.top_radius = 0.0025
    rod_mesh.bottom_radius = 0.0025
    rod_mesh.height = 0.22
    rod.mesh = rod_mesh
    rod.rotation_degrees = Vector3(90,20,0)
    rod.position = Vector3(0.48,0.893,0.25)
    rod.material_override = material(Color("c0dedb"),0.12,0.15)
    add_child(rod)
