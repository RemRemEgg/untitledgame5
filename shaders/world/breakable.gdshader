shader_type spatial;

varying vec3 pos;

const vec3 c_light = vec3(0.1, 0.03, 0.0)*1.5;
const vec3 c_dark = vec3(0.035, 0.01, 0.0);


void vertex() {
	pos = VERTEX;
}

void fragment() {
	int x = int(floor(pos.x+0.01)) % 2;
	int y = int(floor(pos.y+0.01)) % 2;
	int z = int(floor(pos.z+0.01)) % 2;
	float c = float((x+y+z)%3)/2.0;
	ALBEDO = mix(c_light, c_dark, c);
}
