#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
#define PRECISION highp
#else
#define PRECISION mediump
#endif

extern PRECISION number dissolve;
extern PRECISION number time;
extern PRECISION vec4 texture_details;
extern PRECISION vec2 image_details;
extern bool shadow;
extern PRECISION vec4 burn_colour_1;
extern PRECISION vec4 burn_colour_2;
extern PRECISION vec2 mouse_screen_pos;
extern PRECISION float screen_scale;
extern PRECISION float hovering;
extern PRECISION vec2 redaiden_fire;

vec3 mod289(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289(((x * 34.0) + 1.0) * x);
}

float snoise(vec3 v) {
    const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i = floor(v + dot(v, C.yyy));
    vec3 x0 = v - i + dot(i, C.xxx);

    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 i1 = min(g.xyz, l.zxy);
    vec3 i2 = max(g.xyz, l.zxy);

    vec3 x1 = x0 - i1 + C.xxx;
    vec3 x2 = x0 - i2 + C.yyy;
    vec3 x3 = x0 - D.yyy;

    i = mod289(i);
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));
        
    float n_ = 0.142857142857;
    vec3 ns = n_ * D.wyz - D.xzx;
    
    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.yyyy;
    vec4 y = y_ * ns.x + ns.yyyy;
    vec4 h = 1.0 - abs(x) - abs(y);
    
    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);
    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));
    
    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    vec3 p0 = vec3(a0.xy, h.x);
    vec3 p1 = vec3(a0.zw, h.y);
    vec3 p2 = vec3(a1.xy, h.z);
    vec3 p3 = vec3(a1.zw, h.w);
    
    vec4 norm = inversesqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
    p0 *= norm.x;
    p1 *= norm.y;
    p2 *= norm.z;
    p3 *= norm.w;

    vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    m = m * m;

    return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}

float prng(vec2 seed) {
    seed = fract(seed * vec2(5.3983, 5.4427));
    seed += dot(seed.yx, seed.xy + vec2(21.5351, 14.3137));
    return fract(seed.x * seed.y * 95.4337);
}

float noiseStack(vec3 pos, int octaves, float falloff) {
    float noise = snoise(pos);
    float off = 1.0;

    if (octaves > 1) {
        pos *= 2.0;
        off *= falloff;
        noise = (1.0 - off) * noise + off * snoise(pos);
    }
    if (octaves > 2) {
        pos *= 2.0;
        off *= falloff;
        noise = (1.0 - off) * noise + off * snoise(pos);
    }
    if (octaves > 3) {
        pos *= 2.0;
        off *= falloff;
        noise = (1.0 - off) * noise + off * snoise(pos);
    }

    return (1.0 + noise) / 2.0;
}

vec2 noiseStackUV(vec3 pos, int octaves, float falloff, float diff) {
    float displaceA = noiseStack(pos, octaves, falloff);
    float displaceB = noiseStack(pos + vec3(3984.293, 423.21, 5235.19 + diff), octaves, falloff);
    return vec2(displaceA, displaceB);
}

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;
    vec2 floored_uv = floor(uv * texture_details.ba) / max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);
    
    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));
    
    float field = (1.0 + (
        cos(length(field_part1) / 19.483)
        + sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73)
        + cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92)
    )) / 2.0;
    
    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos(adjusted_dissolve / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;
        
    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow && res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) && res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5))) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(shadow ? vec3(0.0) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0);
}

