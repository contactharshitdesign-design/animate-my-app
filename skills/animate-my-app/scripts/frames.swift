// Extract frames from a recording as 402-pt-wide PNGs named f###_<seconds>.png
//   swiftc -O -o frames frames.swift
//   frames <video> <outdir> <start s> <end s> <step s> [full]  (0.0166667 = every 60 fps frame)
//   full: native resolution. Use it to judge flicker/shimmer: the 402-wide default aliases fine detail
//   (halftone dots) into a shimmer that isn't in the app.
import AVFoundation
import AppKit

let a = CommandLine.arguments
guard a.count == 6 || a.count == 7 else { print("usage: frames <video> <outdir> <start> <end> <step> [full]"); exit(1) }
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let g = AVAssetImageGenerator(asset: asset)
g.requestedTimeToleranceBefore = .zero
g.requestedTimeToleranceAfter = .zero
if a.count < 7 { g.maximumSize = CGSize(width: 402, height: 874) }
let start = Double(a[3])!, end = min(Double(a[4])!, asset.duration.seconds), step = Double(a[5])!
var i = 0, t = start
while t <= end {
    if let img = try? g.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 6000), actualTime: nil) {
        let rep = NSBitmapImageRep(cgImage: img)
        try? rep.representation(using: .png, properties: [:])!
            .write(to: URL(fileURLWithPath: a[2] + String(format: "/f%03d_%.3f.png", i, t)))
    }
    i += 1
    t = start + Double(i) * step
}
print("frames:", i, "duration:", asset.duration.seconds)
