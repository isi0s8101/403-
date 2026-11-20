shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform vec3 tint = vec3(0.24, 0.31, 0.10);
uniform bool is_grass = false;
uniform float map_size = 96.0;
varying vec3 world_position;
varying vec4 vertex_tint;
void vertex() {
    vec3 base = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float influence = is_grass ? clamp(VERTEX.y * 3.0, 0.0, 1.0) : clamp(VERTEX.y - 1.0, 0.0, 3.0) * 0.35;
    VERTEX.x += sin(TIME * 1.25 + base.x * 0.63 + base.z * 0.38) * influence * 0.035;
    VERTEX.z += cos(TIME * 0.92 + base.z * 0.49) * influence * 0.018;
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vertex_tint = COLOR;
}
void fragment() {
    vec2 uv = clamp(world_position.xz / map_size, vec2(0.001), vec2(0.999));
    float fog = texture(fog_tex, uv).r;
    if (fog < 0.025) { discard; }
    if (is_grass && texture(ground_mask, uv).g > 0.66) { discard; }
    float visible = clamp(fog * fog * 1.35, 0.0, 1.0);
    ALBEDO = tint * vertex_tint.rgb * visible;
    ROUGHNESS = 0.86;
    SPECULAR = 0.26 * visible;
    BACKLIGHT = tint * 0.24 * visible;
}
