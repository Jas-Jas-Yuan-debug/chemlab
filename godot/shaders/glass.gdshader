shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
void fragment() {
    float edge = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
    ALBEDO = vec3(0.77, 0.91, 0.94);
    METALLIC = 0.0;
    ROUGHNESS = 0.08;
    SPECULAR = 0.65;
    ALPHA = 0.018 + edge * 0.32;
}
