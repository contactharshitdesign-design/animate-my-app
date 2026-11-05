# Photo try-on layers — mix-and-match pieces on a photographed person

A pipeline for an app where clothing pieces (tops, bottoms, bags, hats) swap and morph on one photographed model.
1. Generate the person once with an image model, then one image edit per item with the same reference
   ("keep everything pixel-identical, only change: …"). Renders drift a few px and in colour.
2. Cut the model out of every render (background removal), decontaminate edges, put all on one white page with one
   shared floor shadow (faded by distance from the feet), and carry each render's colour drift measured on the old
   backdrop.
3. Extract each piece as a layer = |render − base| in its body zone, cleaned (open/close/fill/largest parts),
   colour-split against what surrounds it.
   Draw order: shoe band, bottoms, shared ARMS (from the base), tops, bags (forearm cross-fade), hats.
   Bottoms cover the base trousers' whole footprint; tops' and bags' shadows on trousers are kept as separate alpha.
4. Pack colour (JPG, bled past the edge) + mask PNG (R alpha, G signed distance, B shadow) per layer; the morph
   mixes two layers' distance fields on a spring (the outline melts) while the new colour pours in from the top.
5. Depth tilt: depth = dome over the union of all cut-out mattes; shade only the person so the white page stays white.

## Edges are where a mix-and-match photo breaks (judge every piece over the darkest other piece)
- **A layer's soft edge carries what its render had beside it** (the base's beige trousers), invisible over the
  base and a tan rim over jeans. Matte each edge pixel against the garment just inside (F) and the render just
  outside (B) — on the colour line AND on hue (trousers in the garment's shadow are darker than B, which on
  the colour line reads as garment). Skip edges against the white page (already clean); use F as the colour
  where the pixel is mostly B (un-mixing against a wrong B leaves red/grey lines at cuffs).
- **A shared layer peeks out beside per-render pieces that moved.** The base arm showed beside each sleeve:
  widen each top's sleeve over the shared arm above its cuff (sleeve colour mirrored outward), only where there
  is sleeve colour to copy.
- **A bag's shadow on the trousers comes out with the bag**: pixels with the base's hue, only darker, go to the
  bag's shadow layer. Pixels the render left unchanged (trousers between chain links, pulled in by closing the
  mask) are not bag either: weight alpha by how much the pixel changed, except deep inside the bag.
- Thin parts (chains, straps) need the unchanged-pixel test, not erosion (erosion eats them).
- Check with numbers: composite vs page off-body (≤ 2 levels), the floor between the legs in skirt looks, the
  photo's border ring = 255, then 2× crops of every sleeve, hem, hand and bag over jeans AND a black skirt.

## One hand per side
- Every render of a mix-and-match set has its own arms and hands, a few px off. Layers cut from them carry
  those arms: shared arm + bottoms' arm + bag's gripping hand = up to three hands. Decide who owns each hand:
  the bag side's hand belongs to the bag render below every top's cuff (the shared arm fades out there, the bag
  layer brings forearm + hand, the bottoms paint what the base hand covered); the other hand is the shared one.
- Find a render's arm as the BASE arm moved by the (dx, dy) that best lands it on skin-coloured pixels, then grown
  into skin next to it. Colour rules fail: rust-brown trousers and a cream tee both read as skin.
- Behind a removed arm paint the garment out to its own edge (edge carried across from rows where it shows,
  median-smoothed) and the page beyond, with a smooth fill: row-by-row mirroring leaves blocky steps.
- A gripping hand is the base hand moved onto skin, grown ~7 px into skin (knuckles round a strap). Too tight
  and the knuckles drop out (white page through them); too loose and tan shadows join the hand.
- Bag outlines over the page: take alpha from the render's cut-out matte and un-mix the colour from the page.
- Keep or drop, never half-keep: soft "how much it changed" weights make see-through ghosts.
- A bag's shadow as warm and dark as its own shaded leather can't be split by colour: use a small hand-placed
  shadow box where nothing is bag but the hand, and the darkening becomes the cast shadow.
- Debug by probing each layer's alpha at the bad pixel BEFORE changing anything: the culprit is often a different
  rule than the one you suspect.

## Re-cutting pieces with SAM 2 + matting (when colour-difference masks can't be fixed by more rules)
- Cut each piece with SAM 2.1, ONE prompt point per call and OR the masks (several points in one call return one
  object or nothing), reject a point whose mask is mostly outside the person's matte, and pick points on a gridded
  crop (guesses hit the page).
- Never join two photos on a line through a limb: give the arm to the layer that holds something (bag layer =
  bag + whole arm from the shoulder) and paint that arm out of the base photo. Draw it UNDER the tops.
- Edges: closed-form matting in a 3 px band round the SAM edge + ML foreground estimation; mark see-through gaps
  (pixels equal to the base or the white page inside the mask) as background so straps and chain links open.
- What a top leaves uncovered must be page, not the base's tee: paint out the base tee's shoulders and sleeves
  (dilate ~25 px: the real edge runs past SAM's), clear the matte's fringe in a band around it except hair, but
  keep the tee's body (hem slivers). Let each top own its render's hair beyond the base's hair, neck skin faded in.
- Check with an automatic scan for enclosed white patches on the person across 40 random looks, then frame by frame.

## Adding pieces from the phone's Photos (on-device, no AI service)
- Picker: SwiftUI `.photosPicker` (private access: no permission prompt, the app only gets the photo picked).
- Cut-out: Vision `VNGenerateForegroundInstanceMaskRequest` (Photos' "lift subject"). It FAILS in the Simulator
  ("Could not create inference context", even with the CPU compute device): test the Vision path on the Mac
  (a 30-line Swift script on the same photos), and ship a white-backdrop key as the fallback.
- White key that works (IoU 0.987–0.995 vs Vision on product photos): A = flood from the border in gentle colour
  steps (< 8/channel) through near-white or "darker with little tint for how much darker" pixels (takes the piece's
  shadow off), + enclosed flat pure-backdrop holes; B = plain "not the backdrop's colour" flood. A leaks into
  cream/white pieces through their own soft shading: use B when A keeps < 70 % of B's area. Do it at 600 px max
  side (~2–3 s in a debug Simulator build).
- Placement: hats by their CROWN (median width of rows 20–55 %), centred on the head, lowest point at the brow.
  Bags by their BODY width (below the handles), handles' top under the open hand; export the open hand as its own
  layer and show it over added bags.
- New textures: draw each once offscreen when it loads (WebKit uploads on first draw: a 132 ms frame otherwise).
- A debug-only launch hook (env var with path + slot) runs the whole import without the picker: scriptable tests.
- **Wearing an added top/bottoms without AI**: pick the rendered piece whose product silhouette overlaps the added
  one best (both scaled to one 40×40 box, IoU), copy its mask (fit, sleeves over arms, shadows) and re-dye its
  colour JPG: out = addedMidtoneColour × clamp(L/medianL, 0.15, 1.9) in linear light. Keeps folds and fabric
  texture; a pattern becomes its average colour. Users expect anything they add to be worn: say so up front.
- Slot long-press = a small custom Pin | Delete capsule above the slot (from the same drag-gesture timer), not a
  system contextMenu (its lift preview would be the invisible hit area).
