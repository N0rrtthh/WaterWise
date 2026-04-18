shader_type canvas_item;

// Scroll speed — positive scrolls right, negative scrolls left
uniform float scroll_speed : hint_range(-1.0, 1.0) = 0.15;

// Mirror-repeat UV so the wave tiles seamlessly without a hard seam
float mirror_uv(float x) {
	// ping-pong: 0→1→0→1... giving a seamless reflection tile
	float t = fract(x * 0.5) * 2.0;
	return t > 1.0 ? 2.0 - t : t;
}

void fragment() {
	vec2 uv = UV;
	uv.x = mirror_uv(uv.x + TIME * scroll_speed);
	COLOR = texture(TEXTURE, uv);
}
