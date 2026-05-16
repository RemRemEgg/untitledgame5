shader_type canvas_item;

render_mode unshaded;

const vec4 BASE_COLOR = vec4(1.0, -0.2, 1.0, 1.0) * 0.9;

int pkn(int a, int b, int c) {
	a ^= a << 13;
	a ^= (a^c) >> 17;
	a ^= a << 5;
	b ^= b << 11;
	b ^= (b^c) >> 15;
	b ^= b << 7;
	return a^~b^~c;
}

vec2 sample_grid(vec2 pos) {
	int rng = pkn(int(pos.x * 1000.0), int(pos.y * 1000.0), int(pos.x - pos.y));
	int x = rng % 2048;
	int y = (rng >> 12) % 2048;
	return vec2(float(x)/2048.0, float(y)/2048.0);
}


void fragment() {
	vec2 uv = (UV - vec2(0.5));
	uv *= 10.0;
	vec2 pos = floor(uv);
	float res = 10.0;
	vec4 col = vec4(1.0, 1.0, 1.0, 1.0);
	for (float xo = -1.0; xo < 1.5; xo += 1.0) {
		for (float yo = -1.0; yo < 1.5; yo += 1.0) {
			vec2 grid_pos = (pos + vec2(xo, yo)) * 1.0;
			vec2 sample_pos = sample_grid(grid_pos);
			vec2 diff = abs(sample_pos + grid_pos - uv);
			float d = (diff.x + diff.y);
			d += (sin(TIME*3.0 + grid_pos.x*10.0) - cos(TIME*3.0 + grid_pos.y*16.0)) * 0.2;
			res = min(d, res);
			if (d == res) {
				col = (vec4(sample_pos.x-0.5, (sample_pos.x+sample_pos.y)/2.0, sample_pos.y-0.5, 1.0) + BASE_COLOR) * (1.0-d*0.7);
			}
		}
	}
	COLOR = col;
	COLOR.w = 1.0;
}