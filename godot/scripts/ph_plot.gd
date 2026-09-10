extends Control
var points: Array[Vector2] = []
var x_unit := "mL"
var y_title := "pH"
var y_min := 0.0
var y_max := 14.0

func _draw() -> void:
    var origin:=Vector2(42,size.y-26)
    var width:=maxf(size.x-58,10);var height:=maxf(size.y-48,10)
    var font:=ThemeDB.fallback_font
    var min_x:=points[0].x if not points.is_empty() else 0.0
    var max_x:=min_x+1
    for p in points:max_x=maxf(max_x,p.x)
    var span:=maxf(y_max-y_min,1e-12)
    for fraction in [0.0,0.5,1.0]:
        var value: float=y_min+fraction*span
        var y: float=origin.y-height*fraction
        draw_line(Vector2(origin.x,y),Vector2(origin.x+width,y),Color(0.7,0.8,0.8,0.15))
        draw_string(font,Vector2(1,y+4),String.num(value,2),HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("a5b8b3"))
    draw_string(font,Vector2(2,14),y_title,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    draw_string(font,Vector2(origin.x,size.y-5),"%.1f"%min_x,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    draw_string(font,Vector2(size.x-86,size.y-5),"%.1f %s"%[max_x,x_unit],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    var previous: Vector2
    for i in points.size():
        var p:=origin+Vector2((points[i].x-min_x)/(max_x-min_x)*width,-(points[i].y-y_min)/span*height)
        if i>0:draw_line(previous,p,Color("8ed7bd"),1.5,true)
        if points.size()<80:draw_circle(p,2.0,Color("bde9d8"))
        previous=p
