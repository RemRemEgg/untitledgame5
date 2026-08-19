shader_type spatial;
render_mode unshaded,blend_add,depth_test_disabled,wireframe;

uniform vec3 color: source_color;

void fragment() {
	ALPHA = 0.025;
	ALBEDO = color;
}