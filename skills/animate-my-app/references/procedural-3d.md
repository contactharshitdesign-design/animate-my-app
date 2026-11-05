# Procedural hero parts (three.js)

Build hero elements, don't cut them from images: an image cut into parts cracks, fringes and flickers; a part you
model yourself can squash, light and cast shadows. The recipes below come with measured constants — start from them.

## 1. Clay letters / clay objects
1. Draw each glyph as a 2D outline in em units: `roundedPoly(points, radii)` for straight-stroke letters
   (concave corner radius ≥ the bevel B or it folds), `superellipse` for O-like bowls, Béziers for D/S curves,
   holes as reversed paths. Match the reference logo's proportions by eye against the Figma export.
2. 2D signed distance to the outline (segments from `shape.extractPoints(24)`), grown by `B = 0.06` em.
3. 3D field = rounded extrusion ("pillow"): `R_ROUND 0.105`, core half-thickness `0.05`, plus value-noise lumps
   only near the surface (`±0.011` + `±0.0025`) = hand-squished clay.
4. Mesh with **surface nets** (grid 0.014 em), normals from the field gradient (smooth, no cracks), fix winding.
5. `MeshPhysicalMaterial` (roughness 0.55, sheen 0.35) + `onBeforeCompile`: simplex bump (lumps, grain,
   fingerprint ridges `sin((0.66x+0.92y)·150 + noise)`) via `perturbNormalArb`, colour mottling ±7 %.
   Set `customProgramCacheKey`.
6. Light: hemisphere (white / warm grey 0.95) + key 3.7 from upper-left with **VSM** shadow (radius 22,
   20 samples, 2048 map), fill 0.5, rim 0.55. Tilt the word back `rotation.x = -0.12` so tops read.
7. Shadows: per-object contact blob (radial gradient canvas texture, warm dark tint) + very faint ambient
   `ShadowMaterial` catcher (opacity ≈ 0.055). Heavy shadows look wrong on clay.
8. Colours: pass hex through `new THREE.Color(hex)` for lit materials; for flat "exact brand colour" shaders
   parse hex as **raw sRGB** (THREE.Color linearises → too dark).

## 2. Self-painting brush background
- The paint is a shader, not an image: theme colour, clay-like body, wet sheen, ragged edges.
- Offline bake (Python/numpy) of a **stroke time map**: boustrophedon strokes along guide rows from the art's
  painted area; per texel: first-touch time, body height, |across| (RGB only — browsers premultiply alpha, which
  corrupts data in A). **Pad the map** (40 texels each side) so brush ends are never cut; the bake asserts no paint
  touches the map edge. Clamp side overflow so paint can't hit the screen edge.
- Shader: coverage = ragged bristle head (`uP - tFirst - noise`) × dry-brush edges; height from baked body +
  continuous grain noise; normal from `dFdx/dFdy(height)`; light `1 + 0.45(n·L - L.z)`; wet sheen just behind
  the brush. `uP` 0→1 over 900 ms. Gate coverage when progress ≤ 0 (or a blob shows at uP = 0).
- Shader seams across strokes → bake blended heights on the CPU instead of mixing per-stroke in GLSL.

## 3. Illustration → animatable pieces
- Classify pixels (hue/saturation/value) into paint vs objects; connected components → characters, clouds,
  stars; merge crumbs only if they touch a piece.
