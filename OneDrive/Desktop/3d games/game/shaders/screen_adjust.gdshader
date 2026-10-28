shader_type canvas_item;
// The brightness / contrast / colour settings: one pass over everything that is on screen (the 3D world and the menus alike).
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float saturation = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	c *= brightness;
	c = (c - 0.5) * contrast + 0.5;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
