shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, blend_mix;
uniform sampler2D field_atlas : filter_linear, repeat_disable;
uniform bool temperature_colors = false;
varying vec3 local_position;
varying vec3 camera_local;
void vertex(){
    local_position=VERTEX;
    camera_local=(inverse(MODEL_MATRIX)*vec4(CAMERA_POSITION_WORLD,1.0)).xyz;
}
float slice_temperature(vec3 p,float z){
    vec2 tile=vec2(mod(z,4.0),floor(z/4.0));
    vec2 uv=(tile*vec2(16.0,28.0)+vec2(0.5)+p.xy*vec2(15.0,27.0))/vec2(64.0,112.0);
    vec2 code=texture(field_atlas,uv).rg;
    return (code.r*65280.0+code.g*255.0)/65535.0;
}
float sample_heat(vec3 p){
    float z=clamp(p.z*15.0,0.0,15.0);
    return mix(slice_temperature(p,floor(z)),slice_temperature(p,min(15.0,floor(z)+1.0)),fract(z));
}
void fragment(){
    vec3 ray=normalize(local_position-camera_local);
    vec3 inv=1.0/(ray+vec3(0.000001));
    vec3 a=(-vec3(0.5)-camera_local)*inv;
    vec3 b=(vec3(0.5)-camera_local)*inv;
    vec3 near_v=min(a,b),far_v=max(a,b);
    float start=max(max(near_v.x,near_v.y),near_v.z);
    float end=min(min(far_v.x,far_v.y),far_v.z);
    start=max(start,0.0);
    vec4 result=vec4(0.0);
    float step_length=max(0.0,end-start)/56.0;
    for(int i=0;i<56;i++){
        vec3 p=camera_local+ray*(start+(float(i)+0.5)*step_length)+vec3(0.5);
        float heat=sample_heat(p);
        float visible_heat=smoothstep(0.07,0.25,heat);
        vec3 color=mix(vec3(0.16,0.35,1.0),vec3(1.0,0.39,0.08),smoothstep(0.13,0.34,heat));
        color=mix(color,vec3(1.0,0.95,0.70),smoothstep(0.34,0.60,heat));
        if(temperature_colors)color=mix(vec3(0.10,0.4,0.95),vec3(1.0,0.18,0.05),clamp(heat*2.0,0.0,1.0));
        float alpha=visible_heat*step_length*2.8;
        result.rgb+=(1.0-result.a)*color*alpha;
        result.a+=(1.0-result.a)*alpha;
    }
    ALBEDO=result.rgb/max(result.a,0.001);
    ALPHA=result.a;
}
