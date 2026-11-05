# Gotchas that already cost time

Grouped by topic. Each entry is a symptom → cause → fix, with measured numbers where they exist.
Recipes for specific effects live in `procedural-3d.md` and `motion-physics.md`; test procedures in `testing.md`.

## 1. Toolchain and environment
- **Xcode 27 has no Simulator.app**; it's Device Hub (`Xcode.app/Contents/Applications/DeviceHub.app`). A simulator
  booted headless (`xcrun simctl boot` with Device Hub not running) shows its screen in other hosts but ignores mouse
  input from them. Open Device Hub first (`open -g …/DeviceHub.app`), then boot, then hide it. Quitting Device Hub
  shuts its simulators down. The simulator control tool's `tap` works either way (use it to tell "app ignores taps"
  from "input path broken").
- Python: `python3 -I` hides user site-packages (numpy, Pillow) — run your own tools without `-I`. Check which tools
  exist before relying on them (ffmpeg, scipy, potrace, xcodegen, brew may be missing); PIL + numpy + Swift
  (AVFoundation/AppKit/CoreGraphics) cover most needs.
- macOS has no `timeout` command (exit 127, the wrapped command never runs). Bound long runs with
  `perl -e 'alarm 3000; exec @ARGV' xcodebuild …`, and always check the exit code before reading results.
- zsh doesn't word-split `$VAR` → use arrays or `${=VAR}`.
- `sips -c` crops around the centre (ignores `--cropOffset`): crop with PIL.
- A session scratchpad can be wiped mid-project → keep reusable tools in the project (`tools/`) or in this skill.
- **Hand-written Xcode project** (objectVersion 77) with a `PBXFileSystemSynchronizedRootGroup` per target folder:
  sources and resources are picked up automatically. Keep Info.plists and entitlements OUTSIDE the synced folders
  (else "multiple commands produce Info.plist"). App + extension with a shared App Group sign and register fine with
  `xcodebuild -allowProvisioningUpdates`.
- **Xcode stores bundle PNGs as CgBI**: `cmp` differs and PIL can't open them. Check with `sips -s format png`
  (ImageIO) — opaque data PNGs come back bit-identical.
- Font names: register the TTF and use its **PostScript** name.
- **Apple fonts used in Figma** (Canela etc.): files under
  `/System/Library/PrivateFrameworks/FontServices.framework/.../Subsets/*.ttc` are 15-glyph name previews. The full
  font is under `/System/Library/AssetsV2/com_apple_MobileAsset_Font*/…/AssetData/`. Bundle the `.ttc` (the template
  registers ttf/otf/ttc) for local demos only; check the licence before shipping.
- System Events `click at` is an accessibility press, not a mouse click; use CGEvent for real input, and only after
  confirming the target app is frontmost (check for floating windows over the target, and stop if someone is using
  the Mac at the same time).
- **White launch flash before a dark scene:** the generated launch screen follows light mode. Add
  `INFOPLIST_KEY_UIUserInterfaceStyle = Dark` (+ `UIStatusBarStyle = UIStatusBarStyleLightContent`) for dark apps.

## 2. WKWebView scene layer
- **WebGL + `file://`**: textures fail → serve via `WKURLSchemeHandler` (custom scheme). The template does this.
- **Stale JS after reinstall:** WKWebView caches custom-scheme responses on disk, so a reinstalled app can keep running
  the OLD `scene.js` while the native side is new. Fix (in the template): `"Cache-Control": "no-store"` header plus
  `config.websiteDataStore = .nonPersistent()`. Quick check: grep a new string in
  `$(xcrun simctl get_app_container <UDID> <bundle>)/scene.js` and in the log output.
- **White first frame:** an opaque WKWebView paints white before the page's first frame. Keep it `isOpaque = false`
  with a clear background over the SwiftUI background (the template is transparent already).
- **rAF doesn't tick for an off-screen WKWebView** → start the clock on the first drawn frame, not at load. A
  pre-loaded scene never gets ready off-screen: park it with `window.insertSubview(webView, at: 0)` (behind the
  opaque root), let it draw one frame, then pause the JS loop until SwiftUI shows it (resume resets the clock).
- **Texture loads mid-animation stall 50–185 ms** → decode + `renderer.initTexture` before the clock, pre-warm.
  New textures added later: draw each once offscreen when it loads (WebKit uploads on first draw).
- **Cold launch shows ~1.2 s of white** before the first scene frame (web process start + three.js parse + 450 ms
  warm-up); the very first launch after install takes ~2.4 s and can start mid-animation. Record with the in-place
  replay, not a cold launch. If a design needs the splash on frame 1, render the first state natively in SwiftUI and
  hand over to the scene once it posts `ready`. Frozen look-dev shots right after a fresh install can come out white:
  wait ~7 s.
- **Clock-driven intros start into the web view's first-present stall** (Simulator: 321, 43, 30, 55 ms frames even
  after warm-up renders), so the first ~0.3 s jumps. Hold the intro on frame 0 until ~10 consecutive steady frames
  arrive, then start its clock. The gate must be **rate-independent** (steady = dt < 45 ms and within 6 ms of the
  previous dt) AND have a **hard timeout** (~0.8 s): a "dt < 20 ms" test never passes on an iPhone capped at 30 fps
  (Low Power Mode, thermal), and the splash waits forever. After this: 132 frames, max 18–19 ms on iPhone.
