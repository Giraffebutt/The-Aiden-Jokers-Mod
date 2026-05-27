#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
#define PRECISION highp
#else
#define PRECISION mediump
#endif

extern PRECISION number time;
extern PRECISION vec2 mouse_screen_pos;
extern PRECISION float screen_scale;
extern PRECISION float hovering;
extern PRECISION float dissolve;
extern PRECISION vec4 texture_details;
extern PRECISION vec2 image_details;
extern PRECISION vec4 burn_colour_1;
extern PRECISION vec4 burn_colour_2;
extern bool shadow;
extern PRECISION vec2 purpleaiden_evil;
extern PRECISION vec2 evil;
extern PRECISION float evil_amount;

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords)
{
    vec4 pixel = Texel(texture, texture_coords);

    if (pixel.a <= 0.0) {
        return pixel;
    }

    float engine_guard = hovering + dissolve + texture_details.x + image_details.x
        + burn_colour_1.r + burn_colour_2.r + evil.x + (shadow ? 1.0 : 0.0);
    float mouse_guard = length(mouse_screen_pos / max(screen_scale, 0.0001)) * 0.000001
        + length(purpleaiden_evil) * 0.000001
        + (engine_guard * 0.000001);
    float pulse = 0.03 * sin((time * 3.0) + (texture_coords.y * 18.0));
    float intensity = clamp(0.24 + (evil_amount * 0.76) + pulse + mouse_guard, 0.0, 1.0);
    vec3 purple = vec3(0.48, 0.04, 0.82);

    return vec4(purple, pixel.a * intensity * 0.38) * colour;
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
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
