shader_type spatial;
render_mode cull_back, depth_draw_opaque;
uniform sampler2D surface_texture : source_color, filter_linear, repeat_enable;
varying vec3 local_direction;
float h(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float n3(vec3 p) {
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(mix(h(i),h(i+vec3(1,0,0)),f.x),mix(h(i+vec3(0,1,0)),h(i+vec3(1,1,0)),f.x),f.y),mix(mix(h(i+vec3(0,0,1)),h(i+vec3(1,0,1)),f.x),mix(h(i+vec3(0,1,1)),h(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_direction=normalize(VERTEX); }
void fragment() {
 vec3 c=texture(surface_texture,UV).rgb;
 float ocean=smoothstep(.01,.065,c.b-c.r)*smoothstep(.0,.10,c.b-c.g*.8);
 float detail=n3(local_direction*120.0)*.6+n3(local_direction*370.0)*.4;
 ALBEDO=c*mix(.85,1.08,detail);
 ROUGHNESS=mix(.94,.24,ocean);
 SPECULAR=mix(.24,.58,ocean);
 METALLIC=0.0;
}
