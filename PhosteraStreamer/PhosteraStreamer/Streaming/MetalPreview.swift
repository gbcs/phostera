/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The Metal preview view.
*/

import CoreMedia
import Metal
import MetalKit
import AVFoundation

class PreviewMetalView: MTKView {
    
    enum Rotation: Int {
        case rotate0Degrees
        case rotate90Degrees
        case rotate180Degrees
        case rotate270Degrees
    }
    
    var mirroring = false {
        didSet {
            syncQueue.sync {
                internalMirroring = mirroring
            }
        }
    }
    
    private var internalMirroring: Bool = false
    
    var rotation: Rotation = .rotate0Degrees {
        didSet {
            syncQueue.sync {
                internalRotation = rotation
            }
        }
    }
    
    private var internalRotation: Rotation = .rotate0Degrees
    
    var pixelBuffer: CVPixelBuffer? {
        didSet {
            syncQueue.sync {
                internalPixelBuffer = pixelBuffer
            }
        }
    }
    
    private var internalPixelBuffer: CVPixelBuffer?
    
    private let syncQueue = DispatchQueue(label: "Preview View Sync Queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    
    private var textureCache: CVMetalTextureCache?
    
    private var textureWidth: Int = 0
    
    private var textureHeight: Int = 0
    
    private var textureMirroring = false
    
    private var textureRotation: Rotation = .rotate0Degrees
    
    private var sampler: MTLSamplerState!
    
    private var renderPipelineState: MTLRenderPipelineState!
    
    private var commandQueue: MTLCommandQueue?
    
    private var vertexCoordBuffer: MTLBuffer!
    
    private var textCoordBuffer: MTLBuffer!
    
    private var internalBounds: CGRect!
    
    private var textureTranform: CGAffineTransform?
    
    func texturePointForView(point: CGPoint) -> CGPoint? {
        var result: CGPoint?
        guard let transform = textureTranform else {
            return result
        }
        let transformPoint = point.applying(transform)
        
        if CGRect(origin: .zero, size: CGSize(width: textureWidth, height: textureHeight)).contains(transformPoint) {
            result = transformPoint
        } else {
            Logger.shared.error("Invalid point \(point) result point \(transformPoint)")
        }
        
        return result
    }
    
    func viewPointForTexture(point: CGPoint) -> CGPoint? {
        var result: CGPoint?
        guard let transform = textureTranform?.inverted() else {
            return result
        }
        let transformPoint = point.applying(transform)
        
        if internalBounds.contains(transformPoint) {
            result = transformPoint
        } else {
            Logger.shared.error("Invalid point \(point) result point \(transformPoint)")
        }
        
        return result
    }
    
    func flushTextureCache() {
        textureCache = nil
    }
    
    private func setupTransform(width: Int, height: Int, mirroring: Bool, rotation: Rotation) {
        var scaleX: Float = 1.0
        var scaleY: Float = 1.0
        var resizeAspect: Float = 1.0
        
        internalBounds = self.bounds
        textureWidth = width
        textureHeight = height
        textureMirroring = mirroring
        textureRotation = rotation
        
        if textureWidth > 0 && textureHeight > 0 {
            switch textureRotation {
            case .rotate0Degrees, .rotate180Degrees:
                scaleX = Float(internalBounds.width / CGFloat(textureWidth))
                scaleY = Float(internalBounds.height / CGFloat(textureHeight))
                
            case .rotate90Degrees, .rotate270Degrees:
                scaleX = Float(internalBounds.width / CGFloat(textureHeight))
                scaleY = Float(internalBounds.height / CGFloat(textureWidth))
            }
        }
        // Resize aspect ratio.
        resizeAspect = min(scaleX, scaleY)
        if scaleX < scaleY {
            scaleY = scaleX / scaleY
            scaleX = 1.0
        } else {
            scaleX = scaleY / scaleX
            scaleY = 1.0
        }
        
        if textureMirroring {
            scaleX *= -1.0
        }
        
        // Vertex coordinate takes the gravity into account.
        let vertexData: [Float] = [
            -scaleX, -scaleY, 0.0, 1.0,
            scaleX, -scaleY, 0.0, 1.0,
            -scaleX, scaleY, 0.0, 1.0,
            scaleX, scaleY, 0.0, 1.0
        ]
        vertexCoordBuffer = device!.makeBuffer(bytes: vertexData, length: vertexData.count * MemoryLayout<Float>.size, options: [])
        
        // Texture coordinate takes the rotation into account.
        var textData: [Float]
        switch textureRotation {
        case .rotate0Degrees:
            textData = [
                0.0, 1.0,
                1.0, 1.0,
                0.0, 0.0,
                1.0, 0.0
            ]
            
        case .rotate180Degrees:
            textData = [
                1.0, 0.0,
                0.0, 0.0,
                1.0, 1.0,
                0.0, 1.0
            ]
            
        case .rotate90Degrees:
            textData = [
                1.0, 1.0,
                1.0, 0.0,
                0.0, 1.0,
                0.0, 0.0
            ]
            
        case .rotate270Degrees:
            textData = [
                0.0, 0.0,
                0.0, 1.0,
                1.0, 0.0,
                1.0, 1.0
            ]
        }
        textCoordBuffer = device?.makeBuffer(bytes: textData, length: textData.count * MemoryLayout<Float>.size, options: [])
        
        // Calculate the transform from texture coordinates to view coordinates
        var transform = CGAffineTransform.identity
        if textureMirroring {
            transform = transform.concatenating(CGAffineTransform(scaleX: -1, y: 1))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(textureWidth), y: 0))
        }
        
