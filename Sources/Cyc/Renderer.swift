import CycCore
import MetalKit

/// Draws the projector image with Metal, the Mac's GPU interface.
///
/// The image is the fixture's look (a solid color or a top-to-bottom gradient)
/// painted on the canvas, then drawn through the mapping's quads; everything
/// outside the quads stays black. The shader in `Shaders.swift` computes each
/// pixel. The view is paused, so it draws only when `look` or `mapping` changes
/// (`needsDisplay`), not 60 times a second. An unchanging look then costs next
/// to nothing while QLab runs.
final class Renderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    /// The look as the shader receives it. Must match `Look` in Shaders.swift.
    private struct LookUniform {
        var top: SIMD4<Float>
        var bottom: SIMD4<Float>
    }

    /// One quad as the shaders receive it. Must match `QuadInfo` in Shaders.swift.
    private struct QuadUniform {
        var outputToCanvas: simd_float3x3
        var outputSize: SIMD2<Float>
        var canvasHeight: Float
        var grid: Float
    }

    /// Fails (returns nil) if the Mac has no Metal GPU or the shader does not compile.
    init?(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        let view = MTKView(frame: frame, device: device)
        do {
            pipeline = try Renderer.makePipeline(device: device, pixelFormat: view.colorPixelFormat)
        } catch {
            print("Could not build the output shader: \(error)")
            return nil
        }
        self.view = view
        commandQueue = queue
        super.init()
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        // Treat our 0...1 numbers as standard sRGB, like most video content.
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)  // outside the quads
        view.delegate = self
    }

    var look: FixtureLook = .black {
        didSet {
            guard look != oldValue else { return }
            view.needsDisplay = true
        }
    }

    var mapping = Mapping() {
        didSet {
            guard mapping != oldValue else { return }
            view.needsDisplay = true
        }
    }

    /// Shows a test grid in the quads instead of the look, to line up the mapping.
    var showsGrid = false {
        didSet {
            guard showsGrid != oldValue else { return }
            view.needsDisplay = true
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = commandQueue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        var lookUniform = LookUniform(top: Self.vector(look.top), bottom: Self.vector(look.bottom))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&lookUniform, length: MemoryLayout<LookUniform>.stride, index: 0)

        let size = view.drawableSize  // real pixels, e.g. 3840 x 1200
        let (quads, canvasHeight) = mapping.drawableQuads(outputWidth: size.width, outputHeight: size.height)
        for quad in quads {
            // Two triangles per quad: top-left, top-right, bottom-right, then
            // top-left, bottom-right, bottom-left.
            let d = quad.destination
            let corners = [d.topLeft, d.topRight, d.bottomRight, d.topLeft, d.bottomRight, d.bottomLeft]
                .map { SIMD2<Float>(Float($0.x), Float($0.y)) }
            var quadUniform = QuadUniform(
                outputToCanvas: Self.floatMatrix(quad.outputToCanvas.matrix),
                outputSize: SIMD2(Float(size.width), Float(size.height)),
                canvasHeight: Float(canvasHeight),
                grid: showsGrid ? 1 : 0)
            encoder.setVertexBytes(corners, length: MemoryLayout<SIMD2<Float>>.stride * corners.count, index: 0)
            encoder.setVertexBytes(&quadUniform, length: MemoryLayout<QuadUniform>.stride, index: 1)
            encoder.setFragmentBytes(&quadUniform, length: MemoryLayout<QuadUniform>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: corners.count)
        }
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }

    private static func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let library = try device.makeLibrary(source: Shaders.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "quadVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "mappedLook")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func floatMatrix(_ matrix: simd_double3x3) -> simd_float3x3 {
        simd_float3x3(columns: (
            SIMD3<Float>(matrix.columns.0),
            SIMD3<Float>(matrix.columns.1),
            SIMD3<Float>(matrix.columns.2)))
    }

    private static func vector(_ color: RGB) -> SIMD4<Float> {
        SIMD4(Float(color.red), Float(color.green), Float(color.blue), 1)
    }
}