- **Replay flash:** posting `reset` on the same tick as the blank render lets SwiftUI lift its veil before WebKit
  presents the blank canvas, so the previous run's last frame flashes ~0.15 s. Post `reset` after two
  `requestAnimationFrame`s (fixed in the template).
- **Relaunching the app to replay looks glitchy** (launch zoom, cold web process) → replay in place.
- **Warm-up renders must not post cues** (the whole UI showed at t = 0.3 s): mute `post()` during boot warm passes.
  Any "post once" cue fired while muted is marked sent and lost, so every warmer must reset its state when it
  switches off. Self-test flags that switch screens must not run during the muted warm-up (the scene switches but its
  message to SwiftUI is muted, leaving native on the old screen): guard them with `!muted`.
- **WKWebView swallows touches** → a clear tap-catcher layer above it; text above gets `allowsHitTesting(false)`.
  For an interactive scene: `isUserInteractionEnabled = true`, touches handled in JS (raycast onto the object's
  plane), native buttons above it.
- **Gesture-tracked 3D in a small web view**: don't drive position/size through JS (`evaluateJavaScript` lags a frame
  or two). Make the WKWebView a small square rendered at its largest size and move/scale it natively (`center` +
  `transform`) in `scrollViewDidScroll`: 1:1 with the finger. JS only gets the pose input, where a frame of lag is
  invisible. Only scale it DOWN natively (scaling up blurs).
- **WKWebView frames depend on the app's main thread**: a SwiftUI hitch shows up as a slow rAF frame even when the
  scene's work is tiny. Print the scene's JS time with each slow frame: small JS time = look at SwiftUI. Example: a
  SwiftUI `Canvas` set up its renderer the first time it appeared and cost one 33 ms frame; plain shape strokes cost
  nothing.
- **Heavy native setup on the main thread stalls the first web frames** (synthesising an 11 s audio loop gave
  30–130 ms frames in the first 0.5 s). Build it on a background queue; skip until ready. Such engines drop the first
  messages of a launch: keep the latest settings on the bridge and re-apply them when the engine is ready.
- Only send sensor updates (tilt) to JS when they change (dead band); `evaluateJavaScript` at 30 Hz is fine then.
- **SwiftUI not updating from bridge events:** writing `@State` from a closure stored on the bridge silently didn't
  redraw. Put scene state in an `@Observable` class on the bridge, hold it in `@State`, react with `.onChange`.
- Pin `webView.overrideUserInterfaceStyle = .light` (or dark) so an app appearance change doesn't re-style the page.
- **Launch flags**: forward `SIMCTL_CHILD_SCENE_QUERY="perf&debug"` (Simulator) or `devicectl … -e` (device) to the
  page's query string. Read logs with `log show --last 1m --predicate 'eventMessage CONTAINS "[tag]"'`; short
  windows can miss reports, widen to `--last 3m`.
- **Debug logs from WKWebView touch handlers**: buffer them and post from the next rAF; a JS event log (start/mode/end
  with ids, order, states) finds gesture bugs that frame sheets alone can't explain. Keep a few lines per touch logged
  always so a bug hit on a phone can be read back.
- **Multi-screen 3D in one renderer:** each screen is a module on a shared global (scene, camera, composite, helpers,
  hooks/warmers/resets); a screen's objects sit in one group so a transition moves them as one; every module
  registers a warmer so all shaders compile at boot. Keep one WebGL context, never a new page.
- Debugging GLSL: WebKit's console only shows "Shader Error 0 - VALIDATE_STATUS false". Serve `Web/` with
  `python3 -m http.server` and open it in a desktop browser to read the real GLSL error lines. A hidden/background
  browser tab throttles rAF, so frozen-time look-dev can look stuck there.

## 3. three.js, WebGL and shaders
- **`THREE.Color(hex)`** converts to linear → flat-colour shaders come out too dark; parse hex as raw sRGB there.
- **PNG alpha is premultiplied by the browser** → put data maps in RGB only.
- The template's `three.min.js` is r159: `scene.environmentIntensity` doesn't exist there; set `envMapIntensity` per
  material (0.18 matched an r170 look). All standard shader chunks (`opaque_fragment` etc.) exist in r159.
- **Meshes in design points vanish:** when geometry holds page/design coordinates and the vertex shader places it,
  three.js frustum-culls by the raw positions. Set `mesh.frustumCulled = false` on every such mesh (in a shared helper).
- **`half` is a reserved word in GLSL ES 3.0** (three.js compiles ShaderMaterial as WebGL2): `float half = …` silently
  kills the whole mesh. Grep shaders for reserved names (`half`, `input`, `output`, `filter`…).
- **Uniform name collisions:** materials that share a uniforms object via `Object.assign` silently replace a
  same-named uniform (→ VALIDATE_STATUS false). Prefix per-material uniforms.
- Never bake `1/PX` (from `innerWidth`) into shader source: a hidden/zero-size web view gives `Infinity` → compile
  error. Use `fwidth()` for anti-alias width.
- **Toggling `material.transparent` mid-animation recompiles and stalls** (a 77 ms frame on iPhone when a fade-in
  ended): keep a fading object on one variant (always transparent, depthWrite on) and include its fade in the warm-up.
- **Faded meshes still cost:** set `visible = false` when opacity reaches 0 (a transparent full-screen plane at
  opacity 0 still costs a blend pass).
