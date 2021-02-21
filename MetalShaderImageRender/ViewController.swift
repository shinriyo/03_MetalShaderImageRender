//
//  ViewController.swift
//  MetalShaderImageRender
//
//  Created by shinriyo on 2021/02/19.
//  Copyright © 2021 shinriyo. All rights reserved.
//

import UIKit
import MetalKit
import ImageIO

let vertexData: [Float] = [-1, -1, 0, 1,
                            1, -1, 0, 1,
                           -1,  1, 0, 1,
                            1,  1, 0, 1]

let textureCoordinateData: [Float] = [0, 1,
                                      1, 1,
                                      0, 0,
                                      1, 0]

class ViewController: UIViewController, MTKViewDelegate {
    public var isAnimation = false
    public var isInfinite = false
    public var isFps = false
    public var fps = 34
    
    private let device = MTLCreateSystemDefaultDevice()!
    private var commandQueue: MTLCommandQueue!
    private var texture: MTLTexture!
    private var textures: [MTLTexture]!
    private var delayTimes: [Double]!
    private var imageCount = 0
    private var playCount = 0
    private var vertexBuffer: MTLBuffer!
    private var texCoordBuffer: MTLBuffer!
    private var renderPipeline: MTLRenderPipelineState!
    private let renderPassDescriptor = MTLRenderPassDescriptor()

    @IBOutlet private weak var mtkView: MTKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mtkView.backgroundColor = .clear
        // setup Metal
        setupMetal()

        // load image as texture
        loadTexture()

        // make buffers
        makeBuffers()
        
        // make pipeline
        makePipeline(pixelFormat: self.texture.pixelFormat)
        
        // if true it need next
        // mtkView.enableSetNeedsDisplay = true

        // delegate draw, and draw(in:) called
        mtkView.setNeedsDisplay()
    }

    private func setupMetal() {
        // MTLCommandQueueを初期化
        commandQueue = device.makeCommandQueue()
        
        // setup MTKView
        mtkView.device = device
        mtkView.delegate = self
    }

    private func makeBuffers() {
        var size: Int
        size = vertexData.count * MemoryLayout<Float>.size
        vertexBuffer = device.makeBuffer(bytes: vertexData, length: size, options: [])
        
        size = textureCoordinateData.count * MemoryLayout<Float>.size
        texCoordBuffer = device.makeBuffer(bytes: textureCoordinateData, length: size, options: [])
    }
    
    private func makePipeline(pixelFormat: MTLPixelFormat) {
        guard let library = device.makeDefaultLibrary() else {fatalError()}
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func loadTexture() {
        // initialize MTKTextureLoader
        let textureLoader = MTKTextureLoader(device: device)
        
        var textures: [MTLTexture] = []
        // #imageLiteral(resourceName: "Animated_PNG_example_bouncing_beach_ball.png")
        let filePath = Bundle.main.path(forResource: "Animated_PNG_example_bouncing_beach_ball", ofType: "png")!
        let fileUrl = URL(fileURLWithPath: filePath)
        guard
            let data = try? Data(contentsOf: fileUrl) as NSData,
            // CGImageSourceRef
            let imageSource = CGImageSourceCreateWithData(
                data,
                nil
            ) else { return  }
        
        // count images from APNG
        self.imageCount = CGImageSourceGetCount(imageSource)

        // DelayTimes
        var delayTimes: [Double] = []
        
        if self.isFps {
            // FPS (lower is slower)
            mtkView.preferredFramesPerSecond = self.fps
        }

        for index in 0 ..< self.imageCount
        {
            if
                // get no n image
                let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, nil),
                let texture = try? textureLoader.newTexture(
                    // don't forget option
                    cgImage: cgImage, options: [MTKTextureLoader.Option.SRGB : (false as NSNumber)])
            {
                // add DelayTime
                let delayTime = imageSource.getDelayTime(index: index)
                delayTimes.append(delayTime)
                // add texture
                textures.append(texture)
            }
        }
        
        // add DelayTimes
        self.delayTimes = delayTimes
        // first one
        self.texture = textures.first
        // APNG splited textures
        self.textures = textures
        
        // fix pixelFormat
        mtkView.colorPixelFormat = texture.pixelFormat
    }
    
    // MARK: - MTKViewDelegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("\(self.classForCoder)/" + #function)
    }
    
    func draw(in view: MTKView) {
        // get drawable
        guard let drawable = view.currentDrawable else {return}

        // create commandBuffer
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {fatalError()}

        //
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        
        // make encoder
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {return}

        guard let renderPipeline = renderPipeline else {fatalError()}
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(texCoordBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        // complete encoding
        renderEncoder.endEncoding()

        // register drawable for draw
        commandBuffer.present(drawable)
        
        // enque
        commandBuffer.commit()
       
        commandBuffer.waitUntilCompleted()
        
        // for next
        self.texture = self.textures[self.playCount]
        let delayTime = self.delayTimes[playCount]

        if self.isInfinite {
            return
        }

        
        // increment
        self.playCount += 1

        if isFps {
            if isInfinite {
                if self.playCount >= self.imageCount {
                    self.playCount = 0
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delayTime) {
                if self.playCount >= self.imageCount {
                    // finished
                    if self.isInfinite {
                        self.playCount = 0
                    } else {
                        self.stopAnimating()
                        return
                    }
                }

                self.callDraw()
            }
        }
    }

    // call draw()
    private func callDraw() {
        mtkView.setNeedsDisplay()

//        self.beforeSetNeedsDisplayDelay = DispatchTime.now()
    }

    // stop
    func stopAnimating() {
        self.playCount = 0
        self.isAnimation = false
//        self.viewDelegate?.apngImageView(self)
    }
}

extension CGImageSource {
    func getDelayTime(index: Int) -> Double {
        let defaultTime = 0.1
        guard let props = CGImageSourceCopyPropertiesAtIndex(self, index, nil) as? [String: Any] else {
            return defaultTime
        }
        guard let prop = props["{PNG}"] as? [String: Any] ?? props["{GIF}"] as? [String: Any] else {
            return defaultTime
        }
        return prop["UnclampedDelayTime"] as? Double ?? prop["DelayTime"] as? Double ?? defaultTime
    }
}
