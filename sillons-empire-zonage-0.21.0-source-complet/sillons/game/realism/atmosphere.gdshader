shader_type spatial;
render_mode cull_front, unshaded, depth_draw_never;
void fragment(){
 float rim=pow(clamp(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),0.0,1.0),2.6);
 ALBEDO=vec3(.16,.40,.72);
 ALPHA=rim*.34;
}
