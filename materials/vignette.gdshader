shader_type canvas_item;
// Full-screen red vignette: clear in the middle, `color` towards the edges. `strength`
// 0 = invisible, 1 = the edges fully coloured. Used while downed and when you're hit.

uniform vec4 color : source_color = vec4(0.75, 0.0, 0.0, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float inner : hint_range(0.0, 1.5) = 0.35; // Distance from the centre where it starts.
uniform float outer : hint_range(0.0, 1.5) = 1.0; // ...and where it's at full strength.

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float edge = smoothstep(inner, outer, length(p));
	COLOR = vec4(color.rgb, color.a * edge * strength);
}
