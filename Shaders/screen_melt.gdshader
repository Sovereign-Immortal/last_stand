shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float melt_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 co) {
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 ip = floor(p);
    vec2 fp = fract(p);
    fp = fp*fp*(3.0-2.0*fp);
    float a = hash(ip);
    float b = hash(ip + vec2(1.0, 0.0));
    float c = hash(ip + vec2(0.0, 1.0));
    float d = hash(ip + vec2(1.0, 1.0));
    return mix(mix(a, b, fp.x), mix(c, d, fp.x), fp.y);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // Procedural noise for vertical columns (melt lanes)
    float col_noise = noise(vec2(uv.x * 35.0, 13.0));
    
    // Shift pixels down
    float shift = progress * (0.8 + 0.4 * col_noise);
    uv.y += shift;
    
    // Sample the screen behind the rect
    vec4 tex_color = texture(screen_texture, uv);
    
    // Burn/dissolve transition effect at the melting front
    float burn_noise = noise(SCREEN_UV * 60.0);
    float threshold = progress * 1.2;
    
    // Melt edge coloring (glowing hot amber/orange at the boundary)
    float edge = smoothstep(threshold - 0.15, threshold, burn_noise);
    vec3 glow_color = vec3(1.0, 0.35, 0.05); // Neon Amber
    
    if (uv.y > 1.0 || burn_noise < threshold) {
        // Melted part becomes white
        COLOR = vec4(1.0, 1.0, 1.0, 1.0);
    } else {
        // Mix the screen with the glowing edge
        COLOR = mix(tex_color, vec4(glow_color, 1.0), (1.0 - edge) * 0.7);
    }
}
