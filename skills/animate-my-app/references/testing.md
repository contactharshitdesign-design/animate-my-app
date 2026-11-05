# Testing — measure, don't eyeball

Scripts are in `../scripts/` (compile Swift ones with `swiftc -O -o <bin> <file>`; keep binaries in a scratch
folder, and keep project-specific test tools inside the project so they survive between sessions).

## Record + frames
```bash
xcrun simctl status_bar <UDID> override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl io <UDID> recordVideo --codec h264 --force run.mov &   # background; stop with kill -INT
xcrun simctl launch <UDID> <bundle>        # or: xcrun simctl spawn <UDID> notifyutil -p com.animatemyapp.replay
frames run.mov outdir 0 8 0.0166667        # scripts/frames.swift: 402-pt PNGs at 60 fps
```
Simulator recordings are variable-frame-rate (a frame per screen change). `scripts/hitch.swift <mov> <from> <to>`
lists gaps > 26 ms — but the encoder itself adds load, so confirm with the in-app probe below.
If ffmpeg isn't installed, the AVFoundation scripts (`frames.swift`, `side_by_side.swift`, `frame_video.swift`)
cover extraction and compositing.

## In-app frame-time probe (temporary; remove before delivering)
In `frame(now)`: push `[t, now - last]` and the update+render CPU time; when the timeline ends, post
`'perf ' + JSON.stringify({hist, n, slow, worst})`. In the bridge: `if event.hasPrefix("perf ") { NSLog("APP-PERF %@", event); return }`.
Read: `xcrun simctl spawn <UDID> log show --last 9s --style compact --predicate 'eventMessage CONTAINS "APP-PERF"'`.
Buckets `<14 / 14-18 / 19-25 / 26-39 / 40+` ms. Target on replay: **0 frames > 25 ms**.
Typical cause of stalls before the preload fix: texture decode/upload mid-animation (50–185 ms frames).
- Log each slow frame with its scene time and the scene's own JS time for the previous frame
  (`index@t:<ms> (js N)`): small JS time on a slow frame means the cost is on the SwiftUI/main-thread side.
- A slow frame at progress 0 is tap → first-frame latency, not a visible hitch in motion.

## Automated motion checks (per build)
Write a small Python (PIL + numpy) checker over the extracted frames. For a logo intro, measure from colour
masks: squeeze start/depth, frames near the bottom (≤ 2), stretch start vs liftoff (same frame ± 1), peak
stretch (+≥ 25 %, 33–200 ms into the climb), overshoot (< 25 pt, stays below the Dynamic Island), arrival before
the next phase, and the order of every element's entrance. Restrict colour masks to regions (yellow letters look
like yellow stars). Print PASS/FAIL lines + a labelled contact sheet and actually look at it.

## Clipping check
On the final frame and a few mid frames: for each animated element's mask, test for long straight runs on
its bounding edges; look at a 2× crop of every edge. Also check source textures for opaque pixels on their
borders (`a[0], a[-1], a[:,0], a[:,-1]`) — short runs are a round shape's extreme, long runs are cuts.

## UI fidelity
Measure the built button against the Figma export at 3×: size in pt, corner radius, colour (mean ΔE),
inner glow profiles. A good match is within ~1/255 mean difference.

## Taps and interaction
- Use the simulator control tool (`tap`, `swipe`, `touch_path`; headless) — never post synthetic clicks to the
  Mac unless the target window is verified frontmost (a stray shortcut can hit another app).
- The control tool's `screenshot` can return the frame from *before* the last tap. For verification, capture
  with `xcrun simctl io <UDID> screenshot` after a ~1.2 s settle, and downscale with `sips -Z 1000`.
- A tap during scroll deceleration only stops the scroll; let scrolls settle before tapping.
- After `simctl launch`, iOS shows a "◀ OtherApp" back-to-app link in the status bar. A tap near the top-left
  (where a nav back button sits, ~y 84 pt) can hit it and switch apps. Go back with an edge swipe from x ≈ 2.
- Two simulators let a long XCUITest run on one while you drive the app on the other.

