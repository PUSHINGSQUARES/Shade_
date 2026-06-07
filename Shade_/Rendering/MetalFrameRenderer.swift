import CoreVideo
import Foundation
import Metal
import MetalKit

final class MetalFrameRenderer: NSObject {
    private struct Uniforms {
        var intensity: Float
        var blueReduction: Float
        var dim: Float
        var contrastProtect: UInt32
    }

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private var textureCache: CVMetalTextureCache?

    init(device: MTLDevice) throws {
        self.device = device
        guard let commandQueue = device.makeCommandQueue() else {
            throw RendererError.commandQueueUnavailable
        }
        self.commandQueue = commandQueue

        let library = try device.makeDefaultLibrary(bundle: .main)
        guard let function = library.makeFunction(name: "readingComfortKernel") else {
            throw RendererError.shaderUnavailable
        }
        self.pipelineState = try device.makeComputePipelineState(function: function)
        super.init()
        CVMetalTextureCacheCreate(nil, nil, device, nil, &textureCache)
    }

    @MainActor
    func render(pixelBuffer: CVPixelBuffer, into view: MTKView, parameters: ReadingTransformParameters) throws {
        guard let drawable = view.currentDrawable else { return }
        guard let inputTexture = makeTexture(from: pixelBuffer) else {
            throw RendererError.textureCreationFailed
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw RendererError.commandBufferUnavailable
        }

        let clampedParameters = parameters.clamped
        var uniforms = Uniforms(
            intensity: clampedParameters.intensity,
            blueReduction: clampedParameters.blueReduction,
            dim: clampedParameters.dim,
            contrastProtect: clampedParameters.contrastProtect ? 1 : 0
        )

        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(drawable.texture, index: 1)
        encoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)

        let width = pipelineState.threadExecutionWidth
        let height = max(1, pipelineState.maxTotalThreadsPerThreadgroup / width)
        let threadsPerGroup = MTLSize(width: width, height: height, depth: 1)
        let threads = MTLSize(width: drawable.texture.width, height: drawable.texture.height, depth: 1)
        encoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func makeTexture(from pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )
        guard status == kCVReturnSuccess, let cvTexture else { return nil }
        return CVMetalTextureGetTexture(cvTexture)
    }
}

enum RendererError: Error {
    case commandQueueUnavailable
    case shaderUnavailable
    case commandBufferUnavailable
    case textureCreationFailed
}
