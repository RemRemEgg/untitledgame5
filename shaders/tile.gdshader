shader_type spatial;

//varying vec2 pos;
varying vec3 pos;
varying vec3 modulo;

void vertex() {
	//pos = UV;
	//pos.x /= length(vec3(MODEL_NORMAL_MATRIX[0][0], MODEL_NORMAL_MATRIX[0][1], MODEL_NORMAL_MATRIX[0][2]));
	//pos.y /= length(vec3(MODEL_NORMAL_MATRIX[2][0], MODEL_NORMAL_MATRIX[2][1], MODEL_NORMAL_MATRIX[2][2]));
	//pos /= length(vec3(MODEL_NORMAL_MATRIX[1][0], MODEL_NORMAL_MATRIX[1][1], MODEL_NORMAL_MATRIX[1][2]));
	pos = VERTEX;
	modulo = NORMAL;
}

void fragment() {
	//ALBEDO = texture(resource, pos).rgb;
	//ALBEDO = vec3(pos.x, pos.y, 0);
	int a = int(floor(pos.x+0.00001))  + int(floor(pos.y+0.00001))  + int(floor(pos.z+0.00001));
	a = a % 2;
	int b = int(floor(pos.x/4.0+0.00001))  + int(floor(pos.y/4.0+0.00001))  + int(floor(pos.z/4.0+0.00001));
	b = b % 2;
	ALBEDO = vec3(0.75-float(a) - float(b) * 0.6);
	//ALBEDO *= NORMAL * inverse(mat3(VIEW_MATRIX));
	//ALBEDO = (ALBEDO + modulo) / 2.0;
	//ALBEDO *= modulo;
	ALBEDO = modulo - ALBEDO * 0.5;
	ALBEDO *= 0.25;
}
