# Craft: motion, interaction and visual polish

The bar every screen is held to. Read it at the start of a build and again before you report. Physics formulas and
measured constants live in `motion-physics.md`; this file is the judgement around them.

## 1. Decide before you animate

Ask three questions for every moving thing:

1. **How often will someone see it?**
   - Many times a minute (typing, keyboard shortcuts, scrolling a list): no animation, or an instant state change.
   - Many times a day (tabs, toggles, row taps): short and quiet, 100–200 ms, no bounce.
   - Now and then (sheets, menus, toasts, page changes): a normal transition, 200–350 ms.
   - Once (splash, onboarding, a first success, a celebration): this is where the hero motion goes. Longer and
     richer is fine, but it must still be skippable and must not block input.
2. **What job does it do?** Give it one: show where something came from or went (spatial continuity), confirm an
   action (feedback), show a state change, explain how something works, or soften a change that would otherwise
   jump. "It looks nice" alone is only enough for rare moments.
3. **Does it still work with no motion at all?** It must. Motion explains and rewards; the screen must never depend
   on it to be understood.

Restraint is part of the craft: one hero moment per screen, everything else supports it.

## 2. Timing and easing

| What | Duration | Curve |
|---|---|---|
| Press feedback (scale, dim) | 80–150 ms | ease-out |
| Small state change (toggle, check, colour) | 120–200 ms | ease-out |
| Tooltip, small popover, menu | 150–220 ms | ease-out, from its trigger |
| Sheet, modal, drawer | 250–400 ms | spring, no or little bounce |
| Page or screen change | 300–450 ms | spring or strong ease-in-out |
| Hero / onboarding moment | as long as the story needs | physics (motion-physics.md) |

- **Exits are faster than entrances**, about 60–75 % of the entrance time. Leaving should never hold up the user.
- **Entering → ease-out** (starts fast, so the response feels instant). **Moving on screen → ease-in-out.**
  **Constant motion (spinners, marquees, progress) → linear.** Avoid plain ease-in for UI: the slow start reads as lag.
- The stock curves are too soft. Use strong ones:
  - ease-out: `cubic-bezier(0.22, 1, 0.36, 1)`
  - ease-in-out: `cubic-bezier(0.76, 0, 0.24, 1)`
  - sheet / drawer: `cubic-bezier(0.3, 0.75, 0.05, 1)`
- Faster feels better. A loader that spins quicker makes the same wait feel shorter; a 180 ms menu feels more
  responsive than a 350 ms one.
- Stagger lists and grouped entrances 30–60 ms per item, capped so the last item starts within ~300 ms.

## 3. Springs

Springs are the default for anything that moves on screen, because they can be interrupted and they keep velocity.

- Describe springs the way iOS does: **damping ratio** (1 = no overshoot, 0.7–0.85 = a little life, < 0.6 = playful)
  and **response** (seconds to get most of the way there).
  - Standard UI move: damping 1.0, response 0.35–0.45.
  - Something thrown or flicked: damping 0.75–0.85, response 0.5–0.6.
  - Playful pop (badge, sticker, success mark): damping 0.5–0.65, response 0.3–0.4.
- SwiftUI: `.spring(duration: 0.4, bounce: 0)` for UI, `bounce: 0.15–0.3` only where play is wanted;
  `.snappy` for small controls, `.smooth` for layout, `.interactiveSpring` while a finger is down.
- Keep bounce out of serious, frequent UI (settings, forms, money). Put it where touch or delight lives.
- **Interruptible always:** a new target starts from the current value and velocity, never from the start.
  Keyframe or fixed-duration animations restart from zero, so don't use them for anything a user can interrupt.

## 4. Entrances, exits and presses

- Nothing appears from nothing: enter from scale 0.9–0.97 plus opacity, or slide a short distance (8–24 pt) plus
  opacity. Never from `scale(0)`.
