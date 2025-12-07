shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.0, 0.6, 0.8, 1.0);
uniform float speed = 2.0;
uniform float frequency = 10.0;
uniform float amplitude = 0.05;
uniform float offset = 0.0;
uniform float surface_level = 0.75; // 0.0 = top, 1.0 = bottom

void fragment() {
	// UV.y goes 0.0 -> top, 1.0 -> bottom
	float wave = sin(UV.x * frequency + TIME * speed + offset) * amplitude;
	float threshold = surface_level + wave;

	// Draw color only for pixels below the wave (i.e. larger UV.y)
	if (UV.y > threshold) {
		COLOR = color;
	} else {
		COLOR = vec4(0.0);
	}
}