        switch textureRotation {
        case .rotate0Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(0)))
            
        case .rotate180Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi)))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(textureWidth), y: CGFloat(textureHeight)))
            
        case .rotate90Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: CGFloat(textureHeight), y: 0))
            
        case .rotate270Degrees:
            transform = transform.concatenating(CGAffineTransform(rotationAngle: 3 * CGFloat(Double.pi) / 2))
            transform = transform.concatenating(CGAffineTransform(translationX: 0, y: CGFloat(textureWidth)))
        }
        
        transform = transform.concatenating(CGAffineTransform(scaleX: CGFloat(resizeAspect), y: CGFloat(resizeAspect)))
        let tranformRect = CGRect(origin: .zero, size: CGSize(width: textureWidth, height: textureHeight)).applying(transform)
        let xShift = (internalBounds.size.width - tranformRect.size.width) / 2
        let yShift = (internalBounds.size.height - tranformRect.size.height) / 2
        transform = transform.concatenating(CGAffineTransform(translationX: xShift, y: yShift))
        textureTranform = transform.inverted()
    }
    
    required init(coder: NSCoder) {
      
        super.init(coder: coder)
        device = MTLCreateSystemDefaultDevice()
      
        
        configureMetal()
        
        createTextureCache()
        
        colorPixelFormat = .bgra8Unorm
    }
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
    
        configureMetal()
        
        createTextureCache()
        
        colorPixelFormat = .bgra8Unorm
        
        preferredFramesPerSecond = 30
    }

    func configureMetal() {
        guard let device else {
            return
        }
        let defaultLibrary = device.makeDefaultLibrary()
        
        guard let defaultLibrary else {
            return
        }
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.vertexFunction = defaultLibrary.makeFunction(name: "vertexPassThrough")
        pipelineDescriptor.fragmentFunction = defaultLibrary.makeFunction(name: "fragmentPassThrough")
        
        // To determine how textures are sampled, create a sampler descriptor to query for a sampler state from the device.
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
        
        do {
            renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Unable to create preview Metal view pipeline state. (\(error))")
        }
        
        commandQueue = device.makeCommandQueue()
    }
    
    func createTextureCache() {
        var newTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device!, nil, &newTextureCache) == kCVReturnSuccess {
            textureCache = newTextureCache
        } else {
            assertionFailure("Unable to allocate texture cache")
        }
    }
    
    var debugMessageSkipCount = 30
    var debugMessageSkipMax = 30
    var debugMessage:String = ""
    func drawFailed(msg:String) {
        if msg != debugMessage {
            Logger.shared.info(msg)
            debugMessage = msg
        } else {
            debugMessageSkipCount += 1
            if debugMessageSkipMax < debugMessageSkipCount {
                Logger.shared.info(msg)
                debugMessageSkipCount = 0
            }
        }
    }
    
    /// - Tag: DrawMetalTexture
    override func draw(_ rect: CGRect) {
        var pixelBuffer: CVPixelBuffer?
        var mirroring = false
        var rotation: Rotation = .rotate0Degrees
        
        syncQueue.sync {
            pixelBuffer = internalPixelBuffer
            mirroring = false
            rotation = internalRotation
        }
        
        guard let drawable = currentDrawable,
            let currentRenderPassDescriptor = currentRenderPassDescriptor,
            let previewPixelBuffer = pixelBuffer else {
                drawFailed(msg: "Problem with drawable")
                return
        }
        
        // Create a Metal texture from the image buffer.
        let width = CVPixelBufferGetWidth(previewPixelBuffer)
        let height = CVPixelBufferGetHeight(previewPixelBuffer)
        
        if textureCache == nil {
            createTextureCache()
        }
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
                                                  textureCache!,
                                                  previewPixelBuffer,
                                                  nil,
                                                  .bgra8Unorm,
                                                  width,
                                                  height,
                                                  0,
                                                  &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            drawFailed(msg: "Failed to create preview texture")
            CVMetalTextureCacheFlush(textureCache!, 0)
            return
        }
        
        if texture.width != textureWidth ||
            texture.height != textureHeight ||
            self.bounds != internalBounds ||
            mirroring != textureMirroring ||
            rotation != textureRotation {
            setupTransform(width: texture.width, height: texture.height, mirroring: mirroring, rotation: rotation)
        }
        
        // Set up command buffer and encoder
        guard let commandQueue = commandQueue else {
            drawFailed(msg: "Failed to create Metal command queue")
            CVMetalTextureCacheFlush(textureCache!, 0)
            return
        }
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            drawFailed(msg: "Failed to create Metal command buffer")
            CVMetalTextureCacheFlush(textureCache!, 0)
            return
        }
        
        guard let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: currentRenderPassDescriptor) else {
            drawFailed(msg: "Failed to create Metal command encoder")
            CVMetalTextureCacheFlush(textureCache!, 0)
            return
        }
        
        commandEncoder.label = "Preview display"
        commandEncoder.setRenderPipelineState(renderPipelineState!)
        commandEncoder.setVertexBuffer(vertexCoordBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(textCoordBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentTexture(texture, index: 0)
        commandEncoder.setFragmentSamplerState(sampler, index: 0)
        commandEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        commandEncoder.endEncoding()
        
        // Draw to the screen.
        commandBuffer.present(drawable)
        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        commandBuffer.waitUntilCompleted()
    }
}

