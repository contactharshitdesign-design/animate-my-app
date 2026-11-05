// Puts a simulator screen recording inside a drawn iPhone 17 Pro frame on a white canvas
// and re-encodes it at a constant 60fps.
//
//   swift scripts/frame_video.swift <in.mov> <out.mp4> <trimStart s> <trimEnd s> <margin px> <canvasWidth px|0> [hevc]
//
// margin is the white space between the device (side buttons included) and every canvas edge.
// canvasWidth 0 keeps the recording at native resolution (1 source pixel = 1 output pixel).
import AVFoundation
import CoreGraphics
import CoreImage
import Foundation

let args = CommandLine.arguments
let inURL = URL(fileURLWithPath: args[1]), outURL = URL(fileURLWithPath: args[2])
let trimStart = Double(args[3])!, trimEnd = Double(args[4])!
let margin = CGFloat(Double(args[5])!), wantWidth = CGFloat(Double(args[6])!)
let useHEVC = args.count > 7 && args[7] == "hevc"
let fps: Int32 = 60

// Device geometry in source (screen) pixels, iPhone 17 Pro @3x.
let screenW: CGFloat = 1206, screenH: CGFloat = 2622
let screenRadius: CGFloat = 186          // 62pt display corner
let bezel: CGFloat = 36                  // black border around the glass
let band: CGFloat = 16                   // aluminium frame
let edge = bezel + band
let bodyW = screenW + 2 * edge, bodyH = screenH + 2 * edge
let bodyRadius = screenRadius + edge
let btnOut: CGFloat = 7                  // how far buttons stand proud of the frame

// Scale everything so the canvas has the requested width (margin stays in output pixels).
let deviceW = bodyW + 2 * btnOut
let scale: CGFloat = wantWidth > 0 ? (wantWidth - 2 * margin) / deviceW : 1
func even(_ v: CGFloat) -> Int { Int((v / 2).rounded(.up)) * 2 }
let W = even(deviceW * scale + 2 * margin), H = even(bodyH * scale + 2 * margin)
let ox = (CGFloat(W) - bodyW * scale) / 2, oy = (CGFloat(H) - bodyH * scale) / 2   // body origin (top-left)

let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: rgb, components: [CGFloat((hex >> 16) & 255) / 255, CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, a])!
}
func rr(_ r: CGRect, _ rad: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil) }

// Draws in a top-left-origin space measured in device pixels.
func deviceSpace(_ c: CGContext) {
    c.translateBy(x: 0, y: CGFloat(H)); c.scaleBy(x: 1, y: -1)
    c.translateBy(x: ox, y: oy); c.scaleBy(x: scale, y: scale)
}
let screenRect = CGRect(x: edge, y: edge, width: screenW, height: screenH)

func drawBackground(_ c: CGContext) {
    c.setFillColor(color(0xFFFFFF)); c.fill(CGRect(x: 0, y: 0, width: W, height: H))
    c.saveGState(); deviceSpace(c)
    let body = CGRect(x: 0, y: 0, width: bodyW, height: bodyH)

    // Side buttons (drawn first so the frame overlaps their inner half).
    let buttons: [(CGFloat, CGFloat, CGFloat, Bool)] = [   // y, height, depth, left side
        (372, 104, btnOut, true),     // Action button
        (600, 196, btnOut, true),     // volume up
        (842, 196, btnOut, true),     // volume down
        (690, 300, btnOut, false),    // side button
        (1440, 186, btnOut - 3, false) // Camera Control (sits nearly flush)
    ]
    for (y, h, d, left) in buttons {
        let r = CGRect(x: left ? -d : bodyW - 10, y: y, width: d + 10, height: h)
        c.addPath(rr(r, 5)); c.setFillColor(color(0x5A5A5E)); c.fillPath()
        let hl = CGRect(x: left ? -d + 1.5 : bodyW + d - 3.5, y: y + 8, width: 2, height: h - 16)
        c.addPath(rr(hl, 1)); c.setFillColor(color(0xA9A9AE, 0.7)); c.fillPath()
    }

    // Soft contact shadow + ambient shadow under the device.
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -28 * scale), blur: 60 * scale, color: color(0x000000, 0.15))   // CG shadow offsets ignore the flip: negative = down
    c.addPath(rr(body, bodyRadius)); c.setFillColor(color(0x2C2C2E)); c.fillPath()
    c.restoreGState()
    c.saveGState()
    c.setShadow(offset: CGSize(width: 0, height: -6 * scale), blur: 14 * scale, color: color(0x000000, 0.14))
    c.addPath(rr(body, bodyRadius)); c.setFillColor(color(0x2C2C2E)); c.fillPath()
    c.restoreGState()

    // Aluminium band: vertical gradient, bright rim, darker inner chamfer.
    c.saveGState()
    c.addPath(rr(body, bodyRadius)); c.clip()
    let g = CGGradient(colorsSpace: rgb, colors: [color(0x6E6E73), color(0x3A3A3C), color(0x48484A), color(0x2C2C2E)] as CFArray,
                       locations: [0, 0.25, 0.7, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: bodyW, y: bodyH), options: [])
    c.restoreGState()
    c.addPath(rr(body.insetBy(dx: 1.5, dy: 1.5), bodyRadius - 1.5)); c.setStrokeColor(color(0xC7C7CC, 0.55)); c.setLineWidth(2.5); c.strokePath()
    c.addPath(rr(body.insetBy(dx: band - 2, dy: band - 2), bodyRadius - band + 2)); c.setStrokeColor(color(0x1C1C1E)); c.setLineWidth(4); c.strokePath()

    // Black glass border.
    c.addPath(rr(body.insetBy(dx: band, dy: band), bodyRadius - band)); c.setFillColor(color(0x050505)); c.fillPath()
    c.restoreGState()
}

