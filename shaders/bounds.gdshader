shader_type spatial;
render_mode unshaded;

const vec3 BASE_COLOR = vec3(0.5, 0.0, 0.0);
const vec3 HILIGHT_COLOR = vec3(0.8, 0.1, 0.0);

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
	ALPHA = clamp(1.0-(length(VERTEX) / 32.0) + 0.25, 0.0, 1.0);
	if (ALPHA > 0.0) {
		float min_d = 1.0;
		float s_time = TIME * 32.0;
		//                  COUNT
		for (int i = 0; i < 64; i++) {
			float local_time = s_time - float(i);
			
			int star_seed = pkn(int(local_time) + 5648, 138421, 1681566);
			vec2 star_pos = vec2(float(star_seed % 100)/100.0, float((star_seed >> 12) % 100)/100.0);
			//                               SCALE
			vec2 pvec = abs(UV - star_pos) * 64.0;
			
			float z = (s_time - floor(local_time));
			//          -(COUNT/2) * (2/COUNT)
			z = abs(z - 32.0)*(2.0/64.0);
			float d = (pvec.x + pvec.y + z*z*z) - (abs(pvec.x - pvec.y));
			
			min_d = min(min_d, d);
		}
		ALBEDO = mix(HILIGHT_COLOR, BASE_COLOR, min_d);
		ALPHA = max(ALPHA - (min_d)*0.2, 0.0);
		//ALBEDO = mix(BASE_COLOR, HILIGHT_COLOR, min_d);
	}
	
}