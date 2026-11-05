# Motion physics — formulas and measured constants

## Springs
`spring(x0, v0, zeta, response, t)` — displacement from target; `w0 = 2π/response`,
under-damped: `e^(-ζ w0 t)(x0 cos wd t + (v0 + ζ w0 x0)/wd sin wd t)`, `wd = w0√(1-ζ²)`.
Apple defaults: move `ζ 1.0 r 0.4`; momentum moves `ζ 0.78 r 0.6` (≈ 7–8 pt overshoot, no jitter).

## Drop-in (letters of a logo)
- Stagger 85 ms, fall 0.23 s from 1.9 em with gravity `y = H(1-u²)` and stretch along motion `sy = 1 + 0.16u`.
- Landing: `y = spring(0, 0.9, 0.5, 0.32, t)`, `sy = 1 + spring(0.16, -10, 0.42, 0.30, t)` (squash + tiny hop).
- Each letter starts with a random tilt (`rz0 ±8–10°`, `ry0 ±30–38°`) springing to its rest tilt
  (`ζ 0.72 r 0.45` / `ζ 0.78 r 0.5`) — reads as hand-placed clay.
- Appear: scale/opacity ease-out cubic over 0.1 s; never from scale 0 on UI. Letters may grow from their own drop
  because they come from off-frame height.

## Volume and grounding
- Always `sx = 1/√sy` (volume-preserving). Baseline-anchored for squash on the ground; top-anchored for the
  trailing jelly in flight. Clamp any downward stretch so the bottom never penetrates the ground it leaves.
- Contact shadow blob per object: opacity `C·e^(-1.25h)`, wider when high, tighter/darker on landing,
  fades ×(1-0.85·airborne) while flying.
- Velocity-only or acceleration-only stretch reads wrong (squashed while climbing) → combine speed stretch +
  jelly + braking squash.

## A jump to the header (shared-element move)
1. Rest beat after landing, then **squeeze** (300 ms, 20 % shorter, wider) with a cosine that is still moving at its
   bottom. A squeeze curve that rests at the bottom reads as a pause, i.e. a bug — never dwell.
2. **Same frame**: launch with a real velocity (700 pt/s) — the position spring gets `v0 = -LAUNCH_V/TRAVEL`.
   Stretch starts that frame: squeeze released with `e^(-t/60ms)` plus a push `0.22·τe^(1-τ)` peaking at 90 ms,
   so the **tallest moment is early in the climb** (~+30 %).
3. Speed stretch `0.22·speed/peakSpeed` + **jelly**: each letter's bottom is a damped spring (ω 58–67, ζ 0.3)
   driven by the root acceleration and an impulse at liftoff; letters lag 0–32 ms (ripple).
4. **Overshoot then braking squash** (`-0.35·braking·(1-speed)`) at the top, settle.
5. Clamp total stretch to [-0.3, +0.5].
A result that reads well, measured: squeeze −14 %, 33 ms near bottom, stretch and liftoff on the same frame (±1),
peak +31 % at 70 ms, overshoot 8 pt.

## Staging
- Compute arrival numerically (`T_ARRIVE`: first time after the overshoot peak within 1.5 pt of target) and start
  the next phase from it (+80 ms). Starting the next phase while the hero is still moving looks wrong.
- Example sequence: logo arrives → paint 900 ms → pieces land when paint is ~80 % down (main figure +720,
  clouds +800 with 110 ms stagger, stars +960 with 70 ms stagger) → headline +200 → button +150.
- Pieces: a figure rises 18 pt with `spring(1,0,0.62,0.5)` plus a 6 % landing squash; clouds drift 22 pt in from
  their own side (`ζ 0.75 r 0.6`), scale 0.9 → 1; stars pop from 0.5 scale with `ζ 0.45 r 0.38` + twist from −0.6 rad.

## Reduced motion
Short cross-fades, no squash/overshoot/rotation, paint fades instead of stroking. Keep the order.

## Gesture-driven 3D card stack on a ring
- **Gesture-driven scenes don't use the timeline engine**: own rAF loop, springs/physics integrated at 240 Hz
  substeps, touches handled in the WKWebView (`isUserInteractionEnabled = true`, CSS `touch-action:none`,
  `user-select:none`). Native buttons call into JS (`stack.next()`); JS posts `index:N`, `haptic:*`.
