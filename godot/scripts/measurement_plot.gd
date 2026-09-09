extends Control
var points: Array[Vector2] = []
var y_max := 1.0
var x_max := 1.0
var unit := "m"
var x_unit := "s"
var line_color := Color("8ed7bd")

func _draw() -> void:
    var origin := Vector2(46,size.y-25)
    var extent := Vector2(maxf(size.x-60,1),maxf(size.y-48,1))
    var font := ThemeDB.fallback_font
    for i in range(5):
        var value := y_max*i/4
        var y := origin.y-extent.y*i/4
        draw_line(Vector2(origin.x,y),Vector2(origin.x+extent.x,y),Color(0.7,0.8,0.8,0.16))
        draw_string(font,Vector2(1,y+4),"%.2f"%value,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9eb8ae"))
    draw_string(font,Vector2(0,13),unit,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9eb8ae"))
    draw_string(font,Vector2(size.x-63,size.y-5),"%.2f %s"%[x_max,x_unit],HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9eb8ae"))
    var previous := origin
    for i in points.size():
        var p := origin+Vector2(points[i].x/maxf(x_max,0.001)*extent.x,-points[i].y/maxf(y_max,0.001)*extent.y)
        if i>0:
            draw_line(previous,p,line_color,2,true)
        previous = p
    if not points.is_empty():
        draw_circle(previous,3,line_color)
