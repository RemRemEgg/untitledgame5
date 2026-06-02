shader_type canvas_item;

render_mode unshaded;

const vec4 BASE_COLOR = vec4(0.1, 0.85, 0.2, 1.0);
const vec4 HILIGHT_COLOR = vec4(0.9, 1.0, 1.0, 1.0);

void fragment() {
	//                            SPEED   SCALE
	float p = (UV.x + UV.y - TIME*0.35) * 0.4;
	p = abs(round(p) - p);
	//           SHARPNESS
	p = p / (p + 0.035);
	p = min(1.0, p*1.6 );
	COLOR = mix(HILIGHT_COLOR, BASE_COLOR, p);
}