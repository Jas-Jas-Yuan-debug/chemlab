extends Node
const Apparatus = preload("res://scripts/apparatus_model.gd")
const Heater = preload("res://scripts/heater_apparatus.gd")
const Indicators = preload("res://scripts/indicators.gd")
const GROUPS = ["容器","加热","连接","支撑","测量","取用","耗材","组合装置","固体药品","溶液"]
const COLORS = {"white":"e5e4db","black":"30333a","gray":"899399","silver":"c9d2d6","purple":"796299","yellow":"dacf7b","sand":"b4a080","copper":"be815d","blue":"508fc4","brown":"9c7356","red":"a9594c","green":"7da690","pink":"bd97a1","orange":"c99355"}
var lab: Node3D
var active := false
var layer := CanvasLayer.new()
var ui := Control.new()
var viewport := SubViewport.new()
var canvas := SubViewportContainer.new()
var world := Node3D.new()
var camera := Camera3D.new()
var catalog: Array = []
var definitions := {}
var objects := {}
var links: Array = []
var selected := ""
var group := "容器"
var query := ""
var search: LineEdit
var cards: GridContainer
var detail_title: Label
var reading: Label
var message: Label
var help_text: Label
var actions: VBoxContainer
var target: OptionButton
var dose: SpinBox
var temperature: SpinBox
var rpm: SpinBox
var flame_switch: CheckButton
var wind: SpinBox
var heat_panel: VBoxContainer
var heat_reading: Label
var heater: Node3D
var heater_mode := false
var selected_reagent := 0
var pending_definition := {}
var dragging := false
var drag_offset := Vector3.ZERO
var guide := 0
var notes: Array = []
var inventory_revision := -1
var refresh_clock := 0.0
var stopwatch := 0.0
var stopwatch_running := false
var chosen_target := ""
var next_id := 1
var title_count: Label
var experiment_picker: OptionButton

