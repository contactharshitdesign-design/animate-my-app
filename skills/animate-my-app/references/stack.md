# Stack: native SwiftUI app + three.js layer

The scaffold (`scripts/new_app.sh`) produces all of this; this file explains it so you can extend it.

## Project
- Hand-written `project.pbxproj`, objectVersion 77, one **PBXFileSystemSynchronizedRootGroup** for the app
  folder: every file dropped in `<App>/` (Swift, `Web/*`, fonts, PNGs) is compiled or bundled automatically,
  so the pbxproj never needs editing. Shared scheme `<App>`.
- Settings: `GENERATE_INFOPLIST_FILE`, `CODE_SIGNING_ALLOWED = NO` (simulator), iPhone only, portrait,
  `UILaunchScreen_Generation`, deployment iOS 17. Bundle resources are flat: load by `lastPathComponent`.
- Build: the iOS Simulator build tool if your environment has one (project path + scheme + device UDID), or
  `xcodebuild -project <App>.xcodeproj -scheme <App> -destination id=<UDID> -derivedDataPath build build`,
  then `xcrun simctl install <UDID> <App.app>` + `xcrun simctl launch <UDID> <bundle id>`.
  For a real iPhone build (signing), see `testing.md` → "Installing on a real iPhone".
- Fonts: drop `.ttf/.otf` into `<App>/Fonts`; `App.registerFonts()` registers every bundled font.
  Use the **PostScript name** in `.custom(...)` (check with `fc-scan`/CTFont — e.g. Phudu Bold is `PhuduLight-Bold`).

## The web layer (`SceneBridge.swift`)
- `BundleSchemeHandler` serves bundle files over `appbundle://app/<file>` (same-origin, so WebGL accepts the
  textures; `file://` fails). MIME by extension.
- `SceneBridge.shared` creates the `WKWebView` **at app init** (web process spins up during launch),
  transparent (`isOpaque = false`, clear backgrounds), no scrolling, `isUserInteractionEnabled = false`,
  `isInspectable` in DEBUG. JS → native: `webkit.messageHandlers.scene.postMessage("event")`; native → JS:
  `evaluateJavaScript("window.scenePlay && window.scenePlay()")`.
- A WKWebView swallows touches, so taps go to a `Color.clear.contentShape(Rectangle())` layer above it;
  text that sits above it gets `.allowsHitTesting(false)`; buttons stay hittable only once shown.

## Layout (`ContentView.swift`)
- Build on the Figma canvas in points (`CW×CH`, iPhone 17 Pro = 402×874), `scaleEffect(min(w/CW, h/CH))`,
  `.ignoresSafeArea()`. Bottom CTA: `padding(.bottom, safeInset/s + 16)`.
- Text/buttons appear from JS cues with SwiftUI springs (`response 0.5, damping 0.7–0.8`), offset 26 → 0,
  opacity 0 → 1, buttons also scale 0.9 → 1. Press style: 0.97 scale + `UIImpactFeedbackGenerator(.light)`.

## Engine (`Web/scene.js`) — API on `window.SCENE`
| member | use |
|---|---|
| `THREE, scene, cam, renderer` | ortho camera, 1 world unit = 1 CSS px; `k` = px per design pt |
| `toWorld(x, y)` | design point (Figma coords, top-left origin) → world `Vector3` |
| `spring(x0, v0, zeta, response, t)` | Apple-style damped spring displacement (t in s) |
| `track(fn)` | `fn(tMs)` runs every frame; must fully define state for any t (incl. t < 0 = hidden) |
| `cue(tMs, 'event')` | posts `event` to SwiftUI once per play (re-armed on replay) |
| `extendEnd(tMs)` | timeline end (render loop stops after it; posts `done`) |
| `loadTexture(file, opts)` | `THREE.Texture` that is decoded + GPU-uploaded **before the clock starts** |
| `hold(promise)` | anything else that must finish before the clock starts |
| `REDUCED`, `FREEZE` | reduced motion; `?t=1234` freezes the timeline for look-dev |
| `post(ev)` | send any event to native |

Boot order: all `<script>`s run → `DOMContentLoaded` → `Promise.all(holds)` → pre-warm render of every
mesh (shaders compiled, textures resident) → `update(-1)` (blank) → `play(450)`.
`play(warmMs)` renders blank immediately, posts `reset`, renders warm frames until `warmMs` has passed,
then starts the clock on the first frame actually drawn. The clock is `performance`-based, so the timeline
is identical on every replay.

## Replay protocol (Darwin notification and tap)
- App observes the Darwin notification **`com.animatemyapp.replay`** (`CFNotificationCenterGetDarwinNotifyCenter`)
  and re-posts it as `Notification.Name.replayRequested`.
- `replay()`: fade content to white (`easeOut 0.18s`, a veil opacity on the scene + text) → after 0.2s reset
  text state without animation and call `bridge.replay()` → JS `play()` posts `reset` → lift the veil 50 ms later
  without animation (scene is blank) → intro runs from frame 0 on a warmed-up renderer.
- Manual trigger: `xcrun simctl spawn booted notifyutil -p com.animatemyapp.replay`.

## Choosing the tool per part
- three.js (in the web layer): 3D objects, clay/soft bodies, procedural paint/brush, shaders, particles,
  anything with lighting or deformation.
- SwiftUI: all UI chrome, text, buttons, list/screen transitions (`matchedGeometryEffect`, `PhaseAnimator`,
  `KeyframeAnimator`, springs). Keep text native (crisp, accessible, exact font).
- Rive / Lottie: only when `.riv` / Lottie JSON is supplied or the part is classic 2D vector character
  animation (load `lottie-motion-design` if installed). Rive runtime can also run in the web layer.
