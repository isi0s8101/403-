shader_type spatial;
render_mode cull_back, depth_draw_opaque, fog_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float map_size=96.0;
varying vec3 wpos;
void vertex() { wpos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 uv=clamp(wpos.xz/map_size,vec2(.001),vec2(.999));
    vec4 mask=texture(ground_mask,uv);
    float f=texture(fog_tex,uv).r;
    float visibility=clamp(f*f*1.35,0.0,1.0);
    vec2 a=wpos.xz*.16+vec2(TIME*.012,TIME*-.009);
    vec2 b=wpos.zx*.21+vec2(TIME*-.008,TIME*.01);
    vec3 n1=texture(ripple_normal,a).rgb;
    vec3 n2=texture(ripple_normal,b).rgb;
    vec3 n=normalize(vec3((n1.xy+n2.xy-1.0)*.27,1.0));
    float shore=mask.r;
    float shallow=clamp(shore*.75+(1.0-mask.a)*.32,0.0,1.0);
    vec3 color=mix(vec3(.018,.065,.075),vec3(.12,.16,.115),shallow);
    float crest=sin(wpos.x*6.0+wpos.z*1.8-TIME*1.3)*sin(wpos.z*4.0+TIME*.7);
    float foam=smoothstep(.78,.98,shore)*smoothstep(.25,.9,crest)*.15;
    ALBEDO=(color+vec3(foam))*visibility;
    NORMAL_MAP=n*.5+.5;
    NORMAL_MAP_DEPTH=.65;
    ROUGHNESS=mix(.19,.38,shallow);
    METALLIC=0.0;
    SPECULAR=.65*visibility;
}