func _ready() -> void:
    for file in ["apparatus","materials"]:
        catalog.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json"%file)).items)
    for d in catalog:
        definitions[d.id] = d
    for reagent in lab.catalog:
        var d := {"id":"reagent%d"%reagent.id,"name":reagent.name_zh,"formula":reagent.formula,"category":"溶液","model":"bottle","action":"reagent","reagent_id":int(reagent.id),"operational":reagent.validation.operational,"scope":reagent.applicability}
        catalog.append(d)
        definitions[d.id] = d
    var favorites := ["烧杯250mL","圆底烧瓶","小试管","量筒100mL","胶头滴管","细口瓶","球形分液漏斗","烧杯100mL"]
    catalog.sort_custom(func(a,b):
        var ai: int=favorites.find(a.name)
        var bi: int=favorites.find(b.name)
        if ai<0:ai=1000
        if bi<0:bi=1000
        return ai<bi)
    add_child(layer)
    layer.layer = 10
    layer.add_child(ui)
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.theme = lab.ui_theme.duplicate()
    for kind in ["normal","hover","pressed"]:
        ui.theme.set_stylebox(kind,"Button",lab.style(Color("343d46") if kind=="normal" else Color("435964"),Color("48525c")))
    var background := ColorRect.new()
    background.color = Color("252c33")
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.add_child(background)
    var margin := MarginContainer.new()
    ui.add_child(margin)
    margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,18)
    var layout := VBoxContainer.new()
    layout.add_theme_constant_override("separation",14)
    margin.add_child(layout)
    var toolbar := HBoxContainer.new()
    toolbar.add_theme_constant_override("separation",10)
    layout.add_child(toolbar)
    var title: Label = lab.label(toolbar,"CHEMLAB  /  自在实验",24,Color("e0ecee"))
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lab.button(toolbar,"保存","BeginnerSave",func(): lab.open_session_dialog("save"))
    lab.button(toolbar,"加载","BeginnerLoad",func(): lab.open_session_dialog("load"))
    lab.button(toolbar,"实验报告","BeginnerReport",show_report)
    lab.button(toolbar,"重新开始","BeginnerReset",reset_workspace)
    lab.button(toolbar,"进入专业模式 →","AdvancedMode",func(): lab.switch_experiment(false))
    var main := HBoxContainer.new()
    main.size_flags_vertical = Control.SIZE_EXPAND_FILL
    main.add_theme_constant_override("separation",18)
    layout.add_child(main)
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation",12)
    main.add_child(left)
    var header := HBoxContainer.new()
    left.add_child(header)
    experiment_picker = OptionButton.new()
    experiment_picker.name = "BeginnerExperiment"
    for s in ["自由搭建","跟着做 · 酸碱中和","跟着做 · 加热与搅拌"]:
        experiment_picker.add_item(s)
    experiment_picker.item_selected.connect(select_guide)
    header.add_child(experiment_picker)
    help_text = lab.label(header,"从右侧选择器材，拖到合适的位置。",15,Color("a9bbc6"))
    help_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lab.button(header,"－","BeginnerZoomOut",func(): camera.size=minf(1.5,camera.size*1.12))
    lab.button(header,"＋","BeginnerZoomIn",func(): camera.size=maxf(0.35,camera.size/1.12))
    lab.button(header,"居中","BeginnerFocus",func(): camera.size=0.40)
    canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
    canvas.custom_minimum_size = Vector2(620,310)
    canvas.stretch = true
    canvas.gui_input.connect(canvas_input)
    left.add_child(canvas)
    viewport.own_world_3d = true
    viewport.handle_input_locally = false
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    viewport.msaa_3d = Viewport.MSAA_2X
    canvas.add_child(viewport)
    viewport.add_child(world)
    var environment := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color("343e49")
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("d9e4eb")
    e.ambient_light_energy = 0.8
    e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.environment = e
    world.add_child(environment)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-38,-32,0)
    light.light_energy = 1.8
    world.add_child(light)
    var fill := OmniLight3D.new()
    fill.position = Vector3(-0.4,0.6,0.6)
    fill.light_energy = 0.6
    fill.omni_range = 2
    world.add_child(fill)
    world.add_child(camera)
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 0.40
    camera.position = Vector3(0,0.46,2.2)
    camera.look_at(Vector3(0,0.12,0))
    camera.near = 0.01
    var bottom := PanelContainer.new()
    bottom.add_theme_stylebox_override("panel",lab.style(Color("202a32")))
    bottom.custom_minimum_size.y = 230
    left.add_child(bottom)
    var bottom_row := HBoxContainer.new()
    bottom_row.add_theme_constant_override("separation",20)
    bottom.add_child(bottom_row)
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bottom_row.add_child(info)
    detail_title = lab.label(info,"选中器材后开始操作",22,Color("d6eef1"))
    reading = lab.label(info,"",16,Color("c7d2d9"))
    reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    reading.size_flags_vertical = Control.SIZE_EXPAND_FILL
    var edit_row := HBoxContainer.new()
    info.add_child(edit_row)
    lab.button(edit_row,"旋转","BeginnerRotate",rotate_selected)
    lab.button(edit_row,"收回","BeginnerRemove",remove_selected)
    lab.button(edit_row,"断开连接","BeginnerDisconnect",disconnect_selected)
    actions = VBoxContainer.new()
    actions.custom_minimum_size.x = 280
    bottom_row.add_child(actions)
    target = OptionButton.new()
    target.name = "BeginnerTarget"
    target.item_selected.connect(func(index): chosen_target=target.get_item_metadata(index))
    actions.add_child(target)
    dose = lab.number(actions,"取用量 / mL 或 g",0.05,250,0.05,5,"BeginnerDose")
    lab.button(actions,"取用 / 转移","BeginnerUse",use_selected)
    lab.button(actions,"用所选溶液重新配液","BeginnerPrepare",prepare_liquid)
    var connect_row := HBoxContainer.new()
    actions.add_child(connect_row)
    lab.button(connect_row,"连接","BeginnerConnect",connect_selected)
    lab.button(connect_row,"固定到支架","BeginnerAttach",attach_selected)
    lab.button(actions,"加入指示剂 · 酚酞","BeginnerIndicator",apply_indicator)
    lab.button(actions,"专用溶解实验","BeginnerDissolution",func():
        if objects.has(selected):lab.choose_reagent(definitions[objects[selected].state.definition].get("batch_reagent",18)))
    heat_panel = VBoxContainer.new()
    heat_panel.custom_minimum_size.x = 330
    bottom_row.add_child(heat_panel)
    temperature = lab.number(heat_panel,"目标水温 / °C",25,95,1,60,"BeginnerTemperature")
    rpm = lab.number(heat_panel,"搅拌转速 / rpm",0,600,10,300,"BeginnerRPM")
    var control_row := HBoxContainer.new()
    heat_panel.add_child(control_row)
    lab.button(control_row,"应用","BeginnerApplyHeat",apply_heat)
    lab.button(control_row,"加热开关","BeginnerHeat",func(): heat_toggle("heat_enabled"))
    lab.button(control_row,"搅拌开关","BeginnerStir",func(): heat_toggle("stir_enabled"))
    flame_switch = CheckButton.new()
    flame_switch.name = "BeginnerFlame3D"
    flame_switch.text = "三维简化燃烧模拟"
    flame_switch.toggled.connect(toggle_flame)
    heat_panel.add_child(flame_switch)
    lab.button(heat_panel,"燃烧产物与能量","BeginnerCombustionReport",func():lab.bench_experiment.show_combustion_report())
    wind = lab.number(heat_panel,"侧向气流 / m·s⁻¹",-0.12,0.12,0.01,0,"BeginnerWind")
    heat_reading = lab.label(heat_panel,"",14,Color("c0d4da"))
    heat_reading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heat_panel.hide()
    var sidebar := VBoxContainer.new()
    sidebar.custom_minimum_size.x = 440
    main.add_child(sidebar)
    search = LineEdit.new()
    search.name = "BeginnerSearch"
    search.placeholder_text = "搜索器材 / 药品 / 化学式"
    search.custom_minimum_size.y = 46
    search.text_changed.connect(func(text): query=text;refresh_cards())
    sidebar.add_child(search)
    title_count = lab.label(sidebar,"",14,Color("91adb9"))
    var browser := HBoxContainer.new()
    browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
    sidebar.add_child(browser)
    var rail := VBoxContainer.new()
    rail.add_theme_constant_override("separation",5)
    browser.add_child(rail)
    for name_value in GROUPS:
        var b: Button = lab.button(rail,name_value,"Category"+name_value,func(): group=name_value;refresh_cards())
        b.custom_minimum_size = Vector2(82,48)
        b.add_theme_font_size_override("font_size",14)
    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    browser.add_child(scroll)
    cards = GridContainer.new()
    cards.columns = 2
    cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cards.add_theme_constant_override("h_separation",10)
    cards.add_theme_constant_override("v_separation",10)
    scroll.add_child(cards)
    message = lab.label(layout,"",15,Color("afc8d2"))
    message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    refresh_cards()
    set_active(false)

