#include <metal_stdlib>
using namespace metal;

struct ReadingTransformUniforms {
    float intensity;
    float blueReduction;
    float dim;
    uint contrastProtect;
};

static inline float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

static inline float3 preserve_luminance(float3 original, float3 transformed) {
    float originalLuma = max(luminance(original), 0.0001);
    float3 displaySafe = clamp(transformed, 0.0, 1.0);
    float transformedLuma = max(luminance(displaySafe), 0.0001);
    return clamp(displaySafe * (originalLuma / transformedLuma), 0.0, 1.0);
}

kernel void readingComfortKernel(
    texture2d<float, access::read> input [[texture(0)]],
    texture2d<float, access::write> output [[texture(1)]],
    constant ReadingTransformUniforms& uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= output.get_width() || gid.y >= output.get_height()) {
        return;
    }

    uint inputX = min(gid.x, input.get_width() - 1);
    uint inputY = min(gid.y, input.get_height() - 1);
    float4 source = input.read(uint2(inputX, inputY));
    float3 color = source.rgb;

    float strain = max(color.b - ((color.r + color.g) * 0.5), 0.0);
    float reduction = strain * clamp(uniforms.blueReduction, 0.0, 1.0) * clamp(uniforms.intensity, 0.0, 1.0);

    float3 transformed = float3(
        color.r + reduction * 0.18,
        color.g - reduction * 0.04,
        color.b - reduction
    );

    if (uniforms.contrastProtect != 0) {
        transformed = preserve_luminance(color, transformed);
    }

    transformed = clamp(transformed * (1.0 - clamp(uniforms.dim, 0.0, 0.8)), 0.0, 1.0);
    output.write(float4(transformed, source.a), gid);
}