- **Edge unmixing**: band pixels are un-blended from the local paint colour so no fringe remains.
- Attach each piece's cast shadow (shadow = darkening of the paint near the piece) as semi-transparent pixels.
- Export tight PNGs + a layout JS (normalised boxes, paint guide rows/radius/colour).
- If the source art itself is cut (e.g. an object eaten by a mask), **repair it** (rebuild the outline from
  circles/lobes, fill with the object's own colour + borrowed grain + measured edge-shading profile). Never ship a
  visibly clipped piece.

## 4. Other parts
- Morphs/liquid: SDF blends in a fragment shader or metaball surface nets.
- Particles/confetti: instanced meshes, one physics step per frame from the shared clock (deterministic replay).
- Anything driven by time must be a pure function of `t` (or re-integrated from t = 0 on replay) so replays match.

## 5. Split key ring + printed cards
- **Split ring**: two-turn helix tube (`P(s) = C + R(cos s·u + sin s·w) + n·offset(s)`, offset steps one wire
  diameter per turn), parallel-transport frames, ends tapered and placed off-screen. Orientation measured from a
  reference photo (ellipse axes → radius and tilt; the hole sits at the end of the long axis).
  Chrome = `MeshPhysicalMaterial` metalness 1, roughness ≈ 0.2 + a canvas-drawn studio equirect through PMREM
  (soft boxes, mid-grey horizon, a few dark flags). Too-bright env → washed out; too-dark → thin black wire.
- **Holes are real**: a printed black dot on a solid card "breaks" the wire where it meets the surface.
  Cut the hole in the extruded shape (`shape.holes`), keep the printed rim, and let the darkness come from physics:
  a shadowed table disc under the stack seen through the aligned holes, dark hole walls, and the wire's soft cast
  shadow on the top card.
- **Printed cards**: bake each face offline: fill + art (Figma FILL = cover, clipped by the card when "clip
  content" is on) + hole + inner-shadow rim, at 3× with 4× supersampling. Mesh = `ExtrudeGeometry` of the rounded
  rect (face at z = 0); a raw-sRGB `ShaderMaterial` whose shade is exactly 1 at rest, so resting colours match
  Figma; back face = fill × 0.96; dark sides.
- **Shadows = a real shadow map, never decals.** Projected quads and baked shadow stickers pop and vanish whenever
  a card lifts. Render a depth map from the light every frame (`WebGLRenderTarget` + `DepthTexture`, ortho light
  camera, casters on layer 1, `scene.overrideMaterial` = colourWrite-off material) and sample it in the card
  `ShaderMaterial`: blocker search → penumbra ∝ blocker gap (contact-hardening, PCSS-lite) → 7×7 PCF; darken by
  ~0.36 so sky light remains. **Receiver-plane depth bias** (solve dz/duv from `dFdx/dFdy` of the shadow coord) or
  the tilted card shadows itself in stripes. Resting colours must still match Figma (measure it).
- **Lifting a card off a stack** pivots about its support edge (the far side of the hole), never about an axis
  through the hole or the tilted wire, or the corner beyond the hole dips into the cards below and gets cut.
  Slide the hole along the wire as it rises (in-plane rise·cot(tilt)), and let the ring be carried up by that
  card (spring-follow its lift) so the wire's front curve never ends up inside the card.

## 6. Metal objects with glow, three.js core only
- Model: `ExtrudeGeometry` of a rounded-rect `Shape` with a keyhole as a hole (bevelEnabled, 5 segments);
  shaft + bit as one polygon outline; ring = `TorusGeometry`; banded collar = 2 cylinders. Pivot the root at the
  object's middle if it somersaults about its centre, body offset inside.
- Engraving: a canvas drawn twice: a colour map (dark lines) and a height map → normal map (Sobel in JS).
  ExtrudeGeometry caps are material group 0 with UV = shape x/y: remap to 0..1 and mirror u on the back cap
  (normal.z < 0) or the back reads mirrored. Text on an arc: draw glyph by glyph, rotated.
- Reflections: build a tiny studio scene (back sphere + a few emissive planes) and `PMREMGenerator.fromScene`; no
  HDRI download needed. A second PMREM without a coloured bounce stops warm metals reading red.
- Glow without addons: MSAA HalfFloat scene target (`samples: 4`, check EXT_color_buffer_(half_)float) → bright
  pass at 1/2 → 4-level separable blur chain → one composite shader (background gradient + scene + bloom + analytic
  star glints → ACES → sRGB + dither). Star glints are uniforms (pos, size, intensity, angle), placed by projecting
  object points.
- "Lights up" moments: scale envMapIntensity over time (dim while assembling, a 14× Gaussian flash when the face
  swings to the light, full once the glow is up).
- ExtrudeGeometry is unwelded: `computeVertexNormals` gives flat bevel facets that chrome shows as stripes. Weld by
  rounded position (Map of "x,y,z"), set an index, then `computeVertexNormals` — fully bevelled shapes go smooth.

## 7. Glossy floor reflections and discs (product-shot look)
- A full mirror floor (high alpha, long fade) reads as "two objects". A front-lit product shot on dark gloss shows
  only the bottom of the object, dim, gone within ~a quarter of its height, highlights not repeated. Recipe: no floor
  mesh, no contact shadow, no light pool. Mirror copy (`scale.y = -1`, y = 2·FLOOR − y), shader fade by world
  distance below the floor: `alpha *= 0.22·exp(−d/28)·(1 − smoothstep(60,95,d))`, colour ×0.7, `discard` past 95,
  highlight terms ×0.25 in the mirror. Object hovers 2 pt with an up-only bob. In a linear HDR → ACES pipeline small
  alphas read much brighter than they look in code: judge on the frame. Reflections write depth and draw nearest
  first (`renderOrder = −10 + distance-from-front`) or back ones show through front ones. Settle/bob the object and
  its mirror as a pair so an entrance never dips the object into its own reflection.
- A mirror copy must be lit by the mirrored light (`(L.x, −L.y, L.z)`), or its highlights land on the wrong side.
  To make a highlight show in a short floor reflection, move it to the object's bottom with that object's own light
  direction and boost just that term in the mirror.
- Shine on a flat disc: a directional Blinn spec is constant over a flat face (N·H the same everywhere), so it shows
  nothing. Use the groove tangent: `pow(1 − dot(T,H)², 30)` gives two narrow wedges through the centre (moves as the
  disc turns), plus a soft gloss band in local coords and a lit-side rim. Tinted discs get it warm-white
  (`mix(tint, 1, 0.55)`), never a hot spot.
- `CircleGeometry` varyings: every triangle shares the centre vertex, so per-vertex radial/tangent directions
  interpolate wrong (and rotate with the mesh). Pass the mesh's world X/Y axes as varyings (constant) and build
  radial/tangent per pixel from the local position.

## 8. Racks, crates and wheels of flat items (records, cards, sleeves)
- Sleeves = BoxGeometry translated to pivot on the bottom edge; one ShaderMaterial picks the face by object normal
  (cover from an atlas via a rect uniform, printed back, card edge). Keep all items parallel so the spacing never
  intersects (check `GAP·cos(angle) > thickness`; per-item lean noise > ~0.006 rad makes them cut each other — jitter
  x and in-plane twist instead). A cursor `c` (items flipped) drives each item's target angle `smooth(c − i)`;
  per-item springs give the domino cascade on a flick for free. Shift the group by `c·GAP` so the current item stays put.
- Look-down views: tilt the group, not the shared camera. Before tuning by screenshots, project group-local points
  through the camera in a 20-line script (screen y of key points): it finds a layout in a couple of tries instead of
  many rebuilds.
- Background bins of many items in one InstancedMesh (`instanceMatrix`/`instanceColor` are available to a
  ShaderMaterial under USE_INSTANCING); keep them dim (×0.4) and haze the far end, or they become a striped curtain
  that steals focus. Don't `ShaderMaterial.clone()` per item: it clones textures (one upload each); build each
  material with shared texture refs.
- Scene coherence: every object of a kind shares one orientation unless the story says otherwise. A picked item moves
  in its own frame first (lift straight up its slot, keep its angle), and anything that comes out of it moves in that
  same plane. Check neighbours for interpenetration on paper before building.
- Rotary wheel: N items in radial slots, one InstancedMesh, per-instance cover rect + dim as
  InstancedBufferAttributes; the wheel angle θ drives every matrix each frame. Pick = the back slot (θ snaps so a
  slot sits at π); the picked instance is scaled to zero and drawn as a separate mesh that rises edge-on out of its
  slot, then yaws (short way round, wrap to ±π) to face the camera. A radial rack seen from the front shows the
  front card edge-on: fan every card by the same angle off radial (~29°; check neighbour separation > thickness) so
  the front card shows its face. Lifting "the one at the front": per-card spring toward a narrow bump
  `exp(−(d/0.42)²)` of slot distance from the front — one at a time at rest, and the springs low-pass a fast spin.
- Many overlapping instanced cards are GPU-bound by overdraw: sort instances front to back every frame (write
  matrices and attributes in sorted order; within one instanced draw the order is the draw order, so early-z rejects
  hidden fragments). Measured 27–30 ms → max 23 ms on iPhone.
- Brass/gold that reads as metal: dark base (the room) + broad `pow(N·H,10)` spot + sharp `pow(N·H,160)` glint +
  Fresnel rim + spun rings `sin(r·2.2)`; a flat bright gold reads as paint.
- Images for a screen (album covers): pack into one atlas, `img.decode()` in a promise the boot waits on, then
  `renderer.initTexture` in the boot — nothing loads mid-animation.

## 9. Finger drawing / signing on a 3D surface
- Raycast the touch onto the surface's plane (`ray.intersectPlane`, then `worldToLocal`), and paint on the GPU, not a
  2D canvas: an InstancedMesh of quads, one per pen dab (radius from pen speed), fragment = dome height
  `sqrt(1 − r²)`, `CustomBlending` + `MaxEquation` into a render target (`autoClear = false` while painting). The dome
  heights give the surface shader a real bead to shade: wet = one sharp glint (`pow(N·H, 140)`), drying to matte. A 2D
  canvas texture re-uploaded (with mips) each frame cost 26–27 ms frames on iPhone; the GPU dabs cost nothing
  measurable. Wide/low-exponent highlights on the bead read as a chrome tube — keep the bump flat and the glint narrow.
- An auto-demo signature: design the path offline (draw variants with PIL first) — a generic sine scribble reads as
  "zzz"; a tall first letter, loops of varying size, one rising stroke mid-word, then an underline swept back left and
  a firm dot reads as a real signature.

## 10. 3D illustrations on curling paper pages
- Detailed procedural props: lathe bodies with caps; slot plates; curved plates = open CylinderGeometry segments;
  seams/keyholes painted into a lathe's map after rewriting its uv.y = height; perforated grilles on an extrude cap
  (remap cap uv from position); knurled knobs; TubeGeometry straps; a book page re-bent on the CPU each frame; a
  wax-seal height field (puddle profile, volume kept R²H, stamp impression from a blurred 256² logo height map read
  bilinearly — nearest + 128² gives stair steps and spiky edges); hinged doors and flags on pivot groups with spring
  overshoot.
- Pages that curl in a vertex shader can't host a 3D scene directly: render each scene into a render target and put
  that picture on a page grid with the curl shader. HalfFloat + samples: 4, two shared targets (≤ 2 pages visible),
  viewport/scissor to the scene's size and uv scaled; tone-map in the page shader (Khronos PBR Neutral keeps red
  red), unpremultiply by alpha (shadows are partial alpha on the paper).
- Studio look without HDRIs: PMREM from a small scene of emissive panels; satin red = MeshPhysical roughness 0.36 +
  clearcoat 0.45; ShadowMaterial floor at 0.08 + a radial contact blob.
- Perf: VSM shadows (2048, blur) for two scenes per frame throttled an iPhone to 30 fps after ~20 s (28–36 ms
  frames). PCFSoft 1024 + caching CPU geometry that hasn't changed → 0 frames > 25 ms. Shadow-camera bounds must be
  wide or their edge shows as a faint line on a white floor.
- Things thrown into a slot READ only with their printed face toward the camera while flying (rotation.x ≈ +1.2),
  turning flat only in the last 40 % before sliding in; seen edge-on they are grey slivers.

## 11. Exact UI colours through an HDR/tone-mapped picture
- With Khronos Neutral tone mapping, white 1.0 comes out 0.87. For a 3D element that must hand over to a flat
  printed one, write the INVERSE tone map in its own shader: grey g → g < 0.04: √(g/6.25); g < 0.76: g + 0.04; else
  0.0576/(1 − g) − 0.24 + 0.8 (cap g at 0.99 → white prints 254). For colours, add the same offset to all channels:
  off = m < 0.04 ? √(m/6.25) − m : 0.04 (m = min channel). Unlit shade = 1 when it faces the camera, so the final
  frame is pixel-for-pixel the card.
- Rounded corners on a 3D sheet: shape the GEOMETRY (rows dense near the ends, half-width follows the corner arc),
  keep the texture square — canvas alpha corners give dark fringes and broken premultiplied edges in the render target.
- Matte paint: MeshStandard roughness 0.94, envMapIntensity 0.42, plus `onBeforeCompile` world-space value noise
  ±4.5 % on diffuse (printed-paint mottle, no UVs needed).
- 2D wordmark → 3D decal: project the decal centre/edges with the scene camera at its landed pose, move the 2D mark
  there in the 2D shader (p = from + (p − to)/s), recolour, then cross-fade to the decal at rest.
- Draw shared marks with ONE GLSL function used by both the 2D page shader and the 3D shader so they match pixel for
  pixel at a hand-over.

## 12. Paper plane folded rigidly from a sheet
- Cut the flat sheet (rounded outline) into convex pieces with half-plane clipping along EVERY crease and along the
  pre-image of later creases under earlier folds (a corner flap reflected across y = L ± x lands on the wing line
  x = ±K at y = L − K, so cut there too). Label pieces by centroid: half, flap, wing (wing tested AFTER the flap fold).
- Per vertex compose rigid hinges in fold order but apply inner frames first: flap rotation (about its crease,
  +0.9 pt lift against z-fighting) → wing hinge in the half's own frame → half swings about the centre line.
  Non-indexed geometry + `computeVertexNormals` gives crisp creases. Rodrigues rotations compose layered folds.
- Group frame: x across, y = nose, z = face. Orient with a basis (Y = flight tangent, Z = up made orthogonal,
  X = Y×Z); the plane's MIDDLE rides the path. Fit the plane to a target by choosing the sheet's world scale.
- Proportions: a long sheet folded corner-first gives a short nose and a long tail. Fold order decides where a
  printed mark lands — check it on paper first.
- Glitches found by measuring per-frame difference on a recording: a half folding behind swung past the far edge
  with its back face lit dark (a grey slab); the centre fold reached ~75° before the wings came out (the plane
  collapsed to a sliver and popped); bouncy springs on 180° folds overshot (flaps through the sheet); the centre fold
  had the wrong sign (tent instead of keel). A real plane: the centre crease is the lowest line, halves rise, wings
  fold back out at the top, level.
- Fixes: flat folds use smootherstep (no overshoot, angle ≤ π − 0.02); wings counter-rotate with the halves
  (a3 = a2 − dihedral) so they stay level; paper lit by a soft overhead light (shade 0.84–1.0, back ≥ 0.88) so a
  tilting sheet never turns into a dark band; keep the camera still while it folds.
- Rotations of flags/arms: check the sign with a frame — "up" with the wrong sign hangs down.
- Reading another object's world position: call the PARENT's `updateMatrixWorld(true)` first, or you read a stale
  pose from before the root moved.

## 13. Chrome without HDR files
- Chrome is all environment. Build the environment ONLY from smooth functions in a sphere's shader and PMREM it:
  sky gradient (0.62 → 0.95 linear), a soft gaussian grey band at the horizon (−0.44, σ 0.2 — never black), a moderate
  floor bounce (0.6 → 0.72), plus soft gaussian light lobes (overhead 3.2, σ 0.38 rad; two high side lobes 0.6–0.7).
  Pure white metal, roughness 0.08, NO clearcoat.
- Why chrome looks like "grey with white paint": hard-edged emissive PANELS in the PMREM scene (black flags, slim
  white strips). A mirror (roughness < 0.1) reflects their exact edges → black bars and crisp white lines; clearcoat
  adds a second razor reflection; a too-white sky washes big areas into the page. A dark horizon with no front fill
  reads gunmetal; a pale front card alone reads flat lilac/grey.
- Y2K tint: add a cool-blue strip on one side and a pink one on the other as soft lobes, not hard panels.
- Flat faces need curvature to look like chrome: bend the NORMALS, not the mesh (`onBeforeCompile`, front-facing
  local normal z > 0.85: normal += viewAxisX·qx·k + viewAxisY·qy·0.8k). `modelMatrix`/`normalMatrix` don't exist in
  the fragment shader: pass the view-space axes from the vertex shader. Give each variant its own
  `customProgramCacheKey`.
- Better: **inflate the outline**. Grid over the outline; points outside snap onto it; solve a balloon ∇²h = −1
  with h = 0 at the rim (SOR ω 1.9, ~260 sweeps at 1.5 pt steps, ~30 ms); z = T·√(h/hmax) front and back. A raw
  distance-field height creases along the medial axis (an X-shaped pyramid) — use the Poisson solve. Normals from the
  height field (central differences), not grid triangles. Keep a bilinear zAt(x, y) to lay decals onto the curve.
- Trims in a darker silver (0xa9afba); stickers: map + clearcoat, envMapIntensity ~0.35 or the reflection washes the
  colour out; place them on the OUTER surface (+ bevel size).
- No shadow maps needed: soft radial contact blobs (and a blurred rounded rect for a sheet) scaled/faded by height.
- A glowing die-cut sticker in one texture: draw on opaque black with 'lighter' compositing, mark → R, die-cut (mark
  grown with round stroke, counters filled) → G, glow (shadowBlur cast from off-canvas) → B; the shader colours each.
- MEASURE against the reference: crop the object, take luminance percentiles (p5/p25/p50/p75/p95) of non-background
  pixels. Good chrome references run roughly p25 ≈ 155, p50 ≈ 190, p75 ≈ 210, p95 ≈ 250 with a neutral tint; too
  narrow a spread (e.g. 169–180) reads as satin plastic.

## 14. Seat-view / interior scenes
- Portrait "view from a seat": a wide rectilinear lens (vertical FOV ~100°, horizontal ~58°), like a phone's 0.5×
  photo. Narrower lenses push the sides of the subject out of frame.
- Bottom panel over a 3D view: lens-shift the camera (`cam.setViewOffset(W, H, 0, shift, W, H)`, ~96 pt) instead of
  re-aiming it, so the subject sits above the panel without changing the perspective.
- A map that IS the 3D scene: tiles as one instanced quad mesh (SDF rounded rects + glyph atlas, `gl_InstanceID` for
  the focus tile) on a plane above the room, a single-sided dark plane under them, single-sided inward walls and a
  downward ceiling so a top-down camera sees through the roof.
- Fly-in as an orbit (focus, distance, yaw, pitch) is easy to frame, but its focus must not leave the subject: moving
  the focus to a far target while the distance grows makes the camera dive and come back. Recipe: spin half a turn
  looking straight down → orbit radius → 0 onto the eye point → lift the gaze (three overlapping smoothsteps).
- Fit a 16:9 picture on a wider screen by composing it into a canvas of the screen's ratio with black bars (fit, never
  crop); its 1×1 average colour tints the screen's light on the room. Skip glare/halo around a screen — it reads as a
  glow behind it.
