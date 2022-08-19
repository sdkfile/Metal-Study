import PlaygroundSupport
import MetalKit


guard let device = MTLCreateSystemDefaultDevice() else {
 fatalError("GPU is not supported")
}

let frame = CGRect(x: 0, y: 0, width: 600, height: 600)
let view = MTKView(frame: frame, device: device)
view.clearColor =
  MTLClearColor(red: 1, green: 1, blue: 0.8, alpha: 1)
view.isPaused = true
view.enableSetNeedsDisplay = false

let allocator = MTKMeshBufferAllocator(device: device)
let mdlMesh = MDLMesh(
    coneWithExtent: [1,1,1],
    segments: [10,10],
    inwardNormals: false,
    cap: true,
    geometryType: .triangles,
    allocator: allocator
)
// begin export code
// 1
let asset = MDLAsset()
asset.add(mdlMesh)
// 2
let fileExtension = "obj"
guard MDLAsset.canExportFileExtension(fileExtension) else{
    fatalError("Can't export a .\(fileExtension) format")
}
// 3
do {
    let url = playgroundSharedDataDirectory.appendingPathComponent("primitive.\(fileExtension)")
    try asset.export(to: url)
} catch {
    fatalError("Error \(error.localizedDescription)")
}
// end export code
let mesh = try MTKMesh(mesh: mdlMesh, device: device)

guard let commandQueue = device.makeCommandQueue() else {
  fatalError("Could not create a command queue")
}

let shader = """
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
  float4 position [[attribute(0)]];
};

vertex float4
  vertex_main(const VertexIn vertex_in [[stage_in]]) {
  return vertex_in.position;
}

fragment float4 fragment_main() {
  return float4(1, 0, 0, 1);
}
"""

let library =
  try device.makeLibrary(source: shader, options: nil)
let vertexFunction = library.makeFunction(name: "vertex_main")
let fragmentFunction =
  library.makeFunction(name: "fragment_main")

let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
pipelineDescriptor.vertexFunction = vertexFunction
pipelineDescriptor.fragmentFunction = fragmentFunction

pipelineDescriptor.vertexDescriptor =
    MTKMetalVertexDescriptorFromModelIO(mesh.vertexDescriptor)

let pipelineState =
  try device.makeRenderPipelineState(
    descriptor: pipelineDescriptor)

guard let commandBuffer = commandQueue.makeCommandBuffer(),
  let renderPassDescriptor = view.currentRenderPassDescriptor,
  let renderEncoder =
    commandBuffer.makeRenderCommandEncoder(
    descriptor:  renderPassDescriptor)
else { fatalError() }

renderEncoder.setRenderPipelineState(pipelineState)

renderEncoder.setVertexBuffer(
  mesh.vertexBuffers[0].buffer,
  offset: 0,
  index: 0)

guard let submesh = mesh.submeshes.first else {
 fatalError()
}
renderEncoder.setTriangleFillMode(.lines)
renderEncoder.drawIndexedPrimitives(
  type: .triangle,
  indexCount: submesh.indexCount,
  indexType: submesh.indexType,
  indexBuffer: submesh.indexBuffer.buffer,
  indexBufferOffset: 0)

renderEncoder.endEncoding()
guard let drawable = view.currentDrawable else { fatalError() }
commandBuffer.present(drawable)
commandBuffer.commit()

PlaygroundPage.current.liveView = view
