shader_type canvas_item;
// Drifting fog for the title backdrop: two layers of noise sliding at
// different speeds, thinner toward the top of the screen.

uniform sampler2D noise : repeat_enable, filter_linear;
uniform vec4 tint : source_color = vec4(0.62, 0.66, 0.85, 1.0);
uniform float strength = 0.12;
uniform vec2 drift = vec2(0.012, 0.003);

void fragment() {
	float near = texture(noise, UV * vec2(1.6, 0.9) + TIME * drift).r;
	float far = texture(noise, UV * vec2(3.1, 1.7) - TIME * drift * 0.6).r;
	float fog = smoothstep(0.35, 0.85, near * 0.6 + far * 0.4);
	COLOR = vec4(tint.rgb, fog * strength * smoothstep(0.0, 0.65, UV.y));
}
