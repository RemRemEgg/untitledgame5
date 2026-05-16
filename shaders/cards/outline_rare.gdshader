shader_type canvas_item;

render_mode unshaded;

const vec4 BASE_COLOR = vec4(0.2, 0.8, 0.9, 1.0);
const vec4 HILIGHT_COLOR = vec4(0.0, 0.3, 0.5, 1.0);

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
	float min_d = 1.0;
	//                    SPEED
	float s_time = TIME * 12.0;
	//                  COUNT
	for (int i = 0; i < 16; i++) {
		float local_time = s_time - float(i);
		
		int star_seed = pkn(int(local_time) + 5648, 138431, 1687566);
		vec2 star_pos = vec2(float(star_seed % 100)/100.0, float((star_seed >> 12) % 100)/100.0);
		//                               SCALE
		vec2 pvec = abs(UV - star_pos) * 15.0;
		
		float z = (s_time - floor(local_time));
		//          -(COUNT/2) * (2/COUNT)
		z = abs(z - 8.0)*0.125;
		//                                                          SHAPE
		float d = (pvec.x + pvec.y + z*z*z) - (abs(pvec.x - pvec.y)*1.05);
		
		min_d = min(min_d, d);
	}
	COLOR = mix(HILIGHT_COLOR, BASE_COLOR, min_d);
}