// Demo part — replace with the design's hero animation. Shows the patterns every part follows:
// state is a pure function of t (so replays are identical), physics via springs, volume-preserving squash,
// a contact shadow that reacts to height, and cues that bring in the native UI.
(function () {
  'use strict';
  const S = window.SCENE;
  if (!S) return;
  const { THREE, scene, toWorld, spring, k, REDUCED } = S;

  // a soft clay pill (replace with procedural geometry built for the design)
  const body = new THREE.Mesh(
    new THREE.CapsuleGeometry(34 * k, 60 * k, 12, 32),
    new THREE.MeshPhysicalMaterial({ color: 0xF6BE2C, roughness: 0.55, sheen: 0.35, sheenColor: 0xffffff }));
  body.rotation.z = Math.PI / 2;
  const pivot = new THREE.Group();                 // pivot at the object's base, so squash stays grounded
  body.position.y = 34 * k;
  pivot.add(body);
  scene.add(pivot);

  // contact shadow: radial-gradient blob on the ground
  const c = document.createElement('canvas'); c.width = c.height = 128;
  const g = c.getContext('2d'), gr = g.createRadialGradient(64, 64, 0, 64, 64, 64);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.45, 'rgba(255,255,255,0.4)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, 128, 128);
  const shadow = new THREE.Mesh(new THREE.PlaneGeometry(1, 1),
    new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(c), color: 0x2a1e14, transparent: true, depthWrite: false, opacity: 0 }));
  shadow.renderOrder = -1;
  scene.add(shadow);

  const GROUND = toWorld(201, 470), T0 = 80, FALL = 0.32, DROP = 260 * k;
  S.track((t) => {
    const s = (t - T0) / 1000;
    if (s < 0) { pivot.visible = shadow.visible = false; return; }
    pivot.visible = shadow.visible = true;
    let y = 0, sy = 1;
    if (REDUCED) { y = 0; }
    else if (s < FALL) { const u = s / FALL; y = DROP * (1 - u * u); sy = 1 + 0.18 * u; }   // gravity, stretched by speed
    else { const tl = s - FALL; y = spring(0, 260 * k, 0.5, 0.32, tl); sy = 1 + spring(-0.22, -8, 0.42, 0.3, tl); }  // squash + hop
    const sx = 1 / Math.sqrt(Math.max(sy, 0.3));   // keep the clay's volume
    pivot.position.set(GROUND.x, GROUND.y + Math.max(0, y), 0);
    pivot.scale.set(sx, sy, sx);
    const h = Math.max(0, y) / (100 * k);
    shadow.position.set(GROUND.x, GROUND.y - 2 * k, -10);
    shadow.scale.set(150 * k * sx * (1 + 0.4 * h), 34 * k * (1 + 0.3 * h), 1);
    shadow.material.opacity = 0.3 * Math.exp(-1.2 * h) * Math.min(1, s / 0.1);
  });

  // native UI comes in after the hero has landed (staging gated on arrival)
  S.cue(T0 + FALL * 1000 + 450, 'headline');
  S.cue(T0 + FALL * 1000 + 600, 'button');

  // Textures for real parts: const tex = S.loadTexture('my-art.png');  (on the GPU before the clock starts)
})();