- Things leave the way they came, so the user's mental map holds (a toast that rose from the bottom drops back down).
- Popovers and menus grow from the control that opened them; full-screen modals grow from the centre.
- Every pressable thing answers the touch: scale 0.96–0.98 or a dim, on touch-down, released with a quick spring,
  plus a light haptic for primary actions.
- When a cross-fade between two states looks like two objects swapping, add a short blur (2–4 px) at the midpoint
  so the eye reads one thing changing.
- Solid objects that overlap should not fade in (they turn see-through); fade only soft things like glows.

## 5. Gestures

- The thing under the finger moves 1:1 with it. No lag, no easing while dragging.
- On release, hand the finger's velocity to the spring (`initialVelocity = finger speed / remaining distance`).
- **Decide by projection, not position:** project where a flick would land
  (`end = position + velocity × decelerationRate / (1 − decelerationRate)` with rate ≈ 0.998 per ms) and snap to the
  nearest stop. A quick flick should be enough to dismiss; nobody should have to drag past a far line.
- Past a limit, resist instead of stopping dead: `offset = limit × (1 − 1 / (overshoot / limit × 0.55 + 1))`.
- Once a drag starts, ignore extra fingers, and keep tracking even if the finger leaves the element.
- Let a moving thing be grabbed mid-flight; never lock input during an animation unless the action is destructive.
- Give a haptic tick when a threshold is crossed (snap points, pull-to-refresh trigger), once per crossing.

## 6. Interaction anatomy

Write every interaction down as four parts before building it:

1. **Trigger**: what starts it (tap, long press, drag, a value change, the system).
2. **Rules**: what is allowed while it runs, what cancels it, the end states.
3. **Feedback**: what the user sees, feels (haptic) and hears (only if sound was asked for).
4. **Repeat and change**: what happens the second and the hundredth time; whether it should calm down.

Patterns that hold up on iOS:

- **Button:** press scale 0.97 + dim, loading swaps the label for a spinner at the same size (no width jump),
  success morphs to a check for ~1 s, then returns.
- **Toggle:** knob on a stiff spring, track colour fades with it, a selection haptic at the end.
- **Sheet:** follows the finger, snaps to detents by projection, dim behind it at ~20 %, no full-screen blur.
- **Toast:** rises 12–16 pt with opacity, auto-dismisses after 3–4 s, can be swiped away, announced to VoiceOver.
- **Error:** a short horizontal shake (3 cycles, ~6 pt, 300 ms) plus an error haptic and a clear message; never
  shake without saying what is wrong.
- **Loading:** a skeleton that matches the real layout for waits over ~300 ms, a spinner only for small areas;
  content cross-fades in, never pops.
- **Counters and numbers:** roll digits with tabular figures so the width doesn't jitter.
- **Pull-to-refresh / swipe actions:** reveal grows with the pull, a haptic at the trigger point, spring back if
  released early.

Haptics map: light impact for presses, selection for picking and snapping, success / warning / error notifications
for outcomes, medium or heavy only for something physical landing. Prepare the generator before the moment.

## 7. Accessibility

- Always build the reduced-motion version: same order, short cross-fades, no squash, overshoot, spin or parallax.
  SwiftUI `@Environment(\.accessibilityReduceMotion)`; in the web layer read the flag from native.
- Touch targets at least 44 × 44 pt even when the visible control is smaller (expand the hit area, not the drawing).
- Text contrast at least 4.5:1 (3:1 for large text and icons). Check muted greys and brand colours on their
  real backgrounds, in light and dark.
- Support Dynamic Type for reading text; let layouts wrap instead of truncating.
- Every icon-only button gets an accessibility label; announce toasts and results.
- Never convey state by colour alone; pair it with an icon, a label or a shape.

## 8. Performance

- Animate transforms and opacity. Animating size, padding or layout re-lays out every frame.
- In SwiftUI, keep animated views small and isolated; avoid animating a view whose body does heavy work, and avoid
  large `.blur` or material changes per frame.
