---
name: animate-my-app
description: >
  Turn an app design (Figma frames, screenshots, a reference video or an existing app) into a real, native,
  animated iOS app that runs in the Simulator and on iPhone: SwiftUI for layout, text and buttons, plus a
  transparent three.js/WebGL layer for hero motion (clay or chrome 3D objects, logos that assemble, shader and
  paint backgrounds, page curls, particles, physics, gesture-driven 3D). Use it for any request to animate an
  app design or screen; build or fix an onboarding, splash, intro, screen transition, logo or hero animation;
  recreate motion from a reference (Dribbble, Pinterest, a video); tune how something moves (springs, squash and
  stretch, gestures, swipes, card stacks, pull-to-refresh); or add three.js, shaders or physics to a native iOS
  app. Ships a scaffold script, motion and procedural-3D recipes, measurement scripts for frame times and
  motion, and a list of WKWebView, three.js, SwiftUI and Simulator gotchas.
license: MIT
metadata:
  author: "@oiharshit"
  version: "1.1.0"
---

# Animate My App

Take a designed app screen (usually from Figma) and ship it as a native iOS app whose hero moments move like a
Rive- or three.js-level piece: physical, staged, measured. Speed comes from **reusing this pipeline** (scaffold,
engine, test scripts, recipes), not re-deriving it for every app.

## 0. Before anything: read the craft guide

Read `references/craft.md` at the start of every build. It sets the bar for motion, interaction, accessibility,
visual polish, typography, colour and Figma-to-code fidelity, and ends with the review checklist to run before
you report. This skill is self-contained: everything it needs is in this folder.

## 1. Intake (fast), then ASK

1. Pull every frame that was linked: Figma MCP `get_screenshot` + `get_design_context` + `get_metadata`
   (+ `download_assets` for raster art, fonts, exact colours and sizes). Details and fallbacks:
   `references/research-and-tools.md`.
2. Find references when the motion idea is open: Mobbin (MCP or website), Pinterest, Dribbble, a supplied video.
   Generated assets or motion references can come from an image/video generation service if one is connected.
3. **Ask** (2–4 pointed questions) whenever the motion intent is not explicit: sequence and staging, feel (bouncy
   clay / crisp / calm), total length, what is procedural vs image, sound or none, the hand-off between screens.
   When motion is described in words, restate it as physics and confirm ("squeeze → stretch and move on the same
   frame, tallest early in the climb?"). Ask again mid-build whenever a choice changes the result. Never guess
   on intent that matters.

## 2. Build: native app + three.js layer

Scaffold in one command (working app, replay protocol, preload/warm-start engine, demo content):

```bash
scripts/new_app.sh <AppName> <parent-dir> [bundle.id]   # default bundle id: com.example.<appname>
```

Architecture, bridge and engine API: `references/stack.md`. In short:
- SwiftUI owns layout, text, buttons, haptics, safe areas. A transparent full-screen `WKWebView` runs three.js
  for hero parts, served over a custom scheme (WebGL refuses `file://` textures). Created eagerly at launch.
- **One timeline** (JS) is the source of truth; it fires cues (`headline`, `button`, …) that SwiftUI animates.
- Design canvas = the Figma frame in points (iPhone 17 Pro 402×874); ortho camera in design points.
- Pick the right tool per part: three.js for 3D/clay/shaders/procedural paint; SwiftUI springs,
  `matchedGeometryEffect`, `PhaseAnimator`/`KeyframeAnimator` for UI; Rive/Lottie only when such assets are
  supplied or the part is pure 2D vector character animation.

**Build hero parts procedurally, not from cut-up images.** Image cut-outs crack, fringe and flicker. Recipes for
clay letters (SDF + surface nets + clay shader), chrome and metal, self-painting brush backgrounds, paper, and
splitting illustrations into clean animatable pieces: `references/procedural-3d.md`. Photographed people with
swappable pieces: `references/photo-layers.md`.

## 3. Motion rules

Full formulas and constants: `references/motion-physics.md`; timing, easing, gestures and polish:
`references/craft.md`.
- Real physics: damped springs (damping ratio + response), gravity drops, squash and stretch that **preserves
  volume**, contact shadows that react to height.
- Anticipation without dwell: squeeze, then stretch **and** move on the same frame; peak stretch early in the
  travel; jelly follow-through; overshoot then a braking squash. Stretch must be clearly visible.
- **Staging is gated on arrival**: the next phase starts only after the previous element has truly landed
  (compute the arrival time, don't guess a delay).
- Entrances never from `scale(0)`; press feedback 0.97 + light haptic; always a reduced-motion path.
- Buttons and text match Figma exactly (measure size, radius, colour, inner glows) and sit per Apple HIG
  (primary button 16 pt above the bottom safe area; keep the designed spacing to the headline).

## 4. Hard rules (defaults)

- **No clipping** unless asked or the Figma frame has "Clip content" on. Pad every bounded surface (planes,
  textures, canvases, frames) so brush ends, shadows, glows and overshoot fit. Check every edge of rendered frames
  for straight cuts before delivering. If source art itself is cut, repair it.
- **No mid-animation loading:** decode + GPU-upload every texture and pre-warm every shader *before* the clock
  starts; warm frames before the first move. Measure; target 0 frames > 25 ms on replay.
- **Replay protocol:** every app listens for the Darwin notification `com.animatemyapp.replay` and replays its
  intro in place (fade to white → reset → warm → start), plus tap-to-replay outside buttons. Never relaunch to replay.
- Real native app in the Simulator (and on iPhone), never a localhost/web demo. Status bar 9:41 for anything shown.
- **Concentric corners:** outer radius = inner radius + padding for every nested rounded shape (thumbnail in a
  card, highlight in a menu, chip in a composer, outline around media). Derive radii from the innermost element
  out; break it only when truly necessary (full-bleed media clipped by its card simply inherits the card radius).
- No sound unless asked.
- **Test everything** yourself before reporting (section 5). Report measured numbers, not impressions.

## 5. Verify

`references/testing.md` has the scripts and checks. Minimum every iteration:
1. Build (iOS Simulator build tool if available, else `xcodebuild`), install, launch on a simulator you booted
   (pass its UDID to every `simctl` call).
2. Record (`xcrun simctl io <UDID> recordVideo`), extract frames (`scripts/frames.swift`), and check the
   sequence numerically: timing order, stretch amounts, overshoot, arrival before next phase, no cuts at edges.
3. Frame-time probe in-app for stalls (snippet in testing.md); replay via the notification and confirm 0 stalls.
   Simulator WebGL is software-rendered and noisy under load: judge performance on a real iPhone when one is available.
4. Look at contact sheets yourself; compare against the Figma screenshot.

## 6. Deliver

- **Recording:** override the status bar to 9:41, warm-launch once, then trigger the in-place replay
  (`xcrun simctl spawn <UDID> notifyutil -p com.animatemyapp.replay`) while recording with
  `xcrun simctl io <UDID> recordVideo`, or with your own screen recorder. Don't record unless asked.
- **Framed video** when asked: `scripts/frame_video.swift` (iPhone frame on white, ≥ 120 px margins, 60 fps).
- **Side-by-side with a reference:** `scripts/side_by_side.swift`.
- Gotchas that cost time before: `references/gotchas.md`. Read it once per build.

## 7. Keep this skill growing

After each app, add what was learned (new recipe, new gotcha, a measured constant) to the matching reference
file, written as general guidance, so the next build is faster.