- **Per-frame allocations cause GC hitches** on device (~120 `Vector3`s per frame gave 3 frames of 29–37 ms in 20 s).
  Precompute tables, cache static poses, reuse temp vectors: 0 frames > 25 ms after.
- Static parts (a stack at rest) shouldn't rewrite their vertices every frame: return early once at rest.
- **First-use costs land on the first interaction or reveal** (29–49 ms frames): pre-render every program and pose a
  gesture or flight will need at boot (lifted pose, back faces, shadow meshes forced visible, every hero's update at a
  couple of mid-motion times, every stage of a camera flight), with `post()` muted, then reset to t = −1.
- **Particle pools**: clearing the JS state isn't enough; zero the GPU attribute buffers too, or warm-up particles show
  as ghost blobs in the next transition.
- **A morph begun mid-frame flashes its end state for one frame**: set its start uniforms when it begins.
- **Rotation blended by a 0→1 factor must use the angle wrapped to ±π**, or a shape that has spun N whole turns
  unwinds them all while it morphs back.
- A resting body under constant gravity chatters against its contact (tiny bounce every substep) and keeps "moving"
  forever: zero the velocity when a slow contact lands, and skip physics for a body at rest.
- **Fragment cost on device** (translucent discs + per-pixel nested fbm at 3× DPR ran 31–38 ms/frame on iPhone 17).
  Fixes, in order of effect: bake procedural patterns into a DataTexture once and sample it; `FrontSide` for objects
  that always face the camera; discard reflection pixels that have faded out; render at DPR 2 with 4× MSAA (visually
  identical at normal size). Result: 17 ms steady for 34 s.
- VSM shadows (2048, blur) for two scenes per frame throttled an iPhone to 30 fps after ~20 s; PCFSoft 1024 plus caching
  unchanged CPU geometry gave 0 frames > 25 ms.
- Shader seams across strokes → bake blended heights on the CPU instead of mixing per-stroke in GLSL.
- Planes/textures sized exactly to the art clip brush ends, glows and overshoot → pad them.
- Text drawn into a canvas texture: draw a line only if it fits the measure; shorten copy rather than letting the
  texture edge cut it (texture edges are a hard clip).
- Never measure glyph metrics (stem width) from canvas pixels at runtime: the same font measured 9.0 pt in the
  Simulator and 13.0 pt on an iPhone. Use a fixed ratio of the font size.
- **iOS Simulator WebGL is software-rendered**: a heavy scene can take ~10 s to boot there. Judge speed on an iPhone.
- "Tucked between" two sheets: render it between them by `renderOrder` (fractions work: 15.4, 15.6) and discard
  fragments above the line the top sheet covers; the cut stays hidden under the sheet.

## 4. Gesture state machines (what real fingers break)
Real-iPhone breakage the Simulator never showed: wrong card on top, a stack fanned up, a card frozen mid-air, a
headline out of step. Rendering was fine; the gesture state machine wasn't robust. Rules:
1. Call `requestAnimationFrame` FIRST in the frame callback and wrap the body in `try/catch`: one throw otherwise
   freezes the scene forever while SwiftUI keeps updating.
2. A touch whose end never arrives: on the next `touchstart`, check `e.touches` for the old id and close it out; and
   every frame, if no finger is down, nothing may stay `held`.
3. Never act on an object captured at touch-down: re-read the target when the gesture's mode is decided and when it
   commits (a stale one duplicated an id in the order array → wrong card on top).
4. Validate invariants every frame (the order array is a permutation) and repair + log if broken.
5. Swipes made while something is still travelling must not be dropped: count them and run them when free.
- **Start tap-triggered motion 2–3 frames after the tap**: the touch-up costs the compositor one late frame
  (measured 2×33 ms → 0 slow frames).
- Test a held-then-released lift that comes back down, taps right after other gestures, and every gesture on the
  first and last items: that's where the bugs hide.
- Create and `prepare()` haptic generators once, not per event.
- Haptics belong to outcomes. A haptic inside a shared ButtonStyle doubles up with selection haptics; remove it there.

## 5. SwiftUI motion and layout
- **SwiftUI first uses stall the web view.** The first draw of a font (serif), SF Symbol, symbol effect, shadow or
  `.blurReplace` costs 100–300 ms on the main thread, and WKWebView frames stall with it. Draw them once invisibly
  (opacity 0.001) right after `ready`, remove that view, then start the scene (with a fallback timer). Measured: intro
  max 312 ms → 22–28 ms. Put such warm-up layers in `.overlay {}` on the root, not inside the root ZStack (inside, they
  make it taller than the safe area and push the header under the clock).
- **AttributeGraph cycle freezes the root view:** the tab highlight changes but pages never switch, sheets never
  open, console prints `=== AttributeGraph: cycle detected through attribute N ===` (CPU ~1 %, not hung). Cause:
  reading UIKit layout during SwiftUI layout (e.g. `windows.first?.safeAreaInsets.top` in a `.frame(height:)`). Never
  read window/UIScreen geometry in a body; for a fade under the status bar use
  `VStack { Color.page.frame(height: 0).ignoresSafeArea(edges: .top); LinearGradient(...).frame(height: 14); Spacer() }`.
  Find it with `simctl launch --console-pty`, grep `cycle`, then bisect the root ZStack's children (swap for
  `Color.clear`; also test "everything minus one").
