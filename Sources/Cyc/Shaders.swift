/// The GPU programs, written in the Metal Shading Language and compiled when the
/// output opens. Kept as a string so `swift build` works without Xcode's Metal
/// build step.
enum Shaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    // Must match `LookUniform` in Renderer.swift.
    struct Look {
        float4 top;
        float4 bottom;
    };

    struct VertexOut {
        float4 position [[position]];
        float v;  // 0 at the top of the screen, 1 at the bottom
    };

    // One triangle large enough to cover the whole screen, made from the vertex
    // number alone: no vertex data to upload.
    vertex VertexOut fullScreen(uint id [[vertex_id]]) {
        float2 p = float2(float((id << 1) & 2), float(id & 2));  // (0,0), (2,0), (0,2)
        VertexOut out;
        out.position = float4(p.x * 2 - 1, 1 - p.y * 2, 0, 1);
        out.v = p.y;
        return out;
    }

    // Blends the top color into the bottom color.
    fragment float4 gradient(VertexOut in [[stage_in]], constant Look &look [[buffer(0)]]) {
        float4 color = mix(look.top, look.bottom, saturate(in.v));
        if (any(look.top != look.bottom)) {
            // Dithering: a tiny per-pixel random offset (under one 8-bit step)
            // breaks the visible stripes ("banding") of a slow gradient.
            float noise = fract(sin(dot(in.position.xy, float2(12.9898, 78.233))) * 43758.5453);
            color.rgb += (noise - 0.5) / 255.0;
        }
        return color;
    }
    """
}