- **Perspective camera, pixel-exact at rest**: `PerspectiveCamera` at distance D with `fov = 2·atan(H/2/D)` maps
  the z = 0 plane 1:1 onto design points. D ≈ 1100 pt gives a readable 3D tip; at 1700 a lifting card looks squashed.
- **Cards on a ring move ALONG the ring, not about an arbitrary hinge** (a top-edge hinge flip doesn't read as
  "moving through the ring"). Pose = stack pose (height, fan about the hole, swing, pivot on the wire
  `R(wireTangent, lift)`) then the trip `R(ringAxis, phi)` about the ring centre, so the hole rides the wire.
  The top card can only leave by the ring's front curve; it comes back under the stack along the back curve.
  Work out which side that is from the reference before building.
- **Holding** lifts the card about its top edge (solve `lift` so the grabbed point stays under the finger, 1:1);
  **release** commits on finger travel (> 70 pt up, unless coming back down) or an upward flick (> 450 pt/s),
  never on the lift angle (a long lever makes 15 pt of finger = 0.3 rad).
- **Taps** start the motion 3 frames after the event: the touch-up / button press costs the compositor one late
  frame; deferred, it lands while the card is still at rest (measured 28–35 ms hitches → 0).
- **Trip physics**: gravity with the screen as table, `phi'' = −g·cos(phi) − c·phi'` (g ≈ 11): the card slows while
  it climbs towards the viewer, speeds up off-screen, and a critically damped catch spring (0.34 s) takes it into the
  bottom slot. Minimum speed on committed trips.
- Look-dev stills: `?phi=1.4` / `?lift=0.5` freeze the pose (hold the card so physics doesn't take over, and don't
  let the boot warm-up overwrite it).
- Stack order changes at commit; a rolling card's height in the stack is a function of φ (moves to the back only
  while above or edge-on, so it never visibly pops). Fan-out of cards behind = rotation about the ring hole.
- **Headline change** on a card swap: starts the moment the card is let go; the old line moves up ~14 pt while
  fading and blurring out (~0.17 s), the new one rises ~12 pt into place while fading in (~0.26 s, strong ease-out,
  0.12 s after). Going back runs downwards. Per-title offset/opacity/blur state in SwiftUI, the entering title placed
  below instantly (no animation) before animating in.

