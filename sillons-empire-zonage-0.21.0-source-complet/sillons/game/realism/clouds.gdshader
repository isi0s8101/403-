shader_type spatial;
render_mode cull_back, depth_draw_never;
varying vec3 direction;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);}
void vertex(){direction=normalize(VERTEX);}
void fragment(){
 vec3 p=direction*5.3+vec3(TIME*.0012,0,0);
 float clouds=noise3(p)*.56+noise3(p*2.1)*.28+noise3(p*4.3)*.16;
 float coverage=smoothstep(.52,.69,clouds);
 ALBEDO=vec3(.92,.95,.98);
 ROUGHNESS=1.0;
 SPECULAR=.05;
 ALPHA=coverage*.66;
}
