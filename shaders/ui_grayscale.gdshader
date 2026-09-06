shader_type canvas_item;

// Desaturates whatever the CanvasItem draws — stylebox fills, icons and text glyphs
// alike. Used for locked shop/accessory entries, where `modulate` alone cannot do the
// job: the item icons are colour-font emoji, and dimming them with modulate leaves them
// fully saturated and still reading as available.
//
// COLOR arrives already multiplied by TEXTURE and the vertex/modulate colour, so this
// works for untextured stylebox draws as well as textured glyph draws.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	float grey = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, vec3(grey), amount);
}
