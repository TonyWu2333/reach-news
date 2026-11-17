#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

[[ stitchable ]] half4 liquidGlassLayer(float2 position, SwiftUI::Layer layer, float2 size, float strength, float phase) {
    float2 centered = position - size * 0.5;
    float radius = min(28.0, min(size.x, size.y) * 0.5);
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
    float bloom = clamp(abs(phase - 0.5) * 2.0, 0.0, 1.0);
    float localStrength = strength * (0.75 + bloom * 0.9);
    float2 offset = -normal * rim * localStrength;
    half4 color = layer.sample(position + offset);
    float highlight = rim * (0.10 + bloom * 0.18);
    // Warm refraction tint, like looking through a water droplet onto UI.
    color.rgb = mix(color.rgb, half3(0.55, 0.34, 0.18), half(rim * bloom * 0.22));
    color.rgb += half3(highlight, highlight * 0.96, highlight * 0.90);
    return color;
}
