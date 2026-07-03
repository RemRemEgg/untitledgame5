shader_type spatial;
render_mode unshaded,blend_add,depth_test_disabled,wireframe;

uniform vec3 color: source_color;

void fragment() {
	ALPHA = 0.032;
	ALBEDO = color;
	//float svc = min(barys.x, min(barys.y, barys.z));
	//if (svc < 0.02) {
		////ALPHA = 1.0;
		////ALBEDO = vec3(1.0);
	//} else {discard;}
	//svc = svc < fwidth(svc) ? 0.3 : 0.15;
	//ALBEDO = vec3(0.5, 0.8, 0.8);
	//ALPHA = svc;
}