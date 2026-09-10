shader_type spatial;
render_mode blend_mix, cull_back;
uniform vec4 tint : source_color = vec4(0.91, 0.96, 0.97, 0.08);
uniform vec4 upper_tint : source_color = vec4(0.91, 0.96, 0.97, 0.08);
uniform bool separate_zones = false;
uniform float zone_height = 0.02;
uniform vec2 slope = vec2(0.0);
uniform float plane_center = 0.01;
uniform vec2 cavity[32];
uniform int profile_count = 2;
varying vec3 local_position;
void vertex() {
    if (UV.x > 0.5) {
        VERTEX.y = plane_center + dot(slope, VERTEX.xz);
        NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
    }
    local_position = VERTEX;
}
void fragment() {
    float y = local_position.y;
    if (y < cavity[0].y - 0.00001 || y > cavity[profile_count-1].y || y > plane_center + dot(slope, local_position.xz) + 0.00001) discard;
    float radius = cavity[profile_count-1].x;
    for (int i=0; i<31; i++) {
        if (i+1 >= profile_count) break;
        if (y <= cavity[i+1].y) {
            radius = mix(cavity[i].x,cavity[i+1].x,clamp((y-cavity[i].y)/max(cavity[i+1].y-cavity[i].y,0.000001),0.0,1.0));
            break;
        }
    }
    if (length(local_position.xz) > radius + 0.000005) discard;
    vec4 color = separate_zones ? mix(tint,upper_tint,smoothstep(zone_height-0.001,zone_height+0.001,y)) : tint;
    float fresnel = 0.0204 + 0.9796 * pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),5.0);
    ALBEDO=color.rgb;
    ROUGHNESS=0.055;
    SPECULAR=0.5;
    ALPHA=min(0.78,color.a+fresnel*0.18);
}
