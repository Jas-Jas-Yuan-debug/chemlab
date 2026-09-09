extends Control
var points: Array[Vector2] = []

func _draw() -> void:
    var origin := Vector2(34,size.y-26)
    var width: float = maxf(size.x-50,10.0)
    var height: float = maxf(size.y-45,10.0)
    var font := ThemeDB.fallback_font
    var max_x := 1.0
    for p in points:
        max_x = max(max_x,p.x)
    for ph in [0,7,14]:
        var y: float = origin.y-height*ph/14.0
        draw_line(Vector2(origin.x,y),Vector2(origin.x+width,y),Color(0.7,0.8,0.8,0.15))
        draw_string(font,Vector2(5,y+4),str(ph),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    draw_string(font,Vector2(2,15),"pH",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    draw_string(font,Vector2(origin.x,size.y-5),"0",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    draw_string(font,Vector2(size.x-76,size.y-5),"%.1f mL"%max_x,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("a5b8b3"))
    var previous: Vector2
    for i in points.size():
        var p := origin+Vector2(points[i].x/max_x*width,-points[i].y/14.0*height)
        if i>0:
            draw_line(previous,p,Color("8ed7bd"),2.0,true)
        draw_circle(p,2.5,Color("bde9d8"))
        previous = p
