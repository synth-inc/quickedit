//
//  ImageDiffGPU.swift
//  Onit
//
//  Created by Timothy Lenardo on 9/10/25.
//

import Foundation
import Metal
import MetalKit
import CoreGraphics

final class ImageDiffGPU: @unchecked Sendable {
    static let shared = ImageDiffGPU()

    let device: MTLDevice?
    let queue: MTLCommandQueue?
    let lib: MTLLibrary?
    let diffPSO: MTLComputePipelineState?
    let ssdPSO: MTLComputePipelineState?
    let loader: MTKTextureLoader?
    let available: Bool
    let textureCache: CVMetalTextureCache?

    init() {
        guard let dev = MTLCreateSystemDefaultDevice(),
              let q = dev.makeCommandQueue(),
              let lib = try? dev.makeDefaultLibrary(bundle: .main),
              let diffFunction = lib.makeFunction(name: "diff_and_tile_count"),
              let ssdFunction = lib.makeFunction(name: "ssd_anchor_kernel"),
              let diffPSO = try? dev.makeComputePipelineState(function: diffFunction),
              let ssdPSO = try? dev.makeComputePipelineState(function: ssdFunction) else {
            device = nil
            queue = nil
            lib = nil
            diffPSO = nil
            ssdPSO = nil
            loader = nil
            available = false
            textureCache = nil
            return
        }
        self.device = dev
        self.queue = q
        self.lib = lib
        self.loader = MTKTextureLoader(device: dev)
        self.diffPSO = diffPSO
        self.ssdPSO = ssdPSO
        self.available = true
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, dev, nil, &cache)
        self.textureCache = cache
    }

    // Convert CGImages to CVPixelBuffers for GPU-efficient processing
    func makePixelBuffer(from cgImage: CGImage) throws -> CVPixelBuffer {
        let width = cgImage.width
        let height = cgImage.height
        let attrs: [CFString: Any] = [
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        var pxbuf: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pxbuf
        )
        guard status == kCVReturnSuccess, let pixelBuffer = pxbuf else {
            throw NSError(domain: "ImageDiffGPU", code: -10, userInfo: [NSLocalizedDescriptionKey: "Failed to create CVPixelBuffer"])
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw NSError(domain: "ImageDiffGPU", code: -11, userInfo: [NSLocalizedDescriptionKey: "Failed to create CGContext for CVPixelBuffer"])
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    /// Creates a Metal texture from a single CGImage.
    func makeTexture(from image: CGImage) throws -> MTLTexture {
        guard let loader = loader else { throw NSError(domain: "Metal", code: -1) }
        let opts: [MTKTextureLoader.Option: Any] = [
            .SRGB: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ]
        return try loader.newTexture(cgImage: image, options: opts)
    }

    func makeTexture(from pixelBuffer: CVPixelBuffer) throws -> MTLTexture {
        guard let cache = textureCache else { throw NSError(domain: "Metal", code: -1) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        var metalTexture: CVMetalTexture?
        let result = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            cache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &metalTexture
        )

        guard result == kCVReturnSuccess,
              let texture = metalTexture,
              let metalTexture = CVMetalTextureGetTexture(texture) else {
            throw NSError(domain: "Metal", code: -1)
        }

        return metalTexture
    }

    /// Creates a Metal texture by combining two CGImages side-by-side (horizontally).
    func makeSideBySideTexture(from left: CGImage, and right: CGImage) throws -> MTLTexture {
        guard let device = device else { throw NSError(domain: "Metal", code: -1) }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: left.width + right.width,
            height: max(left.height, right.height),
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite, .renderTarget] // or add .blit
        desc.storageMode = .private
        guard let dst = device.makeTexture(descriptor: desc) else {
            throw NSError(domain: "Metal", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create Metal texture"])
        }

        guard let queue = queue else { throw NSError(domain: "Metal", code: -1) }
        guard let cmdBuf = queue.makeCommandBuffer() else {
            throw NSError(domain: "Metal", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create command buffer"])
        }
        guard let blit = cmdBuf.makeBlitCommandEncoder() else {
            throw NSError(domain: "Metal", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create blit command encoder"])
        }
        blit.copy(
            from: try makeTexture(from: left),
            sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: left.width, height: left.height, depth: 1),
            to: dst,
            destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.copy(
            from: try makeTexture(from: right),
            sourceSlice: 0, sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: right.width, height: right.height, depth: 1),
            to: dst,
            destinationSlice: 0, destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: left.width, y: 0, z: 0)
        )
        blit.endEncoding()
        cmdBuf.commit()

        return dst
    }

    func findBestShift(
        before: CVPixelBuffer,
        after: CVPixelBuffer,
        beforeWidth: Int,
        beforeHeight: Int,
        maxShift: Int,
        anchorW: Int = 80,
        anchorH: Int = 40
    ) throws -> (Int, Int, Double) {
        guard available, let device, let queue, let ssdPSO else {
            return (0, 0, Double.greatestFiniteMagnitude)
        }
        let setupStart = CACurrentMediaTime()
        let aw = min(anchorW, beforeWidth)
        let ah = min(anchorH, beforeHeight)

        let beforeTexture = try makeTexture(from: before)
        let afterTexture = try makeTexture(from: after)
        // let sideBySideTex = try makeSideBySideTexture(from: before, and: after)

        var shifts: [SIMD2<Int32>] = []
        for r in 0...maxShift {
            if r == 0 {
                shifts.append(.init(0, 0))
                continue
            }
            for d in -r...r {
                let cand = [
                    SIMD2<Int32>(Int32(d), -Int32(r)),
                    SIMD2<Int32>(Int32(d), Int32(r)),
                    SIMD2<Int32>(-Int32(r), Int32(d)),
                    SIMD2<Int32>(Int32(r), Int32(d))
                ]
                for s in cand where (abs(s.x) == r || abs(s.y) == r) {
                    shifts.append(s)
                }
            }
        }
        guard let shiftBuf = device.makeBuffer(bytes: shifts, length: shifts.count * MemoryLayout<SIMD2<Int32>>.stride) else {
            throw NSError(domain: "Metal", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create shift buffer"])
        }
        guard let mseBuf = device.makeBuffer(length: shifts.count * MemoryLayout<Float>.stride, options: .storageModeShared) else {
            throw NSError(domain: "Metal", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create mse buffer"])
        }

        var p = SSDParams(
            width: UInt32(beforeWidth),
            height: UInt32(beforeHeight),
            anchorX: 0,
            anchorY: 0,
            anchorW: UInt32(aw),
            anchorH: UInt32(ah)
        )
        let setupEnd = CACurrentMediaTime()
        let setupTime = setupEnd - setupStart

        // Timing: Command buffer commit and wait
        let gpuStart = CACurrentMediaTime()
        guard let cb = queue.makeCommandBuffer() else {
            throw NSError(domain: "Metal", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create command buffer"])
        }
        guard let enc = cb.makeComputeCommandEncoder() else {
            throw NSError(domain: "Metal", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to create compute command encoder"])
        }
        enc.setComputePipelineState(ssdPSO)
        enc.setTexture(beforeTexture, index: 0)
        enc.setTexture(afterTexture, index: 1)
        enc.setBuffer(shiftBuf, offset: 0, index: 0)
        enc.setBuffer(mseBuf, offset: 0, index: 1)
        enc.setBytes(&p, length: MemoryLayout<SSDParams>.size, index: 2)

        let tpg = MTLSize(width: min(ssdPSO.threadExecutionWidth, shifts.count), height: 1, depth: 1)
        let tg = MTLSize(width: (shifts.count + tpg.width - 1) / tpg.width, height: 1, depth: 1)
        enc.dispatchThreadgroups(tg, threadsPerThreadgroup: tpg)
        enc.endEncoding()
        cb.commit()
        cb.waitUntilCompleted()
        let gpuEnd = CACurrentMediaTime()
        let gpuTime = gpuEnd - gpuStart

        // Timing: Post-processing
        let postStart = CACurrentMediaTime()
        let msePtr = mseBuf.contents().bindMemory(to: Float.self, capacity: shifts.count)
        var best = 0
        var bestVal = Float.infinity
        for i in 0..<shifts.count {
            let v = msePtr[i]
            if v < bestVal {
                bestVal = v
                best = i
            }
        }
        let postEnd = CACurrentMediaTime()
        let postTime = postEnd - postStart

        return (Int(shifts[best].x), Int(shifts[best].y), Double(bestVal))
    }

    func computeTileChangeMask(
        before: CVPixelBuffer,
        after: CVPixelBuffer,
        width: Int,
        height: Int,
        tileSize: Int,
        tileStrideX: Int,
        tileStrideY: Int,
        sampleStride: Int,
        threshold: UInt8,
        shiftDX: Int,
        shiftDY: Int
    ) throws -> (tilesX: Int, tilesY: Int, changedCounts: [UInt32], sampledCounts: [UInt32]) {
        guard available, let device, let queue, let diffPSO else {
            throw NSError(domain: "Metal", code: -2)
        }
        let tilesX = max(1, (width - tileSize + tileStrideX - 1) / tileStrideX + 1)
        let tilesY = max(1, (height - tileSize + tileStrideY - 1) / tileStrideY + 1)
        let count = tilesX * tilesY

        let beforeTexture = try makeTexture(from: before)
        let afterTexture = try makeTexture(from: after)

        guard let changedBuf = device.makeBuffer(length: count * MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            throw NSError(domain: "Metal", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create changed buffer"])
        }
        guard let sampledBuf = device.makeBuffer(length: count * MemoryLayout<UInt32>.size, options: .storageModeShared) else {
            throw NSError(domain: "Metal", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to create sampled buffer"])
        }
        memset(changedBuf.contents(), 0, count * MemoryLayout<UInt32>.size)
        memset(sampledBuf.contents(), 0, count * MemoryLayout<UInt32>.size)

        var p = DiffParams(
            width: UInt32(width),
            height: UInt32(height),
            tileSize: UInt32(tileSize),
            tileStrideX: UInt32(tileStrideX),
            tileStrideY: UInt32(tileStrideY),
            tilesX: UInt32(tilesX),
            tilesY: UInt32(tilesY),
            sampleStride: UInt32(sampleStride),
            threshold: UInt32(threshold),
            shiftDX: Int32(shiftDX),
            shiftDY: Int32(shiftDY)
        )

        guard let cb = queue.makeCommandBuffer() else {
            throw NSError(domain: "Metal", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to create command buffer"])
        }
        guard let enc = cb.makeComputeCommandEncoder() else {
            throw NSError(domain: "Metal", code: -6, userInfo: [NSLocalizedDescriptionKey: "Failed to create compute command encoder"])
        }
        enc.setComputePipelineState(diffPSO)
        enc.setTexture(beforeTexture, index: 0)
        enc.setTexture(afterTexture, index: 1)
        enc.setBuffer(changedBuf, offset: 0, index: 0)
        enc.setBuffer(sampledBuf, offset: 0, index: 1)
        enc.setBytes(&p, length: MemoryLayout<DiffParams>.size, index: 2)
        let tpt = MTLSize(width: 16, height: 16, depth: 1)
        let tg = MTLSize(width: (width + 15) / 16, height: (height + 15) / 16, depth: 1)
        enc.dispatchThreadgroups(tg, threadsPerThreadgroup: tpt)
        enc.endEncoding()

        cb.commit()
        cb.waitUntilCompleted()

        let changed = Array(UnsafeBufferPointer(start: changedBuf.contents().bindMemory(to: UInt32.self, capacity: count), count: count))
        let sampled = Array(UnsafeBufferPointer(start: sampledBuf.contents().bindMemory(to: UInt32.self, capacity: count), count: count))
        return (tilesX, tilesY, changed, sampled)
    }
}

private struct DiffParams {
    var width, height, tileSize, tileStrideX, tileStrideY, tilesX, tilesY, sampleStride, threshold: UInt32
    var shiftDX, shiftDY: Int32
}

private struct SSDParams {
    var width, height, anchorX, anchorY, anchorW, anchorH: UInt32
}
