# Inputs, references and generators — with fallbacks

## Figma (the usual input)
- Follow the Figma-to-code steps in `craft.md` (section 12).
- Per linked node: `get_screenshot` (ground truth), `get_design_context` (sizes, colours, fonts, effects),
  `get_metadata` (tree), `download_assets` for raster art/illustrations at the highest scale, fonts used.
  Motion data in the file → `get_motion_context`.
- If the Figma MCP needs auth, ask for it to be authorised via `/mcp`. Meanwhile, if the frame is open in Figma
  (desktop or browser), export via a browser/computer-use route. Ask rather than guessing from a low-res
  screenshot when exact assets matter.
- **Huge Figma pages**: `get_metadata` on a page can overflow the MCP response. Find frames by name with a read-only
  `use_figma` (`page.findAll(n => /name/i.test(n.name))`), then dump only the properties you need.
- **Check `visible` on every stroke/effect** before drawing it: buttons often carry strokes and drop shadows that are
  switched off. Figma's `rx = h/2` + corner smoothing on a pill renders as a plain circular capsule.
- `download_assets` raw images include **hidden fills** (e.g. the art with its original background). Use the visible
  one (usually the RGBA cut-out); confirm against the frame export.
- **Figma avatar/image raws have a soft 1–2 px edge** (alpha < 250 on the outer row, transparent rounded corners): a
  circle inscribed edge-to-edge picks it up. Bake circles at 97 % of the side (4× supersampled mask, LANCZOS down),
  assert alpha ≥ 250 inside every circle, and reframe off-centre faces.

