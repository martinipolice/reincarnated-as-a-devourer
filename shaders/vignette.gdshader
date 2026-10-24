// Screen-edge darkness (the souls-like frame) plus danger feedback: a red
// flash when hit and a slow red pulse at low HP. Drawn on a full-screen
// ColorRect under the HUD; see scripts/ui/vignette.gd.
shader_type canvas_item;

uniform float strength = 0.7;  // how dark the corners get
uniform float aspect = 1.78;  // screen width / height, so the falloff is round
uniform float hurt = 0.0;  // 0..1, decays after a hit
uniform float danger = 0.0;  // 0..1, the low-HP pulse

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= aspect / 1.78 * 1.4;
	float d = length(p);
	float dark = smoothstep(0.3, 0.95, d) * strength;
	float red = clamp(hurt + danger, 0.0, 1.0) * smoothstep(0.2, 0.85, d) * 0.75;
	float alpha = clamp(dark + red, 0.0, 1.0);
	vec3 tint = vec3(0.55, 0.0, 0.04);
	COLOR = vec4(tint * (red / max(alpha, 0.001)), alpha);
}
