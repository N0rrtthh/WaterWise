shader_type canvas_item;

uniform vec4 grid_color : source_color = vec4(0.0, 0.0, 0.0, 0.1);
uniform float cell_size = 50.0;
uniform float line_thickness = 2.0;

void fragment() {
	vec2 pos = FRAGCOORD.xy;
	float grid_x = step(cell_size - line_thickness, mod(pos.x, cell_size));
	float grid_y = step(cell_size - line_thickness, mod(pos.y, cell_size));
	
	float grid = max(grid_x, grid_y);
	
	COLOR = mix(vec4(0.0), grid_color, grid);
}
