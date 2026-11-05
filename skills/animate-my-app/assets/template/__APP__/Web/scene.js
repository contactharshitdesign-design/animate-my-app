// Scene engine: design-point ortho camera, one timeline clock, assets on the GPU before the clock starts,
// warm start, in-place replay, cues to SwiftUI. Animated parts live in their own scripts (see content.js)
// and talk to this file only through window.SCENE.
(function () {
  'use strict';

  // ---------- look-dev switches (query string) ----------
  const Q = new URLSearchParams(location.search);
  const FREEZE = Q.has('t') ? parseFloat(Q.get('t')) : null;     // freeze the timeline at ms
  if (Q.get('bg')) document.documentElement.style.background = Q.get('bg');
  const REDUCED = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;

  function post(ev) {
    try { window.webkit.messageHandlers.scene.postMessage(ev); } catch (e) { /* not in the app */ }
  }

  // ---------- design canvas mapping (Figma frame in points) ----------
  const W = window.innerWidth, H = window.innerHeight;
  const DW = 402, DH = 874;
  const k = Math.min(W / DW, H / DH);                              // px per design point
  const ox = (W - DW * k) / 2, oy = (H - DH * k) / 2;
  const toWorld = (x, y) => new THREE.Vector3(ox + x * k - W / 2, H / 2 - (oy + y * k), 0);

  // ---------- renderer / scene / camera ----------
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 3));
  renderer.setSize(W, H);
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.NoToneMapping;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.VSMShadowMap;
  document.body.appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const cam = new THREE.OrthographicCamera(-W / 2, W / 2, H / 2, -H / 2, 1, 4000);
  cam.position.set(0, 0, 1500);
  cam.lookAt(0, 0, 0);

  // soft studio light (clay reads well under it); parts may add their own
  scene.add(new THREE.HemisphereLight(0xffffff, 0xe2dbd0, 0.95));
  const key = new THREE.DirectionalLight(0xfff3e4, 3.2);
  key.position.set(-0.28, 0.72, 1.0).multiplyScalar(1000);
  scene.add(key);
  const fill = new THREE.DirectionalLight(0xe9f0ff, 0.5);
  fill.position.set(0.9, 0.05, 0.6).multiplyScalar(1000);
  scene.add(fill);

  // Apple-style damped spring: displacement from target, given damping ratio + response (s).
  function spring(x0, v0, zeta, response, t) {
    const w0 = 2 * Math.PI / response;
    if (zeta >= 1) return (x0 + (v0 + w0 * x0) * t) * Math.exp(-w0 * t);
    const wd = w0 * Math.sqrt(1 - zeta * zeta);
    return Math.exp(-zeta * w0 * t) * (x0 * Math.cos(wd * t) + ((v0 + zeta * w0 * x0) / wd) * Math.sin(wd * t));
  }

  // ---------- timeline ----------
  const tracks = [], cues = [], holds = [];
  let T_END = 0, lastT = -1, finished = false;
  function update(t) {
    if (t < lastT) cues.forEach(c => { c.sent = false; });         // replay re-arms the cues
    lastT = t;
    tracks.forEach(fn => fn(t));
    cues.forEach(c => { if (!c.sent && t >= c.t) { c.sent = true; post(c.ev); } });
    if (!finished && t > T_END) { finished = true; post('done'); }
  }

  let startTime = null, holdUntil = 0, rafOn = false;
  function frame(now) {
    if (now < holdUntil) { renderer.render(scene, cam); requestAnimationFrame(frame); return; }
    if (startTime === null) startTime = now;                        // clock starts on a frame actually drawn
    const t = FREEZE !== null ? FREEZE : now - startTime;
    update(t);
    renderer.render(scene, cam);
    if (FREEZE === null && !finished) requestAnimationFrame(frame);
    else rafOn = false;
  }

  // (re)start from the very first frame: blank right away, then warm frames so the compositor and GPU
  // are already running at full rate when the first thing moves
  function play(warmMs = 120) {
    startTime = null;
    finished = false;
    update(-1);
    renderer.render(scene, cam);
    holdUntil = performance.now() + warmMs;
    // tell the app only once the blank frame is actually on screen: lifting its veil on the same tick showed the
    // previous run's last frame for ~0.15 s (WebKit presents the canvas on its next rendering update)
    requestAnimationFrame(() => requestAnimationFrame(() => post('reset')));
    if (!rafOn) { rafOn = true; requestAnimationFrame(frame); }
  }
  window.scenePlay = play;

  // A texture that is decoded and uploaded to the GPU before the clock starts (loading mid-animation stalls).
  function loadTexture(file, opts = {}) {
    const tex = new THREE.Texture();
    tex.colorSpace = opts.data ? THREE.NoColorSpace : THREE.SRGBColorSpace;   // data maps: raw, RGB only
    if (opts.data) { tex.magFilter = tex.minFilter = THREE.LinearFilter; tex.generateMipmaps = false; tex.flipY = false; }
    Object.assign(tex, opts.props || {});
    holds.push(new Promise(res => {
      const img = new Image();
      img.onload = () => (img.decode ? img.decode() : Promise.resolve()).catch(() => {}).then(() => {
        tex.image = img; tex.needsUpdate = true; renderer.initTexture(tex); res();
      });
      img.onerror = () => { console.error('missing texture ' + file); res(); };
      img.src = file;
    }));
    return tex;
  }

  window.SCENE = {
    THREE, scene, cam, renderer, k, W, H, toWorld, spring, REDUCED, FREEZE, post,
    track: fn => tracks.push(fn),
    cue: (t, ev) => { cues.push({ t, ev, sent: false }); T_END = Math.max(T_END, t + 400); },
    extendEnd: t => { T_END = Math.max(T_END, t); },
    loadTexture,
    hold: p => holds.push(p),
  };

  // Boot after every part script has run and every asset is on the GPU: draw every mesh once (shaders
  // compiled, textures resident), go blank, then play with a longer warm-up so iOS's launch zoom settles.
  function boot() {
    Promise.all(holds).then(() => {
      const hidden = [];
      scene.traverse(o => { if (o.isMesh && !o.visible) { hidden.push(o); o.visible = true; } });
      renderer.render(scene, cam);
      hidden.forEach(o => { o.visible = false; });
      post('ready');
      play(450);
    });
  }
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot); else setTimeout(boot, 0);
})();