func tell(text: String, record: bool = false) -> void:
    message.text = text
    if record:
        notes.append({"time_s":lab.elapsed,"text":text})
        if notes.size()>1000: notes.pop_front()

func refresh_cards() -> void:
    for child in cards.get_children():
        cards.remove_child(child)
        child.queue_free()
    var count := 0
    for d in catalog:
        var search_text: String = d.name+" "+d.get("formula","")
        if query.is_empty() and d.category!=group: continue
        if not query.is_empty() and query.to_lower() not in search_text.to_lower(): continue
        count+=1
        var b := Button.new()
        b.name = "Card_"+d.id
        b.custom_minimum_size = Vector2(158,160)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.pressed.connect(func(): choose(d.id))
        b.tooltip_text = d.get("scope","点击放到实验区")
        cards.add_child(b)
        var box := VBoxContainer.new()
        box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        b.add_child(box)
        box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        box.offset_left=8;box.offset_right=-8;box.offset_top=6;box.offset_bottom=-8
        var icon := TextureRect.new()
        icon.custom_minimum_size.y = 98
        icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        var path: String = "res://assets/apparatus/"+d.get("model","bottle")+".png"
        if ResourceLoader.exists(path): icon.texture=load(path)
        box.add_child(icon)
        var title: Label = lab.label(box,d.name,16,Color("dfebee"))
        title.mouse_filter=Control.MOUSE_FILTER_IGNORE
        title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
        var caption: String = d.get("formula", "%.0f mL"%d.capacity_ml if d.has("capacity_ml") else "点击添加")
        var sub: Label = lab.label(box,caption,12,Color("92aab7"))
        sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
        sub.mouse_filter=Control.MOUSE_FILTER_IGNORE
    title_count.text = "%d 项%s  ·  点击卡片添加"%[count,"搜索结果" if not query.is_empty() else group]

func set_active(value: bool) -> void:
    active=value
    layer.visible=value
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
    if not value:
        dragging=false
        lab.core.pause_bench()
    else:
        sync_vessels()
        update_targets()
        tell("点击选择 · 拖动摆放 · 连接接口 · 下方操作 · 每一步都可保存")

func choose(id: String) -> void:
    var d: Dictionary=definitions[id]
    if d.action=="reagent":
        selected_reagent=d.reagent_id
        if selected_reagent in [10,18,19]:
            lab.choose_reagent(selected_reagent)
            return
        tell("已选 %s。选中容器后点击“用所选溶液重新配液”，重新配制 %.2f mL、0.001 mol/L 溶液。%s"%[d.name,dose.value,"此条目尚未支持。" if not d.operational else ""])
        return
    if d.action=="vessel":
        if lab.core.is_busy(): tell("请等待当前计算完成。");return
        pending_definition=d
        lab.add_vessel(d.name,float(d.get("capacity_ml",250)))
        return
    if objects.size()>=60: tell("实验区最多放置 60 件器材；收回一些后再添加。");return
    var key := "o%d"%next_id
    next_id+=1
    var state := {"definition":id,"position":[0,0,0],"rotation":0.0,"vessel_id":0,"mass_g":d.get("default_mass_g",0.0),"contents":{},"open":true,"attachments":[],"scale":1.0}
    add_object(key,state)
    select_object(key)
    if d.action=="heater": activate_heater(d.get("source",0))
    else: tell("已添加 "+d.name+"。"+d.get("scope","选择接收对象后可操作。"),true)

func add_object(key: String, state: Dictionary, keep_position: bool = false) -> void:
    var d: Dictionary=definitions[state.definition]
    var model := Apparatus.new()
    world.add_child(model)
    model.build(d)
    if not keep_position:
        var slot := objects.size()%12
        state.position=[(slot%4-1.5)*0.19,0.005,0.08-float(slot/4)*0.18]
    model.position=Vector3(state.position[0],state.position[1],state.position[2])
    model.rotation.y=state.rotation
    var collider := StaticBody3D.new()
    collider.set_meta("object_id",key)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size=Vector3(maxf(model.nominal_radius*2,0.06),maxf(model.nominal_height,0.18),0.06)
    shape.shape=box
    shape.position.y=box.size.y/2
    collider.add_child(shape)
    model.add_child(collider)
    objects[key]={"state":state,"model":model,"last_volume":-1.0,"last_ph":null}
    if d.action=="solid":
        model.set_liquid(100,250,Color(COLORS.get(d.get("appearance","white"),"e4e5da")))
    update_targets()

func sync_vessels() -> void:
    for key in objects.keys():
        var id := int(objects[key].state.vessel_id)
        if id>0 and not lab.states.has(id):
            objects[key].model.queue_free()
            objects.erase(key)
            links=links.filter(func(link):return key not in link)
            if selected==key:selected=""
            if chosen_target==key:chosen_target=""
    for id in lab.states:
        var key := "v%d"%id
        var s: Dictionary=lab.states[id]
        if not objects.has(key):
            var d: Dictionary=pending_definition if not pending_definition.is_empty() and lab.views[id].kind==pending_definition.name else find_definition(lab.views[id].kind,s.capacity_ml)
            var state := {"definition":d.id,"position":[0,0,0],"rotation":0.0,"vessel_id":int(id),"mass_g":0.0,"contents":{},"open":true,"attachments":[],"scale":1.0}
            add_object(key,state)
            if not pending_definition.is_empty() and d.id==pending_definition.id:
                pending_definition={}
                select_object(key)
        var o: Dictionary=objects[key]
        var substances: Array[String]=[]
        for reagent_id in s.ingredients_mol:
            if int(reagent_id)>0 and int(reagent_id)<=lab.catalog.size():substances.append(lab.catalog[int(reagent_id)-1].formula)
        o.model.caption.text="%s · %s\n%.1f mL"%[key," + ".join(substances) if not substances.is_empty() else "H₂O" if s.volume_ml>0 else "空容器",s.volume_ml]
        var color := Color(0.46,0.76,0.89,0.48)
        if s.ph!=null and lab.indicator_by_vessel.get(id,0)>0:
            color=Indicators.color_for(lab.indicator_by_vessel[id],s.ph)
        if o.last_volume!=s.volume_ml or o.last_ph!=s.ph or o.get("color",Color.BLACK)!=color:
            o.model.set_liquid(s.volume_ml,s.capacity_ml,color)
            o.last_volume=s.volume_ml;o.last_ph=s.ph;o.color=color
    if selected.is_empty() and not objects.is_empty(): select_object(objects.keys()[0])

