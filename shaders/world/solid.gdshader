shader_type spatial;

varying vec3 pos;
varying vec3 modulo;

void vertex() {
	pos = VERTEX;
	modulo = NORMAL;
}

void fragment() {
	int a = int(floor(pos.x+0.001))  + int(floor(pos.y+0.001))  + int(floor(pos.z+0.001));
	a = a % 2;
	int b = int(floor(pos.x/4.0+0.001))  + int(floor(pos.y/4.0+0.001))  + int(floor(pos.z/4.0+0.001));
	b = b % 2;
	ALBEDO = vec3(0.75-float(a) - float(b) * 0.6);
	ALBEDO = modulo - ALBEDO * 0.5;
	ALBEDO *= 0.25;
}
