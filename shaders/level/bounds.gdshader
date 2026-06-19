shader_type spatial;
render_mode unshaded;

const vec3 BASE_COLOR = vec3(-1.0);
const vec3 HILIGHT_COLOR = vec3(0.0);

varying vec3 pos;
varying vec3 modulo;

void vertex() {
	pos = VERTEX;
	modulo = NORMAL;
}


int pkn(int a, int b, int c) {
	a ^= a << 13;
	a ^= (a^c) >> 17;
	a ^= a << 5;
	b ^= b << 11;
	b ^= (b^c) >> 15;
	b ^= b << 7;
	return a^~b^~c;
}

void fragment() {
	int a = int(floor(pos.x+0.00001))  + int(floor(pos.y+0.00001))  + int(floor(pos.z+0.00001));
	a = a % 2;
	int b = int(floor(pos.x/4.0+0.00001))  + int(floor(pos.y/4.0+0.00001))  + int(floor(pos.z/4.0+0.00001));
	b = b % 2;
	ALBEDO = vec3(0.75-float(a) - float(b) * 0.6);
	ALBEDO = modulo - ALBEDO * 0.5;
	
	
	float min_d = 1.0;
	float s_time = TIME * 4.0;
	//                  COUNT
	for (int i = 0; i < 16; i++) {
		float local_time = s_time - float(i);
		
		int star_seed = pkn(int(local_time) + 5648, 138421, 1681566);
		vec2 star_pos = vec2(float(star_seed % 100)/100.0, float((star_seed >> 12) % 100)/100.0);
		//                               SCALE
		vec2 pvec = abs(UV - star_pos) * 24.0;
		
		float z = (s_time - floor(local_time));
		//          -(COUNT/2) * (2/COUNT)
		z = abs(z - 8.0)*(2.0/11.0);
		float d = (pvec.x + pvec.y + z*z*z) - (abs(pvec.x - pvec.y) * 1.1);
		
		min_d = min(min_d, d);
	}
	ALBEDO *= 1.5;
	ALBEDO = mix(vec3(1.0) - ALBEDO, ALBEDO, min_d);
	ALBEDO /= 1.5*4.0;
}