func find_definition(kind: String, capacity: float) -> Dictionary:
    if kind=="试剂瓶":kind="细口瓶"
    for d in catalog:
        if d.name==kind and d.action=="vessel": return d
    var target_name := "烧杯250mL" if capacity==250 else "量筒100mL" if capacity==100 else "胶头滴管"
    for d in catalog:
        if d.name==target_name:return d
    return catalog[0]

func select_object(key: String) -> void:
    selected=key
    for id in objects:
        objects[id].model.caption.modulate=Color("8ae0ed") if id==selected else Color("d7e0e3")
    var state: Dictionary=objects[key].state
    if state.vessel_id>0:lab.select_vessel(int(state.vessel_id))
    update_detail()

func update_targets() -> void:
    if not target:return
    target.clear()
    for id in objects:
        var d: Dictionary=definitions[objects[id].state.definition]
        target.add_item("接收 / 操作："+d.name+" · "+id)
        target.set_item_metadata(target.item_count-1,id)
        if id==chosen_target:target.select(target.item_count-1)
    if not objects.has(chosen_target):chosen_target=""
    if chosen_target.is_empty() and target.item_count>0:
        chosen_target=target.get_item_metadata(0)

func update_detail() -> void:
    if not objects.has(selected):return
    var state: Dictionary=objects[selected].state
    var d: Dictionary=definitions[state.definition]
    detail_title.text=d.name+"  ·  "+selected
    for name_value in ["BeginnerPrepare","BeginnerIndicator"]:
        var control=ui.find_child(name_value,true,false)
        if control:control.visible=d.action=="vessel"
    ui.find_child("BeginnerConnect",true,false).visible=d.get("ports",0)>0
    ui.find_child("BeginnerAttach",true,false).visible=d.category=="支撑" or d.action in ["hold","vessel"]
    ui.find_child("BeginnerDissolution",true,false).visible=d.has("batch_reagent")
    var lines: Array[String]=[]
    if state.vessel_id>0 and lab.states.has(int(state.vessel_id)):
        var s: Dictionary=lab.states[int(state.vessel_id)]
        lines.append("%.2f / %.0f mL    25.0 °C"%[s.volume_ml,s.capacity_ml])
        lines.append("pH  "+("—" if s.ph==null else "%.2f"%s.ph))
    if d.action=="solid":lines.append(d.formula+"    剩余 %.2f g"%state.mass_g)
    if not state.contents.is_empty():
        for id in state.contents: lines.append("%s  %.2f g（未求解反应）"%[definitions[id].name,state.contents[id]])
    if d.get("ports",0)>0:lines.append("%d 个连接口    %s"%[d.ports,"通路开启" if state.open else "通路关闭"])
    var count := 0
    for link in links:
        if selected in link: count+=1
    if count>0:lines.append("已连接 %d 件器材"%count)
    if d.action in ["material","solid","no2","dry","scrub","gasreaction","iodine","condenser"]:
        lines.append(d.get("scope","可摆放与连接；该专用反应尚未验证。"))
    if stopwatch_running or stopwatch>0:lines.append("秒表  %.2f s"%stopwatch)
    reading.text="\n".join(lines)

func prepare_liquid() -> void:
    if not objects.has(selected):return
    var obj: Dictionary=objects[selected].state
    if obj.vessel_id<=0 or selected_reagent<=0:tell("先选择一个溶液卡片，再选择容器。");return
    if not obj.contents.is_empty():tell("容器含未求解固体，暂不能配液。");return
    var reagent: Dictionary=definitions["reagent%d"%selected_reagent]
    if not reagent.operational or selected_reagent in [10,18,19]:tell(reagent.scope);return
    if lab.core.is_busy():tell("请等待当前计算完成。");return
    var cap: float=lab.states[int(obj.vessel_id)].capacity_ml
    if dose.value<1 or dose.value>minf(250,cap):tell("配液体积需在 1 mL 与容器容量之间；每次最多 250 mL。");return
    lab.chosen_reagent=selected_reagent
    lab.volume.value=dose.value
    lab.concentration.value=0.001
    lab.prepare_selected()
    tell("正在重新配制 "+reagent.name+"；此操作定义该容器的新初始条件。",true)

