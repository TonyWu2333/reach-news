#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 liquidGlassLayer(float2 position, SwiftUI::Layer layer, float2 size, float strength, float phase) {
    float2 centered = position - size * 0.5;
    float radius = min(22.0, min(size.x, size.y) * 0.5);
    float2 q = abs(centered) - (size * 0.5 - radius);
    float2 outside = max(q, float2(0.0));
    float distance = length(outside) + min(max(q.x, q.y), 0.0) - radius;
    float2 normal = float2(0.0);
    if (length(outside) > 0.001) {
        normal = normalize(outside) * sign(centered);
    } else if (q.x > q.y) {
        normal = float2(sign(centered.x), 0.0);
    } else {
        normal = float2(0.0, sign(centered.y));
    }
    float bevel = 15.0;
    float edgeDepth = clamp(-distance / bevel, 0.0, 1.0);
    float rim = 1.0 - smoothstep(0.0, 0.72, edgeDepth);
    float wave = sin((position.x / max(size.x, 1.0) + phase) * 18.0) * 0.22;
    float2 offset = -normal * rim * (strength + wave * strength);
    half4 color = layer.sample(position + offset);
    float highlight = rim * (0.24 + 0.10 * sin((position.x + position.y) * 0.12 + phase * 8.0));
    color.rgb += half3(highlight * 0.72, highlight * 0.86, highlight);
    return color;
}
