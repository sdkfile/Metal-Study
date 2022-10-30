//
//  Renderer.swift
//  Pipeline
//
//  Created by Seonggu Kim on 2022/10/29.
//

import MetalKit

class Renderer: NSObject{
    init(metalView: MTKView){
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue() else {
            fatalError("GPU not available")
        }
        Renderer.device = device
        Renderer.commandQueue = commandQueue
        metalView.device = device
        // create the mesh
        let allocator = MTKMeshBufferAllocator(device: device)
//        let size: Float = 0.8
        guard let assetURL = Bundle.main.url(
            forResource: "train",
            withExtension: "usd") else {
            fatalError()
        }
        // 1
        let vertexDescriptor = MTLVertexDescriptor()
        // 2
        vertexDescriptor.attributes[0].format = .float3
        // 3
        vertexDescriptor.attributes[0].offset = 0
        // 4
        vertexDescriptor.attributes[0].bufferIndex = 0

        // 1
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        // 2
        let meshDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        // 3
        (meshDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        let asset = MDLAsset(
            url: assetURL,
            vertexDescriptor: meshDescriptor,
            bufferAllocator: allocator)
        let mdlMesh = asset.childObjects(of: MDLMesh.self).first as! MDLMesh
//        let mdlMesh = MDLMesh(boxWithExtent: [size, size, size], segments: [1, 1, 1], inwardNormals: false, geometryType: .triangles, allocator: allocator)
        do {
            mesh = try MTKMesh(mesh: mdlMesh, device: device)
        } catch let error {
            print(error.localizedDescription)
        }
        vertexBuffer = mesh.vertexBuffers[0].buffer
        // create the shader function library
        let library = device.makeDefaultLibrary()
        Renderer.library = library
        let vertexFunction = library?.makeFunction(name: "vertex_main")
        let fragmentFunction = library?.makeFunction(name: "fragment_main")
        // create the pipeline state object
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalView.colorPixelFormat
        pipelineDescriptor.vertexDescriptor = MTKMetalVertexDescriptorFromModelIO(mdlMesh.vertexDescriptor)
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch let error {
            fatalError(error.localizedDescription)
        }
        super.init()
        metalView.clearColor = MTLClearColor(
            red: 1.0,
            green: 1.0,
            blue: 0.8,
            alpha: 1.0)
        metalView.delegate = self
    }
    static var device: MTLDevice!
    static var commandQueue: MTLCommandQueue!
    static var library: MTLLibrary!
    var mesh: MTKMesh!
    var vertexBuffer: MTLBuffer!
    var pipelineState: MTLRenderPipelineState!
}

extension Renderer : MTKViewDelegate{
    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize){
            
        }
    func draw(in view: MTKView){
        guard
            let commandBuffer = Renderer.commandQueue.makeCommandBuffer(),
            let descriptor = view.currentRenderPassDescriptor,
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        for submesh in mesh.submeshes {
            renderEncoder.drawIndexedPrimitives(
                type: .triangle,
                indexCount: submesh.indexCount,
                indexType: submesh.indexType,
                indexBuffer: submesh.indexBuffer.buffer,
                indexBufferOffset: submesh.indexBuffer.offset)
        }
        
        // 1
        renderEncoder.endEncoding()
        // 2
        guard let drawable = view.currentDrawable else {
            return
        }
        commandBuffer.present(drawable)
        // 3
        commandBuffer.commit()
    }
}