func use_selected() -> void:
    if not objects.has(selected):return
    var obj: Dictionary=objects[selected].state
    var d: Dictionary=definitions[obj.definition]
    var receiver: Dictionary=objects[chosen_target].state if objects.has(chosen_target) else {}
    var action: String=d.action
    if action=="vessel":
        if not obj.contents.is_empty():tell("此容器含未求解的固体，请先用药匙取回固体。不会把未求解混合物当作纯溶液。");return
        if receiver.get("vessel_id",0)>0 and chosen_target!=selected:
            if not receiver.contents.is_empty():tell("接收容器含未求解固体，暂不能加入溶液。");return
            lab.target_id=int(receiver.vessel_id)
            lab.paused=false
            lab.request_pour(dose.value)
            tell("正在转移 %.2f mL；物质与体积由同一份状态计算。"%dose.value,true)
        else:tell("请先选择一个不同的接收容器。")
    elif action=="heater":heat_toggle("heat_enabled")
    elif action=="ignite":
        if not heater_mode:activate_heater(1)
        heat_toggle("heat_enabled")
    elif action=="stir":
        if heater_mode:heat_toggle("stir_enabled")
        else:tell("水溶液模型已按充分混合求平衡。加热实验可调节实际累计转数。",true)
    elif action in ["ph","temperature","weigh"]:
        measure(action,receiver)
    elif action=="timer":stopwatch_running=not stopwatch_running;tell("秒表已开始。" if stopwatch_running else "秒表已暂停：%.2f s"%stopwatch,true)
    elif action=="solid":
        if receiver.is_empty() or selected==chosen_target:tell("选择一个接收器材后取用固体。");return
        if receiver.get("vessel_id",0)>0 and lab.states[int(receiver.vessel_id)].volume_ml>0:tell("此固液反应尚未求解。先取用到空容器；已验证的方解石 / 石膏请使用专用实验。");return
        var n := minf(dose.value,obj.mass_g)
        obj.mass_g-=n
        receiver.contents[d.id]=receiver.contents.get(d.id,0.0)+n
        tell("已取用 %s %.2f g，原料剩余 %.2f g。反应另行求解。"%[d.name,n,obj.mass_g],true)
    elif action=="scoop":
        if receiver.is_empty():tell("先选择操作对象。");return
        if not receiver.contents.is_empty():
            var id: String=receiver.contents.keys()[0]
            var n := minf(dose.value,receiver.contents[id])
            receiver.contents[id]-=n
            obj.contents[id]=obj.contents.get(id,0.0)+n
            if receiver.contents[id]<=0:receiver.contents.erase(id)
            tell("药匙取出 %s %.2f g。"%[definitions[id].name,n],true)
        elif not obj.contents.is_empty():
            for id in obj.contents:receiver.contents[id]=receiver.contents.get(id,0.0)+obj.contents[id]
            obj.contents={}
            tell("已将药匙中的样品全部转入接收对象。",true)
    elif action in ["support","hold","cover"]:attach_selected()
    elif action in ["connect","seal","valve"]:
        if action=="valve":obj.open=not obj.open;tell("止水夹已"+("打开。" if obj.open else "关闭；该节点不通流。"),true)
        else:connect_selected()
    elif action=="lift":
        obj.position[1]=fmod(obj.position[1]+0.03,0.18)
        objects[selected].model.position.y=obj.position[1]
        for id in obj.attachments:
            if objects.has(id):objects[id].model.position.y=obj.position[1]+0.10;objects[id].state.position[1]=objects[id].model.position.y
        tell("升降台高度 %.0f cm。"%(obj.position[1]*100),true)
    elif action in ["grind","cut","polish"]:
        if receiver.is_empty():tell("先选择加工对象。");return
        receiver.scale=maxf(0.125,receiver.scale/2)
        tell("已记录样品加工；质量保留。此操作不推断反应速率。",true)
    elif action=="clean":
        if receiver.is_empty():return
        if not receiver.contents.is_empty() or (receiver.get("vessel_id",0)>0 and lab.states[int(receiver.vessel_id)].volume_ml>0):tell("先把内容物转入废液缸 / 回收器材，再清洁空容器。");return
        tell("空容器已清洁。",true)
    elif action=="optics":lab.switch_bench();lab.bench_experiment.select_model(4)
    elif action=="calorimeter":lab.switch_bench();lab.bench_experiment.select_model(2)
    elif action=="conductivity":tell("此装置需要离子迁移率模型；当前不把电阻电路冒充溶液电导率。")
    elif action=="gasreaction":lab.switch_batch(false)
    elif action=="bath":activate_heater(0)
    elif action=="filter":tell("先使用已验证的沉淀实验生成固体，再通过“分离清液”完成固液分离。")
    elif action=="spectrum":tell("选择“实验报告”查看已支持模型；此光谱装置的发射强度与谱线尚未验证。")
    else:tell(d.get("scope","该器材已可摆放；专用化学行为尚未验证。"))
    update_detail()

func measure(action: String, receiver: Dictionary) -> void:
    if action=="temperature" and heater_mode:
        tell("水温 %.2f °C"%lab.core.bench_snapshot().temperature_c,true);return
    var vessel_id := int(receiver.get("vessel_id",0))
    if action=="weigh":
        var mass: float=receiver.get("mass_g",0.0)
        for n in receiver.get("contents",{}).values():mass+=float(n)
        if vessel_id>0:mass+=lab.states[vessel_id].sample_mass_g
        tell("样品读数 %.2f g（溶剂与溶质的总质量；器材已去皮）。"%mass,true)
    elif vessel_id>0 and lab.states.has(vessel_id):
        var s: Dictionary=lab.states[vessel_id]
        if not receiver.contents.is_empty():tell("此样品含未求解的固体，无法给出新的 pH。");return
        tell("读数：25.0 °C" if action=="temperature" else "pH —（空容器）" if s.ph==null else "pH %.2f"%s.ph,true)
    else:tell("先选择含液体的测量对象。")