## Pull-to-refresh with a character
- Make the character feel **generated by the swipe**: beads laid from the Dynamic Island downward (island measured
  y 15–50 pt on iPhone 17 Pro recordings). The head pops in first touching the island, then moves down 1:1 with the
  list (always ≥ 16 pt above the list's top edge). Index beads FROM THE TAIL, so each stays where it was laid and pops
  in just behind the passing head; pulling back pops them away.
- **Pop:** per-bead spring state. In: start at 0.4 with v 5, spring k 520 d 23 (ζ ≈ 0.5, ~15 % overshoot).
  Out: k 1400 d 75 (critically damped, ~0.12 s), vanish below 0.28. Hysteresis on existence (in ≥ 0.12, out < 0.07)
  so the spin's stretch doesn't flicker the bead next to the head.
- **Release:** constant-curvature curl (0.42 s ease-out) into a circle at the slot centre, arc 280° so the head–tail
  gap is small but clear; keep generating beads while curling. Rotation starts 0.12 s in, while still curling.
- **Spins:** two in 1.6 s (sine ease over 4π), head and tail leading/lagging a little each turn. While curled, rotate
  by the angle **wrapped to ±π** times the blend factor — blending the raw angle unwinds whole turns during the uncurl.
- **End:** uncurl (0.4 s ease-in-out); JS posts `collapse` 0.16 s before it finishes so the list starts closing with no
  pause; the beads pop away, head last. Insert new rows only after the last bead is gone (a SwiftUI insert mid-motion
  cost a 62 ms frame).
- Haptics: light tick at the threshold (hysteresis 18 pt), soft one when the head pops away.

## Floor shadows of raster/cut-out art
- Never scale or move a drawn floor shadow with the object, and never split it into per-object pieces that move
  separately: the outline crawls every frame and seams open between pieces. That reads as flicker.
- A lifted part's shadow STAYS ON THE GROUND and slides away from the light by k·h (k from the art: offset of the drawn
  shadow from the contact), its edge softens σ = σ0 + 0.12 h (σ0 = the art's own edge), and it lightens e^(-h/100);
  lit floor opens between the raised part and its shadow. Fading in place looks like a ghost slab.
- Draw it from a SIGNED-DISTANCE map of the shadow (+ its grey, + a rest residual so frame 0 = the art):
  opacity = Φ(d/σ), Φ(x) = 1/(1+e^(-1.702x)). Do NOT fake the blur with offset taps (stepped copies) or by blending a
  sharp and pre-blurred copy (pixels dip then recover = a light-dark blink at lift-off). Owner map (which object
  stands above each shadow pixel) + pose → per-pixel height in the shader.
- The ground under a sole: give the shadow the sole's WHOLE footprint, hidden at rest.
- A landed object stays down: after first contact hold 0 (a damped spring re-lifts it slightly otherwise).
- Contact: clamp every spring at the ground (`max(0, …)`): the overshoot past contact is the impact, not a dip below.
- Lace/strap wiggle on landing: a smooth displacement field (damped wave, amp 3 px, period 0.17 s, decay 0.12 s)
  inside a weight map that is 0 within 10 px of the object's own outline, so the silhouette never moves.

## Page curl
Paper sheet = fine grid in page points; every mesh on the page shares one set of curl uniforms. Cylinder of radius R,
axis through A with normal N: d = dot(p − A, N); d ≤ 0 flat; 0 < d < πR wraps (q = base + N·R·sin(d/R),
z = R(1 − cos(d/R))); beyond πR lies flat face-down at z = 2R. Paper wobble: R·(1 + flex·sin(πy/H)) with flex from
the radius spring's lag and tilt velocity (±0.4). Springs: tilt ζ 0.42 / 0.42 s, radius ζ 0.5 / 0.34 s (target R0 52 +
speed), release progress ζ 0.9 / 0.46 s with the finger's velocity handed over; commit if u + v·0.18 > 0.5. Shade from
the bent normal (back side slightly warm grey), and darken the page below near the bulge (exp falloff). Measured on the
iPhone 17 Pro Simulator: p50 17 ms, 0 frames > 25 ms during drags and releases.

## Paper dropped onto a desk, seen from above
Height h above the desk: h = 230·(1 − p)^1.5 over a 1.0 s fall (fast, then the air cushion). Scale 1 + h/620
(nearer the camera). Drift in from off-screen with ease-out; sway x += 24·sin(ωτ + φ)·(1 − p), rock
r += 0.2·cos(ωτ + φ)·(1 − p) with ω = 2π/0.92. Flutter = tilt about its width: scaleY 1 − 0.18·(1 − p)·(0.5 + 0.5 sin 2ωτ).
Cast shadow: offset (1.5 + 0.28h) down-right, σ = 2.6 + 0.12h, opacity 0.13·e^(−h/170) via an SDF + logistic step.
Stagger 0.46 s so each lands before the next (gate on arrival). Sheets below get nudged by each landing:
1.4 pt·(t/0.07)·e^(1 − t/0.07) the way the newcomer travelled. A soft haptic on every landing.

## Ribbon bookmark
A strip with 3 columns (the middle stops 13 pt short for the V-cut tail). It slips out in rigid free fall (0.4 s), and
the tucked end catches: a 0.16 s stretch spring (barely visible), then sway from the exit edge,
x = 13·e^(−t/0.9)·sin(2πt/0.9)·f^1.7 + 3.5·e^(−t/0.42)·sin(2.76·…)·f^3.2, with f = distance below the exit / visible
length. Satin shading: a sheen just left of centre, darker edges, faint grosgrain ribs. Hang it from something inside the
layout, not the top screen edge (it would run through the status bar).

