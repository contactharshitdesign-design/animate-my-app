// Side-by-side comparison video: reference on the left, our recording on the right, both scaled to the same
// height, synced by an offset (seconds into OURS that matches reference t = 0).
//   swift side_by_side.swift <reference.mp4> <ours.mov> <oursOffset> <seconds> <out.mp4> [fps]
import AVFoundation
import CoreImage
import AppKit

let a = CommandLine.arguments
guard a.count >= 6 else { print("usage: side_by_side <ref> <ours> <oursOffset> <seconds> <out.mp4> [fps]"); exit(1) }
let refURL = URL(fileURLWithPath: a[1]), oursURL = URL(fileURLWithPath: a[2])
let offset = Double(a[3])!, seconds = Double(a[4])!, outURL = URL(fileURLWithPath: a[5])
let fps = a.count > 6 ? Double(a[6])! : 30

func generator(_ url: URL) -> AVAssetImageGenerator {
    let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
    g.appliesPreferredTrackTransform = true
    g.requestedTimeToleranceBefore = CMTime(value: 1, timescale: 600)
    g.requestedTimeToleranceAfter = CMTime(value: 1, timescale: 600)
    return g
}
let gRef = generator(refURL), gOurs = generator(oursURL)
func frame(_ g: AVAssetImageGenerator, _ t: Double) -> CGImage? {
    try? g.copyCGImage(at: CMTime(seconds: max(0, t), preferredTimescale: 600), actualTime: nil)
}
guard let r0 = frame(gRef, 0), let o0 = frame(gOurs, offset) else { print("cannot read frames"); exit(1) }
let H = r0.height, refW = r0.width
let oursW = Int(Double(o0.width) * Double(H) / Double(o0.height))
let gap = 40, label = 70
var W = refW + gap + oursW; if W % 2 == 1 { W += 1 }
let HH = H + label

try? FileManager.default.removeItem(at: outURL)
let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: HH,
                               AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 16_000_000]])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: HH])
writer.add(input); writer.startWriting(); writer.startSession(atSourceTime: .zero)

let n = Int(seconds * fps)
for i in 0..<n {
    let t = Double(i) / fps
    var pb: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
    guard let buf = pb else { continue }
    CVPixelBufferLockBaseAddress(buf, [])
    let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: HH, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.setFillColor(CGColor(gray: 0.12, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: HH))
    if let r = frame(gRef, t) { ctx.draw(r, in: CGRect(x: 0, y: 0, width: refW, height: H)) }
    if let o = frame(gOurs, t + offset) { ctx.draw(o, in: CGRect(x: refW + gap, y: 0, width: oursW, height: H)) }
    let g = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = g
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 30, weight: .semibold), .foregroundColor: NSColor.white]
    ("REFERENCE" as NSString).draw(at: CGPoint(x: 24, y: H + 18), withAttributes: attrs)
    ("OURS (iPhone Simulator)" as NSString).draw(at: CGPoint(x: refW + gap + 12, y: H + 18), withAttributes: attrs)
    (String(format: "t = %.2f s", t) as NSString).draw(at: CGPoint(x: W - 190, y: H + 18), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    CVPixelBufferUnlockBaseAddress(buf, [])
    while !input.isReadyForMoreMediaData { usleep(2000) }
    adaptor.append(buf, withPresentationTime: CMTime(seconds: t, preferredTimescale: 600))
}
input.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("wrote \(outURL.path) \(W)x\(HH) \(n) frames")