vec3 fire_colour(vec2 fragCoord, vec2 resolution, float realTime) {
    float xpart = fragCoord.x / resolution.x;
    float ypart = fragCoord.y / resolution.y;
    float clip = resolution.y * 0.78;
    float ypartClip = fragCoord.y / clip;
    float ypartClippedFalloff = clamp(2.0 - ypartClip, 0.0, 1.0);
    float ypartClipped = min(ypartClip, 1.0);
    float ypartClippedn = 1.0 - ypartClipped;
    float xfuel = 1.0 - abs(2.0 * xpart - 1.0);

    vec2 offset = vec2(0.0);
    vec2 coordScaled = 0.01 * fragCoord - 0.02 * vec2(offset.x, 0.0);
    vec3 position = vec3(coordScaled, 0.0) + vec3(1223.0, 6434.0, 8425.0);
    vec3 flow = vec3(4.1 * (0.5 - xpart) * pow(ypartClippedn, 4.0), -2.0 * xfuel * pow(ypartClippedn, 64.0), 0.0);
    vec3 timing = realTime * vec3(0.0, -1.7, 1.1) + flow;
    
    vec3 displacePos = vec3(1.0, 0.5, 1.0) * 2.4 * position + realTime * vec3(0.01, -0.7, 1.3);
    vec3 displace3 = vec3(noiseStackUV(displacePos, 2, 0.4, 0.1), 0.0);
    vec3 noiseCoord = (vec3(2.0, 1.0, 1.0) * position + timing + 0.4 * displace3);
    float noise = noiseStack(noiseCoord, 3, 0.4);

    float flames = pow(ypartClipped, 0.3 * xfuel) * pow(noise, 0.3 * xfuel);
    float f = ypartClippedFalloff * pow(1.0 - flames * flames * flames, 8.0);
    float fff = f * f * f;
    
    // TWEAK: Significantly boosted multipliers for a thicker, more vibrant fire
    vec3 fire = 3.5 * vec3(f, fff * 0.4, fff * fff * 0.04);
    
    // TWEAK: Dropped the ambient smoke even lower to prevent muddying
    float smokeNoise = 0.5 + snoise(0.4 * position + timing * vec3(1.0, 1.0, 0.2)) / 2.0;
    vec3 smoke = vec3(0.05 * pow(xfuel, 3.0) * pow(ypart, 2.0) * (smokeNoise + 0.4 * (1.0 - noise)));
    
    float sparkGridSize = 30.0;
    vec2 sparkCoord = fragCoord - vec2(2.0 * offset.x, 190.0 * realTime);
    sparkCoord -= 30.0 * noiseStackUV(0.01 * vec3(sparkCoord, 30.0 * realTime), 1, 0.4, 0.1);
    sparkCoord += 100.0 * flow.xy;
    if (mod(sparkCoord.y / sparkGridSize, 2.0) < 1.0) {
        sparkCoord.x += 0.5 * sparkGridSize;
    }

    vec2 sparkGridIndex = floor(sparkCoord / sparkGridSize);
    float sparkRandom = prng(sparkGridIndex);
    float sparkLife = min(10.0 * (1.0 - min((sparkGridIndex.y + (190.0 * realTime / sparkGridSize)) / (24.0 - 20.0 * sparkRandom), 1.0)), 1.0);
    vec3 sparks = vec3(0.0);

    if (sparkLife > 0.0) {
        float sparkSize = xfuel * xfuel * sparkRandom * 0.08;
        float sparkRadians = 999.0 * sparkRandom * 6.28318530718 + 2.0 * realTime;
        vec2 sparkCircular = vec2(sin(sparkRadians), cos(sparkRadians));
        vec2 sparkOffset = (0.5 - sparkSize) * sparkGridSize * sparkCircular;
        vec2 sparkModulus = mod(sparkCoord + sparkOffset, sparkGridSize) - 0.5 * vec2(sparkGridSize);
        float sparkLength = length(sparkModulus);
        float sparksGray = max(0.0, 1.0 - sparkLength / max(sparkSize * sparkGridSize, 0.001));
        sparks = sparkLife * sparksGray * vec3(1.0, 0.2, 0.0);
    }

    return max(fire, sparks) + smoke;
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    vec2 uv = ((texture_coords * image_details) - texture_details.xy * texture_details.ba) / texture_details.ba;
    
    vec2 cardScale = vec2(71.0, 95.0);
    vec2 fragCoord = vec2(uv.x, 1.0 - uv.y) * cardScale;
    
    float realTime = max(redaiden_fire.x, time * 0.01);
    float alpha = clamp(redaiden_fire.y, 0.0, 1.0);
    
    vec3 fire_rgb = fire_colour(fragCoord, cardScale, realTime);
    
    // TWEAK: Simplified alpha scaling. 
    // This removes the dark background entirely but leaves the fire fully opaque.
    float flameIntensity = max(fire_rgb.r, max(fire_rgb.g, fire_rgb.b));
    float flameAlpha = clamp(flameIntensity * 2.5, 0.0, 1.0);
    
    float mask = smoothstep(0.0, 0.18, pixel.a);
    
    vec4 overlay = vec4(fire_rgb, pixel.a * alpha * mask * flameAlpha);

    return dissolve_mask(overlay * colour, texture_coords, uv);
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.0) {
        return transform_projection * vertex_position;
    }

    float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy) / screen_scale;
    float scale = 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist))
        * hovering * (length(mouse_offset) * length(mouse_offset)) / (2.0 - mid_dist);
        
    return transform_projection * vertex_position + vec4(0.0, 0.0, 0.0, scale);
}
#endif