- In the web layer: one render loop, no per-frame allocations, textures uploaded before the clock starts.
- Budget: 60 fps (16.7 ms) on device, 0 frames over 25 ms on a replay. Measure, don't eyeball (testing.md).
- Low Power Mode caps web views at 30 fps; turn it off before judging performance on a phone.

## 9. Visual polish

- **Concentric corners:** outer radius = inner radius + padding (see SKILL.md).
- **Optical alignment:** centre icons and play triangles by eye, not by box (a triangle sits ~1–2 pt right of centre);
  round shapes slightly overshoot the line that square shapes sit on.
- **Depth:** build shadows from two or three layers (a tight dark contact shadow plus a wide soft ambient one),
  tinted by the surface colour, never a single grey blur. Lifted things get softer, wider shadows.
- **Borders:** hairlines at 0.5–1 pt with low-alpha ink read cleaner than solid grey lines; on dark surfaces, a light
  top edge sells depth.
- **Spacing:** pick one 4 pt grid and keep it; equal gaps where things are related, bigger gaps between groups.
  Measure from the visible edge.
- **Icons:** one family, one weight, sized to the text they sit beside; icons that change with state should morph or
  cross-fade, not snap.
- **States:** design every control for rest, pressed, disabled, loading, error and empty, before calling it done.

## 10. Typography

- SF Pro (or the design's font) with the platform's size-specific tracking: large titles slightly loose, body near
  0, small captions a little open. Copy the Figma letter spacing exactly when given.
- Line height about 1.2–1.3 for headings, 1.4–1.5 for reading text; tighter for big display type.
- Use tabular figures for anything that counts, ticks or aligns in columns (`.monospacedDigit()`).
- Hierarchy from size and weight first, colour second. Two or three sizes per screen is usually enough.
- Balance short headlines so they don't leave a single word on the last line; never truncate a headline.
- Use real quotes and apostrophes (’ “ ”), a real ellipsis (…) and non-breaking spaces between numbers and units.

## 11. Colour

- Define colours as named roles (background, surface, ink, muted ink, accent, danger), with light and dark values,
  and use the roles, never raw hex in views.
- Dark mode is not inverted light mode: lift surfaces with lightness, mute bright accents, avoid pure white text on
  pure black for long reading.
- Tint neutrals slightly toward the brand hue so greys don't look dead.

## 12. From Figma to code

1. Pull ground truth first: a screenshot of the frame, then the design context (sizes, colours, fonts, effects),
   then the node tree. Treat generated code from Figma as a reference to translate into SwiftUI, never as final code.
2. Reuse what the project already has (components, spacing, colour roles) before creating anything new.
3. Export every icon and image from the file at full scale; never redraw an icon by hand or leave a placeholder.
   SF Symbols map back to `Image(systemName:)` by name.
4. Derive the arithmetic (grid, spacing steps, radii, type scale) instead of copying one-off numbers.
5. If the file has prototype motion, read its timing and curves and match them; Smart Animate durations are the
   designer's intent.
6. Prove fidelity by measuring: put the build next to the Figma screenshot at the same scale and compare positions,
   sizes and colours numerically (research-and-tools.md, testing.md). Fix until they match.

## 13. Rive and Lottie

Use them when the design ships `.riv` or Lottie files, or when the part is classic 2D vector character animation.
Play supplied files as they are; don't rebuild them by hand. Keep text and buttons native on top, and preload the
file before the first frame like any other asset.

## 14. Review before you report

- Does each animation have one job, and is frequent motion short and quiet?
- Entrances ease-out, exits faster, nothing from scale 0, presses answer on touch-down?
- Springs interruptible, velocity carried from gestures, flicks decided by projection?
- Reduced-motion path built and checked? Hit areas 44 pt? Contrast measured?
- Nothing clipped, concentric corners, consistent spacing and icon weights?
- Numbers measured on device: frame times, arrival before the next phase, alignment with the design?
