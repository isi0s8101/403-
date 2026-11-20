shader_type spatial;
render_mode cull_back, depth_draw_opaque, fog_disabled;
uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform sampler2D ground_mask : filter_linear, repeat_disable;
uniform sampler2D contact_tex : filter_linear, repeat_disable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_orm : filter_linear_mipmap, repeat_enable;
uniform float map_size = 96.0;
uniform vec3 biome_tint = vec3(1.0);
// 0.19 — routes et calque de zonage (une texture par couche, une valeur par case ; aucune géométrie en plus).
uniform sampler2D road_tex : filter_linear, repeat_disable;     // 1/255 et plus : route
uniform sampler2D zone_tex : filter_nearest, repeat_disable;    // code de zone (0 à 8)
uniform sampler2D filter_tex : filter_nearest, repeat_disable;  // valeur d'un filtre (0 = bien, 1 = mal)
uniform vec4 zone_colors[9];
uniform vec3 road_color = vec3(0.45, 0.38, 0.28);
uniform float road_on = 0.0;
uniform int overlay_mode = 0;          // 0 rien, 1 zonage, 2 filtre
uniform float overlay_strength = 0.0;
varying vec3 wpos;
float hash12(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise2(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash12(i),hash12(i+vec2(1.0,0.0)),f.x),mix(hash12(i+vec2(0.0,1.0)),hash12(i+vec2(1.0)),f.x),f.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
    vec2 uv=clamp(wpos.xz/map_size,vec2(.001),vec2(.999));
    vec4 mask=texture(ground_mask,uv);
    vec2 tile=wpos.xz*.19;
    float macro=noise2(wpos.xz*.105);
    vec2 offset=vec2(noise2(wpos.xz*.036),noise2(wpos.zx*.045))*.12;
    vec3 grass=texture(grass_tex,tile+offset).rgb;
    grass=mix(grass,texture(grass_tex,vec2(-tile.y,tile.x)*.71+vec2(.37,.71)).rgb,.30);
    float worn=clamp(mask.g*.92+smoothstep(.48,.79,macro)*.20,0.0,.98);
    float stone=clamp(mask.b*.86,0.0,.85);
    float bank=clamp(mask.r*.78,0.0,.9);
    vec3 color=mix(grass,texture(soil_tex,tile*.87).rgb,worn);
    color=mix(color,texture(rock_tex,tile*.7).rgb,stone);
    color=mix(color,texture(sand_tex,tile*.93).rgb,bank);
    vec3 norm=mix(texture(normal_tex,tile).rgb,texture(soil_normal,tile*.87).rgb,worn);
    norm=mix(norm,texture(rock_normal,tile*.7).rgb,stone);
    norm=mix(norm,texture(sand_normal,tile*.93).rgb,bank);
    vec3 orm=mix(texture(grass_orm,tile).rgb,texture(soil_orm,tile*.87).rgb,worn);
    orm=mix(orm,texture(rock_orm,tile*.7).rgb,stone);
    orm=mix(orm,texture(sand_orm,tile*.93).rgb,bank);
    if (road_on > 0.5) {
        float road=smoothstep(.35,.65,texture(road_tex,uv).r*255.0);
        if (road > 0.0) {
            vec3 paved=road_color*mix(.88,1.06,noise2(wpos.xz*2.7));
            color=mix(color,paved,road*.94);
            norm=mix(norm,vec3(.5,.5,1.0),road*.85);
            orm=mix(orm,vec3(1.0,.9,0.0),road*.6);
        }
    }
    if (overlay_mode > 0 && overlay_strength > 0.0) {
        vec2 f=fract(wpos.xz);
        float edge=step(.93,max(f.x,f.y));
        if (overlay_mode == 1) {
            int code=int(texture(zone_tex,uv).r*255.0+.5);
            if (code > 0 && code < 9) {
                vec4 zc=zone_colors[code];
                color=mix(color,zc.rgb,zc.a*overlay_strength);
                color*=1.0-edge*.18;
            }
        } else {
            float v=texture(filter_tex,uv).r;
            if (v > 0.0) {
                vec3 ramp=mix(vec3(.15,.75,.30),vec3(.95,.25,.18),clamp((v-1.0/255.0)*1.004,0.0,1.0));
                color=mix(color,ramp,.62*overlay_strength);
            }
        }
    }
    float fog=texture(fog_tex,uv).r;
    float visible=clamp(fog*fog*1.35,0.0,1.0);
    ALBEDO=color*biome_tint*mix(.91,1.08,macro)*visible;
    NORMAL_MAP=norm;
    NORMAL_MAP_DEPTH=.50;
    ROUGHNESS=clamp(orm.g,.52,1.0);
    AO=clamp(orm.r*texture(contact_tex,uv).r,.35,1.0);
    AO_LIGHT_AFFECT=.45;
    SPECULAR=.24*visible;
    METALLIC=0.0;
}
