#version 440
// Dot mask, ported from glyph-rice (github.com/Nebelung-cloud/glyph-rice, GPL-3.0).
// Turns an item into a matrix of LED dots. Each dot takes the colour at the centre of its cell, so every dot has the
// same size and an even tone, like the Glyph lights on the back of the phone. Luminance only: the result is monochrome.
// Rebuild after editing: qsb --qt6 -o dots.frag.qsb dots.frag (qt6-shadertools)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;   // item size, px
    float pitch; // grid step, px. Not "step": that is a GLSL builtin, SPIRV-Cross renames it and Qt can't find the uniform
    float circ;  // 1 = only the dots inside the inscribed circle (album covers)
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 c = (floor(p / pitch) + 0.5) * pitch;
    float r = pitch * 0.3; // dot radius
    float m = 1.0 - smoothstep(r - 0.6, r + 0.6, distance(p, c));
    if (circ > 0.5 && distance(c, size * 0.5) > min(size.x, size.y) * 0.5) m = 0.0;
    vec4 t = texture(source, c / size);
    float l = dot(t.rgb, vec3(0.299, 0.587, 0.114)); // monochrome: coloured covers turn grey too
    fragColor = vec4(vec3(l), t.a) * m * qt_Opacity;
}
