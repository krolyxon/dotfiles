#version 440
// Wallpaper, ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0).
// The image as a matrix of LED dots (dots 1) or as a photo (dots 0); mono 1 = in the theme's tone (lo..hi), 0 = own colours.
// A change runs as a wave from origin: each cell decides as a whole, srcA before the front, srcB behind it. On the crest a
// cell is always a dot that swells and brightens, so the photo dissolves into the matrix and comes back as the new one.
// The side without an image is transparent (the dot grid and orb show through), the crest still runs over it.
// Rebuild after editing: qsb --qt6 -o wall.frag.qsb wall.frag (qt6-shadertools)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;   // px
    vec2 origin; // px, where the wave starts
    vec2 cropA;  // visible part of the texture in x/y (PreserveAspectCrop)
    vec2 cropB;
    vec4 lo;     // dark end of the tone
    vec4 hi;     // light end
    vec4 bg;
    float pitch;  // dot step, px
    float dots;   // 0 photo .. 1 dots
    float mono;   // 0 colour .. 1 tone
    float bright; // 0 .. 1: from the background to the full image
    float wave;   // 0 .. 1
    float hasA;
    float hasB;
};
layout(binding = 1) uniform sampler2D srcA;
layout(binding = 2) uniform sampler2D srcB;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;

    // a front `band` wide travels from origin to the farthest corner; k 0 = still old .. 1 = already new
    float band = pitch * 14.0;
    float far = length(max(origin, size - origin)) + band;
    float k = clamp((wave * far - distance(c, origin)) / band, 0.0, 1.0);
    float crest = 1.0 - abs(2.0 * k - 1.0);
    bool isB = k > 0.5;
    float has = isB ? hasB : hasA;

    // d 0 = own pixel, 1 = cell centre: in between the image shrinks towards the centre (smooth pixelation)
    float d = max(dots, crest);
    vec2 uv = mix(p, c, d) / size - 0.5;
    vec4 t = isB ? texture(srcB, uv * cropB + 0.5) : texture(srcA, uv * cropA + 0.5);
    vec3 rgb = t.rgb + bg.rgb * (1.0 - t.a); // transparent parts of the image go onto the background
    float l = dot(rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = has > 0.5 ? mix(bg.rgb, mix(rgb, mix(lo.rgb, hi.rgb, l), mono), bright) : bg.rgb;
    col = mix(col, hi.rgb, 0.4 * crest);

    // dot radius from "the whole cell" (photo) to .3 of the step (like the dot mask), swelling on the crest
    float r = pitch * mix(0.75, 0.3, d) * (1.0 + 0.55 * crest);
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    float a = has > 0.5 ? 1.0 : m * crest;
    fragColor = vec4(mix(bg.rgb, col, m) * a, a) * qt_Opacity;
}
