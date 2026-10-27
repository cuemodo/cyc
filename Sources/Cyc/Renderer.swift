import CycCore
import MetalKit

/// Draws the projector image with Metal, the Mac's GPU interface.
///
/// The image is the fixture's look: a solid color or a top-to-bottom gradient,
/// computed per pixel by the shader in `Shaders.swift`. The view is paused, so
/// it draws only when `look` changes (`needsDisplay`), not 60 times a second.
/// An unchanging look then costs next to nothing while QLab runs.
final class Renderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let commandQueue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState

    /// The look as the shader receives it. Must match `Look` in Shaders.swift.
    private struct LookUniform {
        var top: SIMD4<Float>
        var bottom: SIMD4<Float>
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
        view.delegate = self
    }

    var look: FixtureLook = .black {
        didSet {
            guard look != oldValue else { return }
            view.needsDisplay = true
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = commandQueue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        var uniform = LookUniform(top: Self.vector(look.top), bottom: Self.vector(look.bottom))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniform, length: MemoryLayout<LookUniform>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }

    private static func makePipeline(device: MTLDevice, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let library = try device.makeLibrary(source: Shaders.source, options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullScreen")
        descriptor.fragmentFunction = library.makeFunction(name: "gradient")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func vector(_ color: RGB) -> SIMD4<Float> {
        SIMD4(Float(color.red), Float(color.green), Float(color.blue), 1)
    }
}
