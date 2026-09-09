shader_type spatial;
render_mode blend_mix, cull_back;
uniform vec4 tint : source_color = vec4(0.66, 0.85, 0.86, 0.25);
uniform vec2 slope = vec2(0.0);
uniform float fill_height = 0.01;
void vertex() {
    // Linear tilt integrates to zero over a circular section. Only the top
    // ring moves; the base stays fixed. This is a visual surface approximation.
    float top = step(0.0, VERTEX.y);
    VERTEX.y += top * dot(slope, VERTEX.xz);
    if (NORMAL.y > 0.5) NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));
}
void fragment() {
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 3.0);
    ALBEDO = tint.rgb;
    ROUGHNESS = 0.13;
    SPECULAR = 0.65;
    ALPHA = min(0.82, tint.a + edge * 0.18);
}
