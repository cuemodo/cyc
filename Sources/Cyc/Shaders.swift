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

    // Must match `QuadUniform` in Renderer.swift.
    struct QuadInfo {
        float3x3 outputToCanvas;  // homography: output pixel -> canvas pixel
        float2 outputSize;        // output size in pixels
        float canvasHeight;       // the gradient runs from canvas y = 0 to this
    };

    struct VertexOut {
        float4 position [[position]];
    };

    // Places one corner of a quad's triangles. Corners come in output pixels;
    // the GPU wants "clip space", from -1 to 1 with y pointing up.
    vertex VertexOut quadVertex(uint id [[vertex_id]],
                                constant float2 *corners [[buffer(0)]],
                                constant QuadInfo &quad [[buffer(1)]]) {
        float2 p = corners[id] / quad.outputSize;
        VertexOut out;
        out.position = float4(p.x * 2 - 1, 1 - p.y * 2, 0, 1);
        return out;
    }

    // Runs once per output pixel inside a quad: finds where that pixel comes
    // from on the canvas, then takes the look's color at that height.
    fragment float4 mappedLook(VertexOut in [[stage_in]],
                               constant Look &look [[buffer(0)]],
                               constant QuadInfo &quad [[buffer(1)]]) {
        float3 canvas = quad.outputToCanvas * float3(in.position.xy, 1);
        float v = saturate((canvas.y / canvas.z) / quad.canvasHeight);
        float4 color = mix(look.top, look.bottom, v);
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
