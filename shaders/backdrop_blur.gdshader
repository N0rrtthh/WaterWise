shader_type canvas_item;

// Menu backdrop softener: nine taps in a cross-plus-diagonal pattern, followed by a
// flat scrim.
//
// Used by CharacterCustomization, where the Waterville house and hills are drawn at
// full sharpness directly behind the character preview card and the card had nothing
// separating it from them.
//
// Deliberately cheap. This covers the whole screen on the thesis target hardware
// (Cortex-A53 class, gl_compatibility renderer), where a separable two-pass Gaussian
// would need a second viewport and a second full-screen pass. Nine taps sink the
// hard edges of the background art without reading as a smear.
//
// The radius is multiplied by SCREEN_PIXEL_SIZE, so its strength is the same on every
// resolution rather than shrinking as the canvas grows.
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float radius : hint_range(0.0, 16.0) = 5.0;
uniform vec4 scrim : source_color = vec4(0.85, 0.92, 0.98, 0.42);

void fragment() {
	vec2 d = SCREEN_PIXEL_SIZE * radius;

	vec3 sum = texture(screen_tex, SCREEN_UV).rgb * 0.2;
	sum += texture(screen_tex, SCREEN_UV + vec2(d.x, 0.0)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(-d.x, 0.0)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(0.0, d.y)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(0.0, -d.y)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(d.x, d.y)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(-d.x, d.y)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(d.x, -d.y)).rgb * 0.1;
	sum += texture(screen_tex, SCREEN_UV + vec2(-d.x, -d.y)).rgb * 0.1;

	COLOR = vec4(mix(sum, scrim.rgb, scrim.a), 1.0);
}
