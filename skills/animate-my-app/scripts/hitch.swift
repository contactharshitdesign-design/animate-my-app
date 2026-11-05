// Simulator recordings are variable-frame-rate (a frame is written when the screen changes). Lists gaps
// between consecutive frames inside a window where the animation should be moving continuously.
//   swiftc -O -o hitch hitch.swift
//   hitch <video> <from s> <to s>
// The recorder itself adds load: confirm stalls with the in-app frame probe (references/testing.md).
import AVFoundation

let a = CommandLine.arguments
guard a.count == 4 else { print("usage: hitch <video> <from> <to>"); exit(1) }
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let from = Double(a[2])!, to = Double(a[3])!
let reader = try! AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: asset.tracks(withMediaType: .video)[0], outputSettings: nil)
reader.add(out)
reader.startReading()
var ts: [Double] = []
while let sb = out.copyNextSampleBuffer() {
    if CMSampleBufferGetNumSamples(sb) > 0 { ts.append(CMSampleBufferGetPresentationTimeStamp(sb).seconds) }
}
let w = ts.filter { $0 >= from && $0 <= to }
guard w.count > 1 else { print("no frames in window"); exit(1) }
var gaps: [(Double, Double)] = []
for i in 1..<w.count {
    let g = (w[i] - w[i - 1]) * 1000
    if g > 26 { gaps.append((w[i - 1], g)) }
}
print(String(format: "frames %d in %.2fs (%.1f fps); gaps > 26ms: %d", w.count, to - from, Double(w.count) / (to - from), gaps.count))
for (t, g) in gaps { print(String(format: "  at %.3fs  %.0fms", t, g)) }
