shader_type spatial;
render_mode blend_mix, cull_disabled;
uniform vec4 tint : source_color = vec4(0.66, 0.85, 0.86, 0.25);
uniform vec2 slope = vec2(0.0);
uniform float plane_center = 0.01;
uniform float container_height = 0.094;
void vertex() {
    float top = UV.x;
    float level = clamp(plane_center + dot(slope, VERTEX.xz), 0.0, container_height);
    VERTEX.y = 0.0031 + top * level;
    if (NORMAL.y > 0.5) NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
}
void fragment() {
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    ALBEDO = tint.rgb;
    ROUGHNESS = 0.13;
    SPECULAR = 0.65;
    ALPHA = min(0.82, tint.a + edge * 0.18);
}
