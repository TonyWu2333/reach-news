#include <metal_stdlib>
using namespace metal;

// A small edge-bulge displacement used by the draggable glass indicator.
// The strongest displacement lives around the rim, where real glass bends
// the background and produces the characteristic liquid edge.
[[ stitchable ]] float2 liquidGlass(float2 position, float2 size, float strength, float phase) {
    float2 uv = position / max(size, float2(1.0));
    float2 centered = uv - 0.5;
    float distanceFromCenter = length(centered);
    float rim = smoothstep(0.16, 0.50, distanceFromCenter);
    float2 normal = centered / max(distanceFromCenter, 0.001);
    float wave = sin((uv.x * 2.0 + uv.y + phase) * 24.0) * 0.30;
    float directional = sin((uv.x - phase) * 12.0) * 0.12;
    return position + normal * (rim * (strength + wave * strength + directional * strength));
}