func drawGlass(_ c: CGContext) {
    // A faint reflection along the top-left of the glass so the screen reads as covered.
    c.saveGState(); deviceSpace(c)
    c.addPath(rr(CGRect(x: band, y: band, width: bodyW - 2 * band, height: bodyH - 2 * band), bodyRadius - band)); c.clip()
    let g = CGGradient(colorsSpace: rgb, colors: [color(0xFFFFFF, 0.05), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: bodyW * 0.45, y: bodyH * 0.3), options: [])
    c.restoreGState()
}

func makeContext(_ pb: CVPixelBuffer) -> CGContext {
    CGContext(data: CVPixelBufferGetBaseAddress(pb), width: W, height: H, bitsPerComponent: 8,
              bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: rgb,
              bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
}

// Pre-render the static device once.
let bgCtx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: rgb,
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
drawBackground(bgCtx)
let bgImage = bgCtx.makeImage()!

// Reader
let asset = AVURLAsset(url: inURL)
let track = asset.tracks(withMediaType: .video)[0]
let reader = try! AVAssetReader(asset: asset)
reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, trimStart - 0.5), preferredTimescale: 600), end: CMTime(seconds: trimEnd, preferredTimescale: 600))
let rOut = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
rOut.alwaysCopiesSampleData = false
reader.add(rOut); reader.startReading()

// Writer
try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let pixels = Double(W * H)
var compression: [String: Any] = [
    AVVideoAverageBitRateKey: Int(pixels * Double(fps) * (useHEVC ? 0.12 : 0.18)),   // generous: flat white + fine clay texture
    AVVideoExpectedSourceFrameRateKey: fps,
    AVVideoMaxKeyFrameIntervalKey: fps,
]
if !useHEVC { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel; compression[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC }
let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: useHEVC ? AVVideoCodecType.hevc : AVVideoCodecType.h264,
    AVVideoWidthKey: W, AVVideoHeightKey: H,
    AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
    AVVideoCompressionPropertiesKey: compression,
])
vIn.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: vIn, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H])
writer.add(vIn); writer.startWriting(); writer.startSession(atSourceTime: .zero)

func cgImage(_ pb: CVPixelBuffer) -> CGImage {
    CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(pb), width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb),
                        bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: rgb,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    return ctx.makeImage()!
}

// Constant frame rate: each output frame shows the newest source frame at or before its time.
var current: CGImage? = nil
var pending: CMSampleBuffer? = rOut.copyNextSampleBuffer()
let nFrames = Int(((trimEnd - trimStart) * Double(fps)).rounded())
for i in 0..<nFrames {
    let t = trimStart + Double(i) / Double(fps)
    while let sb = pending, CMSampleBufferGetPresentationTimeStamp(sb).seconds <= t + 1e-4 {
        if let pb = CMSampleBufferGetImageBuffer(sb) { current = cgImage(pb) }
        pending = rOut.copyNextSampleBuffer()
    }
    guard let src = current else { continue }
    while !vIn.isReadyForMoreMediaData { usleep(1000) }
    var pbOut: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pbOut)
    let pb = pbOut!
    CVPixelBufferLockBaseAddress(pb, [])
    let c = makeContext(pb)
    c.interpolationQuality = .high
    c.draw(bgImage, in: CGRect(x: 0, y: 0, width: W, height: H))
    c.saveGState(); deviceSpace(c)
    c.addPath(rr(screenRect, screenRadius)); c.clip()
    // Undo the flip for the image draw so it lands upright.
    c.translateBy(x: screenRect.minX, y: screenRect.maxY); c.scaleBy(x: 1, y: -1)
    c.draw(src, in: CGRect(x: 0, y: 0, width: screenW, height: screenH))
    c.restoreGState()
    drawGlass(c)
    CVPixelBufferUnlockBaseAddress(pb, [])
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(i), timescale: fps))
}
vIn.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
if writer.status != .completed { print("FAILED", writer.error as Any); exit(1) }
print("wrote \(W)x\(H) \(nFrames) frames @\(fps)fps, device at x=\(Int(ox)) y=\(Int(oy)) scale \(String(format: "%.3f", scale))")
