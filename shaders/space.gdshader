shader_type sky;

const float SCALE = 18.0;
const float DENSITY = 0.005;
const float BRIGHTNESS = 0.64;

const vec3 BLACK = vec3(0, 0, 0);
const vec3 CMP = vec3(1.0, 1.0, 1.0) * 0.08;
const float dxz = BRIGHTNESS / DENSITY;

const vec3[] COLORS = {vec3(0.3, 0.7, 1.0), vec3(1.0, 0.2, 0.7), vec3(1.0, 1.0, 1.0)};

int pkn(int a, int b, int c) {
	a ^= a << 13;
	a ^= (a^c) >> 17;
	a ^= a << 5;
	b ^= b << 11;
	b ^= (b^c) >> 15;
	b ^= b << 7;
	return a^~b^~c;
}

void sky() {
	if (AT_CUBEMAP_PASS) { COLOR = vec3(0, 0, 0);
    } else {
		COLOR = BLACK;
		for (float ii = 0.5; ii < 2.0; ii += 0.7) {
			float x = SKY_COORDS.x*SCALE*16.0*(4.0-ii); //int(SKY_COORDS.x * SCALE * sin( floor(SKY_COORDS.y*SCALE) /SCALE*PI))
			float y = SKY_COORDS.y*SCALE*9.00*(4.0-ii); //int(SKY_COORDS.y * SCALE)
			int p = pkn(int(x + POSITION.x*ii*0.02),int(y + POSITION.z*ii*0.02),int(ii*157348.0));
			p = abs(p);
			float z1 = float(p)/35565.0;
			z1 -= floor(z1);
			if (z1 > DENSITY) z1 = 0.0;
			COLOR += z1 * dxz * COLORS[p % 3];
		}
		COLOR = min(COLOR, vec3(1, 1, 1));
	}
}