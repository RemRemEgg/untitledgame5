shader_type spatial;
render_mode cull_disabled;

varying vec3 pos;
varying vec3 vnorm;

const vec3 c_light = vec3(0.1, 0.03, 0.0)*1.5;
const vec3 c_dark = vec3(0.035, 0.01, 0.0);


void vertex() {
	pos = VERTEX;
	vnorm = NORMAL;
}

void fragment() {
	vec3 opos = pos + vec3(0.001);
	//q_proj = point - dot(point, normal) * normal
	vec3 proj = opos - dot(opos, vnorm) * vnorm;
	proj += vnorm * 0.5;
	
	vec3 rpos = floor(abs(proj - round(proj)) * 2.2);
	float d = rpos.x + rpos.y + rpos.z;
	if (d < 2.0) discard;
	
	int x = int(floor(proj.x)) % 2;
	int y = int(floor(proj.y)) % 2;
	int z = int(floor(proj.z)) % 2;
	float c = float((x+y+z)%3)/2.0;
	ALBEDO = mix(c_light, c_dark, c);
}