func connect_selected() -> void:
    if not objects.has(selected) or not objects.has(chosen_target) or selected==chosen_target:return
    var a: Dictionary=definitions[objects[selected].state.definition]
    var b: Dictionary=definitions[objects[chosen_target].state.definition]
    if a.get("ports",0)<1 or (b.get("ports",0)<1 and b.action!="vessel"):
        tell("连接需要导管接口与容器开口；夹具请使用“固定到支架”。");return
    var used := 0
    var target_used := 0
    for link in links:
        if selected in link and chosen_target in link:tell("这两个接口已连接。");return
        if selected in link:used+=1
        if chosen_target in link:target_used+=1
    if used>=a.get("ports",0):tell("该器材没有空余接口。");return
    if target_used>=int(b.get("ports",1)):tell("接收对象没有空余接口。");return
    links.append([selected,chosen_target])
    tell("已连接 %s → %s。连接图记录接口；化学流动须使用已验证的专用实验。"%[a.name,b.name],true)
    redraw_links()
    update_detail()

func attach_selected() -> void:
    if not objects.has(selected) or not objects.has(chosen_target) or selected==chosen_target:return
    var destination: Dictionary=objects[chosen_target]
    var selected_definition: Dictionary=definitions[objects[selected].state.definition]
    var destination_definition: Dictionary=definitions[destination.state.definition]
    var support_id := chosen_target
    var child_id := selected
    if selected_definition.category=="支撑" or selected_definition.action=="hold":support_id=selected;child_id=chosen_target
    elif destination_definition.category!="支撑":tell("请选择支架、夹具、三脚架或升降台作为支撑。");return
    var support: Dictionary=objects[support_id]
    var child: Dictionary=objects[child_id]
    var point: Vector3=support.model.position+Vector3(0.025,0.16,0.015)
    child.model.position=point
    child.state.position=[point.x,point.y,point.z]
    if child_id not in support.state.attachments:support.state.attachments.append(child_id)
    tell("已将 %s 固定到 %s。"%[definitions[child.state.definition].name,definitions[support.state.definition].name],true)

func disconnect_selected() -> void:
    links=links.filter(func(link):return selected not in link)
    redraw_links()
    update_detail()

func redraw_links() -> void:
    for node in world.get_children():
        if node.name.begins_with("Connection"):world.remove_child(node);node.queue_free()
    for i in links.size():
        var link: Array=links[i]
        if not objects.has(link[0]) or not objects.has(link[1]):continue
        var line := MeshInstance3D.new()
        line.name="Connection%d"%i
        var a: Vector3=objects[link[0]].model.position+Vector3(0,0.1,0)
        var b: Vector3=objects[link[1]].model.position+Vector3(0,0.1,0)
        if a.distance_to(b)<0.005:continue
        var m := CylinderMesh.new()
        m.top_radius=0.002;m.bottom_radius=0.002;m.height=a.distance_to(b);m.radial_segments=8
        line.mesh=m
        line.position=(a+b)/2
        line.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
        line.material_override=preload("res://scripts/lab_room.gd").material(Color("beac78"))
        world.add_child(line)

func rotate_selected() -> void:
    if objects.has(selected):
        objects[selected].state.rotation=fmod(objects[selected].state.rotation+PI/4,TAU)
        objects[selected].model.rotation.y=objects[selected].state.rotation

func remove_selected() -> void:
    if not objects.has(selected):return
    var o: Dictionary=objects[selected]
    if o.state.vessel_id>0:tell("科学容器保留在实验记录中；重新开始可清空实验台。其余器材可单独收回。");return
    if not o.state.contents.is_empty():tell("器材仍装有样品，先把样品转回容器。");return
    disconnect_selected()
    o.model.queue_free()
    objects.erase(selected)
    selected=""
    update_targets()
    detail_title.text="器材已收回"
    reading.text=""

func apply_indicator() -> void:
    if not objects.has(selected):return
    var id := int(objects[selected].state.vessel_id)
    if id<=0:tell("请先选择溶液容器。");return
    lab.indicator_by_vessel[id]=1
    lab.apply_indicators()
    sync_vessels()
    tell("已加入酚酞。颜色随求解出的 pH 改变；忽略指示剂微量加入对物质收支的影响。",true)

func activate_heater(source: int) -> void:
    experiment_picker.selected=2
    guide=2
    heater_mode=true
    heat_panel.show()
    actions.hide()
    if lab.core.bench_snapshot().kind!="heater":lab.bench_experiment.select_model(5)
    lab.bench_experiment.heat_source.selected=source
    lab.bench_experiment.apply_heater_control()
    if heater:heater.queue_free()
    heater=Heater.new()
    world.add_child(heater)
    heater.position=Vector3(0,-0.86,0)
    heater.update_state(lab.core.bench_snapshot())
    for object in objects.values():object.model.visible=false
    for node in world.get_children():
        if node.name.begins_with("Connection"):node.hide()
    camera.size=0.70
    camera.position=Vector3(0,0.65,2.2)
    camera.look_at(Vector3(0,0.26,0))
    reading.text="调节水温与搅拌，观察燃料消耗。"
    detail_title.text=Heater.SOURCES[source]+" · 水加热实验"
    tell("独立水加热实验：可设置水温、启停搅拌，燃料按能量消耗。",true)

func apply_heat() -> void:
    var e=lab.bench_experiment
    e.fields.target_c.value=temperature.value
    e.fields.stir_rpm.value=rpm.value
    e.apply_heater_control()

