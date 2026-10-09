shader_type canvas_item;
// Full-screen colour grade under the HUD: the downed screen fades towards grey.
// saturation 1 = normal colour, 0 = greyscale.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(grey), c, saturation), 1.0);
}
