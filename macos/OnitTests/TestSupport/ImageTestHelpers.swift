//
//  ImageTestHelpers.swift
//  Onit
//
//  Created by Timothy Lenardo on 10/1/25.
//

import Foundation
import AppKit

enum ImageTestHelpers {
    
    /// Save an NSBitmapImageRep as PNG to the specified URL.
    static func savePNG(bitmapRep: NSBitmapImageRep, to url: URL) throws {
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImageTestHelpers", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data from NSBitmapImageRep"])
        }
        try pngData.write(to: url)
    }
    
    /// Save a CGImage as PNG to the specified URL.
    static func savePNG(cgImage: CGImage, to url: URL) throws {
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        try savePNG(bitmapRep: bitmapRep, to: url)
    }
    
    /// Draw an NSImage into a bitmap rep and save as PNG.
    /// Creates a bitmap context, draws the image, and saves to the specified URL.
    static func drawAndSavePNG(nsImage: NSImage, size: NSSize, to url: URL, draw: (NSGraphicsContext) -> Void = { _ in }) throws {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )
        
        guard let rep = rep else {
            throw NSError(domain: "ImageTestHelpers", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create NSBitmapImageRep"])
        }
        
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            throw NSError(domain: "ImageTestHelpers", code: 3,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create NSGraphicsContext"])
        }
        
        NSGraphicsContext.current = context
        nsImage.draw(at: .zero, from: NSRect(origin: .zero, size: size), 
                    operation: .sourceOver, fraction: 1.0)
        draw(context)
        NSGraphicsContext.restoreGraphicsState()
        
        try savePNG(bitmapRep: rep, to: url)
    }
}

