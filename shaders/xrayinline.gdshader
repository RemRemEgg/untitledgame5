shader_type spatial;
render_mode unshaded;
render_mode cull_disabled,blend_add,depth_test_inverted;
//render_mode unshaded,cull_disabled,blend_add;

varying vec3 barys;
uniform vec3 color = vec3(1.0, 0.0, 0.0);

void vertex() {
	int index = (VERTEX_ID+2) % 3;
	switch (index) {
		case 0:
			barys = vec3(1.0, 0.0, 0.0);
			break;
		case 1:
			barys = vec3(0.0, 1.0, 0.0);
			break;
		case 2:
			barys = vec3(0.0, 0.0, 1.0);
			break;
	}
}

void fragment() {
	float svcu = max(barys.x, max(barys.y, barys.z));
	ALBEDO = color;
	ALPHA = float(svcu < 0.55) * 0.25;
}