extension PreviewMetalView.Rotation {
    init?(with interfaceOrientation: UIInterfaceOrientation, videoOrientation: CGFloat, cameraPosition: AVCaptureDevice.Position) {
        /*
         Calculate the rotation between the videoOrientation and the interfaceOrientation.
         The direction of the rotation depends upon the camera position.
         */
        switch videoOrientation {
        case 0.0:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portrait:
                self = .rotate0Degrees
                
            case .portraitUpsideDown:
                self = .rotate180Degrees
                
            default: return nil
            }
        case 90.0:
            switch interfaceOrientation {
            case .landscapeRight:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .landscapeLeft:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portrait:
                self = .rotate180Degrees
                
            case .portraitUpsideDown:
                self = .rotate0Degrees
                
            default: return nil
            }
            
        case 180.0:
            switch interfaceOrientation {
            case .landscapeRight:
                self = .rotate0Degrees
                
            case .landscapeLeft:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            default: return nil
            }
            
        case 0:
            switch interfaceOrientation {
            case .landscapeLeft:
                self = .rotate0Degrees
            case .landscapeRight:
                self = .rotate180Degrees
                
            case .portrait:
                if cameraPosition == .front {
                    self = .rotate90Degrees
                } else {
                    self = .rotate270Degrees
                }
                
            case .portraitUpsideDown:
                if cameraPosition == .front {
                    self = .rotate270Degrees
                } else {
                    self = .rotate90Degrees
                }
                
            default: return nil
            }
        default:
            fatalError("Unknown orientation.")
        }
        Logger.shared.error("Orientation: \(videoOrientation)")
    }
}