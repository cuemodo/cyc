import CycCore
import MetalKit

/// Draws the projector image with Metal, the Mac's GPU interface.
///
/// For now the whole image is one color: the GPU "clears" the screen to it and
/// that is all. The view is paused, so it draws only when `color` changes
/// (`needsDisplay`), not 60 times a second. An unchanging look then costs
/// next to nothing while QLab runs on the same Mac.
final class Renderer: NSObject, MTKViewDelegate {
    let view: MTKView
    private let commandQueue: MTLCommandQueue

    /// Fails (returns nil) only if the Mac has no Metal GPU.
    init?(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue() else { return nil }
        commandQueue = queue
        view = MTKView(frame: frame, device: device)
        super.init()
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        // Treat our 0...1 numbers as standard sRGB, like most video content.
        view.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.delegate = self
    }

    var color: RGB = .black {
        didSet {
            guard color != oldValue else { return }
            view.clearColor = MTLClearColor(red: color.red, green: color.green, blue: color.blue, alpha: 1)
            view.needsDisplay = true
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let pass = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commands = commandQueue.makeCommandBuffer(),
              let encoder = commands.makeRenderCommandEncoder(descriptor: pass) else { return }
        // The pass clears to `clearColor`; there is nothing else to draw yet.
        encoder.endEncoding()
        commands.present(drawable)
        commands.commit()
    }
}
