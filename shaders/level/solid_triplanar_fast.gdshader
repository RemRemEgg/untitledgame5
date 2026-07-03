shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_toon;

uniform sampler2D tex : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 modulo : source_color = vec3(1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0);
uniform float specular : hint_range(0.0, 1.0, 0.01);

uniform vec3 scale = vec3(0.25);
uniform vec3 offset = vec3(0.0);

varying vec2 triplanar_pos;

void vertex() {
	vec3 normal = NORMAL;
	vec3 an = abs(normal);
	vec3 vs = VERTEX * scale;
	vec3 triplanar_3d = vs + offset + fract(abs(vs));
	
	// TODO optimize
	if (an.x >= an.y && an.x >= an.z) {
		triplanar_pos = triplanar_3d.zy * vec2(-sign(normal.x), -1.0);
	} else if (an.y >= an.z) {
		triplanar_pos = triplanar_3d.xz * vec2(sign(normal.y), 1.0);
	} else {
		triplanar_pos = triplanar_3d.xy * vec2(sign(normal.z), -1.0);
	}
	
}

void fragment() {
	vec4 albedo_tex = texture(tex, triplanar_pos);
	ALBEDO = albedo_tex.rgb * modulo;
	SPECULAR = specular;
	ROUGHNESS = albedo_tex.x * roughness;
}
