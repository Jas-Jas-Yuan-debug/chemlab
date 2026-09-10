extends RefCounted
# Dimensions in metres. Griffin 250 mL: ~68 mm OD x 90 mm;
# narrow-mouth 250 mL reagent bottle: ~70 mm OD x 160 mm incl. stopper.
# Source: Corning 1000-250 and 1500-250; details in docs/REACTION_DYNAMICS.md.
static func shape(kind: String, capacity: float) -> Dictionary:
    var p: Array[Vector2]
    var form := "beaker"
    var base_capacity := 250.0
    if "烧瓶" in kind:
        form="flask"
        p=[]
        for i in range(19):
            var a := -PI/2+float(i)/18*PI*0.89
            p.append(Vector2(maxf(0.003,cos(a)*0.041),0.044+sin(a)*0.041))
        p.append(Vector2(0.013,0.105));p.append(Vector2(0.013,0.15))
        if "平底" in kind:p[0]=Vector2(0.017,0.003)
    elif kind=="试剂瓶" or "口瓶" in kind or "集气瓶" in kind:
        form="bottle"
        var neck := 0.012 if "广口" not in kind and "集气" not in kind else 0.024
        p=[Vector2(0.028,0.0015),Vector2(0.033,0.004),Vector2(0.035,0.012),Vector2(0.035,0.089),Vector2(0.033,0.098),Vector2(0.027,0.108),Vector2(neck+0.003,0.12),Vector2(neck,0.125),Vector2(neck,0.145),Vector2(neck+0.0015,0.147)]
    elif "量筒" in kind:
        form="cylinder";base_capacity=100
        p=[Vector2(0.018,0.002),Vector2(0.018,0.181),Vector2(0.019,0.184)]
    elif "滴管" in kind:
        form="dropper";base_capacity=5
        p=[Vector2(0.002,0.003),Vector2(0.002,0.027),Vector2(0.0075,0.045),Vector2(0.0075,0.105)]
    elif "试管" in kind:
        form="testtube";base_capacity=25
        p=[]
        for i in range(10):
            var a := -PI/2+float(i)/9*PI/2
            p.append(Vector2(maxf(0.001,cos(a)*0.010),0.012+sin(a)*0.010))
        p.append(Vector2(0.010,0.13));p.append(Vector2(0.011,0.131))
    else:
        p=[Vector2(0.028,0.0015),Vector2(0.0325,0.003),Vector2(0.034,0.007),Vector2(0.034,0.085),Vector2(0.035,0.089),Vector2(0.0345,0.090)]
    var scale := pow(capacity/base_capacity,1.0/3.0)
    for i in p.size():p[i]*=scale
    var inner: Array[Vector2]=[]
    for v in p:
        inner.append(Vector2(maxf(0.0005,v.x-0.0014*scale),maxf(v.y,0.0035*scale)))
    # Remove equal-height points at the bottom of the inner cavity.
    while inner.size()>2 and inner[0].y>=inner[1].y:inner.remove_at(0)
    return {"outer":p,"inner":inner,"form":form,"scale":scale,"radius":p.map(func(v):return v.x).max(),"height":p[-1].y}

static func radius_at(profile: Array[Vector2], y: float) -> float:
    if y<profile[0].y or y>profile[-1].y:return 0
    for i in range(profile.size()-1):
        if y<=profile[i+1].y:
            return lerpf(profile[i].x,profile[i+1].x,(y-profile[i].y)/maxf(profile[i+1].y-profile[i].y,1e-10))
    return profile[-1].x

static func profile_volume(profile: Array[Vector2], level: float) -> float:
    var volume := 0.0
    for i in range(profile.size()-1):
        var a:=profile[i];var b:=profile[i+1]
        if level<=a.y:break
        var top:=minf(level,b.y)
        var r:=lerpf(a.x,b.x,(top-a.y)/maxf(b.y-a.y,1e-10))
        volume+=PI*(top-a.y)*(a.x*a.x+a.x*r+r*r)/3
    return volume

static func point(profile: Array[Vector2], index: int, angle: float, spout: bool, rim_y: float) -> Vector3:
    var p:=profile[index]
    var lip:=clampf((p.y-rim_y+0.014)/0.014,0,1)
    var bulge:=pow(maxf(0,cos(angle)),28)*lip*lip if spout else 0.0
    return Vector3((p.x+0.008*bulge)*cos(angle),p.y-0.003*bulge,(p.x+0.008*bulge)*sin(angle))

static func shell_mesh(outer: Array[Vector2], inner: Array[Vector2], spout: bool) -> ArrayMesh:
    var profile: Array[Vector2]=[Vector2(0,outer[0].y)]
    profile.append_array(outer)
    for i in range(inner.size()-1,-1,-1):profile.append(inner[i])
    profile.append(Vector2(0,inner[0].y))
    var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for j in range(profile.size()-1):
        for i in range(96):
            var a:=TAU*i/96;var b:=TAU*(i+1)/96
            var corners: Array[Vector3]=[point(profile,j,a,spout,outer[-1].y),point(profile,j+1,a,spout,outer[-1].y),point(profile,j+1,b,spout,outer[-1].y),point(profile,j,b,spout,outer[-1].y)]
            for tri in [[0,1,2],[0,2,3]]:
                if (corners[tri[1]]-corners[tri[0]]).cross(corners[tri[2]]-corners[tri[0]]).length_squared()<1e-22:continue
                for k in tri:
                    var t:=a if k<2 else b
                    var along:=point(profile,j+1,t,spout,outer[-1].y)-point(profile,j,t,spout,outer[-1].y)
                    var normal:=along.cross(Vector3(-sin(t),0,cos(t))).normalized()
                    surface.set_normal(normal)
                    surface.add_vertex(corners[k])
    return surface.commit()
