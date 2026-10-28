shader_type sky;
// A painted fantasy sky: a colour gradient, a glowing sun or moon, soft drifting clouds, stars and shooting glints at night, northern lights,
// and light shafts for the underwater map. Every map sets its own colours (see MapLoader.SKY).

uniform vec3 top_color : source_color = vec3(0.2, 0.4, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.88, 0.95);
uniform vec3 ground_color : source_color = vec3(0.2, 0.22, 0.28);
uniform vec3 sun_color : source_color = vec3(1.0, 0.92, 0.7);
uniform vec3 sun_dir = vec3(0.3, 0.6, 0.7);      // towards the sun (or the moon at night)
uniform float night = 0.0;                      // 0 = day, 1 = full night (stars, moon)
uniform float cloud_amount = 0.5;
uniform vec3 cloud_color : source_color = vec3(1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.6, 0.75);
uniform float aurora = 0.0;
uniform vec3 aurora_color : source_color = vec3(0.3, 1.0, 0.7);
uniform vec3 aurora_color2 : source_color = vec3(0.6, 0.3, 1.0);
uniform float rays = 0.0;                       // underwater light shafts
uniform sampler2D noise : repeat_enable, filter_linear;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sd = normalize(sun_dir);
	float h = d.y;
	// gradient
	vec3 col = mix(horizon_color, top_color, pow(clamp(h * 1.25, 0.0, 1.0), 0.55));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 4.0, 0.0, 1.0));
	}
	float sdot = max(dot(d, sd), 0.0);
	// warm glow around the sun, stronger near the horizon
	float glow = pow(sdot, 6.0) * 0.35 + pow(sdot, 40.0) * 0.5;
	col += sun_color * glow * (1.0 - 0.6 * night);

	// stars
	if (night > 0.01 && h > -0.05) {
		vec2 sp = d.xz / (abs(d.y) + 0.35) * 90.0;
		vec2 cell = floor(sp);
		float r = hash(cell);
		float star = step(0.985, r);
		vec2 f = fract(sp) - 0.5;
		float tw = 0.6 + 0.4 * sin(TIME * (1.0 + r * 3.0) + r * 40.0);
		float bright = star * smoothstep(0.35, 0.0, length(f)) * tw;
		col += vec3(1.0, 0.97, 0.9) * bright * night * smoothstep(0.0, 0.25, h);
	}

	// sun or moon disc
	float disc = smoothstep(0.9993 - 0.0007 * night, 0.9997, sdot);
	if (night > 0.5) {
		vec3 moon = mix(vec3(0.95, 0.95, 0.88), vec3(0.8, 0.82, 0.9), texture(noise, d.xz * 4.0 + 0.3).r * 0.6);
		col = mix(col, moon, disc);
		col += vec3(0.5, 0.55, 0.8) * pow(sdot, 120.0) * 0.5;
	} else {
		col = mix(col, sun_color * 1.6, disc);
	}

	// clouds
	if (h > 0.015 && cloud_amount > 0.01) {
		vec2 uv = d.xz / (h + 0.28) * 0.9 + vec2(TIME * 0.004, TIME * 0.0015);
		float n = texture(noise, uv).r * 0.6 + texture(noise, uv * 2.7 + 3.1).g * 0.4;
		float cov = smoothstep(1.0 - cloud_amount, 1.0 - cloud_amount + 0.28, n);
		float lit = pow(sdot, 3.0) * 0.5 + 0.5;
		vec3 cc = mix(cloud_shadow, cloud_color, lit);
		cc = mix(cc, sun_color, pow(sdot, 20.0) * 0.4);
		cc *= 1.0 - 0.55 * night;
		col = mix(col, cc, cov * smoothstep(0.015, 0.2, h) * (1.0 - 0.3 * night));
	}

	// northern lights
	if (aurora > 0.01 && h > 0.05) {
		vec2 uv = d.xz / (h + 0.4) * 1.4;
		float wave = sin(uv.x * 3.0 + TIME * 0.15 + texture(noise, uv * 0.6).r * 4.0);
		float band = smoothstep(0.35, 0.0, abs(uv.y * 0.9 - wave * 0.22 - 0.25));
		float fade = smoothstep(0.05, 0.35, h) * smoothstep(0.95, 0.5, h);
		vec3 ac = mix(aurora_color, aurora_color2, smoothstep(0.0, 1.0, uv.y * 0.5 + 0.5));
		col += ac * band * fade * aurora * (0.6 + 0.4 * texture(noise, uv * 2.0 + TIME * 0.02).g);
	}

	// underwater light shafts
	if (rays > 0.01 && h > 0.0) {
		float a = atan(d.x, d.z);
		float shaft = smoothstep(0.55, 1.0, sin(a * 9.0 + TIME * 0.2) * 0.5 + 0.5) * pow(clamp(h, 0.0, 1.0), 0.4);
		col += sun_color * shaft * 0.35 * rays;
	}
	COLOR = col;
}