## Frame-by-frame proof for cut-out art animations
- Build an OFFLINE renderer that replays the app's pose function with the same transforms (scale/rotate about the
  same pivots, the same clips) on the parts at art resolution, and assert per frame: no holes in the container,
  static surfaces unchanged, outlines present where they must be, nothing uncovered by shakes, first/last frame =
  the art. Then contact sheets at native resolution of every phase. Then the same poses in the app (`?snapAt=t`),
  because resampling seams (background hairlines between abutting parts) only appear there — fix by underlapping
  the lower part 3 px under the upper one.
- In the offline renderer, check "background showing through anywhere" (fill holes of the composite), not only
  inside one part: it catches holes from spring overshoot that a per-part check misses.
- Before building parts for a motion, simulate the motion on the part masks and count what it uncovers (and what
  hidden content it would need); choose the motion with the least invented content.
- Bright pixels along EVERY outline in an app-vs-original diff (also inside one part) = resampling, not seams;
  a seam is a line only where two parts meet. Check which before "fixing" it.
- People read single frames: one torn edge in one frame reads as "it's broken". Don't hand over before both passes.

## Flicker test on a recording
Extract at FULL resolution (`frames.swift … full`; the 402-wide default aliases halftones into fake shimmer),
drop the recorder's repeated frames, and count pixels whose lightness jumps > 8 one frame and back the next —
only on floor pixels > 8 px from any object (moving outlines aren't flicker). A clean result is a handful of
pixels in one frame out of ~300k, 0 in all others.

## Recreating a reference video "same to same"
- Map the reference's phone screen to design points first: find the screen edges (glow / home indicator) →
  px per pt + origin. If the video zooms (presentation camera), measure a second mapping for that part.
- Compare at matching times: pairs of frozen frames (`?t=`) early on, then a real recording rendered side by side
  with `scripts/side_by_side.swift <ref> <ours> <offset> <secs> <out>`; sync on a distinctive first event (a glint,
  the first element appearing on a dark screen). Wrap record + sync + render in a small project script.
- Read motion off the reference at 30 fps with a 100 pt grid drawn on the crops; guessed paths are often wrong
  (an object that somersaults in place is easy to mistake for one flying in from a corner).
- When an object looks wrong, isolate before theorising: add look-dev flags that hide a layer (`?nobins`) or force
  a known value (`?bincover=7`) and shoot the same frozen frame both ways. Also confirm the installed build is the
  new one (grep a new string in the bundled JS) — an "impossible" frame can be a stale install.

## Real-iPhone measurement
- Low Power Mode caps WKWebView `requestAnimationFrame` at 30 fps: every frame at 33 ms from frame 0, even on
  untouched screens. Log `ProcessInfo.isLowPowerModeEnabled` + `thermalState` at launch next to the perf lines and
  read it before chasing a regression. 60 fps headroom can only be measured with Low Power Mode off.
- A scene that starts at 17 ms and drifts to 22+ ms after ~20 s is thermally borderline: cut cost until it holds
  17 ms with headroom.
- Bisect a repeatable slow frame by its scene time: if it lands at the same t every run, list what fires then (cues,
  sounds, first-time draws), change one thing per device run, and keep the run that proves the fix.
- Frame-probe numbers depend on content: compare runs only on the same data.

## Installing on a real iPhone
The scaffold sets `CODE_SIGNING_ALLOWED = NO` (Simulator only), so a device build comes out unsigned and install
fails with "integrity could not be verified / No code signature found". Build with your own team ID:
```bash
xcodebuild -configuration Release -destination id=<DEVICE_UDID> DEVELOPMENT_TEAM=<YOUR_TEAM_ID> \
  CODE_SIGN_STYLE=Automatic CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES \
  CODE_SIGN_IDENTITY="Apple Development" -allowProvisioningUpdates build
xcrun devicectl list devices                                     # find the phone
xcrun devicectl device install app --device <DEVICE_UDID> <App.app>
xcrun devicectl device process launch --device <DEVICE_UDID> <bundle id>
```
- If `-destination id=<phone>` says "Unable to find a destination" but devicectl lists the phone as available,
  build with `-destination 'generic/platform=iOS'` and install with `devicectl device install app`.
- A locked phone shows "connected" rather than "available (paired)" and refuses launches ("device was not, or could
  not be, unlocked"), though the install still lands. `devicectl` launch can also fail silently
  (FBSOpenApplicationErrorDomain 7): check for "Launched" before trusting a copied-back log (it may be the
  previous run's). Ask for an unlock rather than retrying blindly.

## Testing on the iPhone without touching it
- A `?auto` self-test (presses buttons on a schedule, logs states + frame times twice a second); the bridge writes
  `perf:` lines to `Documents/scene.log`; launch with
  `xcrun devicectl device process launch -e '{"SCENE_QUERY":"auto"}' …` and read back with
  `devicectl device copy from --domain-type appDataContainer --source Documents/scene.log`.
  A duplicate key in the `-e` JSON keeps the first value.
- Self-test flags that switch screens must not run during the boot's muted warm-up frames (see gotchas), and test the
  normal launch path on the device too — a self-test that skips the splash never exercises it.
- Device tests must never touch real data: give the app a sandbox launch flag (its own temp store + defaults suite,
  iCloud and notification prompts off). Gate any debug persistence on that flag.
- `xctrace record --device … --launch -- <bundle id>` profiles a device run; it times out while the phone is locked.

## XCUITest for flows
- Add a `com.apple.product-type.bundle.ui-testing` target (TEST_TARGET_NAME = app, TestTargetID in
  TargetAttributes, a TestAction in the shared scheme) to the hand-written pbxproj. Run
  `xcodebuild -scheme <App>UITests -parallel-testing-enabled NO -collect-test-diagnostics never -resultBundlePath … test`,
  then `xcresulttool export attachments`. Without `-parallel-testing-enabled NO` xcodebuild clones the simulator and
  shuts the original down; without `-collect-test-diagnostics never` a failure hangs ~10 minutes in `simctl diagnose`.
- Record the screen meanwhile (`simctl io recordVideo`), find motion by diffing 0.25 s frames, then extract 50 ms
  frames around it for the contact sheet.
- A small script that runs one test, exports attachments and lists the screenshots turns each fix→test loop into
  ~1 minute; make contact sheets of the shots and look at every one — a passing test can still show a broken UI.
- Query by `accessibilityIdentifier`, never by label text or index, and pick the first `isHittable` match (the first
  match can sit under the nav bar). A text view's `value` is its text.
- "Neither element nor any descendant has keyboard focus" after a coordinate tap = the element was off-screen:
  scroll it into view first.
- XCUITest waits for idle between its own taps, so drive rapid toggles from the app (a demo mode) and screenshot
  in a loop from the test; require "saw it open" or the test can pass without testing anything.
- `-key NO` launch arguments pin a UserDefaults/@AppStorage key for the whole run (the argument domain wins over
  writes). Set test defaults in code instead.
- Scripted stand-ins for system pickers: a DEBUG env hook that feeds the same code path the picker would (simulator
  apps can read host paths); test the picker itself only to the point it opens.
- On a real iPhone with the display asleep, XCUITest/devicectl screenshots return the same stale frame.
- Driving another installed app: `XCUIApplication(bundleIdentifier:)` → `.activate()`; find bundle ids with
  `xcrun devicectl device info apps --device <UDID> --include-all-apps` (the default list shows only Xcode-installed
  apps). Close any sheet it reopens on first, and never leave one open at the end.

## macOS: synthesizing trackpad input
- Two-finger swipes: `CGEvent(scrollWheelEvent2Source:units:.pixel, wheelCount: 2, wheel1: dy, wheel2: dx)` with
  `.scrollWheelEventIsContinuous = 1` and `.scrollWheelEventScrollPhase` (128 mayBegin, 1 began, 2 changed, 4 ended).
  Synthetic events report `isDirectionInvertedFromDevice == false`, so check both directions.
- Scroll and click events reach only the frontmost app's window; `postToPid` to a background window is ignored.
  Bring the test process forward only briefly, and only when on-screen testing was asked for.
- Typed CGEvents need `flags = []` explicitly: after posting ⌘-shortcuts the session keeps ⌘.
- The Look Up gesture (three-finger tap) cannot be synthesized; test the shared path another way and say so.
- `screencapture -l <windowID>` captures a window even when it's behind other apps; `-R` captures what's on top.
- SimulatorKit's display view ignores synthetic mouse events (both `NSApp.postEvent` and CGEvents at the HID tap):
  drive simulator touches with `simctl`-level tools instead.