## Paper sheets as cloth (Verlet / PBD)
- Sliding out of a slot and falling flat: a strip of ~61 points, Verlet at 240 Hz simulated ONCE at boot (≈ 10 ms),
  24 PBD iterations: length constraints, bending = pull toward neighbours' midpoint (kb 0.22), floor y ≥ 0.4 with
  friction (μ 0.6 per substep), the container as walls. Air: damp velocity ACROSS the sheet hard (8/s), along it
  barely (0.8/s): that one rule gives the edge-first slide, the glide and the soft "air cushion" flop. g 5000 pt/s².
- The slot is a RAIL with one degree of freedom: everything still inside slides as one body, moved only by the length
  constraint to the first free point (projected on the rail's tangent). A kinematic feed instead launches the paper
  across the floor.
- Sliding down out of a pocket: a vertical rail (gravity acts fully along it, NOT scaled by the share inside — that
  leaves the last points stuck), bend forward 0.25 rad just under the exit so the foot leans out; g 5000, cross damping
  10, floor μ 0.9. Don't add ad-hoc position "walls" at the exit: one shove can flip the sheet over backwards.
- Tune it offline in node first (same code), print tip/mid/top per 0.05 s and "free at / flat at" times.
- Make the landing exact: blend the last 0.26 s to the ideal flat pose, then frame the next screen's camera on the
  sim's final foot position, so the 3D sheet and the printed 2D card coincide and the switch is invisible.
- Anything that rides in a moving container must take the container's offset while idle, or it shows outside it
  during the entrance.
- Camera from 3/4 front to straight down: interpolate target, log-distance, pitch and yaw separately; Euler order
  'YXZ' (`lookAt` is singular at straight down). Fade the floor shadow before the end (PCF halo around a resting sheet).

## Thrown-in object that brakes to a stop
- **Flight = viscous friction, not a spring**: x(t) = target + (start − target)·e^(−t/τ) per axis. Max speed at
  t = 0 (it enters already moving, from off screen), monotonic braking, never overshoots. Different τ per axis bends
  the path (τy 0.118 < τx 0.15: rises first, drifts sideways as it slows). Measured on device:
  1700 → 1100 → 690 → 460 → 230 pt/s per 50 ms. A spring from rest starts slow (wrong); a spring with a big v0 overshoots.
- For a readable curved path: progress along a quadratic Bézier with u(t) = 1 − e^(−t/0.21). "Quick" still means
  every stage must be readable: ~1 s flight, ~2 s for a reveal that follows.
- **Secondary motion from the real acceleration**: a handle = pendulum spring driven by the acceleration across it
  (swings when braking); tilt ∝ speed (foreshorten along the motion: q += (1/cosθ − 1)(q·d̂)d̂) with the highlight
  sliding along; height ∝ speed → shadow offset/blur shrink as it touches down.
- **Gate the next step on true arrival** (dist < 4 pt and speed < 45 pt/s), not a fixed delay.
- **Stretch with volume kept**: width × √(rest/length) while a bar overshoots (thins at the peak, thickens back).
- **Ink "coming out of" a bar = capillary rise**: front height ∝ √t (Washburn), per letter once the bar tip passes;
  front edge = noise stretched vertically (columns climb unevenly) + a blurred-mip halo while wet, dries crisp. Wet
  halos drawn from a blurred mip need padding in their texture box, or the box edge shows as a line.
- Simulate the whole thing once at 240 Hz into a Float32Array and sample it: frame-rate independent, and any moment
  can be frozen for look-dev (`?splash=T`).
- 3D-looking black objects in one fragment pass: SDF ring/capsules, tube normal n = (r̂·u, √(1−u²)) across the width,
  glossy black = base 0.03 + Blinn spec (pow 70) + a soft "window" reflection + Fresnel of the WHITE PAPER at grazing
  edges (that bright rim is what sells black-on-white 3D). Keep contact shadows subtle (≤ ~7.5 % darkening, wide blur).
- Joining a stroke to a round letter: make the bar TANGENT to the O (its lower edge = the O's lowest point, so the
  bottom contour runs curve → straight with no step), and add a smooth-min fillet ONLY at the outside corner where the
  bar's top edge meets the O. An unrestricted smin also rounds the counter, adds a lump and leaves seams; gate it to
  that region, clamp it out of the counter with max(fillet, −dCounter). Verify by scanning the bottom edge per column
  (monotonic, no step) and counting light specks inside the ink (0).

## Auto camera (zoom toward touches) without the lurch
A single critically damped spring jumps to max acceleration the instant its target changes (felt as a glitch when a
zoom kicks in). Run each value through two critically damped springs in series (same ω): zero acceleration at start
and end, an S-curve. Response 0.42 s → 97 % in 0.58 s; start it ~0.55–0.75 s before the touch, hold ~0.7 s, merge
touches < 0.9 s apart. Measured vs one 0.45 s spring: peak accel 59.7 → 12.1 /s², peak jerk 2412 → 250 /s³. Precompute
the track (120 Hz) so preview and export match, and draw the camera in the same render pass as the picture (not a UI
transform on top) or it can sit a frame apart and wobble.

## Turntable physics
Record: φ, ω (rad/s), 33⅓ rpm = −3.49 rad/s (clockwise from above). Held: φ follows the finger's angle about the
centre (scaled down within 18–58 pt of the centre, where the angle is twitchy); ω = mean finger angular speed over the
last 90 ms; release = flick (clamped ±34 rad/s). Free: ω → target with τ 0.55 s (motor; 0.7 s braking an over-speed)
or → 0 with τ 1.9 s (coasting). Tonearm: yaw spring (held response 0.12 s ζ 0.85, free 0.42 s ζ 0.72), lift spring
0.28 s ζ 0.48 with a floor (the stylus can't enter the vinyl: bounce × −0.25); needle down when lift < 0.012 rad over
the grooves; while playing the groove radius walks inward at 0.35 pt/s × speed. Sound reads the same numbers: a
synthesized loop played at ω ÷ 33⅓ (scratches bend pitch and reverse), crackle × speed.
- A turntable reads right when the record is level and seen from ~30–35° above (tilt 0.98 rad, no roll), the tonearm
  pivot sits back-right and the arm runs toward the viewer, and the base stands on the deck. Ground it with a soft
  floor contact shadow. The arm's shadow can be analytic in the record shader: arm + headshell as segments, each end
  pushed along the light by its height, rotated into the spinning record's frame; softer where higher. A shadow only
  reads on dark vinyl if there's a broad soft sheen for it to cut. Check placement with a debug tint first.

## Vinyl look (shader)
Grooves run along the tangent T: anisotropic sheen pow(1 − (T·H)², 120). Diffraction rainbow: one sector where the
grooves face the light, exp(−((T·(L+V))/0.45)²) × smoothstep on (L+V)·radial (sign picks the side); hue runs with the
radius (red at the rim → violet by the label), dark groove bands through it. Thin bright gaps between tracks, a smooth
lead-in and run-out, faint ring texture with an angular term so the spin is visible in the grooves, not just the label.
Light direction = base + phone tilt, so tilting moves the rainbow. A shader "flow" term with sin(angle × 4) prints a
square four-lobed pattern on a disc; use non-integer-looking combinations (3 and 7) at low amplitude.

## Synth sound that reads as the material
"Noisy" usually means hiss: measure the spectrum. A paper swish with 45 % of its energy above 3 kHz reads as hiss; a
3-pole low-pass (cut 0.22), sin³ envelope and 11 Hz flutter (1.4 % above 3 kHz, centre ~720 Hz) reads as paper. Too
low a cut (centre ~108 Hz) reads as rumble.

## Squash press (molten puck)
Puck = lathe rebuilt per frame from a superellipse profile (exponent 3 → 15 as it flattens), volume kept:
r = √(V/πh). Plastic: h only ever decreases (h = min(h, gap)); a half-press stays half-squashed. Ram: held → v → −360
pt/s in air, −(30…140) pt/s once touching (viscous, slower as it thins); released → spring back to open (0.8 s,
ζ 0.92). Heat cools only after lift-off (τ 1.4 s); the rim keeps heat longest. A finished piece is ejected
(slides out, easeIn²) before the next one drops (gravity 2200 pt/s², squash-wobble on landing). Check numerically:
3 cycles at 120 Hz, minimum clearance between the press and the puck ≥ 0.

## Multi-screen 3D onboarding transitions
- Auto-actions after "settled for N s" must not re-fire on the thing that was just undone: remember the put-back item
  and only auto-pick once the person moves on to another; give a tap as the explicit way to redo it.
- iOS-style back swipe on a scene with scripted screen transitions: drive the forward transition in reverse rather
  than adding a new animation — keep each transition as a start time `tGoN` with `e = easeInOut((t − tGoN)/T)`, and
  while the finger is down set `tGoN = t − T·invEase(1 − p)` (inverse of the easing, so the scene follows the finger
  1:1). Release: past 40 % or a flick (> 1.2 widths/s) finishes, a flick back cancels; a critically damped spring
  carries the release velocity. Cancel: restore the saved `tGoN` (the screen's own timeline resumes; nothing replays).
  Catch the edge touch with a window capture listener + stopPropagation so no screen's own drag sees it.
- Copy during a back swipe: cross-fading two centred headlines in place reads as a double exposure. The current copy
  is gone by 50 % (drifting with the scene), the previous fades in over the second half. Switch the native screen
  state with `Transaction.disablesAnimations` so enter/leave transitions don't replay a fade (flash).
- Spin-and-settle wheel: drag maps 1:1 at the radius the finger is on (pt per radian = that radius); release velocity
  carries on with exponential friction (τ ~0.8 s); once |ω| < ~0.9 rad/s hand over to a spring (0.45 s, ζ 0.85) aimed
  at the slot nearest θ + ω·0.35, so it never stops between slots or snaps backwards.
- Native copy must move with its illustration, not fade in place ("text already there, then the illustration comes
  up" looks wrong). Mount every screen's copy from launch, give each a position on the same axis as the 3D move
  (−1000 behind, 0 current, +1000 waiting), animated with the scene's own curve and duration (JS cubic easeInOut
  over 0.95 s ≙ `.timingCurve(0.65, 0, 0.35, 1, duration: 0.95)`); the outgoing copy also dissolves in ~0.4 s.
- Copy reveal follows the illustration's last arrival beat, not the screen change (needle drops, puck lands, records
  settle). Then title +0.1 s, subtitle +0.3 s, CTA +0.5 s (blur 10 → 0, 12 pt rise, ζ = 1 spring). Let each scene post
  `beat:N` (once per visit, tracked against that visit's start time) and keep a native fallback timer; a screen
  re-entered by a back swipe keeps its copy. Don't depend on one-shot scene cues for re-entry.

## Small physical moments
- Pixel-game collisions: find the hit moment by stepping the motion 1 ms at a time and testing sprite pixel overlap,
  at load — a freeze on contact must land on the exact frame. Sweep the jump parameters first: a weak hop that
  reliably clips the obstacle's top reads as a trip. Hit-stop: freeze ~0.9 s, then let gravity drop it.
- Things that fly into slots (digits into code boxes): travel sideways early (`easeOut`) and rise late (`smoothstep`),
  so they cross the open space under the row and enter their own slot from below; check every path against the other
  slots' rects numerically. Rising through the slot and dropping back reads as a glitch.
- Ballistic "lands in its slot": flight time = 1.16·√(2·dy/g) so it rises just past the slot and drops in.
- Parallax layers that must start and end in set places: pick each layer's rest position, x0 = rest + total_scroll·K,
  and sweep K until the start positions are also on screen and well apart.
- **Stacking coins**: stacking reads only if each coin LANDS on a coin that has already landed (8 ms gaps with a 0.16 s
  fall drop a whole stack at once — it reads as a sliding column). Recipe: short fall (18 pt, `y -= fall·(1−u²)`,
  0.09 s) so each landing is crisp; gaps start at 42 ms and shrink 10 % per coin to a 22 ms floor (poured from a hand);
  a falling coin is solid within 30 ms; landing = 22 % squash decaying 45 ms + 1.5 pt wobble; stacks start 25 ms
  apart; one light haptic per stack on its last coin (one per coin is too many). A 13-coin stack builds in ~0.42 s.
  Coins wait for their container: start after the panel's open spring is ~90 % done.