- **Panels that move in leave lazily-created children behind** ("the icons are already there and the rest slides in
  later"): a view entering with `.transition(.move/.offset/.scale)` leaves any child created during the animation (a
  `LazyVGrid`'s cells, an image that finishes loading) at its final spot. Add `.geometryGroup()` before every moving
  panel's `.transition` and keep lazy containers out of panels. Prove it with a 60 fps recording.
- **Card that grows out of a bar:** inserted views appear at their FINAL layout position while the container's frame
  animates, so text shows outside the growing card. Split state: `open` drives layout, `contentShown` drives opacity.
  Open: grow, then fade contents in at ~80 % (0.15 s of a 0.28 s spring). Close: fade contents (90 ms), then shrink.
  Verify by scanning frames for text outside the card's edge. Stagger small items (22–25 ms) instead of one block fade.
- **Togglable panels:** never attach a separate `.animation(...delay...)` to a panel's insertion/removal; interrupted,
  the old copy keeps fading on its own clock while a new one appears. Drive the panel from ONE `withAnimation(spring)`
  at the toggle (open: 0.35 s bounce 0.08; close: 0.25 s bounce 0); the inserted view uses a plain `.opacity`
  transition. Content that animates itself waits for the container (~90 % of the open spring) and its chrome fades in
  over that wait; Canvas-drawn labels ignore the view's transition timing unless you gate them.
- A floating overlay inside a ZStack that's even a few points wider than the screen makes the ZStack grow and
  re-centre every sibling: the page "shifts a little" when it appears. Sum min widths (8 × 44 pt chips + padding =
  408 > 402) and diff two frames around the change.
- `.frame(maxHeight:)` around a `.fixedSize` card centres it in the taller frame; a handle pinned to the frame's top
  floats above the content. Apply max height only to the tall variant.
- A modifier on `Group` applies to each child separately; wrap in a `VStack` to fade a block as one layer.
- `@Observable` classes: one stored property per line (`var a = 0, b = 0` fails with "declaration name '_b' is not
  covered by macro 'ObservationTracked'").
- An app type named `Layout` shadows SwiftUI's `Layout` protocol: write `SwiftUI.Layout`.
- `@ScaledMetric` inside a ViewModifier used on hundreds of Texts overflowed the stack; a plain
  `UIFontMetrics.default.scaledValue(for:)` + root `.id(dynamicTypeSize)` does the same at no cost.
- `.offset` doesn't move a view's layout frame: an `.overlay` added after `.offset` still covers the original frame.
- A full-width drag-handle zone with `contentShape` swallows taps on header buttons: keep it to the middle (~140×24).
- `.onDisappear` also fires when a screen is pushed over the view: don't tear the model down there.
- Values formatted from a global (UserDefaults) don't redraw when it changes: key the view on observed state (`.id`).
- A tile `ZStack { colour; Image.scaledToFill() }` sizes to the photo and spills out; size on the colour and put the
  photo in `.overlay`, then clip.
- Menus that open upward get reversed by iOS: `.menuOrder(.fixed)` when order must match something on screen.
- Static caches touched from concurrent `.task`s must be locked or `@MainActor` (a dictionary crashed at launch).
- Paired elements (dim + card, fog + composer) must use the same animation; check both modifiers.
- Don't animate a full-screen `.blur` behind a sheet: expensive per frame on device and reads as lag; dim alone (~22 %).
- Switching `.preferredColorScheme` at a light→dark transition flips the status bar instantly; flip it at mid-fade.
- **Motion tokens in SwiftUI** (Emil Kowalski's animation guidance, translated): `.spring(duration:bounce: 0)`
  tokens; asymmetric transitions with a faster `.easeIn` removal via `.transition(.x.animation(...))`; a `Motion.x(reduceMotion) -> Animation?` helper returning nil.
  List rows: inset highlight (rounded rect, on instantly, 0.25 s fade out), not a scale.
- **Drag to dismiss:** carry velocity with `.interpolatingSpring(duration:bounce:initialVelocity:)` where
  initialVelocity = finger speed / remaining distance; close with `withAnimation { } completion: { }` then unmount in a
  transaction with `disablesAnimations`. Threshold min(140 pt, ¼ card) or a flick.
- **Gestures:** `.onTapGesture` + `.onLongPressGesture(pressing:)` on one view race (holds left it pressed and fired
  nothing) → one `DragGesture(minimumDistance: 0)`: press on touch-down, a 0.4 s timer for the hold, quick release taps,
  sliding > 14 pt cancels. Press-and-drag inside a ScrollView: `LongPressGesture(0.12).sequenced(before:
  DragGesture(minimumDistance: 0))` with `.updating($gestureState)` (GestureState resets on cancel; `onEnded` doesn't
  fire when the ScrollView steals the touch), and `.scrollDisabled(flag)` once the press activates.
- **Swipe rows in a ScrollView:** a SwiftUI DragGesture (even `simultaneousGesture`) or a sequenced LongPress on rows
  can stop the page scrolling. Use a `UIGestureRecognizerRepresentable` (pan with `gestureRecognizerShouldBegin`
  requiring |vx| > 1.2|vy| and `shouldBeRequiredToFailBy` the scroll view's pan; or `UILongPressGestureRecognizer` for
  lift-and-drag). Block the row's tap for ~0.35 s after a swipe; round the row's clip like the card.
- SwiftUI buttons inside a UIScrollView: `delaysContentTouches = false` so press feedback starts on touch-down.
- **2D procedural reveals inside a SwiftUI app** don't need WebGL: one `TimelineView(.animation)` + `Canvas` with the
  scene as a pure function of t ran with 0 dropped frames on iPhone 17 (~10 ribbons, ~45 coins). Add an env var that
  freezes t for exact screenshots, and pause the TimelineView when done. Canvas clips centre-anchored edge labels:
  clamp by the measured width. Hand-off to real text: lay digits out with `CTLine` offsets of the same font and place
  the Text at `baseline + lineHeight/2 − ascender` so the cross-fade doesn't move.
- **Exact Figma text in Core Text**: first baseline = `(lineHeight − (ascent+descent))/2 + ascent`, then every
  `lineHeight`; measure against the export (some fonts need a fraction of a point). SwiftUI `lineSpacing` can't go negative.
- **Hero motion "every time the app opens"** = cold launch AND scenePhase `.background → .active` (not
  `.inactive → .active`, which is Control Center), after Face ID if locked. Start it ~0.45 s after first appear: the
  first 0.45 s of a launch had 4–7 frames > 25 ms on iPhone (system zoom + startup). Split the probe window.
- **Device-measured SwiftUI costs (iPhone 17):** a system `.sheet` costs 7–8 frames > 25 ms per open → present your
  own bottom card (7 → 0–1). `List` ~60 ms per push, `Form` ~100 ms per sheet, `.searchable` / segmented `Picker`
  ~30–40 ms → LazyVStack, plain cards, own pill switch. Swift Charts with ~30 stacked bars cost 2–3 slow frames per
  change; a Canvas-drawn chart cost 0–1 (swap periods with `.id(period).transition(.opacity)`).
- **Navigation:** pushing from a hidden nav bar to a large title makes the bar appear mid-push and the title jump; hide
  the bar on every pushed screen and draw the header in the page. A hidden nav bar disables swipe-back: re-enable by
  setting `interactivePopGestureRecognizer?.delegate` (begin only when `viewControllers.count > 1`). Zoom morph from a
  card: `.matchedTransitionSource(id:in:)` + `.navigationTransition(.zoom(...))`.
- **3D → SwiftUI card hand-off:** fly the mesh to the SwiftUI view's global frame (from `onGeometryChange(.global)`),
  ramp `emissive = color` and fade its shadow on the way in, then show the real view.

## 6. Keyboard
- **The keyboard's first appearance per launch is the single worst frame** (55–204 ms on iPhone 17). For number entry
  an in-view keypad removes it (worst 20.8 ms). Otherwise warm it once after launch: an off-screen `UITextField` in
  the key window, `becomeFirstResponder()` + `resignFirstResponder()` in the same main-loop turn, then removed. That
  warm-up still posts keyboard notices and changes SwiftUI's keyboard safe area: put `.ignoresSafeArea(.keyboard)` on
  chrome that should never ride the keyboard and ignore keyboard notices while the warm-up flag is set.
- **Keyboard must rise from the bottom, never ride in sideways.** iOS carries it sideways with a push/pop when a field
  becomes first responder while its page is still sliding in, or is still first responder when the push starts.
  Resign the moment the navigation path changes, and focus a new page only after the push (in the
  `transitionCoordinator`'s `animate(alongsideTransition:completion:)` completion).
- **A card that rides the keyboard**: don't also give it a `.move(edge: .bottom)` insertion (it slides to its
  pre-keyboard spot, sits, then jumps). Focus in `.onAppear`, insertion `.opacity` only, `.geometryGroup()`: one rise
  in ~0.22 s instead of two steps in ~0.5 s.
- **Swapping the keyboard for a custom panel** without the bar jumping: opening, set the SwiftUI state FIRST, then
  resign (resign-first dipped the bar 145 pt). Closing, in the text view's `becomeFirstResponder` override (before
  `super`) set the state on the keyboard's own curve (`.interpolatingSpring(mass: 3, stiffness: 1000, damping: 500)`
  = UIKit curve 7) and `layoutIfNeeded()`. The QuickType row changes the keyboard's height (~17 pt) — not a jump.
- Measure keyboard motion from a recording: threshold the keyboard backdrop colour, print its top and left edges per
  frame (from the bottom = top edge climbs, left edge fixed at 0). Template matching mis-locks on look-alike rows.
- Scripted typing via `text = …` costs ~15 ms/char in UIKit; use `UIKeyInput.insertText` (after calling the
  delegate's `shouldChangeTextIn`, like the keyboard does).
- A `.background` fade with `.ignoresSafeArea(edges: .bottom)` stretches behind the keyboard; use a fixed-height fade.
- An invisible caret usually inherits a near-white `.tint`: test with `.tint(.red)`, then use the accent.
- Keypad keys: haptic on touch-down (`sensoryFeedback(... trigger: isPressed)`), 0.96 scale, instant press-in /
  spring release. Hardware keys on a non-text view: `.focusable().focused($f).focusEffectDisabled().onKeyPress(phases: .down)`.

## 7. UIKit scroll views and pull-to-refresh
- **UIScrollView snaps an over-pulled list back if you re-assign its frame or contentInset in
  `viewDidLayoutSubviews`** (it runs on every scroll). Set insets once; assign the frame only when it changed.
- **Custom pull-to-refresh hold**: in `scrollViewWillEndDragging`, if past the threshold set
  `contentInset.top += SLOT` and `targetContentOffset.y = -(safeTop + SLOT)`; the bounce lands on the slot. Collapse
  with `UIView.animate(springDuration:bounce: 0)` on inset + offset. Hosted SwiftUI list: UIHostingController with
  `sizingOptions = .intrinsicContentSize`, `safeAreaRegions = []`, pinned to the content layout guide.
- **Dropping `contentInset.top` while the list rests on it snaps the offset shut for a frame**: save the gap, change
  the inset, restore `contentOffset` in the same pass.
- A `UIView.animate` of `contentOffset` doesn't call `scrollViewDidScroll` per frame; when something must follow the
  list while it animates, step the offset yourself with a CADisplayLink spring.

## 8. Simulator and device testing
- **Always pass the UDID**: `simctl … booted` hits an arbitrary device when several are booted (a recording came out
  at iPad size). Use it for install / launch / io / get_app_container / spawn / log show. Create your own simulator
  (`xcrun simctl create "<App> Test" "iPhone 17 Pro" <runtime>`) and never touch simulators other sessions or tools
  are using (screenshots can come back from a different app).
- **Simulator control calls sent in one message run concurrently**: gestures overlap. Send one gesture per message
  and wait between them. `touch_path`'s first `dt_ms` does not delay the start; `touch_path` blocks until the path
  ends, so a screenshot sent alongside runs after release (to see a held pose, record video or log).
- The control tool's `screenshot` can be stale right after input: trust a recording + frame extraction, and give the
  recorder ~3 s of lead-in (it starts writing late). Injected touch paths arrive coalesced, so flick velocity can't be
  tested in the Simulator — distance thresholds can.
- The control tool's `text` injects into the focused field and skips keyboard-layout logic; to test keyboard behaviour
  tap real key coordinates from a screenshot (points = pixels × 402/1206).
- **Never screenshot while measuring frame times** (each capture costs a 26–28 ms frame), and **a frame probe while
  `simctl recordVideo` runs is meaningless** for heavy WebGL (63 frames with 7 > 40 ms recorded, 96/96 at 60 fps
  without). Record for the look, probe without recording.
- **Simulator frame numbers are meaningless under host load** (other builds, other simulators): an idle control run
  showed 0 slow frames, the same demo 30–50. Probes also vary run to run (worst right after a build or launch): take
  3 runs, report the spread, and compare JS CPU per frame. Run a native CADisplayLink probe next to the JS rAF probe:
  native frames all ≤ 16 ms while web frames are 30–117 ms points at the host, not the app. The native probe doesn't
  see WebGL hitches on its own. The iPhone run is the measurement.
- Low Power Mode caps WKWebView rAF at 30 fps on device (every frame exactly 33.3 ms). Log it before tuning.
- **Apps with sound keep playing in a headless simulator** (nothing on screen, audio still audible). After testing an
  app that makes sound, `xcrun simctl terminate` it; in the app, pause the audio engine when `scenePhase != .active`.
- An idle-shutdown hook or another tool may shut a simulator mid-test: if `simctl` says "Shutdown", boot it and go on.
- "Looks bolder on the phone than in the Simulator" = check `UIAccessibility.isBoldTextEnabled` (log it at launch);
  `.environment(\.legibilityWeight, .bold)` doesn't emulate it. Screenshot the device with
  `xcrun devicectl device capture screenshot --device <UDID> --destination x.png` and compare.
- Measure alignment from a device screenshot (pixels ÷ 3 = pt) instead of eyeballing.
- Before resetting device data for a demo, copy the App Group store (and -shm/-wal) back with
  `devicectl device copy from --domain-type appGroupDataContainer`. Debug sample data must never write real state.
- `simctl io <UDID> recordVideo` prints "Recording started" on stderr at the first frame: use that moment
  (systemUptime, same clock as NSEvent timestamps) as t0 to sync input logs with the video.
- Foreground app in a simulator: newest pid among `simctl spawn <UDID> launchctl list` "UIKitApplication:<id>" rows.
- Vision's `VNGenerateForegroundInstanceMaskRequest` fails in the Simulator ("Could not create inference context"):
  test Vision paths on the Mac or a device.
- **Recording a feature walkthrough: script it inside the app, don't drive it with tool taps.** Tool-driven taps
  leave 2–14 s dead gaps and a cold first launch can show seconds of white. Add a demo mode (env var via
  `SIMCTL_CHILD_…`) that runs a fixed timeline from the intro's UI cue and calls the same functions the gestures call,
  with a soft finger dot (40 pt, black 16 %, white rim) for taps, holds and drags. Warm-launch once before recording.
- **Re-check every approved motion after any scene change.** Adding scenery after the motion was approved can break it
  (a new platter visible from frame 0 sliced through a sleeve; a landing bounce went down into it). Rules: anything
  added gets an entrance timed against everything that moves through its space; landings bounce *up* only and rocks
  pivot on the rim (lift by R·sin(rock)); finish rotations before contact (~85 % of the flight). Prove it numerically
  (`?check` steps the intro at 120 Hz and reports the lowest point relative to the surface: must be ≥ 0).

## 9. Recordings, video and image export
- **Resample Simulator recordings to 60 fps by NEAREST frame, not "last frame ≤ t".** Their timestamps wobble
  13–20 ms apart, so "last before" repeats one frame and skips the next ~6×/s (77 dup+skip pairs in 12.5 s vs 1 with
  nearest). Compare colours of downscaled video in linear light — averaging gamma values looks 5–8 levels "off".
- **Simulator recordings are Display P3.** A Core Image pipeline in sRGB clips saturated colours (yellow (248,248,0)
  exported as (249,249,82)). Use `workingColorSpace` extendedLinearSRGB, render out in displayP3, tag buffers P3 and
  write video with `AVVideoColorPrimaries_P3_D65` + 709 transfer/matrix. For Rec. 709 exports render into
  `CGColorSpace(name: .coreMedia709)` (0.1–0.6/255 off the preview vs 6/255 for sRGB, 12/255 for plain itur_709).
- **GIFs:** never 15 fps (or any rate that doesn't divide 100): delays are whole hundredths, so 15 fps alternates 6/7 cs
  = judder. Use 20, 25 or 50 fps. Bayer dithering crawls on soft gradients: `paletteuse=dither=sierra2_4a` or none,
  `palettegen=stats_mode=full`. Prefer MP4: H.264 1080p60, `-crf 18 -tune animation -preset slow`,
  `-movflags +faststart`; full-range sources need `scale=...:in_range=pc:out_range=tv`.
- **Cut clips on rest frames, never mid-transition.** Per-frame difference (ffmpeg
  `tblend=all_mode=difference,signalstats` YAVG); a cut point is where the next ~6 frames are < 0.06. Look at the first
  and last frame of every clip. Verify smoothness: every pts gap exactly 1/60 s, 0 frozen frames between moving ones.
- A "glitch" in a recording = a per-frame mean |Δ| far above its neighbours (e.g. 16 vs ~5): find it numerically, then
  look at the frames around it. Simulator recordings are variable-rate: use `mpdecimate` and don't read timing from
  frame counts. ffmpeg `tile` from an image sequence needs `-frames:v 1`.
- Check a framed video with a 1-per-second contact sheet; `frames.swift` with start == end returns the wrong frames.
- Frame-accurate cut checks: per-frame mean |Δ| inside the region that changes; onset = jump over 3× the median of the
  6 frames before. Pale content on paper changes by only ~1–3/255 at first: lower the threshold (diff > 1.2 after
  < 0.6; static paper is < 0.3).
- **Hand-offs between a 3D object and its 2D twin** need a cross-fade over a STILL moment (~0.2 s): sharpness,
  tone-map rounding and missing soft edges make an instant swap read as a glitch. Diff consecutive unique frames: a
  smooth curve with no one-frame spike = invisible switch. Between full-screen layers, fade the foreground mark first,
  then the background, so no frame has both half there.
- **iOS screen recordings** widen the Dynamic Island into a pill with a red dot (1206 px wide screen: island x 415–790,
  y 42–151; pill x 335–851). Remove it with a pill-shaped patch ~14 px larger, filled per column from 6-row bands
  above/below (averaged, blurred sideways σ 3 px, feathered σ 2.5 px). Never sample left/right (clock and signal
  icons sit at x < 223 and x > 879). On dark content the pill is see-through glass: test on a dark frame at 5×
  contrast. Thumbnails need the same cleanup. Simulator recordings have no Dynamic Island: draw it
  (x 415, y 42, 375×109, fully round, at 1206 px wide).
- **Touch indicators for app recordings:** a glass ring that refracts the screen (`CITorusLensDistortion`, radius
  30 pt, width 12 pt, refraction 1.7) with crisp edges (outer rim lit top-left, faint dark contour so it reads on
  white). Arrives at 1.7× and tightens in 130 ms (ease-out), follows the finger, on release grows to 1.45× and fades in
  170 ms; a quick tap must still finish tightening. Coloured indicators need ~2.6× the strength of white to be visible.
  macOS cursor art is vector: `HIServices.framework/Resources/cursors/<name>/cursor.pdf` (+ hotspot plist).
- **Core Image performance:** with `cacheIntermediates: false`, CGImage-backed CIImages re-upload every frame; draw
  static layers once into IOSurface-backed CVPixelBuffers (16.2 → 5.1 ms/frame). Render an expensive layer to an
  MTLTexture only when it changes, then just transform + composite per frame. CI's CPU cost grows with node count:
  bake layers that stopped moving into one cached image (on the SECOND request of a key, so drags never pay). Preview
  at 60 fps on your own render thread (CADisplayLink on a dedicated thread + `CAMetalLayer.nextDrawable()`), not
  `MTKView`'s main-thread draw (57–127 of ~650 frames > 25 ms → 0). `CIRenderDestination(mtlTexture:)` needs
  `isFlipped = true`.
- One deterministic `frame(t) -> CIImage` used by both the live preview and the export makes "preview = export" a test:
  render the same t both ways and diff (mean |Δ| ≤ ~3/255 = codec).
- Core Image drop shadows: never `clampedToExtent()` a shape before blurring its alpha (the shadow fills its crop).
- AVAssetWriter stops taking video frames when the audio track ends early (an mp3 shorter than stated): finish the
  audio input as soon as its reader runs dry. Never decode video inside the frame function: decode short moments into
  memory before the clock starts. A 30 fps preview logs every frame "> 25 ms": measure at the rate you claim.
- Non-colour data masks in Core Image must be `CIImage(cgImage:options:[.colorSpace: NSNull()])` or they get
  linearised. Iterate `.ci.metal` kernels in a Mac harness (`xcrun -sdk macosx metal -c` + `metal x.air -o x.metallib
  -framework CoreImage`) — seconds per try instead of a simulator cycle.
- Quiet synth sounds (peak ~0.03) need a louder mix in the app for recordings (peak ~0.2).
- App icons drawn in code: SVG (true superellipse squircle) → WKWebView snapshot → `sips` → iconset → `iconutil -c icns`.

## 10. Image processing (Python/PIL)
- PIL `ImageDraw.floodfill` silently does nothing on an image that wraps a numpy buffer (`Image.fromarray`): `.copy()` it.
- PIL blur/resize on float maps goes through uint8 and destroys 0–1 data: blur floats with numpy (box passes).
- **Round, never truncate, when writing 0–255 images**: `astype(uint8)` turns 254.9 into 254 → a faint grey band
  across a white page with straight ends.
- **Two half-clear edges stacked show what's under both**: the layer underneath must be solid before the one above
  starts fading.
- **Fade a floor shadow by distance from the contact, not by the photo's edges.** Edge fades leave straight cuts
  and a faint rectangle on a white page. Fade between ~200 and ~560 px from the feet: it ends in a soft round edge.
- Background removal services return RGB that is NOT decontaminated: decontaminate against an inpainted backdrop,
  F = (I − (1−α)B)/α. Per-render floor shadows disagree between layers: use one shared shadow.
- Generated art on "white" is 253–255, not 255: flood-fill near-white from the border only (white inside the object
  survives), feather the rim from whiteness. "Transparent" generated doodles come with a faint white halo: key alpha by
  chroma (`alpha × smoothstep(0.10, 0.25, max−min)`).
- **Generated art whose parts must move or sit in front of code-drawn things: generate them as separate layers**
  (e.g. the wall without the plant, the plant alone on a transparent background). Keying one out of the other leaves
  ghosts and holes.
- To remove a part of generated art, fit a line to the body's outline above and below the part and cut along it.
- Text rendered to images: pad by ~35 % of the font size (+3× shadow blur) — script faces swing past their box.
- Concept mock-ups from generated art: feather the art's edges into the background (~46 pt alpha ramp) when it's
  scaled below full bleed, or its rectangle shows as straight cuts.
- Hanging things that sway: put the pivot above the canvas so the art's cut top edge never dips into view
  (lift = half-width × sin(max angle); assert it).
- Contrast on art backgrounds: render with and without the text; letters = pixels that differ ≥ 60 % of the max;
  background = the text-free frame over the text's box; WCAG ratio.

## 11. Visual defaults that hold up on review
- **Image segmentation of a logo** gives cracks, fringes and a flicker when swapping → build it procedurally.
- An entrance alpha fade on solid objects makes them see-through while they overlap. Objects that slide in from
  off-screen don't need it: fade only soft things (reflections, glows).
- Carousel labels that travel 1:1 with mostly-off-screen items get cut by the screen edge: let them travel less
  (parallax ~0.64×).
- Anything pinned to the top screen edge runs through the status bar: hang it from something inside the layout.
- A sideways strip that keeps stepping runs off the canvas (that's clipping): rest it inside the edge and move content
  through still windows instead.
- Small props read as nothing on a phone: size the hero for a 6-inch screen first, then shrink the decor.
- White script on a photo needs two dark halos (a wide soft one plus a tight one); a single 0.42-alpha shadow measured
  1.07:1 on a bright sky. Frosted cards with white text: tint the glass dark (35–60 % alpha), not light.
- Reels and previews are judged on frame 1: have the hero on screen at t = 0, don't fade it in from 0.
- Real-object card shadow: three blurred copies of the card shape (tight dark contact, mid, wide tinted ambient),
  drifting opposite the tilt and spreading when lifted, instead of one `.shadow`.
- Full-bleed cover images at the top of a card read better than an image inset by the card padding.
- Chips that sit together share one style exactly (glyph style, text colour, weight, chevron); don't encode state as a
  different colour on just one of them. Two icons in one picker must not look alike; check at real size on a phone.
- Spacing inside a card: the gap below the last row equals the side gap to the same items (measure from the visible
  edge, not a selection ring).
- Contrast: Apple's link blue #007AFF is only 3.6:1 on the #F2F2F7 grouped page; #0062CC is 5.2:1 (dark #409CFF 6.0:1).
  In dark mode system brights glare on black: prefer muted inks and ~12 % hue fills, keep text pairs ≥ 4.5:1.
- Onboarding copy: say the feature and the benefit in plain words, one idea per page; poetic or abstract lines read as
  AI-written.
- Chrome that must move with a 3D page (dots, Continue): print it on the page in the web layer and keep an invisible
  native Button over it (contentShape only) whose ButtonStyle reports `isPressed` to JS so the printed button dims.
- Report a page change to SwiftUI when the move is visibly done (|u − target| < 0.03), not when the spring's tail
  settles (0.4 s of a stale button otherwise).
- **Hero clocks on pages that get uncovered:** start the hero while the page underneath is revealed, KEEP that clock
  when the page lands (no restart jump), and reset every other page to t = −1 on settle so the next reveal never shows
  a half-played hero. Per-frame lerps must snap when t < 0, because hidden pages don't get update calls.
- When words are open ("appear and become larger", "comes to the centre"), ask with options BEFORE building; a guess
  is easy to get wrong.
