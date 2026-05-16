shader_type canvas_item;

render_mode unshaded;

const vec4 BASE_COLOR = vec4(1.0, 0.95, 0.0, 1.0);
const vec4 HILIGHT_COLOR = vec4(0.4, 0.4, 0.45, 1.0);

int pkn(int a, int b, int c) {
	a ^= (a^c) >> 5;
	return ~a^b^~c;
}

float sample(vec2 uv) {
	int r = pkn(int(uv.x), int(uv.y), 4515973);
	r %= 100;
	return float((int(TIME*38.0 + float(r % 50)*2.0) % 100) < r-5);
}

void fragment() {
	COLOR = BASE_COLOR;
	//             SCALE
	vec2 frac = UV * 64.0 - vec2(0.5, 0.5);
	vec2 uv = floor(frac);
	frac -= uv;
	
	float s1 = sample(uv);
	float s2 = sample(uv + vec2(1.0, 0.0));
	float s3 = sample(uv + vec2(0.0, 1.0));
	float s4 = sample(uv + vec2(1.0, 1.0));
	
	float i1 = mix(s1, s2, frac.x);
	float i2 = mix(s3, s4, frac.x);
	float i3 = mix(i1, i2, frac.y);
	
	if (i3 > 0.5) {
		COLOR = HILIGHT_COLOR;
	}
	//COLOR = mix(COLOR, HILIGHT_COLOR, i3);
	//if (sample(uv)) {
		//COLOR = HILIGHT_COLOR;
	//}
}