## References for how top apps animate this kind of screen
- **Mobbin**: prefer the Mobbin MCP if connected (`search_flows`, `search_screens`, `search_sections`,
  `save_content` into a collection named after the app); otherwise search mobbin.com in a browser. Read flows/videos,
  note the pattern, cite the apps. Describe the screen and its feel in the query ("notifications screen with filter
  pills, comment preview bubble and reply button") rather than a single keyword.
- **Pinterest** in a signed-in browser: navigate straight to `pinterest.com/search/pins/?q=...`, wait 2 s, screenshot
  at reduced scale, zoom into single pins for detail. Run 5–7 different queries (product view, shadow, material, UI,
  motion subject). Close the tab after.
- Use references only for structure, timing and layout. Never download reels or copy their music; drop brand names
  and logos from the version you build.

## Measuring motion from web references (browser JavaScript)
- `<video>` frames on many sites are **canvas-readable** (no CORS taint), so measure instead of eyeballing:
  - Cut times: seek every 1/15 s, draw at 36×64, take the mean RGB difference against the previous frame. Peaks above
    ~3× the median are cuts. When only a small inset changes, whole-frame diffs stay low: lower the threshold or diff
    only the inset's rectangle.
  - Contact sheet: draw frames at regular times onto a fixed full-screen canvas, then screenshot it once.
  - Helpers live on `window`: re-inject them after every navigation (a full page load).
- **GIF pins:** `fetch()` the original GIF from the pin page (CORS OK), decode it with
  `new ImageDecoder({data, type:'image/gif'})` to get every frame and its exact duration, draw onto a canvas sheet.
- **Video pins:** the on-page `<video>` is an MSE blob, so don't use it. The pin JSON holds the MP4 URLs
  (`videos.video_list.V_720P.url`, or `story_pin_data.pages[].blocks[].video.video_list` for Idea pins). Load that MP4
  in your own off-screen `<video crossOrigin="anonymous">` and seek it every 1/15–1/30 s. Pause the page's own videos
  first. A pin page can stall on first load; navigating again fixes it.
- **Mobbin's animations page** is a virtualised infinite list: collect each card's label and `<video>` `currentSrc`
  while scrolling (cards leave the DOM). If loading stalls at the bottom, scroll up ~1,200 px and back down in steps.
  Its MP4s are 720×1560 px (1 pt = 1.83 px) and canvas-readable in your own off-screen video. Check the frame rate
  with `requestVideoFrameCallback` at `playbackRate` 0.25: some are 30 fps content in a 60 fps container (each frame
  twice); seek to `(k+0.5)/60` and drop duplicates.
- Browser-tool scripts can time out (~45 s): start long loops without awaiting, write progress to `window.__status`,
  poll it, and write measurements to a scratch file as you go (a tab can vanish mid-session).
- To measure motion, scan pixels per frame: an edge row (first/last pixel matching a colour test in a column), a
  dark-pixel area (area ∝ scale², immune to rotation), the width of a row run (squash), colour bounding boxes from
  per-row/column counts above N (ignores text and small icons), the centroid of the frame-to-frame difference for
  small flying items, gradient sharpness for blur-ins.
- Fit springs from the 50 % and 90 % times: for a critically damped spring, 50 % falls at ωt = 1.68 and 90 % at
  ωt = 3.89; `response = 2π/ω`. Fit power ease curves too: system moves are usually critically damped springs
  (sheet ~0.33 s, small morphs ~0.22 s), but hero cards can be ease-out cubic (~0.5 s) and flights ease-in quad.
- Mock-up videos often zoom the camera during editing: flag those stretches and don't treat them as app motion.
  Some loops play the open in reverse as the close, so the close isn't real data.

## Measuring screenshots
- Crop the phone screen (inner bezel edges from dark runs along a row and a column), scale the crop to the device's
  point width, lay an 8 pt grid over it (labels every 40 pt). Margins, card heights, gaps and type sizes read straight
  off it. Font size ≈ cap height ÷ 0.72.
- Accent hex: median of the high-saturation pixels in a hue band. Page and card hex: most common colour in a region
  (PIL `getcolors` on flat patches; single-pixel samples hit borders).
- Full-resolution screenshots in a signed-in browser can be drawn into an in-page canvas to measure radii (fit against
  Apple's continuous corner shape), insets, chip and toast sizes, and shadow alpha. If the canvas is tainted, fetch the
  image as a blob and use `createImageBitmap`.
- Copying a screen from a screen recording: extract frames, read layout in points (frame px ÷ scale), and reproduce
  behaviours seen only in motion. Never copy logos.
- Theme boards render well as one HTML page through headless Chrome
  (`--headless=new --force-device-scale-factor=2 --allow-file-access-from-files --virtual-time-budget=4000 --screenshot`).
  SF Pro / New York installed in `/Library/Fonts` work by family name; SF Mono needs `@font-face` with
  `url(file:///System/Library/Fonts/SFNSMono.ttf)`. To read element positions back, write them into a hidden `<pre>`
  and use `--dump-dom` (take the *last* match; the dump also contains the script source).
- Run a contrast check on every colour-role pair before showing themes; fix failures by changing lightness, never
  hue. Tertiary greys usually fail (Apple's own tertiary label sits near 2.2:1); yellow and light sky only work as
  fills under dark text; a red/orange "signal" accent shouldn't tick checkboxes (reads as an error).

## Generated assets
- If an image/video generation service is connected (MCP or website), use it for things that can't be built
  procedurally in reasonable time (complex illustration pieces, textures, a 3D model, a motion reference video,
  background removal/upscale of supplied art). Show the credit cost before large jobs.
- Generated art must match the design's style; procedural is still preferred for the hero piece.
- 9:16 concept frames work well for "pick one of 4" motion directions before building.

## Rive / Lottie
- Supplied `.riv` or Lottie JSON → use them (Rive runtime in the web layer or rive-ios; lottie-ios for Lottie). Don't recreate a supplied vector animation by hand.

## When to ask (always allowed)
- Motion intent, sequence, feel, length, sound — before building (2–4 questions).
- Which parts are procedural vs keep-as-image when it isn't obvious.
- Before spending paid credits on big generations.
- Any time a reference suggests a direction different from what was described.
- When a colour or element is named loosely, list the 2–3 real candidates (with hex values) and ask.

## Pushing app screens to Figma
- **Real SF Symbols in Figma:** in an SF Pro text node, `figma.util.getSfSymbolCharacter("tram.fill")` renders the
  real glyph and stays editable/tintable. Without that helper, find the private-use character by shape:
  `scripts/sf_symbol_bitmap.swift <dir>/want <names…>` renders the names, `scripts/sf_symbol_codepoints.py <dir>`
  matches every SF Pro glyph (check the contact sheet by eye), then
  `t.fontName = {family:'SF Pro', style:'Semibold'}; t.characters = String.fromCodePoint(cp)`.
  Drawing a symbol into a PDF from Swift gives a bitmap, not paths. For true vectors: render to PNG at ~10×, trace
  with `vtracer` (`colormode="binary"`, `mode="polygon"`) and import with `figma.createNodeFromSvg`
  (`fill-rule="evenodd"`).
- **Match iOS text widths:** add Apple's default tracking to Figma text styles (34 pt +0.40, 28 pt +0.38,
  20 pt −0.45, 17 pt −0.43, 15 pt −0.23, 11 pt +0.06). iOS avoids one-word last lines; Figma doesn't, so use the app's
  own line breaks (one text node per line) to match its wrapping exactly.
- The Apple logo is U+F8FF in SF Pro: it stays editable text. Build multi-colour ring logos from `arcData` ellipses.
- Paint `opacity` on a variable-bound colour can read back as 1 (and comes out 1.0 in instances): put the opacity on
  the layer (`node.opacity`) or re-assign a JSON copy and read it back.
- Gradient stops can bind variables: `gradientStops: [{position, color, boundVariables: {color: {type: "VARIABLE_ALIAS", id}}}]`.
- No spacer frames: empty `createAutoLayout()` frames default to 100×100 and inflate rows; use `SPACE_BETWEEN`.
- `createAutoLayout`/`createFrame` default to `clipsContent = true`; set false on every frame (no-clipping default).
- Rotated cards: set `relativeTransform` about the centre (Figma rotation is counter-clockwise).
- Scrolling screens: build the full content height and pin a floating bar as an ABSOLUTE child with vertical
  constraint MAX. Stacked overlapping items: negative spacing + `itemReverseZIndex = true`.
- `upload_assets` without nodeIds drops a frame per picture on the page: take the imageHash from the reply, apply it
  where needed, then remove those frames.
- A failed `use_figma` script rolls back completely, including setup steps earlier in the same script.
- Apple's iOS community UI kit imports by key without adding the library (status bar, keyboard, alerts, menus,
  toggles); its colours follow its "Color Scheme" collection, so set that mode to Dark on dark screens.
- When pushed frames are hand-edited afterwards, dump the frame tree (sizes, gaps, paddings, radii, fills, hidden or
  deleted layers) and diff it against what you built; ask about big removals.
