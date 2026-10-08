shader_type spatial;
// Viewmodel material: squashes depth so the gun always renders in front of
// the world (no clipping into walls) while still sorting correctly against itself.
// Godot 4.3+ uses reversed-Z, so pushing depth toward w = closer to the camera.

uniform vec4 albedo : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.6;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float depth_scale : hint_range(0.001, 1.0) = 0.05;
uniform vec3 emission : source_color = vec3(0.0);

void vertex() {
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	POSITION.z = mix(POSITION.w, POSITION.z, depth_scale);
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission;
}