func heat_toggle(key: String) -> void:
    if not heater_mode:activate_heater(1)
    apply_heat()
    lab.bench_experiment.toggle_heater(key)

func toggle_flame(enabled: bool) -> void:
    var error: String=lab.core.set_flame_enabled(enabled)
    if not error.is_empty():flame_switch.set_pressed_no_signal(false);tell(error);return
    tell("三维简化燃烧已开启：计算对流、扩散、浮力、混合受限放热与局部温度。" if enabled else "三维计算已关闭，燃料与整体能量计算继续；再次开启会新建空间场。")

func select_guide(index: int) -> void:
    guide=index
    if index==2:activate_heater(1);help_text.text="① 设定水温  ② 开启加热  ③ 开启搅拌  ④ 观察燃料和温度"
    else:
        heater_mode=false
        heat_panel.hide();actions.show()
        lab.core.pause_bench()
        if heater:heater.queue_free();heater=null
        for object in objects.values():object.model.visible=true
        for node in world.get_children():
            if node.name.begins_with("Connection"):node.show()
        camera.size=0.40
        camera.position=Vector3(0,0.46,2.2)
        camera.look_at(Vector3(0,0.12,0))
        selected_reagent=0
        if index==1:help_text.text="① 选盐酸烧杯  ② 选择 NaOH 为接收对象  ③ 加入酚酞  ④ 分次加入并测量 pH"
        else:help_text.text="从右侧选择器材。溶液卡片配液，选择“自由搭建”后可转移液体。"

