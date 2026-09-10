shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never;
void fragment() {
    // Schlick reflectance at an air/borosilicate interface, IOR ~1.47.
    float fresnel = 0.0362 + 0.9638 * pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),5.0);
    ALBEDO=vec3(0.92,0.97,0.975);
    METALLIC=0.0;
    ROUGHNESS=0.06;
    SPECULAR=0.5;
    ALPHA=0.008+fresnel*0.30;
}
