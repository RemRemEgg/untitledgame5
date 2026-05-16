shader_type sky;

const vec3 BLACK = vec3(0, 0, 0);
const int w = 8 * 32;
const int s = 4 * 32;

float rng(int x, int y) {
	int a = x;
	int b = y;
	a ^= a << 13;
	a ^= a >> 17;
	a ^= a << 5;
	b ^= b << 11;
	b ^= b >> 15;
	b ^= b << 7;
	float v = abs(float(a ^ ~b) / 127.0);
	v -= floor(v);
	v = max(0, v * 4.0 - 3.0);
    return v;
}
float perlin(float x, float y) {
	int x0 = int(x);
	int x1 = x0 + 1;
	int y0 = int(y);
	int y1 = y0 + 1;
	float sx = x - float(x0);
	float sy = y - float(y0);
	x0 %= 32;
	y0 %= 32;
	x1 %= 32;
	y1 %= 32;
	
	float xa, xb, xc, ya, yb, yc;
	
	xa = rng(x0, y0);
	xb = rng(x1, y0);
	xc = mix(xa, xb, sx);

	ya = rng(x0, y1);
	yb = rng(x1, y1);
	yc = mix(ya, yb, sx);
	
	return mix(xc, yc, sy);
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		COLOR = vec3(0.0, 0.0, 0.0);
	} else {
		COLOR = BLACK;
		float r = perlin(SKY_COORDS.x * 32.0, SKY_COORDS.y * 32.0 + TIME);
		float g = perlin(SKY_COORDS.y * 64.0 + TIME, SKY_COORDS.x * 64.0);
		float b = perlin(SKY_COORDS.x * 32.0 + TIME, SKY_COORDS.y * 32.0 + 18000.0-TIME);
		COLOR = vec3(r*r*r, g*g*g*g, b*b*b);
	}
}