func canvas_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index==MOUSE_BUTTON_LEFT:
            dragging=false
            if event.pressed and not heater_mode:
                var origin := camera.project_ray_origin(event.position)
                var query_ray := PhysicsRayQueryParameters3D.create(origin,origin+camera.project_ray_normal(event.position)*10)
                var hit := viewport.world_3d.direct_space_state.intersect_ray(query_ray)
                if not hit.is_empty() and hit.collider.has_meta("object_id"):
                    select_object(hit.collider.get_meta("object_id"))
                    dragging=true
                    var model=objects[selected].model
                    var point = Plane(Vector3(0,0,1),model.position.z).intersects_ray(origin,camera.project_ray_normal(event.position))
                    drag_offset=model.position-point if point!=null else Vector3.ZERO
        elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
            camera.size=clampf(camera.size*(0.9 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.1),0.35,1.5)
    elif event is InputEventMouseMotion and dragging and objects.has(selected):
        var model=objects[selected].model
        var point=Plane(Vector3(0,0,1),model.position.z).intersects_ray(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
        if point!=null:
            point+=drag_offset
            point.x=clampf(point.x,-0.7,0.7);point.y=clampf(point.y,0,0.5)
            model.position=point
            objects[selected].state.position=[point.x,point.y,point.z]
            redraw_links()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:dragging=false

func _process(delta: float) -> void:
    if not active:return
    if stopwatch_running:stopwatch+=delta
    refresh_clock+=delta
    if refresh_clock>0.1:
        refresh_clock=0
        sync_vessels()
        if not heater_mode:update_detail()
        if not lab.status.text.is_empty() and lab.core.is_busy():message.text=lab.status.text
    if heater_mode:
        var r: Dictionary=lab.core.advance_bench(minf(delta,0.1))
        lab.bench_experiment.update_reading(r,true)
        heater.update_state(r)
        var field: Dictionary=lab.core.advance_flame(minf(delta,0.1),wind.value)
        flame_switch.set_pressed_no_signal(field.get("enabled",false))
        if field.get("enabled",false):
            if field.has("error"):tell(field.error);lab.core.pause_bench()
            heater.update_flame_field(field)
        else:heater.clear_flame_field()
        heat_reading.text="水温 %.1f °C · %.0f rpm\n燃料剩余 %.2f g · 已放热 %.2f kJ"%[r.temperature_c,r.stir_rpm,r.fuel_remaining_g,r.chemical_energy_j/1000]
        if field.get("enabled",false):heat_reading.text+="\n空间场最高 %.0f °C"%(field.peak_temperature_k-273.15)

func reset_workspace() -> void:
    for object in objects.values():object.model.queue_free()
    objects.clear();links.clear();notes.clear();selected="";chosen_target=""
    redraw_links()
    stopwatch=0;stopwatch_running=false
    select_guide(0)
    lab.reset_lab()
    tell("正在重新开始；器材与当前记录会重置。")

func show_report() -> void:
    var dialog := AcceptDialog.new()
    dialog.title="实验报告"
    var text := "器材 %d 件 · 连接 %d 条\n\n"%[objects.size(),links.size()]
    for note in notes.slice(maxi(0,notes.size()-20)):
        text+="%.1f s  %s\n"%[note.time_s,note.text]
    text+="\n保存可保留完整实验；导出 CSV 可查看科学测量数据。"
    dialog.dialog_text=text
    dialog.add_button("导出 CSV",true,"csv")
    dialog.custom_action.connect(func(action):if action=="csv":lab.open_session_dialog("csv"))
    ui.add_child(dialog)
    dialog.popup_centered(Vector2i(820,620))
    dialog.visibility_changed.connect(func():if not dialog.visible:dialog.queue_free())

func save_view() -> Dictionary:
    var heating: bool=heater_mode and lab.core.bench_snapshot().kind=="heater"
    var entries := {}
    for id in objects:entries[id]=objects[id].state.duplicate(true)
    return {"objects":entries,"links":links.duplicate(true),"selected":selected,"target":chosen_target,"guide":guide if guide!=2 or heating else 0,"notes":notes.duplicate(true),"next_id":next_id,"stopwatch":stopwatch,"camera_size":camera.size if not heater_mode or heating else 0.40,"wind":wind.value,"heater_mode":heating}

func validate_view(data: Variant) -> String:
    if not data is Dictionary or not data.get("objects") is Dictionary or data.objects.size()>60 or not data.get("links") is Array or data.links.size()>128:return "新手实验区记录无效。"
    for id in data.objects:
        var s=data.objects[id]
        if not id is String or not s is Dictionary or not definitions.has(s.get("definition")) or not s.get("position") is Array or s.position.size()!=3 or not s.get("contents") is Dictionary or not s.get("attachments") is Array:return "新手器材记录不完整。"
        for value in s.position+[s.get("rotation"),s.get("mass_g"),s.get("scale"),s.get("vessel_id")]:
            if not preload("res://scripts/session_io.gd").finite(value):return "新手器材记录包含无效数值。"
        if abs(s.position[0])>1 or abs(s.position[1])>1 or abs(s.position[2])>1 or s.mass_g<0 or s.mass_g>1000 or s.scale<0.125 or s.scale>1 or s.vessel_id<0 or s.vessel_id>12 or s.vessel_id!=floor(s.vessel_id):return "新手器材状态超出范围。"
        if not s.get("open") is bool or s.attachments.size()>60:return "器材开关或固定记录无效。"
        for attachment in s.attachments:
            if not attachment is String or not data.objects.has(attachment) or attachment==id:return "固定对象无效。"
        if s.vessel_id>0 and id!="v%d"%int(s.vessel_id):return "容器绑定编号无效。"
        for key in s.contents:
            if not definitions.has(key) or not preload("res://scripts/session_io.gd").finite(s.contents[key]) or s.contents[key]<0 or s.contents[key]>10000:return "样品库存无效。"
    var occupied := {}
    var seen_links := {}
    for link in data.links:
        if not link is Array or link.size()!=2 or not data.objects.has(link[0]) or not data.objects.has(link[1]) or link[0]==link[1]:return "器材连接记录无效。"
        var key: String=str(link[0])+"/"+str(link[1])
        if seen_links.has(key) or seen_links.has(str(link[1])+"/"+str(link[0])):return "重复器材连接。"
        seen_links[key]=true
        for id in link:
            var d: Dictionary=definitions[data.objects[id].definition]
            occupied[id]=occupied.get(id,0)+1
            if occupied[id]>int(d.get("ports",1 if d.action=="vessel" else 0)):return "接口数量超出器材范围。"
    if not data.get("selected") is String or not data.get("target") is String:return "选择记录无效。"
    if (not data.selected.is_empty() and not data.objects.has(data.selected)) or (not data.target.is_empty() and not data.objects.has(data.target)):return "选择的器材不存在。"
    if not preload("res://scripts/session_io.gd").finite(data.get("guide")) or data.guide<0 or data.guide>2 or data.guide!=floor(data.guide) or not data.get("heater_mode") is bool or not data.get("notes") is Array or data.notes.size()>1000:return "新手引导记录无效。"
    for key in ["next_id","stopwatch","camera_size","wind"]:
        if not preload("res://scripts/session_io.gd").finite(data.get(key)):return "新手实验参数无效。"
    if data.next_id<1 or data.next_id>100000 or data.stopwatch<0 or data.stopwatch>86400 or data.camera_size<0.35 or data.camera_size>1.5 or abs(data.wind)>0.12:return "新手实验参数超出范围。"
    if data.next_id!=floor(data.next_id):return "器材序号无效。"
    for id in data.objects:
        if id.begins_with("o") and (not id.substr(1).is_valid_int() or int(id.substr(1))>=data.next_id):return "器材序号会发生冲突。"
    for note in data.notes:
        if not note is Dictionary or not note.get("text") is String or note.text.length()>4000 or not preload("res://scripts/session_io.gd").finite(note.get("time_s")):return "实验记录无效。"
    return ""

func restore_view(data: Dictionary) -> void:
    for object in objects.values():object.model.queue_free()
    objects.clear()
    for id in data.objects:add_object(id,data.objects[id].duplicate(true),true)
    links=data.links.duplicate(true);notes=data.notes.duplicate(true)
    selected=data.selected;chosen_target=data.target;next_id=int(data.next_id)
    stopwatch=data.stopwatch;stopwatch_running=false;camera.size=data.camera_size;wind.value=data.wind
    guide=int(data.guide);experiment_picker.selected=guide
    heater_mode=data.heater_mode and lab.core.bench_snapshot().kind=="heater"
    heat_panel.visible=heater_mode;actions.visible=not heater_mode
    camera.position=Vector3(0,0.46,2.2);camera.look_at(Vector3(0,0.12,0))
    if heater:heater.queue_free();heater=null
    if heater_mode:
        camera.position=Vector3(0,0.65,2.2);camera.look_at(Vector3(0,0.26,0))
        heater=Heater.new();world.add_child(heater);heater.position=Vector3(0,-0.86,0)
        var r: Dictionary=lab.core.bench_snapshot()
        heater.update_state(r)
        temperature.value=r.target_c;rpm.value=r.stir_setpoint_rpm
        for object in objects.values():object.model.visible=false
    flame_switch.set_pressed_no_signal(lab.core.flame_snapshot().get("enabled",false))
    redraw_links();update_targets();sync_vessels();update_detail()
